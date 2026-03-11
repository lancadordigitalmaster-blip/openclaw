#!/bin/bash
# ============================================================
# WOLF TOOL FALLBACK — Auto-correção quando Alfred falha
# Monitora logs por padrões de falha e executa scripts
# determinísticos como fallback
# ============================================================
set -euo pipefail

set -a
source "$HOME/.openclaw/.env"
set +a

LOG="/tmp/wolf-tool-fallback.log"
GATEWAY_LOG="/tmp/openclaw/openclaw-$(date '+%Y-%m-%d').log"
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
NETTO_CHAT="789352357"
SCRIPTS_DIR="$HOME/.openclaw/workspace/scripts"
FALLBACK_STATE="/tmp/wolf-fallback-state.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tool Fallback check iniciado" >> "$LOG"

# Initialize state file if missing
if [[ ! -f "$FALLBACK_STATE" ]]; then
  echo '{"last_check_ms": 0}' > "$FALLBACK_STATE"
fi

LAST_CHECK=$(python3 -c "import json; print(json.load(open('$FALLBACK_STATE')).get('last_check_ms', 0))")
NOW_MS=$(python3 -c "import time; print(int(time.time() * 1000))")

# ============================================================
# CHECK 1: Moonshot/Kimi API quota exceeded
# ============================================================
# Check for API quota errors in last 2 hours only (not full day)
TWO_HOURS_AGO=$(date -v-2H '+%Y-%m-%dT%H:%M' 2>/dev/null || date --date='2 hours ago' '+%Y-%m-%dT%H:%M' 2>/dev/null || echo "")
if [[ -n "$TWO_HOURS_AGO" ]]; then
  RECENT_QUOTA=$(grep "exceeded_current_quota_error\|insufficient balance" "$GATEWAY_LOG" 2>/dev/null | grep -c "$TWO_HOURS_AGO" || echo "0")
else
  RECENT_QUOTA=0
fi
if [[ "$RECENT_QUOTA" -gt 0 ]]; then
  echo "[$(date)] ALERTA: API quota errors detectados nas ultimas 2h ($RECENT_QUOTA)" >> "$LOG"
  if ! grep -q "quota-alert-$(date '+%Y-%m-%d')" "$FALLBACK_STATE" 2>/dev/null; then
    # Identify which API failed
    FAILED_API=$(grep "exceeded_current_quota_error\|insufficient balance" "$GATEWAY_LOG" 2>/dev/null | tail -1 | grep -o "Kimi\|Moonshot\|Gemini\|Google" || echo "desconhecida")
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d chat_id="$NETTO_CHAT" \
      --data-urlencode "text=ALERTA: API $FAILED_API com erro de quota. Verificar saldo ou trocar provider." \
      >> "$LOG" 2>&1
    python3 -c "
import json
s = json.load(open('$FALLBACK_STATE'))
s['quota-alert-$(date "+%Y-%m-%d")'] = True
json.dump(s, open('$FALLBACK_STATE', 'w'))
"
  fi
fi

# ============================================================
# CHECK 2: Cron job failed consecutively (>= 3x)
# ============================================================
python3 << 'PYEOF'
import json, os, subprocess, sys

jobs_path = os.path.expanduser("~/.openclaw/cron/jobs.json")
scripts_dir = os.path.expanduser("~/.openclaw/workspace/scripts")
log_path = "/tmp/wolf-tool-fallback.log"

# Map cron names to fallback scripts
FALLBACK_MAP = {
    "YouTube Monitor": "wolf-youtube-monitor.sh",
    "ClickUp": "wolf-clickup-check.sh",
}

with open(jobs_path) as f:
    data = json.load(f)

for job in data.get("jobs", []):
    name = job.get("name", "")
    state = job.get("state", {})
    errors = state.get("consecutiveErrors", 0)
    last_status = state.get("lastRunStatus", "")
    enabled = job.get("enabled", False)

    if not enabled or errors < 3:
        continue

    # Find matching fallback script
    fallback = None
    for key, script in FALLBACK_MAP.items():
        if key.lower() in name.lower():
            fallback = script
            break

    if fallback:
        script_path = os.path.join(scripts_dir, fallback)
        if os.path.exists(script_path):
            with open(log_path, "a") as lf:
                lf.write(f"[FALLBACK] {name} falhou {errors}x — executando {fallback}\n")
            result = subprocess.run(["bash", script_path],
                                    capture_output=True, text=True, timeout=60)
            with open(log_path, "a") as lf:
                lf.write(f"[FALLBACK] {fallback} exit={result.returncode}\n")
                if result.stderr:
                    lf.write(f"[FALLBACK] stderr: {result.stderr[:200]}\n")
    else:
        with open(log_path, "a") as lf:
            lf.write(f"[SEM FALLBACK] {name} falhou {errors}x mas nao tem script determinístico\n")
PYEOF

# ============================================================
# CHECK 3: Missing files referenced in SOUL.md
# ============================================================
MISSING_FILES=""
for F in \
  "$HOME/.openclaw/workspace/memory/boot-context.md" \
  "$HOME/.openclaw/workspace/memory/agenda-alfred.md" \
  "$HOME/.openclaw/workspace/shared/memory/alfred-core.md" \
  "$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md"; do
  if [[ ! -f "$F" ]]; then
    MISSING_FILES="$MISSING_FILES $F"
    # Create minimal file
    mkdir -p "$(dirname "$F")"
    echo "# $(basename "$F" .md) — $(date '+%Y-%m-%d')" > "$F"
    echo "Arquivo criado automaticamente pelo fallback." >> "$F"
    echo "[$(date)] Criado arquivo ausente: $F" >> "$LOG"
  fi
done

# ============================================================
# CHECK 4: Gateway restart failures
# ============================================================
RESTART_FAILS=$(grep -c "ETIMEDOUT.*falling back" "$GATEWAY_LOG" 2>/dev/null || echo "0")
if [[ "$RESTART_FAILS" -gt 3 ]]; then
  echo "[$(date)] Gateway com $RESTART_FAILS falhas de restart" >> "$LOG"
fi

# Update state
python3 -c "
import json, time
s = json.load(open('$FALLBACK_STATE'))
s['last_check_ms'] = int(time.time() * 1000)
json.dump(s, open('$FALLBACK_STATE', 'w'))
"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tool Fallback check concluido" >> "$LOG"
