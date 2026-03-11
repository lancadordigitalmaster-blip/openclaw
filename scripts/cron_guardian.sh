#!/bin/bash
# cron_guardian.sh — Wolf Agency
# Detecta respostas fantasma em crons LLM (< 10s sem confirmacao OK)
# USO: ./cron_guardian.sh "Nome do Cron" "comando a executar"
# EXEMPLO: ./cron_guardian.sh "Check Diario" "openclaw cron run abc123"

set -euo pipefail

CRON_NAME="${1:-unknown}"
CRON_CMD="${2:-}"
WORKSPACE="$HOME/.openclaw/workspace"
LOG_FILE="$WORKSPACE/memory/logs/guardian.log"
METRICS="$WORKSPACE/memory/logs/cron_metrics.jsonl"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$TIMESTAMP] [GUARDIAN] $1" | tee -a "$LOG_FILE"; }

# Telegram via .env
source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

[ -z "$CRON_CMD" ] && echo "USO: $0 'nome' 'comando'" && exit 1

START=$(date +%s)
OUTPUT=$(eval "$CRON_CMD" 2>&1) || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}
END=$(date +%s)
DURATION=$(( END - START ))

HAS_OK=$(echo "$OUTPUT" | grep -c "^OK:" 2>/dev/null; true)
HAS_OK=${HAS_OK:-0}
HAS_OK=$(echo "$HAS_OK" | tr -d '[:space:]')

# Registrar metricas
echo "{\"timestamp\":\"$TIMESTAMP\",\"cron\":\"$CRON_NAME\",\"duration_s\":$DURATION,\"exit\":$EXIT_CODE,\"has_ok\":$HAS_OK}" \
  >> "$METRICS"

if [ $EXIT_CODE -ne 0 ]; then
  send_telegram "Netto, o cron *$CRON_NAME* falhou (exit $EXIT_CODE, ${DURATION}s).

Vou verificar os logs pra entender o que aconteceu."
  log "CRITICAL: $CRON_NAME failed in ${DURATION}s (exit $EXIT_CODE)"
elif [ $DURATION -lt 10 ] && [ "$HAS_OK" -eq 0 ]; then
  send_telegram "Netto, o cron *$CRON_NAME* parece suspeito — rodou em ${DURATION}s sem confirmar execucao.

Pode ser resposta fantasma do modelo. Vou ficar de olho."
  log "SUSPICIOUS: $CRON_NAME — ${DURATION}s sem OK (possivel fantasma)"
else
  log "OK: $CRON_NAME — ${DURATION}s | exit=$EXIT_CODE"
fi

echo "GUARDIAN: $CRON_NAME | ${DURATION}s | exit=$EXIT_CODE"
exit $EXIT_CODE
