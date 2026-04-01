#!/bin/bash
# ============================================================
# WOLF GATEWAY MONITOR — Detecta gateway down e faz self-heal
# Roda a cada 5 minutos via LaunchAgent
# ============================================================
set -euo pipefail

LOG="/tmp/wolf-gateway-monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
source "$HOME/.openclaw/.env" 2>/dev/null
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

send_telegram() {
  local msg="$1"
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${msg}" \
    --max-time 10 2>/dev/null || true
}

if ! lsof -i :18789 >/dev/null 2>&1; then
  echo "[$TIMESTAMP] Gateway DOWN — attempting restart" >> "$LOG"
  launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null || true
  sleep 10

  if lsof -i :18789 >/dev/null 2>&1; then
    echo "[$TIMESTAMP] Gateway RECOVERED" >> "$LOG"
    send_telegram "Gateway estava down. Self-heal executado. Status: OK"
  else
    echo "[$TIMESTAMP] Gateway STILL DOWN after restart" >> "$LOG"
    send_telegram "CRITICO: Gateway down e restart falhou. Verificar manualmente."
  fi
else
  # Only log every 30min to avoid log spam (check minute)
  MINUTE=$(date '+%M')
  if [[ "$MINUTE" == "00" ]] || [[ "$MINUTE" == "30" ]]; then
    echo "[$TIMESTAMP] OK" >> "$LOG"
  fi
fi

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
