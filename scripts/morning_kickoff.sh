#!/bin/bash
# morning_kickoff.sh — Wolf Agency
# Cron: 07:30 diario | Briefing matinal baseado na fila de trabalho

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
LOG_FILE="$WORKSPACE/memory/logs/morning_kickoff.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_DISPLAY=$(date '+%d/%m/%Y')
DAY_NAME=$(LANG=pt_BR.UTF-8 date '+%A' 2>/dev/null || date '+%A' | sed 's/Monday/Segunda/;s/Tuesday/Terca/;s/Wednesday/Quarta/;s/Thursday/Quinta/;s/Friday/Sexta/;s/Saturday/Sabado/;s/Sunday/Domingo/')

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

if [ ! -f "$QUEUE" ]; then
  send_telegram "Netto, nao encontrei o QUEUE.md. Algo pode ter saido do lugar — preciso de uma olhada."
  log "ERROR: QUEUE.md not found"
  exit 1
fi

TOTAL_OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
URGENT_LIST=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null \
  | grep "^- \[ \]" | head -3 \
  | sed 's/- \[ \] /- /' | sed 's/ | agente:.*//' || true)
BLOCKED=$(awk '/## BLOCKED/,/## METRICAS/' "$QUEUE" 2>/dev/null \
  | grep -c "^- \[ \]" || echo "0")

MSG="Bom dia, Netto. $DAY_NAME, $DATE_DISPLAY.

Temos *$TOTAL_OPEN tasks* na fila hoje."

if [ -n "$URGENT_LIST" ]; then
  MSG="$MSG

Prioridade pra hoje:
$URGENT_LIST"
else
  MSG="$MSG Nada urgente no momento."
fi

[ "$BLOCKED" -gt 0 ] && MSG="$MSG

Tem $BLOCKED coisa(s) travada(s) esperando input teu."

send_telegram "$MSG"

# Atualizar metricas no QUEUE.md
sed -i '' "s/- Total pendente: .*/- Total pendente: $TOTAL_OPEN/" "$QUEUE" 2>/dev/null || true
sed -i '' "s/- Ultima atualizacao: .*/- Ultima atualizacao: $TIMESTAMP/" "$QUEUE" 2>/dev/null || true

log "Morning Kickoff concluido — $TOTAL_OPEN tasks abertas"
echo "OK: morning_kickoff completed at $TIMESTAMP"
