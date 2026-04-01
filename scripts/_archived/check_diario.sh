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

# ── Error trap — notifica via WhatsApp se script travar ────────────────────
source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh" 2>/dev/null || true
trap 'EXIT_CODE=$?; if [ $EXIT_CODE -ne 0 ]; then
  wolf_notify "⚠️ check_diario.sh falhou (código $EXIT_CODE) às $(date +%H:%M). Ver log: memory/logs/check_diario.log" 2>/dev/null || true
  log "ERRO: script falhou com código $EXIT_CODE"
fi' EXIT

OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
URGENT="$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || true)"
URGENT="${URGENT%%$'\n'*}"; URGENT="${URGENT:-0}"
BLOCKED="$(awk '/## BLOCKED/,/## METRICAS/' "$QUEUE" 2>/dev/null | grep -c "^- \[ \]" 2>/dev/null || true)"
BLOCKED="${BLOCKED%%$'\n'*}"; BLOCKED="${BLOCKED:-0}"

# Verificar notas antigas (>3 dias sem update)
OLD_NOTES=$(find "$WORKSPACE/memory/daily/" -name "*.md" -mtime +3 2>/dev/null | wc -l | tr -d ' ')

DATE_BR=$(date '+%d/%m')

MSG="🐺 *Wolf — Check Matinal | ${DATE_BR} 9h*

📋 *Fila*
${OPEN} tasks abertas"
[ "$URGENT" -gt 0 ] && MSG="$MSG · 🔴 ${URGENT} urgentes" || MSG="$MSG · 0 urgentes"
[ "$BLOCKED" -gt 0 ] && MSG="$MSG · ⏳ ${BLOCKED} bloqueadas"

[ "$OLD_NOTES" -gt 0 ] && MSG="$MSG

⚠️ *Atenção*
${OLD_NOTES} nota(s) parada(s) há mais de 3 dias"

wolf_notify "$MSG"
log "Check diario: open=$OPEN urgent=$URGENT blocked=$BLOCKED"
echo "OK: check_diario completed at $TIMESTAMP"
