#!/bin/bash
# ============================================================
# WOLF COST TRACKER — Monitor de custo LLM (zero-token)
# Le token-telemetry.jsonl e gera relatorio de consumo
# Roda a cada 4h via LaunchAgent + relatorio diario as 23h50
# ============================================================

set -euo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

LOG="/tmp/wolf-cost-tracker.log"
REPORT_FILE="/tmp/wolf-cost-report-$(date '+%Y-%m-%d').txt"
TELEMETRY="$HOME/.openclaw/logs/token-telemetry.jsonl"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

# --- Config: custo por modelo (USD per 1M tokens) ---
# Precos Anthropic + OpenRouter
DAILY_BUDGET_USD="3.00"
SESSION_ALERT_THRESHOLD=50  # alerta se mais de X sessoes/dia

if [[ ! -f "$TELEMETRY" ]]; then
  echo "[$TIMESTAMP] ERROR: token-telemetry.jsonl not found" >> "$LOG"
  exit 1
fi

# --- Analise via Python ---
REPORT=$(python3 << 'PYEOF'
import json, sys, os
from datetime import datetime

today = datetime.now().strftime('%Y-%m-%d')
telemetry_path = os.path.expanduser('~/.openclaw/logs/token-telemetry.jsonl')

# Precos USD por 1M tokens (input / output)
PRICES = {
    'anthropic/claude-sonnet-4-6': {'input': 3.00, 'output': 15.00},
    'claude-sonnet-4-6': {'input': 3.00, 'output': 15.00},
    'claude-haiku-4-5-20251001': {'input': 0.80, 'output': 4.00},
    'gemini-2.5-flash': {'input': 0.15, 'output': 0.60},
    'llama-3.3-70b-versatile': {'input': 0.59, 'output': 0.79},
    'anthropic/claude-haiku-4-5': {'input': 0.80, 'output': 4.00},
    'google/gemini-2.5-flash': {'input': 0.075, 'output': 0.30},
}
DEFAULT_PRICE = {'input': 0.50, 'output': 0.50}

entries = []
with open(telemetry_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except:
            pass

# Filter today
today_entries = [e for e in entries if e.get('ts', '').startswith(today)]

# IMPORTANT: telemetry is cumulative snapshots (every 5 min).
# Each snapshot lists ALL active sessions at that moment.
# We must deduplicate by session key, keeping the LATEST values.
# Then aggregate across ALL snapshots to catch sessions that ended early.
session_latest = {}  # key -> {model, input, output, ts}

for e in today_entries:
    ts = e.get('ts', '')
    for s in e.get('sessions', []):
        key = s.get('key', '')
        model = s.get('model', '?')
        inp = s.get('inputTokens', 0)
        out = s.get('outputTokens', 0)

        if model == '?' or (inp == 0 and out == 0):
            continue

        # Keep latest snapshot for each session key
        if key not in session_latest or ts > session_latest[key]['ts']:
            session_latest[key] = {'model': model, 'input': inp, 'output': out, 'ts': ts}

# Aggregate from deduplicated sessions
models = {}
cron_jobs = {}
total_input = 0
total_output = 0
total_cost = 0.0
session_count = 0
cron_session_count = 0
telegram_session_count = 0

for key, s in session_latest.items():
    model = s['model']
    inp = s['input']
    out = s['output']

    session_count += 1
    total_input += inp
    total_output += out

    prices = PRICES.get(model, DEFAULT_PRICE)
    cost = (inp * prices['input'] + out * prices['output']) / 1_000_000
    total_cost += cost

    if model not in models:
        models[model] = {'input': 0, 'output': 0, 'cost': 0.0, 'calls': 0}
    models[model]['input'] += inp
    models[model]['output'] += out
    models[model]['cost'] += cost
    models[model]['calls'] += 1

    # Track cron usage (count unique cron IDs, not session keys)
    if ':cron:' in key:
        cron_session_count += 1
        cron_id = key.split(':cron:')[1].split(':')[0][:8]
        if cron_id not in cron_jobs:
            cron_jobs[cron_id] = {'tokens': 0, 'cost': 0.0, 'runs': 0}
        cron_jobs[cron_id]['tokens'] += inp + out
        cron_jobs[cron_id]['cost'] += cost
        cron_jobs[cron_id]['runs'] += 1

    if 'telegram' in key.lower():
        telegram_session_count += 1

# --- Output ---
budget = float(os.environ.get('DAILY_BUDGET_USD', '3.00'))
pct = (total_cost / budget * 100) if budget > 0 else 0
status = 'OK' if pct < 80 else ('ATENCAO' if pct < 100 else 'ESTOURO')

print(f'STATUS: {status}')
print(f'DATA: {today}')
print(f'CUSTO: ${total_cost:.4f} / ${budget:.2f} ({pct:.0f}%)')
print(f'SESSOES: {session_count} total | {cron_session_count} crons | {telegram_session_count} telegram')
print(f'TOKENS: {total_input:,} input | {total_output:,} output')
print()
print('POR MODELO:')
for m, d in sorted(models.items(), key=lambda x: -x[1]['cost']):
    print(f'  {m:25s} ${d["cost"]:.4f}  {d["input"]:>10,} in  {d["output"]:>8,} out  ({d["calls"]} calls)')
print()
print(f'CRONS ATIVOS HOJE: {len(cron_jobs)}')
for cid, d in sorted(cron_jobs.items(), key=lambda x: -x[1]['cost']):
    print(f'  {cid}  ${d["cost"]:.4f}  {d["tokens"]:,} tokens  ({d["runs"]} runs)')

# Machine-readable summary for other scripts
print()
print(f'__COST={total_cost:.4f}')
print(f'__SESSIONS={session_count}')
print(f'__STATUS={status}')
print(f'__PCT={pct:.0f}')
PYEOF
)

echo "$REPORT" > "$REPORT_FILE"
echo "[$TIMESTAMP] Cost report generated" >> "$LOG"

# Extract machine-readable values
COST=$(echo "$REPORT" | grep '^__COST=' | cut -d= -f2)
SESSIONS=$(echo "$REPORT" | grep '^__SESSIONS=' | cut -d= -f2)
STATUS=$(echo "$REPORT" | grep '^__STATUS=' | cut -d= -f2)
PCT=$(echo "$REPORT" | grep '^__PCT=' | cut -d= -f2)

echo "[$TIMESTAMP] Status=$STATUS Cost=\$$COST Sessions=$SESSIONS Budget=${PCT}%" >> "$LOG"

# --- Telegram notification ---
# Load token from .env
set +u
source "$HOME/.openclaw/.env" 2>/dev/null || true
set -u
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

# Daily report mode: --daily flag sends summary always (not just on alert)
SEND_DAILY=false
for arg in "$@"; do
  [[ "$arg" == "--daily" ]] && SEND_DAILY=true
done

if [[ -n "$TELEGRAM_TOKEN" ]]; then
  # Build human-readable report from the report file
  MODELS_LINE=$(echo "$REPORT" | grep -A50 '^POR MODELO:' | grep '^\s\s' | head -5 | while read -r line; do
    echo "  $line"
  done)

  # Build human-readable message
  ICON="✅"
  [[ "$STATUS" == "ATENCAO" ]] && ICON="⚠️"
  [[ "$STATUS" == "ESTOURO" ]] && ICON="🔴"

  # Extract model breakdown
  MODEL_LINES=$(echo "$REPORT" | awk '/^POR MODELO:/{found=1; next} found && /^  /{print} found && !/^  /{exit}' | head -5 | while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    MCOST=$(echo "$line" | awk '{print $2}')
    echo "  $NAME: $MCOST"
  done)

  MSG="$ICON *Wolf Custo | $TODAY*

💰 Custo: \$$COST / \$3.00 (${PCT}%)
📊 Sessões: $SESSIONS
📈 Status: $STATUS

Por modelo:
$MODEL_LINES"

  if [[ "$SEND_DAILY" == "true" ]]; then
    # Daily summary - always send via WhatsApp
    wolf_notify "$MSG"
    wolf_log "cost-tracker" "Daily report enviado"
    echo "[$TIMESTAMP] Daily report sent" >> "$LOG"

  elif [[ "$STATUS" == "ESTOURO" ]]; then
    # Budget overflow - urgent alert (WhatsApp + Telegram)
    wolf_notify_urgent "🔴 *ALERTA CUSTO*

Orçamento diário estourado!
Custo: \$$COST (${PCT}% do budget \$3.00)
Sessões: $SESSIONS

Verificar sessões ativas e considerar pausar crons não-essenciais."
    wolf_log "cost-tracker" "ALERTA: Budget estourado \$$COST"
    echo "[$TIMESTAMP] BUDGET ALERT sent (status=$STATUS)" >> "$LOG"

  elif [[ "$STATUS" == "ATENCAO" || "${SESSIONS:-0}" -gt "$SESSION_ALERT_THRESHOLD" ]]; then
    # Warning - WhatsApp only
    wolf_notify "$MSG"
    wolf_log "cost-tracker" "Warning enviado: ${PCT}% budget"
    echo "[$TIMESTAMP] Warning sent (status=$STATUS, sessions=$SESSIONS)" >> "$LOG"
  fi
fi

# --- Trim log ---
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# --- Clean old reports (keep 7 days) ---
find /tmp -name "wolf-cost-report-*.txt" -mtime +7 -delete 2>/dev/null || true
