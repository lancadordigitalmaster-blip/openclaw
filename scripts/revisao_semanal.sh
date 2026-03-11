#!/bin/bash
# revisao_semanal.sh — Wolf Agency
# Cron: sexta 17h | Consolida semana e envia resumo

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
DONE_FILE="$WORKSPACE/memory/DONE.md"
DAILY="$WORKSPACE/memory/daily"
LOG_FILE="$WORKSPACE/memory/logs/revisao_semanal.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

# Contar notas da semana
NOTAS=$(find "$DAILY" -name "*.md" -mtime -7 2>/dev/null | wc -l | tr -d ' ')

# Tasks concluidas na semana (do DONE.md)
DONE_WEEK=$(grep -c "\[x\]" "$DONE_FILE" 2>/dev/null || echo "0")

# Tasks abertas
OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")

# Urgent
URGENT=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || echo "0")

# Backlog
BACKLOG=$(awk '/## BACKLOG/,/## BLOCKED/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || echo "0")

MSG="Netto, resumo da semana.

*$NOTAS* notas diarias registradas.
*$DONE_WEEK* tasks concluidas no historico.
*$OPEN* ainda abertas — $URGENT urgente(s), $BACKLOG no backlog.

Bom fim de semana."

send_telegram "$MSG"
log "Revisao semanal: notas=$NOTAS done=$DONE_WEEK open=$OPEN"
echo "OK: revisao_semanal completed at $TIMESTAMP"
