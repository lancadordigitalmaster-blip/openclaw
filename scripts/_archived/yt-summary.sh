#!/bin/bash
# yt-summary.sh — Resumo de YouTube 100% gratuito
# Usa: yt-dlp (transcricao) + Gemini Flash (resumo)
# Sem dependencias externas, sem API paga
#
# Uso: ./scripts/yt-summary.sh "https://www.youtube.com/watch?v=VIDEO_ID"

set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"

VIDEO_URL="${1:?Uso: yt-summary.sh URL_DO_VIDEO}"
GOOGLE_API_KEY="${GOOGLE_API_KEY:-$(grep GOOGLE_API_KEY ~/.openclaw/.env 2>/dev/null | cut -d= -f2)}"

if [ -z "$GOOGLE_API_KEY" ]; then
  echo "ERRO: GOOGLE_API_KEY nao encontrada" >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# 1. Extrair transcricao com yt-dlp (GRATIS) — com impersonation para evitar rate limit
yt-dlp --impersonate chrome --write-auto-sub --sub-lang pt --sub-format srt \
  --skip-download -o "$TMPDIR/video" "$VIDEO_URL" 2>/dev/null || true

SRT_FILE=$(ls "$TMPDIR"/video*.srt 2>/dev/null | head -1)
if [ -z "$SRT_FILE" ]; then
  # Tentar sem impersonation
  yt-dlp --write-auto-sub --sub-lang pt --sub-format srt \
    --skip-download -o "$TMPDIR/video" "$VIDEO_URL" 2>/dev/null || true
  SRT_FILE=$(ls "$TMPDIR"/video*.srt 2>/dev/null | head -1)
fi

if [ -z "$SRT_FILE" ]; then
  # Tentar ingles se portugues nao disponivel
  yt-dlp --impersonate chrome --write-auto-sub --sub-lang en --sub-format srt \
    --skip-download -o "$TMPDIR/video" "$VIDEO_URL" 2>/dev/null || true
  SRT_FILE=$(ls "$TMPDIR"/video*.srt 2>/dev/null | head -1)
fi

if [ -z "$SRT_FILE" ]; then
  # Ultimo recurso: sem impersonation + ingles
  yt-dlp --write-auto-sub --sub-lang en --sub-format srt \
    --skip-download -o "$TMPDIR/video" "$VIDEO_URL" 2>/dev/null || true
  SRT_FILE=$(ls "$TMPDIR"/video*.srt 2>/dev/null | head -1)
fi

if [ -z "$SRT_FILE" ]; then
  echo "ERRO: Nao foi possivel extrair transcricao do video" >&2
  echo "Tente usar o browser built-in: browser open \"$VIDEO_URL\"" >&2
  exit 1
fi

# 2. Limpar SRT -> texto puro (remover timestamps e duplicatas)
python3 -c "
import sys, re
seen = set()
lines = []
for line in open('$SRT_FILE'):
    line = line.strip()
    if not line: continue
    if line.isdigit(): continue
    if '-->' in line: continue
    line = re.sub(r'<[^>]+>', '', line)
    if line and line not in seen:
        seen.add(line)
        lines.append(line)
text = ' '.join(lines)[:30000]
print(text)
" > "$TMPDIR/transcript.txt"

WORD_COUNT=$(wc -w < "$TMPDIR/transcript.txt" | tr -d ' ')

if [ "$WORD_COUNT" -lt 5 ]; then
  echo "ERRO: Transcricao muito curta ($WORD_COUNT palavras)" >&2
  exit 1
fi

# 3. Resumir com Gemini 2.5 Flash (GRATIS - free tier)
python3 -c "
import json, urllib.request, sys

with open('$TMPDIR/transcript.txt') as f:
    transcript = f.read()

prompt = '''Resuma este video do YouTube em portugues brasileiro.

Formato OBRIGATORIO (mantenha exatamente estas secoes):

# [TITULO DO VIDEO]
**Canal:** [nome do canal/autor]
**Duracao:** estimada baseada no conteudo

## Pontos Principais
1. [ponto detalhado]
2. [ponto detalhado]
3. [ponto detalhado]
4. [ponto detalhado]
5. [ponto detalhado]

## Takeaway Principal
[mensagem central do video em 2-3 frases]

## Citacoes
> \"[citacao direta relevante do video]\"
> \"[outra citacao direta relevante]\"

TRANSCRICAO:
''' + transcript

payload = json.dumps({
    'contents': [{'parts': [{'text': prompt}]}],
    'generationConfig': {'maxOutputTokens': 2048, 'temperature': 0.3}
})

req = urllib.request.Request(
    f'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GOOGLE_API_KEY',
    data=payload.encode(),
    headers={'Content-Type': 'application/json'}
)

resp = urllib.request.urlopen(req, timeout=120)
data = json.loads(resp.read())
summary = data['candidates'][0]['content']['parts'][0]['text']
print(summary)
print()
print(f'---')
print(f'Palavras transcritas: {$WORD_COUNT} | Modelo: gemini-2.5-flash | Custo: \$0.00')
"
