#!/bin/bash
# bridge-health.sh — Deep health check for Telegram + WhatsApp bridges
# Crontab: */15 8-23 * * * bash /.../scripts/bridge-health.sh >> /.../logs/bridge-health.log 2>&1
set -uo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

ENV_FILE="$HOME/.openclaw/.env"
TELEGRAM_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
TELEGRAM_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
TS=$(date '+%Y-%m-%d %H:%M:%S')
PROBLEMS=""

send_tg() {
  # Desabilitado — era ruído no WhatsApp do Netto. Apenas logar.
  echo "[$(date '+%H:%M:%S')] ALERTA (silenciado): $1"
  return 0
}

# === TELEGRAM CHECKS ===

# 1. Polling offset freshness (stale if >30min)
OFFSET_FILE="$HOME/.openclaw/telegram/update-offset-default.json"
if [[ -f "$OFFSET_FILE" ]]; then
  OFFSET_AGE=$(( $(date +%s) - $(stat -f %m "$OFFSET_FILE" 2>/dev/null || echo 0) ))
  if [[ "$OFFSET_AGE" -gt 43200 ]]; then
    PROBLEMS+="Telegram polling offset stale ($(( OFFSET_AGE / 3600 ))h sem update). "
  fi
else
  PROBLEMS+="Telegram offset file ausente. "
fi

# 2. Bot API reachable
TG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" 2>/dev/null || echo "000")
[[ "$TG_STATUS" != "200" ]] && PROBLEMS+="Telegram Bot API falhou (HTTP $TG_STATUS). "

# 3. getUpdates callable (HTTP 200 check only, peek mode)
TG_UPD=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?limit=0&timeout=0" 2>/dev/null || echo "000")
[[ "$TG_UPD" != "200" ]] && PROBLEMS+="Telegram getUpdates falhou (HTTP $TG_UPD). "

# === WHATSAPP CHECKS ===

# 1. Bridge API responding
WA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://127.0.0.1:3002" 2>/dev/null || echo "000")
[[ "$WA_STATUS" == "000" ]] && PROBLEMS+="WhatsApp Bridge fora do ar. "

# 2. Auth state fresh (<24h)
AUTH_DIR="$HOME/openclaw/whatsapp-bridge/auth_state"
if [[ -d "$AUTH_DIR" ]]; then
  NEWEST=$(find "$AUTH_DIR" -type f -mmin -1440 2>/dev/null | head -1)
  [[ -z "$NEWEST" ]] && PROBLEMS+="WhatsApp auth_state sem arquivos recentes (>24h). "
else
  PROBLEMS+="WhatsApp auth_state dir ausente. "
fi

# 3. Recent errors in bridge log
WA_LOG="$HOME/.openclaw/logs/whatsapp-bridge.log"
if [[ -f "$WA_LOG" ]]; then
  ERR_COUNT=$(tail -50 "$WA_LOG" | grep -cE "DisconnectReason|connection closed|QR" 2>/dev/null || true)
  ERR_COUNT="${ERR_COUNT:-0}"; ERR_COUNT="${ERR_COUNT// /}"
  [[ "$ERR_COUNT" -gt 0 ]] && PROBLEMS+="WhatsApp log: $ERR_COUNT erros recentes (disconnect/QR). "
fi

# === ALERT OR SILENT ===
if [[ -n "$PROBLEMS" ]]; then
  MSG="🔴 Bridge Health [$TS]
$PROBLEMS"
  echo "[$TS] ALERT: $PROBLEMS"
  send_tg "$MSG"
else
  echo "[$TS] OK — Telegram + WhatsApp healthy"
fi
