#!/bin/bash
# =============================================================================
# Alfred Quality Report — Análise diária de qualidade do gateway
# Roda: 23h30 diário via crontab
# Notifica Telegram apenas se houver problemas
# =============================================================================
set -uo pipefail

DATE=$(date '+%Y-%m-%d')
DATE_BR=$(date '+%d/%m')
LOGFILE="/tmp/openclaw/openclaw-${DATE}.log"
GWLOG="$HOME/.openclaw/logs/gateway.log"
SESSIONS="$HOME/.openclaw/agents/main/sessions/sessions.json"
ENV_FILE="$HOME/.openclaw/.env"

TELEGRAM_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

# Abort if no log today
if [ ! -f "$LOGFILE" ]; then
  echo "[$(date)] No log file for today: $LOGFILE"
  exit 0
fi

# --- Volume ---
MSGS_SENT_TODAY=$(grep "$DATE" "$GWLOG" 2>/dev/null | grep -c "sendMessage ok")
MSGS_RECV=$(grep -c 'sessionKey=agent:main:main' "$LOGFILE" 2>/dev/null)

# --- Errors ---
TOOL_FAILS=$(grep -c '\[tools\].*failed\|tool.*error\|exec failed' "$LOGFILE" 2>/dev/null)
OVERLOADED=$(grep -c 'overloaded' "$LOGFILE" 2>/dev/null)
RATE_LIMITS=$(grep -c '"429"\|rate.limit' "$LOGFILE" 2>/dev/null)
FAILOVERS=$(grep -c 'failover' "$LOGFILE" 2>/dev/null)
AUTH_ERRORS=$(grep -c '"unauthorized"\|"authentication_error"' "$LOGFILE" 2>/dev/null)
LOG_ERRORS=$(grep -c '"logLevelName":"ERROR"' "$LOGFILE" 2>/dev/null)

# --- Crons ---
CRON_RUNS=$(grep -c 'embedded run' "$LOGFILE" 2>/dev/null)
CRON_ERRORS=$(grep 'embedded run' "$LOGFILE" 2>/dev/null | grep -c 'isError=true')
CRON_PCT=0
[ "$CRON_RUNS" -gt 0 ] && CRON_PCT=$(( CRON_ERRORS * 100 / CRON_RUNS ))

# --- Sessions ---
ACTIVE_SESSIONS=0
[ -f "$SESSIONS" ] && ACTIVE_SESSIONS=$(python3 -c "import json; print(len(json.load(open('$SESSIONS'))))" 2>/dev/null || echo 0)

# --- Error rate ---
TOTAL=$((MSGS_RECV + CRON_RUNS)); ERRS=$((TOOL_FAILS + CRON_ERRORS + LOG_ERRORS)); ERROR_RATE=0
[ "$TOTAL" -gt 0 ] && ERROR_RATE=$(( ERRS * 100 / TOTAL ))

# --- Build report ---
REPORT="🐺 *Wolf — Quality Alert | ${DATE_BR}*"
REPORT+="\n\n📊 *Volume*"
REPORT+="\n${MSGS_RECV} msgs recebidas · ${MSGS_SENT_TODAY} respostas"
REPORT+="\n\n⚙️ *Sistema*"
REPORT+="\nErros: ${TOOL_FAILS} tool fails · $((OVERLOADED + RATE_LIMITS)) rate limits · ${FAILOVERS} fallbacks · ${AUTH_ERRORS} auth"
REPORT+="\nCrons: ${CRON_RUNS} executados · ${CRON_ERRORS} com erro (${CRON_PCT}%)"
REPORT+="\nSessoes: ${ACTIVE_SESSIONS} ativas"

# --- Alerts ---
ALERT=0
ALERTS_TEXT=""
[ "$ERROR_RATE" -gt 10 ] && ALERTS_TEXT+="\n🔴 Taxa de erro elevada (${ERROR_RATE}%)" && ALERT=1
[ "$((OVERLOADED + RATE_LIMITS))" -gt 5 ] && ALERTS_TEXT+="\n⚠️ Rate limits frequentes — reduzir crons" && ALERT=1
[ "$AUTH_ERRORS" -gt 0 ] && ALERTS_TEXT+="\n🔴 Erros de autenticacao — verificar tokens" && ALERT=1

[ "$ALERT" -eq 1 ] && REPORT+="\n\n🚨 *Alertas*${ALERTS_TEXT}"

# --- Log always, Telegram only on alerts ---
echo "[$(date)] $REPORT" | sed 's/\\n/\n/g'

if [ "$ALERT" -eq 1 ]; then
  wolf_log "alfred-quality" "$REPORT"
  echo "[$(date)] Alerta enviado ao Telegram"
fi

exit 0
