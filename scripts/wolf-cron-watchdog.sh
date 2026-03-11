#!/bin/bash
# ============================================================
# WOLF CRON WATCHDOG — Detecta crons falhando 2x+ seguidas
# Roda a cada 15 minutos via LaunchAgent
# ============================================================
set -euo pipefail

LOG="/tmp/wolf-cron-watchdog.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
source "$HOME/.openclaw/.env" 2>/dev/null
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

ALERT=$(python3 << 'PYEOF'
import json, os

jobs_path = os.path.expanduser('~/.openclaw/cron/jobs.json')
state_path = '/tmp/wolf-cron-failures.json'

# Load previous state
prev = {}
if os.path.exists(state_path):
    try:
        with open(state_path) as f:
            prev = json.load(f)
    except:
        prev = {}

with open(jobs_path) as f:
    data = json.load(f)

current = {}
alerts = []

for j in data.get('jobs', []):
    if not j.get('enabled', False):
        continue
    jid = j['id']
    name = j.get('name', '?')
    status = j.get('state', {}).get('lastRunStatus', 'never')

    if status == 'error':
        count = prev.get(jid, {}).get('count', 0) + 1
        current[jid] = {'name': name, 'count': count, 'status': 'error'}
        if count >= 2:
            alerts.append(f"- {name} ({count}x seguidas)")
    elif status == 'ok':
        current[jid] = {'name': name, 'count': 0, 'status': 'ok'}
    else:
        # Keep previous state for 'never' status
        if jid in prev:
            current[jid] = prev[jid]

# Save state
with open(state_path, 'w') as f:
    json.dump(current, f, indent=2)

if alerts:
    print("ALERT:" + "\n".join(alerts))
else:
    print("OK")
PYEOF
)

if echo "$ALERT" | grep -q "^ALERT:"; then
  MSG=$(echo "$ALERT" | sed 's/^ALERT:/Cron Watchdog\n/')
  echo "[$TIMESTAMP] $ALERT" >> "$LOG"
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${MSG}" \
    --max-time 10 2>/dev/null || true
else
  # Log OK only every hour
  MINUTE=$(date '+%M')
  if [[ "$MINUTE" == "00" ]]; then
    echo "[$TIMESTAMP] OK" >> "$LOG"
  fi
fi

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
