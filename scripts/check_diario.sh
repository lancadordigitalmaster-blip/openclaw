#!/bin/bash
# check_diario.sh — Wolf Agency
# Cron: 09:00 diario | Check-in rapido com status da fila

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
CONTEXT="$WORKSPACE/memory/morning_context.md"
LOG_FILE="$WORKSPACE/memory/logs/check_diario.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
URGENT="$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || true)"
URGENT="${URGENT%%$'\n'*}"; URGENT="${URGENT:-0}"
BLOCKED="$(awk '/## BLOCKED/,/## METRICAS/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || true)"
BLOCKED="${BLOCKED%%$'\n'*}"; BLOCKED="${BLOCKED:-0}"

# Verificar notas antigas (>3 dias sem update)
OLD_NOTES=$(find "$WORKSPACE/memory/daily/" -name "*.md" -mtime +3 2>/dev/null | wc -l | tr -d ' ')

MSG="Netto, update das 9h.

*$OPEN tasks* abertas na fila."
[ "$URGENT" -gt 0 ] && MSG="$MSG
$URGENT delas sao urgentes."
[ "$BLOCKED" -gt 0 ] && MSG="$MSG
$BLOCKED travada(s) esperando teu input."
[ "$OLD_NOTES" -gt 0 ] && MSG="$MSG

Tem $OLD_NOTES nota(s) diaria(s) parada(s) ha mais de 3 dias — vale dar uma olhada."

send_telegram "$MSG"
log "Check diario: open=$OPEN urgent=$URGENT blocked=$BLOCKED"
echo "OK: check_diario completed at $TIMESTAMP"
