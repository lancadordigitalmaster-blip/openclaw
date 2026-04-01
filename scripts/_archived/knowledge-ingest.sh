#!/bin/bash
# ============================================================
# knowledge-ingest.sh — Wrapper para o pipeline Video → Knowledge Base
# Suporta YouTube, Instagram, TikTok
#
# Uso:
#   ./knowledge-ingest.sh "URL" "Nome da Fonte" [topico]
#
# Exemplos:
#   ./knowledge-ingest.sh "https://youtube.com/watch?v=XXX" "Curso Meta Ads" "Meta Ads"
#   ./knowledge-ingest.sh "https://instagram.com/reel/XXX" "Reel Pedro Sobral"
#   ./knowledge-ingest.sh "https://tiktok.com/@user/video/XXX" "TikTok Dica"
# ============================================================

set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

SCRIPT_DIR="$HOME/.openclaw/workspace/skills/knowledge-traffic/scripts"
PIPELINE="$SCRIPT_DIR/youtube-to-knowledge.py"

URL="${1:-}"
SOURCE="${2:-}"
TOPIC="${3:-}"

if [[ -z "$URL" || -z "$SOURCE" ]]; then
  echo "Uso: $0 \"URL\" \"Nome da Fonte\" [topico]"
  echo ""
  echo "Exemplos:"
  echo "  $0 \"https://youtube.com/watch?v=XXX\" \"Curso Meta Ads\" \"Meta Ads\""
  echo "  $0 \"https://instagram.com/reel/XXX\" \"Reel Pedro Sobral\""
  exit 1
fi

ARGS=("$URL" --source "$SOURCE")
[[ -n "$TOPIC" ]] && ARGS+=(--topic "$TOPIC")

echo "Iniciando pipeline..."
python3 "$PIPELINE" "${ARGS[@]}"
