#!/bin/bash
# ============================================================
# WOLF COST TRACKER — Monitor de custo LLM (zero-token)
# Le token-telemetry.jsonl e gera relatorio de consumo
# Roda a cada 4h via LaunchAgent + relatorio diario as 23h50
# ============================================================

set -euo pipefail

LOG="/tmp/wolf-cost-tracker.log"
REPORT_FILE="/tmp/wolf-cost-report-$(date '+%Y-%m-%d').txt"
TELEMETRY="$HOME/.openclaw/logs/token-telemetry.jsonl"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

# --- Config: custo por modelo (USD per 1M tokens) ---
# Precos Ollama Cloud Pro
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
    'kimi-k2.5':      {'input': 0.15, 'output': 0.15},
    'deepseek-v3.2':  {'input': 0.14, 'output': 0.28},
    'qwen3.5:397b':   {'input': 0.30, 'output': 0.30},
    'gemma3:27b':     {'input': 0.10, 'output': 0.10},
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
CHAT_ID="789352357"

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

  if [[ "$SEND_DAILY" == "true" ]]; then
    # Daily summary - always send
    MSG=$(python3 -c "
import urllib.parse
status='$STATUS'
cost='$COST'
pct='$PCT'
sessions='$SESSIONS'
today='$TODAY'

icon = '✅' if status == 'OK' else ('⚠️' if status == 'ATENCAO' else '🔴')

lines = [
    f'{icon} Wolf Custo | {today}',
    '',
    f'💰 Custo: \${cost} / \$3.00 ({pct}%)',
    f'📊 Sessoes: {sessions}',
    f'📈 Status: {status}',
]

# Add model breakdown from report file
import os
report_path = f'/tmp/wolf-cost-report-{today}.txt'
if os.path.exists(report_path):
    with open(report_path) as f:
        content = f.read()
    in_models = False
    lines.append('')
    lines.append('Por modelo:')
    for l in content.split('\n'):
        if l.startswith('POR MODELO:'):
            in_models = True
            continue
        if in_models and l.startswith('  '):
            parts = l.strip().split()
            if len(parts) >= 2:
                name = parts[0]
                cost_val = parts[1]
                lines.append(f'  {name}: {cost_val}')
        elif in_models and not l.startswith('  '):
            in_models = False

print(urllib.parse.quote('\n'.join(lines)))
")
    curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=${MSG}&parse_mode=" 2>/dev/null || true
    echo "[$TIMESTAMP] Daily report sent to Telegram" >> "$LOG"

  elif [[ "$STATUS" == "ESTOURO" || "${SESSIONS:-0}" -gt "$SESSION_ALERT_THRESHOLD" ]]; then
    # Alert mode - only on budget overflow
    if [[ "$STATUS" == "ESTOURO" ]]; then
      MSG="🔴 Wolf Cost | ALERTA%0A%0ACusto hoje: \$${COST} (${PCT}%25 do budget)%0ASessoes: ${SESSIONS}%0A%0AOrcamento diario estourado."
    else
      MSG="⚠️ Wolf Cost | ATENCAO%0A%0A${SESSIONS} sessoes hoje (limite: ${SESSION_ALERT_THRESHOLD})%0ACusto: \$${COST}%0A%0AVolume alto de sessoes."
    fi
    curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=${MSG}" 2>/dev/null || true
    echo "[$TIMESTAMP] Alert sent to Telegram (status=$STATUS)" >> "$LOG"
  fi
fi

# --- Trim log ---
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# --- Clean old reports (keep 7 days) ---
find /tmp -name "wolf-cost-report-*.txt" -mtime +7 -delete 2>/dev/null || true
