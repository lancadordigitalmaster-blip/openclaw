#!/usr/bin/env python3
"""
youtube-to-knowledge.py — Pipeline completo: Video → Base de Conhecimento vetorizada

Suporta: YouTube, Instagram (Reels/Posts), TikTok, e qualquer URL compativel com yt-dlp.

Fluxo:
  1. Baixa audio do video (yt-dlp)
  2. Converte para chunks de 24MB (ffmpeg) — limite do Groq Whisper
  3. Transcreve cada chunk (Groq Whisper large-v3)
  4. Organiza transcricao em documento estruturado (Gemini)
  5. Chunka o documento para RAG
  6. Gera embeddings (Gemini embedding)
  7. Armazena no Supabase pgvector

Uso:
  # YouTube
  python3 youtube-to-knowledge.py "https://youtube.com/watch?v=XXXX" --source "Nome do Curso"
  python3 youtube-to-knowledge.py "https://youtube.com/watch?v=XXXX" --source "Aula Meta Ads" --topic "Meta Ads"

  # Instagram (requer cookies)
  python3 youtube-to-knowledge.py "https://instagram.com/reel/XXXX" --source "Reel Fulano" --cookies-from-browser chrome

  # Playlist inteira
  python3 youtube-to-knowledge.py "https://youtube.com/playlist?list=XXXX" --source "Playlist" --playlist
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from dotenv import load_dotenv

# Garantir que homebrew binarios estao no PATH
os.environ['PATH'] = '/opt/homebrew/bin:' + os.environ.get('PATH', '')

# Carregar .env
load_dotenv(Path.home() / '.openclaw/workspace/.env')

GROQ_API_KEY = os.environ.get('GROQ_API_KEY', '')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY', '')
SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SUPABASE_SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', '')

WORKSPACE = Path.home() / '.openclaw/workspace'
KB_DIR = WORKSPACE / 'shared/memory'

# Limites
WHISPER_MAX_BYTES = 24 * 1024 * 1024  # 24MB por chunk (Groq limit = 25MB)
CHUNK_DURATION_SEC = 600  # 10 min por chunk de audio


def step(n, msg):
    print(f"\n{'='*60}")
    print(f"  PASSO {n}: {msg}")
    print(f"{'='*60}\n")


# ─────────────────────────────────────────────
# PASSO 1: Baixar audio do YouTube
# ─────────────────────────────────────────────
def detect_platform(url):
    """Detecta plataforma pela URL"""
    url_lower = url.lower()
    if 'instagram.com' in url_lower:
        return 'instagram'
    if 'tiktok.com' in url_lower:
        return 'tiktok'
    if 'youtube.com' in url_lower or 'youtu.be' in url_lower:
        return 'youtube'
    return 'other'


def download_audio(url, output_dir, cookies_from_browser=None, allow_playlist=False):
    platform = detect_platform(url)
    step(1, f"Baixando audio ({platform})")

    output_path = os.path.join(output_dir, "audio.%(ext)s")
    cmd = [
        "yt-dlp",
        "-x",  # extract audio
        "--audio-format", "mp3",
        "--audio-quality", "5",  # quality 5 = ~130kbps (bom pra transcricao)
        "-o", output_path,
        url
    ]

    if not allow_playlist:
        cmd.insert(-1, "--no-playlist")

    # Instagram/TikTok precisam de cookies para conteudo privado
    if cookies_from_browser:
        cmd.insert(-1, "--cookies-from-browser")
        cmd.insert(-1, cookies_from_browser)
    elif platform == 'instagram':
        # Tentar cookies do Chrome automaticamente
        cmd.insert(-1, "--cookies-from-browser")
        cmd.insert(-1, "chrome")

    # YouTube: tentar impersonate primeiro
    if platform == 'youtube':
        cmd_with_imp = cmd.copy()
        cmd_with_imp.insert(-1, "--impersonate")
        cmd_with_imp.insert(-1, "chrome")
        result = subprocess.run(cmd_with_imp, capture_output=True, text=True)
        if result.returncode == 0:
            cmd = cmd_with_imp  # usou impersonate com sucesso
        else:
            print(f"  impersonate falhou, tentando sem...")
            result = subprocess.run(cmd, capture_output=True, text=True)
    else:
        result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"  yt-dlp stderr: {result.stderr[:500]}")
        raise RuntimeError(f"yt-dlp falhou para {platform}: {result.stderr[:300]}")

    # Encontrar arquivo(s) baixado(s)
    audio_files = sorted([
        os.path.join(output_dir, f)
        for f in os.listdir(output_dir)
        if f.startswith("audio") and not f.endswith('.part')
    ])

    if not audio_files:
        raise RuntimeError("Arquivo de audio nao encontrado apos download")

    for path in audio_files:
        size_mb = os.path.getsize(path) / (1024*1024)
        print(f"  Audio baixado: {os.path.basename(path)} ({size_mb:.1f} MB)")

    return audio_files[0]


# ─────────────────────────────────────────────
# PASSO 2: Dividir audio em chunks
# ─────────────────────────────────────────────
def split_audio(audio_path, output_dir):
    step(2, "Dividindo audio em chunks de 10min")
    size = os.path.getsize(audio_path)
    if size <= WHISPER_MAX_BYTES:
        print(f"  Audio pequeno ({size/(1024*1024):.1f} MB) — sem necessidade de split")
        return [audio_path]

    # Usar ffmpeg para dividir
    chunks = []
    cmd = [
        "ffmpeg", "-i", audio_path,
        "-f", "segment",
        "-segment_time", str(CHUNK_DURATION_SEC),
        "-c:a", "libmp3lame",
        "-q:a", "5",
        "-y",
        os.path.join(output_dir, "chunk_%03d.mp3")
    ]
    subprocess.run(cmd, capture_output=True, text=True, check=True)

    for f in sorted(os.listdir(output_dir)):
        if f.startswith("chunk_") and f.endswith(".mp3"):
            path = os.path.join(output_dir, f)
            size_mb = os.path.getsize(path) / (1024*1024)
            chunks.append(path)
            print(f"  {f}: {size_mb:.1f} MB")

    print(f"  Total: {len(chunks)} chunks")
    return chunks


# ─────────────────────────────────────────────
# PASSO 3: Transcrever com Groq Whisper
# ─────────────────────────────────────────────
def transcribe_chunks(chunk_paths):
    step(3, f"Transcrevendo {len(chunk_paths)} chunks com Groq Whisper")
    import httpx

    full_text = []
    for i, path in enumerate(chunk_paths):
        print(f"  [{i+1}/{len(chunk_paths)}] Transcrevendo {os.path.basename(path)}...")
        with open(path, "rb") as f:
            files = {"file": (os.path.basename(path), f, "audio/mpeg")}
            data = {
                "model": "whisper-large-v3",
                "language": "pt",
                "response_format": "verbose_json",
            }
            headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}

            resp = httpx.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers=headers,
                files=files,
                data=data,
                timeout=300,
            )

        if resp.status_code != 200:
            print(f"  ERRO chunk {i+1}: {resp.status_code} — {resp.text[:200]}")
            continue

        result = resp.json()
        text = result.get("text", "")
        segments = result.get("segments", [])

        # Adicionar timestamps dos segmentos
        for seg in segments:
            start = int(seg.get("start", 0))
            offset = i * CHUNK_DURATION_SEC
            total_sec = start + offset
            mins, secs = divmod(total_sec, 60)
            full_text.append(f"[{mins:02d}:{secs:02d}] {seg.get('text', '').strip()}")

        if not segments and text:
            full_text.append(text)

        print(f"  [{i+1}/{len(chunk_paths)}] OK — {len(segments)} segmentos")
        if i < len(chunk_paths) - 1:
            time.sleep(1)  # rate limit

    transcript = "\n".join(full_text)
    print(f"\n  Transcricao total: {len(transcript)} chars, {len(transcript.split())} palavras")
    return transcript


# ─────────────────────────────────────────────
# PASSO 4: Organizar em documento estruturado
# ─────────────────────────────────────────────
def organize_transcript(transcript, source, url, topic=None):
    step(4, "Organizando transcricao em documento estruturado (Gemini)")
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)

    topic_hint = f"\nTopico principal: {topic}" if topic else ""

    prompt = f"""Voce e um organizador de conhecimento profissional.

Recebeu a transcricao bruta de um video/aula. Sua tarefa e transformar isso em um
DOCUMENTO DE BASE DE CONHECIMENTO estruturado e denso.

REGRAS:
1. Mantenha TODOS os dados, numeros, exemplos e insights — nao resuma demais
2. Organize em secoes logicas com headers claros (## e ###)
3. Use bullet points para listas
4. Preserve citacoes importantes entre aspas
5. Adicione um resumo executivo no inicio
6. No final, liste "Licoes-Chave" numeradas
7. Remova repeticoes, hesitacoes e filler words
8. Mantenha o tom e estilo do autor original
9. Escreva em portugues brasileiro

METADATA:
- Fonte: {source}
- URL: {url}{topic_hint}

TRANSCRICAO BRUTA:
{transcript[:80000]}

Gere o documento de base de conhecimento completo e organizado:"""

    model = genai.GenerativeModel("gemini-2.5-flash")
    response = model.generate_content(prompt)
    organized = response.text

    print(f"  Documento organizado: {len(organized)} chars")
    return organized


# ─────────────────────────────────────────────
# PASSO 5: Salvar como .md
# ─────────────────────────────────────────────
def save_knowledge_base(organized_text, source, url):
    step(5, "Salvando documento .md")
    slug = re.sub(r'[^a-z0-9]+', '-', source.lower()).strip('-')
    filename = f"kb-{slug}.md"
    filepath = KB_DIR / filename

    header = f"""# Base de Conhecimento: {source}

**Fonte:** {source}
**URL:** {url}
**Data de extracao:** {time.strftime('%Y-%m-%d')}
**Pipeline:** youtube-to-knowledge.py (audio → Whisper → Gemini → pgvector)

---

"""
    KB_DIR.mkdir(parents=True, exist_ok=True)
    filepath.write_text(header + organized_text, encoding='utf-8')
    print(f"  Salvo em: {filepath}")
    return filepath


# ─────────────────────────────────────────────
# PASSO 6: Chunkar para RAG
# ─────────────────────────────────────────────
def chunk_document(text, source, chunk_size=None, overlap=None):
    step(6, "Chunkando documento para RAG")

    # Auto-adapt chunk size based on document length
    doc_len = len(text)
    if chunk_size is None:
        if doc_len < 5000:        # video curto (reels, shorts)
            chunk_size = 800
            overlap = 150
        elif doc_len < 20000:     # video medio (10-20min)
            chunk_size = 1800
            overlap = 300
        elif doc_len < 80000:     # aula longa (30-60min)
            chunk_size = 3000
            overlap = 500
        else:                     # curso completo (1h+)
            chunk_size = 5000
            overlap = 800
    if overlap is None:
        overlap = int(chunk_size * 0.17)

    print(f"  Documento: {doc_len:,} chars → chunk_size={chunk_size}, overlap={overlap}")
    topics_map = {
        'Meta Ads':   ['meta ads','facebook ads','instagram ads','gerenciador','conjunto de anuncios'],
        'Google Ads': ['google ads','search ads','display','youtube ads','pmax'],
        'Publicos':   ['publico','audience','lookalike','remarketing','custom audience'],
        'Criativos':  ['criativo','copy','imagem','video','hook','headline','cta'],
        'Orcamento':  ['orcamento','budget','bid','lance','custo','cpa','roas'],
        'Otimizacao': ['otimizacao','performance','escalar','testar','ab test','split'],
        'Estrutura':  ['estrutura','campanha','adset','funil','topo','meio','fundo'],
        'Analise':    ['analise','metricas','kpi','relatorio','dashboard','dados'],
        'Vendas':     ['venda','proposta','fechamento','objecao','preco','negociacao'],
        'Copy':       ['copy','headline','gancho','persuasao','storytelling','oferta'],
        'IA':         ['ia','inteligencia artificial','prompt','agente','llm','gpt','claude','openclaw'],
        'Gestao':     ['gestao','processo','equipe','delegacao','lideranca','operacao'],
    }

    def detect_topic(chunk_text):
        cl = chunk_text.lower()
        for topic, kws in topics_map.items():
            if any(k in cl for k in kws):
                return topic
        return 'Geral'

    # Split by sections (## headers) first, then by paragraphs within sections
    sections = re.split(r'\n(?=## )', text)
    chunks, idx = [], 0

    for section in sections:
        section = section.strip()
        if not section:
            continue

        # If section fits in one chunk, keep it whole
        if len(section) <= chunk_size:
            chunks.append({
                'chunk_index': idx,
                'content': section,
                'topic': detect_topic(section),
                'char_count': len(section),
            })
            idx += 1
            continue

        # Section too large — split by paragraphs with overlap
        paragraphs = section.split('\n\n')
        current = ''
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            if len(current) + len(para) > chunk_size and current:
                chunks.append({
                    'chunk_index': idx,
                    'content': current.strip(),
                    'topic': detect_topic(current),
                    'char_count': len(current),
                })
                # Overlap: keep tail of previous chunk for context continuity
                current = current[-overlap:] + '\n\n' + para
                idx += 1
            else:
                current = (current + '\n\n' + para).strip()
        if current.strip():
            chunks.append({
                'chunk_index': idx,
                'content': current.strip(),
                'topic': detect_topic(current),
                'char_count': len(current),
            })
            idx += 1

    topics_found = sorted(set(c['topic'] for c in chunks))
    print(f"  {len(chunks)} chunks gerados (tamanho alvo: {chunk_size} chars, overlap: {overlap})")
    print(f"  Topicos: {topics_found}")
    return chunks


# ─────────────────────────────────────────────
# PASSO 7: Embeddings + Supabase
# ─────────────────────────────────────────────
def embed_and_store(chunks, source):
    step(7, "Gerando embeddings e armazenando no pgvector")
    import google.generativeai as genai
    from supabase import create_client

    genai.configure(api_key=GEMINI_API_KEY)
    sb = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    MODEL = 'models/gemini-embedding-001'
    BATCH_SIZE = 20

    # Embed em batches
    for i in range(0, len(chunks), BATCH_SIZE):
        batch = chunks[i:i+BATCH_SIZE]
        texts = [c['content'] for c in batch]
        embs = genai.embed_content(
            model=MODEL,
            content=texts,
            task_type='retrieval_document'
        )['embedding']
        for c, e in zip(batch, embs):
            c['embedding'] = e
        print(f"  [{i+len(batch)}/{len(chunks)}] embeddings gerados")
        if i + BATCH_SIZE < len(chunks):
            time.sleep(0.5)

    # Store no Supabase
    ok, err = 0, 0
    for c in chunks:
        try:
            sb.table('knowledge_base').insert({
                'source': source,
                'topic': c['topic'],
                'chunk_index': c['chunk_index'],
                'content': c['content'],
                'embedding': c['embedding'],
                'metadata': {
                    'char_count': c.get('char_count', 0),
                    'pipeline': 'youtube-to-knowledge',
                },
            }).execute()
            ok += 1
        except Exception as e:
            print(f"  Erro chunk {c['chunk_index']}: {e}")
            err += 1

    print(f"\n  {ok} chunks inseridos, {err} erros")
    print(f"  Fonte '{source}' disponivel para Oracle")
    return ok, err


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description='Video → Base de Conhecimento vetorizada (YouTube, Instagram, TikTok)')
    parser.add_argument('url', help='URL do video (YouTube, Instagram Reel, TikTok)')
    parser.add_argument('--source', required=True, help='Nome da fonte (ex: "Curso Meta Ads")')
    parser.add_argument('--topic', default=None, help='Topico principal (opcional)')
    parser.add_argument('--skip-vectorize', action='store_true', help='Pular vetorizacao (so gera .md)')
    parser.add_argument('--transcript-file', default=None, help='Usar transcricao existente em vez de baixar')
    parser.add_argument('--cookies-from-browser', default=None, help='Browser para cookies (chrome, firefox, safari)')
    parser.add_argument('--playlist', action='store_true', help='Permitir download de playlist inteira')
    args = parser.parse_args()

    platform = detect_platform(args.url)
    print(f"\n{'#'*60}")
    print(f"  Video → Knowledge Base Pipeline")
    print(f"  Plataforma: {platform}")
    print(f"  URL: {args.url}")
    print(f"  Fonte: {args.source}")
    print(f"{'#'*60}")

    with tempfile.TemporaryDirectory(prefix="yt-kb-") as tmpdir:
        # Transcricao
        if args.transcript_file:
            print(f"\n  Usando transcricao existente: {args.transcript_file}")
            transcript = Path(args.transcript_file).read_text(encoding='utf-8')
        else:
            audio_path = download_audio(args.url, tmpdir, args.cookies_from_browser, args.playlist)
            chunk_paths = split_audio(audio_path, tmpdir)
            transcript = transcribe_chunks(chunk_paths)

            # Salvar transcricao bruta
            raw_path = KB_DIR / f"raw-transcript-{re.sub(r'[^a-z0-9]+', '-', args.source.lower()).strip('-')}.txt"
            raw_path.write_text(transcript, encoding='utf-8')
            print(f"\n  Transcricao bruta salva: {raw_path}")

        # Organizar
        organized = organize_transcript(transcript, args.source, args.url, args.topic)
        kb_path = save_knowledge_base(organized, args.source, args.url)

        # Vetorizar
        if not args.skip_vectorize:
            chunks = chunk_document(organized, args.source)
            ok, err = embed_and_store(chunks, args.source)
        else:
            print("\n  Vetorizacao pulada (--skip-vectorize)")

    print(f"\n{'#'*60}")
    print(f"  CONCLUIDO")
    print(f"  Documento: {kb_path}")
    if not args.skip_vectorize:
        print(f"  Chunks no pgvector: {ok}")
    print(f"  Pronto para consulta via Oracle")
    print(f"{'#'*60}\n")


if __name__ == '__main__':
    main()
