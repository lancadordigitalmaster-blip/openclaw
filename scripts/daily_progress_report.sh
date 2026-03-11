#!/bin/bash
# daily_progress_report.sh — Wolf Agency
# Cron: 22:30 diario | Consolida tasks do dia, gera nota, move concluidas

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
DAILY="$WORKSPACE/memory/daily"
LOG_FILE="$WORKSPACE/memory/logs/daily_progress.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TODAY=$(date '+%Y-%m-%d')
DATE_DISPLAY=$(date '+%d/%m/%Y')

mkdir -p "$DAILY" "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

DONE="$(grep -icE '^\- \[x\]' "$QUEUE" 2>/dev/null || true)"
DONE="${DONE%%$'\n'*}"; DONE="${DONE:-0}"
OPEN="$(grep -c '^\- \[ \]' "$QUEUE" 2>/dev/null || true)"
OPEN="${OPEN%%$'\n'*}"; OPEN="${OPEN:-0}"
URGENT="$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c '^\- \[ \]' 2>/dev/null || true)"
URGENT="${URGENT%%$'\n'*}"; URGENT="${URGENT:-0}"

# Gerar nota diaria
DONE_LIST=$(grep "^- \[x\]\|^- \[X\]" "$QUEUE" 2>/dev/null || echo "_Nenhuma_")
URGENT_LIST=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep "^- \[ \]" || echo "_Nenhuma_")

cat > "$DAILY/${DATE_TODAY}.md" << EOF
# Nota Diaria — $DATE_DISPLAY
- Tasks concluidas: $DONE
- Tasks em aberto: $OPEN
- Tasks urgentes pendentes: $URGENT

## Concluidas hoje
$DONE_LIST

## Urgentes abertas
$URGENT_LIST

_Gerado automaticamente — 22:30_
EOF

# Mover concluidas para DONE.md
DONE_FILE="$WORKSPACE/memory/DONE.md"
[ ! -f "$DONE_FILE" ] && echo "# DONE.md — Tasks Concluidas" > "$DONE_FILE"
if [ "$DONE" -gt 0 ]; then
  EXISTING="$(grep -cF "## $DATE_DISPLAY" "$DONE_FILE" 2>/dev/null || true)"
  EXISTING="${EXISTING%%$'\n'*}"; EXISTING="${EXISTING:-0}"
  if [ "$EXISTING" -eq 0 ]; then
    echo "" >> "$DONE_FILE"
    echo "## $DATE_DISPLAY" >> "$DONE_FILE"
    grep "^- \[x\]\|^- \[X\]" "$QUEUE" 2>/dev/null >> "$DONE_FILE" || true
  fi
fi

MSG="Fechamento do dia, Netto.

Hoje foram *$DONE concluida(s)*, restam *$OPEN abertas*."
[ "$URGENT" -gt 0 ] && MSG="$MSG
$URGENT delas sao urgentes pra resolver."
MSG="$MSG

Nota diaria salva. Amanha a gente continua."

send_telegram "$MSG"
log "Daily progress: done=$DONE open=$OPEN urgent=$URGENT"
echo "OK: daily_progress_report completed at $TIMESTAMP"
