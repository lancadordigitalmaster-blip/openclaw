#!/bin/bash
# wolf-telemetry-aggregate.sh — Agrega métricas diárias e salva no Supabase
# Roda via crontab às 23:55 BRT
# Coleta: custo LLM, sessões, crons, gateway, disco, missões, alertas
# Zero LLM.

set -eo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

TODAY=$(date '+%Y-%m-%d')
LOG="/tmp/wolf-telemetry.log"
COST_REPORT="/tmp/wolf-cost-report-${TODAY}.txt"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "=== Telemetry Aggregate iniciado ==="

# ── 1. Custo LLM (do cost-tracker report) ──
COST_USD="0"
SESSIONS_TOTAL="0"
SESSIONS_CRON="0"
COST_PCT="0"
TOKENS_IN="0"
TOKENS_OUT="0"

if [[ -f "$COST_REPORT" ]]; then
    COST_USD=$(grep '^__COST=' "$COST_REPORT" | cut -d= -f2 || echo "0")
    SESSIONS_TOTAL=$(grep '^__SESSIONS=' "$COST_REPORT" | cut -d= -f2 || echo "0")
    COST_PCT=$(grep '^__PCT=' "$COST_REPORT" | cut -d= -f2 || echo "0")

    # Parse session breakdown
    SESSIONS_LINE=$(grep '^SESSOES:' "$COST_REPORT" || true)
    if [[ -n "$SESSIONS_LINE" ]]; then
        SESSIONS_CRON=$(echo "$SESSIONS_LINE" | grep -oE '[0-9]+ crons' | grep -oE '[0-9]+' || echo "0")
    fi

    # Parse tokens
    TOKENS_LINE=$(grep '^TOKENS:' "$COST_REPORT" || true)
    if [[ -n "$TOKENS_LINE" ]]; then
        TOKENS_IN=$(echo "$TOKENS_LINE" | grep -oE '[0-9,]+ input' | tr -d ',' | grep -oE '[0-9]+' || echo "0")
        TOKENS_OUT=$(echo "$TOKENS_LINE" | grep -oE '[0-9,]+ output' | tr -d ',' | grep -oE '[0-9]+' || echo "0")
    fi
fi

# ── 2. Crons status (do jobs.json) ──
CRON_STATUS=$(python3 << 'PYEOF'
import json, os
jobs_path = os.path.expanduser('~/.openclaw/cron/jobs.json')
with open(jobs_path) as f:
    data = json.load(f)
ok = err = disabled = 0
for j in data.get('jobs', []):
    if not j.get('enabled', False):
        disabled += 1
        continue
    status = j.get('state', {}).get('lastRunStatus', 'never')
    if status == 'ok':
        ok += 1
    elif status == 'error':
        err += 1
print(f"{ok}|{err}|{disabled}")
PYEOF
)
CRONS_OK=$(echo "$CRON_STATUS" | cut -d'|' -f1)
CRONS_ERROR=$(echo "$CRON_STATUS" | cut -d'|' -f2)
CRONS_DISABLED=$(echo "$CRON_STATUS" | cut -d'|' -f3)

# ── 3. Infra ──
DISK_PCT=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
GW_OK=$(lsof -i :18789 >/dev/null 2>&1 && echo "true" || echo "false")
WA_OK=$(curl -s --max-time 3 http://127.0.0.1:3002/health >/dev/null 2>&1 && echo "true" || echo "false")

# Uptime estimation: check wolf-monitor.log for today's DOWN entries
GW_UPTIME="100"
if [[ -f "/tmp/wolf-monitor.log" ]]; then
    DOWN_COUNT=$(grep "$TODAY" /tmp/wolf-monitor.log 2>/dev/null | grep -ci "DOWN\|STILL DOWN" || echo "0")
    # Each check is 30min. Assume each DOWN = 30min downtime
    if [[ "$DOWN_COUNT" -gt 0 ]]; then
        TOTAL_CHECKS=$(grep -c "$TODAY" /tmp/wolf-monitor.log 2>/dev/null || echo "1")
        GW_UPTIME=$(python3 -c "print(f'{max(0, (1 - $DOWN_COUNT/$TOTAL_CHECKS) * 100):.1f}')")
    fi
fi

# ── 4. Missões WMC ──
MISSIONS_CREATED="0"
MISSIONS_COMPLETED="0"
MISSIONS_BLOCKED="0"

if [[ -n "$WOLF_ANON_KEY" ]]; then
    MISSIONS=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?select=status&created_at=gte.${TODAY}T00:00:00" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null || echo "[]")

    MISSIONS_CREATED=$(echo "$MISSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo "0")
    MISSIONS_COMPLETED=$(echo "$MISSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for m in d if m.get('status')=='done') if isinstance(d,list) else 0)" 2>/dev/null || echo "0")
    MISSIONS_BLOCKED=$(echo "$MISSIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for m in d if m.get('status')=='blocked') if isinstance(d,list) else 0)" 2>/dev/null || echo "0")
fi

# ── 5. Alertas enviados hoje ──
ALERTS_SENT=0
# Count wolf_notify calls in various logs
for LOGF in /tmp/wolf-monitor.log /tmp/wolf-cost-tracker.log /tmp/wolf-token-expiry.log; do
    if [[ -f "$LOGF" ]]; then
        COUNT=$(grep "$TODAY" "$LOGF" 2>/dev/null | grep -ci "ALERTA\|ALERT\|enviado\|sent" || echo "0")
        ALERTS_SENT=$((ALERTS_SENT + COUNT))
    fi
done

# ── 6. Salvar no Supabase (upsert por date) ──
SESSIONS_CHAT=$((SESSIONS_TOTAL - SESSIONS_CRON))
[[ "$SESSIONS_CHAT" -lt 0 ]] && SESSIONS_CHAT=0

PAYLOAD=$(python3 -c "
import json
d = {
    'date': '$TODAY',
    'cost_usd': ${COST_USD:-0},
    'cost_pct': ${COST_PCT:-0},
    'sessions_total': ${SESSIONS_TOTAL:-0},
    'sessions_cron': ${SESSIONS_CRON:-0},
    'sessions_chat': ${SESSIONS_CHAT:-0},
    'tokens_input': ${TOKENS_IN:-0},
    'tokens_output': ${TOKENS_OUT:-0},
    'crons_ok': ${CRONS_OK:-0},
    'crons_error': ${CRONS_ERROR:-0},
    'crons_disabled': ${CRONS_DISABLED:-0},
    'gateway_uptime_pct': ${GW_UPTIME:-100},
    'disk_usage_pct': ${DISK_PCT:-0},
    'whatsapp_bridge_ok': True if '${WA_OK}' == 'true' else False,
    'missions_created': ${MISSIONS_CREATED:-0},
    'missions_completed': ${MISSIONS_COMPLETED:-0},
    'missions_blocked': ${MISSIONS_BLOCKED:-0},
    'alerts_sent': ${ALERTS_SENT:-0}
}
print(json.dumps(d))
")

if [[ -n "$WOLF_ANON_KEY" ]]; then
    # Upsert (insert or update on date conflict)
    RESULT=$(curl -s -X POST "${WOLF_SUPABASE_URL}/rest/v1/system_metrics" \
        -H "apikey: ${WOLF_ANON_KEY}" \
        -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates,return=representation" \
        -d "$PAYLOAD" 2>/dev/null)

    if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if isinstance(d,list) and d else 1)" 2>/dev/null; then
        log "Metrics salvos no Supabase: cost=\$${COST_USD} sessions=${SESSIONS_TOTAL} uptime=${GW_UPTIME}%"
    else
        log "ERRO ao salvar metrics: $RESULT"
    fi
else
    log "SKIP Supabase — ANON_KEY não configurada"
fi

log "=== Telemetry Aggregate concluído ==="
echo "OK: wolf-telemetry cost=\$${COST_USD} sessions=${SESSIONS_TOTAL} crons=${CRONS_OK}ok/${CRONS_ERROR}err"
