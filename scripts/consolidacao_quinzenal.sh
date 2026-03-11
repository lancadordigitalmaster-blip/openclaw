#!/bin/bash
# consolidacao_quinzenal.sh — Wolf Agency
# Cron: dias 1 e 15, 06h | Consolida notas diarias dos ultimos 15 dias

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
DAILY="$WORKSPACE/memory/daily"
DONE_FILE="$WORKSPACE/memory/DONE.md"
LOG_FILE="$WORKSPACE/memory/logs/consolidacao_quinzenal.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_DISPLAY=$(date '+%d/%m/%Y')

mkdir -p "$(dirname "$LOG_FILE")" "$DAILY"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

# Listar notas dos ultimos 15 dias
NOTES=$(find "$DAILY" -name "*.md" -mtime -15 2>/dev/null | sort)
NOTE_COUNT=$(echo "$NOTES" | grep -c "." 2>/dev/null || echo "0")

if [ "$NOTE_COUNT" -eq 0 ]; then
  log "Nenhuma nota diaria nos ultimos 15 dias"
  echo "OK: consolidacao_quinzenal — 0 notas encontradas"
  exit 0
fi

# Extrair itens relevantes de cada nota
ITEMS_FOUND=0
CONSOLIDATED=""

for f in $NOTES; do
  BASENAME=$(basename "$f" .md)
  MATCHES=$(grep -iE "conclu|decis|penden|urgente|bloqu|resolvid|implement" "$f" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    CONSOLIDATED="$CONSOLIDATED
### $BASENAME
$MATCHES
"
    ITEM_COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
    ITEMS_FOUND=$(( ITEMS_FOUND + ITEM_COUNT ))
  fi
done

# Append ao DONE.md se houver itens
if [ $ITEMS_FOUND -gt 0 ] && [ -f "$DONE_FILE" ]; then
  echo "" >> "$DONE_FILE"
  echo "## Consolidacao Quinzenal — $DATE_DISPLAY" >> "$DONE_FILE"
  echo "$CONSOLIDATED" >> "$DONE_FILE"
fi

# Telegram — tom conversacional
MSG="Netto, fiz a consolidacao quinzenal.

Passei por *$NOTE_COUNT notas* dos ultimos 15 dias e encontrei *$ITEMS_FOUND itens* relevantes (decisoes, pendencias, conclusoes).

Tudo registrado no DONE.md."

send_telegram "$MSG"
log "Consolidacao concluida — $NOTE_COUNT notas, $ITEMS_FOUND itens"
echo "OK: consolidacao_quinzenal completed at $TIMESTAMP"
