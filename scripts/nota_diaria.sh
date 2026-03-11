#!/bin/bash
# nota_diaria.sh — Wolf Agency
# Cron: 23:59 diario | Encerra o dia, prepara contexto para amanha

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
LOG_FILE="$WORKSPACE/memory/logs/nota_diaria.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TODAY=$(date '+%Y-%m-%d')
DATE_DISPLAY=$(date '+%d/%m/%Y')

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
DONE=$(grep -c "^- \[x\]\|^- \[X\]" "$QUEUE" 2>/dev/null || echo "0")
NOTES=$(find "$WORKSPACE/memory/daily" -name "${DATE_TODAY}*.md" 2>/dev/null | wc -l | tr -d ' ')

# Contexto para amanha (Overnight Work sobrescreve as 03:00 com dados frescos)
cat > "$WORKSPACE/memory/morning_context.md" << EOF
# Contexto Matinal — encerramento de $DATE_DISPLAY
## Tasks em aberto: $OPEN
$(grep "^- \[ \]" "$QUEUE" 2>/dev/null | head -5 || echo "_Fila vazia_")
## Concluidas hoje: $DONE
## Ultima atualizacao: $TIMESTAMP
EOF

MSG="Encerrando o dia, Netto.

$DONE concluida(s), $OPEN ainda abertas."
[ "$NOTES" -gt 0 ] && MSG="$MSG
$NOTES nota(s) salva(s) na memoria."
MSG="$MSG

Contexto de amanha ja esta preparado. Boa noite."
send_telegram "$MSG"

log "Dia $DATE_TODAY encerrado — done=$DONE open=$OPEN"
echo "OK: nota_diaria completed at $TIMESTAMP"
