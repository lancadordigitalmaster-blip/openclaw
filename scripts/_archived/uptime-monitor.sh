#!/bin/bash
# uptime-monitor.sh — Check critical services every 5min, alert on state change
# Crontab: */5 * * * * bash /.../scripts/uptime-monitor.sh >> /.../logs/uptime-monitor.log 2>&1
set -uo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

ENV_FILE="$HOME/.openclaw/.env"
TELEGRAM_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
TELEGRAM_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
STATE_FILE="/tmp/wolf-uptime-state.json"
[ -f "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"

send_tg() {
  [[ -z "${TELEGRAM_TOKEN:-}" || -z "${TELEGRAM_CHAT:-}" ]] && return
  wolf_notify "$1"
}

check_service() {
  local name="$1" url="$2"
  local status="down"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$url" 2>/dev/null || echo "000")
  if [[ "$http_code" != "000" ]]; then
    status="up"
  fi

  local prev
  prev=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('$name','unknown'))" 2>/dev/null || echo "unknown")

  if [[ "$prev" != "$status" ]]; then
    local ts
    ts=$(date '+%H:%M')
    if [[ "$status" == "down" ]]; then
      send_tg "🔴 DOWNTIME [$ts] — $name está FORA DO AR"
      echo "[$ts] ALERTA: $name DOWN"
    elif [[ "$prev" != "unknown" ]]; then
      send_tg "🟢 RECOVERY [$ts] — $name voltou ao normal"
      echo "[$ts] RECOVERY: $name UP"
    else
      echo "[$ts] INIT: $name = $status"
    fi
  fi

  # Update state
  python3 -c "
import json
d = json.load(open('$STATE_FILE'))
d['$name'] = '$status'
json.dump(d, open('$STATE_FILE','w'))
"
}

check_service "Gateway" "http://127.0.0.1:18789"
check_service "WhatsApp-Bridge" "http://127.0.0.1:3002"
check_service "Supabase" "https://dqhiafxbljujahmpcdhf.supabase.co"
