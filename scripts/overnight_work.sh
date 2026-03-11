#!/bin/bash
# overnight_work.sh — Wolf Agency
# Cron: 03:00 diario | Trabalho noturno deterministico
# Backup, limpeza de logs antigos, prepara morning_context.md

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
LOG_FILE="$WORKSPACE/memory/logs/overnight.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TODAY=$(date '+%Y-%m-%d')
ACTIONS=()

mkdir -p "$WORKSPACE/memory/logs/archive" "$WORKSPACE/backups" "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

# 1. Limpeza de logs > 30 dias
OLD=$(find "$WORKSPACE/memory/logs/archive" -name "*.log" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
if [ "$OLD" -gt 0 ]; then
  find "$WORKSPACE/memory/logs/archive" -name "*.log" -mtime +30 -delete 2>/dev/null
  ACTIONS+=("$OLD logs antigos removidos")
fi

# 2. Backup diario (SOUL.md + QUEUE.md + CLAUDE.md)
BACKUP="$WORKSPACE/backups/overnight_${DATE_TODAY}.tar.gz"
if [ ! -f "$BACKUP" ]; then
  tar -czf "$BACKUP" -C "$WORKSPACE" SOUL.md tasks/QUEUE.md CLAUDE.md 2>/dev/null || true
  [ -f "$BACKUP" ] && ACTIONS+=("Backup criado: $(du -sh "$BACKUP" | cut -f1)")
fi

# 3. Limpar backups > 7 dias
find "$WORKSPACE/backups" -name "overnight_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

# 4. Preparar morning_context.md
QUEUE="$WORKSPACE/tasks/QUEUE.md"
TASKS=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
URGENT_COUNT=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" || true)
URGENT_COUNT=$(echo "$URGENT_COUNT" | tr -d '[:space:]')
URGENT_COUNT=${URGENT_COUNT:-0}
URGENT_LIST=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep "^- \[ \]" | head -3 | sed 's/- \[ \] /- /' || true)

cat > "$WORKSPACE/memory/morning_context.md" << EOF
# Contexto Matinal — preparado overnight em $TIMESTAMP

## Tasks em aberto: $TASKS
## Tasks urgentes: $URGENT_COUNT
$([ -n "$URGENT_LIST" ] && echo "$URGENT_LIST" || echo "_Nenhuma urgente_")

## Ultima atualizacao: $TIMESTAMP
EOF
ACTIONS+=("Contexto matinal preparado ($TASKS tasks, $URGENT_COUNT urgentes)")

# 5. Arquivar logs do dia anterior
YESTERDAY=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null)
for logfile in "$WORKSPACE/memory/logs"/*.log; do
  [ -f "$logfile" ] || continue
  [ "$(basename "$logfile")" = "overnight.log" ] && continue
  LINES=$(grep -c "$YESTERDAY" "$logfile" 2>/dev/null || echo "0")
  if [ "$LINES" -gt 0 ]; then
    grep "$YESTERDAY" "$logfile" >> "$WORKSPACE/memory/logs/archive/${YESTERDAY}_$(basename "$logfile")" 2>/dev/null || true
  fi
done

if [ ${#ACTIONS[@]} -eq 0 ]; then
  log "Overnight: nada a fazer"
else
  MSG="Trabalho noturno concluido.

$(for a in "${ACTIONS[@]}"; do echo "- $a"; done)

Tudo pronto pra amanha."
  send_telegram "$MSG"
  for a in "${ACTIONS[@]}"; do log "ACTION: $a"; done
fi

echo "OK: overnight_work completed at $TIMESTAMP"
