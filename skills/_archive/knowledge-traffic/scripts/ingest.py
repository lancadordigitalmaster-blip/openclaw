#!/usr/bin/env python3
import re, sys, json, argparse
from pathlib import Path

def clean_transcript(text):
    text = re.sub(r'\[?\d{1,2}:\d{2}(?::\d{2})?\]?', '', text)
    text = re.sub(r'^[A-Z][A-Z\s]+:\s*', '', text, flags=re.MULTILINE)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r' {2,}', ' ', text)
    return text.strip()

def detect_topic(chunk):
    topics = {
        'Meta Ads':   ['meta ads','facebook ads','instagram ads','gerenciador','conjunto de anúncios'],
        'Google Ads': ['google ads','search ads','display','youtube ads','pmax'],
        'Públicos':   ['público','audience','lookalike','remarketing','custom audience'],
        'Criativos':  ['criativo','copy','imagem','vídeo','hook','headline','cta'],
        'Orçamento':  ['orçamento','budget','bid','lance','custo','cpa','roas'],
        'Otimização': ['otimização','performance','escalar','testar','ab test','split'],
        'Estrutura':  ['estrutura','campanha','adset','funil','topo','meio','fundo'],
        'Análise':    ['análise','métricas','kpi','relatório','dashboard','dados'],
    }
    cl = chunk.lower()
    for topic, kws in topics.items():
        if any(k in cl for k in kws):
            return topic
    return 'Geral'

def chunk_text(text, chunk_size=600, overlap=100):
    paragraphs = text.split('\n\n')
    chunks, current, idx = [], '', 0
    for para in paragraphs:
        para = para.strip()
        if not para: continue
        if len(current) + len(para) > chunk_size and current:
            chunks.append({'chunk_index':idx,'content':current.strip(),'topic':detect_topic(current),'char_count':len(current)})
            current = current[-overlap:] + '\n\n' + para
            idx += 1
        else:
            current = (current + '\n\n' + para).strip()
    if current.strip():
        chunks.append({'chunk_index':idx,'content':current.strip(),'topic':detect_topic(current),'char_count':len(current)})
    return chunks

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('file')
    parser.add_argument('--source', default='Curso de Tráfego')
    parser.add_argument('--out', default='chunks.json')
    args = parser.parse_args()
    raw = Path(args.file).read_text(encoding='utf-8')
    chunks = chunk_text(clean_transcript(raw))
    output = {'source':args.source,'total_chunks':len(chunks),'chunks':chunks}
    Path(args.out).write_text(json.dumps(output, ensure_ascii=False, indent=2))
    print(f"✅ {len(chunks)} chunks gerados de '{args.source}'")
    print(f"   Tópicos encontrados: {sorted(set(c['topic'] for c in chunks))}")
    print(f"   Salvo em: {args.out}")

if __name__ == '__main__':
    main()
