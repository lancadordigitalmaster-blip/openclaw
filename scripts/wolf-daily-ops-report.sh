#!/bin/bash
# wolf-daily-ops-report.sh — Relatorio Operacional Diario (20h BRT)
# Captura TUDO que aconteceu no dia: negocio, implementacoes, pendencias, erros
# Crontab: 0 20 * * * bash ~/.openclaw/workspace/scripts/wolf-daily-ops-report.sh >> ~/.openclaw/workspace/memory/logs/daily-ops-report.log 2>&1

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

DATE=$(date '+%d/%m/%Y')
TODAY=$(date '+%Y-%m-%d')
LOGS="$HOME/.openclaw/logs"
WORKSPACE="$HOME/.openclaw/workspace"
SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
REPORT_DIR="$WORKSPACE/memory/daily-ops"
REPORT_FILE="$REPORT_DIR/${TODAY}.txt"
TMP_PY=$(mktemp /tmp/wolf-ops-XXXXXX.py)

mkdir -p "$REPORT_DIR"

wolf_log "ops-report" "Iniciando Relatorio Operacional"

# ============================================================
# SECAO 1 — ATIVIDADE DE PESSOAS (quem falou, o que pediu)
# ============================================================
cat > "$TMP_PY" << 'PYEOF'
import json, os, glob, sys
from collections import Counter

sessions_dir = os.path.expanduser("~/.openclaw/agents/main/sessions/")
today = sys.argv[1] if len(sys.argv) > 1 else __import__("datetime").date.today().isoformat()

senders = Counter()
tools_used = Counter()
total_user_msgs = 0
session_count = 0
backticks = chr(96) * 3

for f in glob.glob(sessions_dir + "*.jsonl"):
    has_today = False
    session_senders = set()
    session_user_msgs = 0

    try:
        with open(f) as fh:
            for line in fh:
                try:
                    d = json.loads(line.strip())
                    ts = d.get("timestamp", "")
                    if today not in ts:
                        continue
                    has_today = True

                    if d.get("type") == "message":
                        msg = d.get("message", {})
                        role = msg.get("role", "")
                        if role == "user":
                            total_user_msgs += 1
                            session_user_msgs += 1
                            content = msg.get("content", [])
                            if isinstance(content, list):
                                for c in content:
                                    if isinstance(c, dict) and c.get("type") == "text":
                                        text = c["text"]
                                        if '"sender": "' in text:
                                            s = text.split('"sender": "')[1].split('"')[0]
                                            if s not in ("unknown", "System"):
                                                senders[s] += 1
                                                session_senders.add(s)
                                        # Skip system messages
                                        if backticks in text:
                                            actual = text.split(backticks)[-1].strip()
                                        else:
                                            actual = text
                                        if "HEARTBEAT" in actual or "cron:" in actual or "meta-anti-duplicate" in actual:
                                            total_user_msgs -= 1
                                            session_user_msgs -= 1

                    elif d.get("type") == "toolCall":
                        name = d.get("name", "unknown")
                        tools_used[name] += 1

                except:
                    pass
    except:
        pass

    if has_today and session_senders:
        session_count += 1

sender_str = ", ".join(f"{name} ({count})" for name, count in senders.most_common(10))
if not sender_str:
    sender_str = "Nenhuma interacao humana"

tool_top = ", ".join(f"{name}({count})" for name, count in tools_used.most_common(8))
if not tool_top:
    tool_top = "Nenhuma"

print(f"SENDERS={sender_str}")
print(f"USER_MSGS={total_user_msgs}")
print(f"SESSIONS={session_count}")
print(f"TOOLS={tool_top}")
PYEOF

PEOPLE_DATA=$(python3 "$TMP_PY" "$TODAY" 2>/dev/null || echo "SENDERS=Erro|USER_MSGS=0|SESSIONS=0|TOOLS=Erro")
SENDERS=$(echo "$PEOPLE_DATA" | grep "^SENDERS=" | cut -d= -f2-)
USER_MSGS=$(echo "$PEOPLE_DATA" | grep "^USER_MSGS=" | cut -d= -f2-)
SESSIONS_COUNT=$(echo "$PEOPLE_DATA" | grep "^SESSIONS=" | cut -d= -f2-)
TOOLS_SUMMARY=$(echo "$PEOPLE_DATA" | grep "^TOOLS=" | cut -d= -f2-)

# ============================================================
# SECAO 2 — CUSTO DO DIA
# ============================================================
cat > "$TMP_PY" << 'PYEOF'
import json, os, sys
from collections import defaultdict

today = sys.argv[1] if len(sys.argv) > 1 else __import__("datetime").date.today().isoformat()
telemetry = os.path.expanduser("~/.openclaw/logs/token-telemetry.jsonl")

PRICES = {
    "claude-sonnet-4-6": {"input": 3e-6, "output": 15e-6},
    "claude-haiku-4-5-20251001": {"input": 8e-7, "output": 4e-6},
    "anthropic/claude-haiku-4-5": {"input": 8e-7, "output": 4e-6},
}

session_seen = {}

if os.path.exists(telemetry):
    with open(telemetry) as f:
        for line in f:
            try:
                d = json.loads(line.strip())
                if today not in d.get("ts", ""):
                    continue
                for s in d.get("sessions", []):
                    key = s.get("key", "")
                    model = s.get("model", "?")
                    inp = s.get("inputTokens", 0)
                    out = s.get("outputTokens", 0)
                    total = s.get("totalTokens", 0)
                    prev = session_seen.get(key, {})
                    if total >= prev.get("total", 0):
                        session_seen[key] = {"model": model, "input": inp, "output": out, "total": total}
            except:
                pass

total_cost = 0.0
model_costs = defaultdict(float)
for info in session_seen.values():
    model = info["model"]
    prices = PRICES.get(model, {"input": 3e-6, "output": 15e-6})
    cost = info["input"] * prices["input"] + info["output"] * prices["output"]
    total_cost += cost
    model_costs[model] += cost

cost_str = ", ".join(f"{m}: ${c:.2f}" for m, c in sorted(model_costs.items(), key=lambda x: -x[1]) if c > 0.001)
print(f"TOTAL_COST={total_cost:.2f}")
print(f"COST_BREAKDOWN={cost_str}")
print(f"TOTAL_SESSIONS={len(session_seen)}")
PYEOF

COST_DATA=$(python3 "$TMP_PY" "$TODAY" 2>/dev/null || echo "TOTAL_COST=?|COST_BREAKDOWN=Erro|TOTAL_SESSIONS=0")
TOTAL_COST=$(echo "$COST_DATA" | grep "^TOTAL_COST=" | cut -d= -f2-)
COST_BREAKDOWN=$(echo "$COST_DATA" | grep "^COST_BREAKDOWN=" | cut -d= -f2-)
TOTAL_SESSIONS=$(echo "$COST_DATA" | grep "^TOTAL_SESSIONS=" | cut -d= -f2-)

rm -f "$TMP_PY"

# ============================================================
# SECAO 3 — GIT (commits do dia)
# ============================================================
GIT_COMMITS=0
GIT_LIST=""
if cd "$WORKSPACE" 2>/dev/null; then
    GIT_COMMITS=$(git log --oneline --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GIT_COMMITS" -gt 0 ]; then
        GIT_LIST=$(git log --oneline --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" 2>/dev/null | head -5 | sed 's/^/  - /')
    fi
fi

# ============================================================
# SECAO 4 — AUTO-HEAL
# ============================================================
HEAL_ACTIONS=0
HEAL_SUMMARY="Nenhuma"
if [ -f "/tmp/openclaw/auto-heal.log" ]; then
    HEAL_ACTIONS=$(grep -c "$TODAY" /tmp/openclaw/auto-heal.log 2>/dev/null || echo 0)
    if [ "$HEAL_ACTIONS" -gt 0 ]; then
        HEAL_SUMMARY=$(grep "$TODAY" /tmp/openclaw/auto-heal.log 2>/dev/null | grep -oE "(HEAL|REPORT):.*" | sort -u | head -3 | tr '\n' ' | ' | sed 's/ | $//')
    fi
fi

# ============================================================
# SECAO 5 — ERROS DO GATEWAY
# ============================================================
GW_ERRS=0
GW_TIMEOUTS=0
TG_ERRS=0
if [ -f "$LOGS/gateway.err.log" ]; then
    GW_ERRS=$(grep -ci "$TODAY.*error\|$TODAY.*fail" "$LOGS/gateway.err.log" 2>/dev/null || echo 0)
    GW_TIMEOUTS=$(grep -ci "$TODAY.*timeout\|$TODAY.*timed out" "$LOGS/gateway.err.log" 2>/dev/null || echo 0)
    TG_ERRS=$(grep -ci "$TODAY.*telegram.*failed\|$TODAY.*telegram.*conflict" "$LOGS/gateway.err.log" 2>/dev/null || echo 0)
fi

# ============================================================
# SECAO 6 — GUARDIAN + WATCHDOG
# ============================================================
GUARDIAN_SUMMARY="OK"
if [ -f "$LOGS/guardian.log" ]; then
    G_DOWNS=$(grep -c "$TODAY.*DOWN" "$LOGS/guardian.log" 2>/dev/null || echo 0)
    G_RESTARTS=$(grep -c "$TODAY.*reiniciado\|$TODAY.*restart" "$LOGS/guardian.log" 2>/dev/null || echo 0)
    [ "$G_DOWNS" -gt 0 ] && GUARDIAN_SUMMARY="${G_DOWNS} downs, ${G_RESTARTS} restarts"
fi

WATCHDOG_SUMMARY="OK"
if [ -f "$LOGS/watchdog.log" ]; then
    W_ACTIONS=$(grep -c "$TODAY.*\[WATCHDOG\]" "$LOGS/watchdog.log" 2>/dev/null || echo 0)
    [ "$W_ACTIONS" -gt 0 ] && WATCHDOG_SUMMARY="${W_ACTIONS} acoes"
fi

# ============================================================
# SECAO 7 — CRONS EXECUTADOS
# ============================================================
CRON_LLM=$(python3 -c "
import json, os
f = os.path.expanduser('~/.openclaw/cron/jobs.json')
if os.path.exists(f):
    d = json.load(open(f))
    enabled = [j for j in d.get('jobs', []) if j.get('enabled', True)]
    print(len(enabled))
else:
    print(0)
" 2>/dev/null || echo 0)

CRON_SCRIPT=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l | tr -d ' ')

# ============================================================
# SECAO 8 — SUPABASE MISSIONS
# ============================================================
WMC_DATA="Nao consultado"
if [ -n "$WOLF_SVC_KEY" ] && [ -n "$WOLF_SUPABASE_URL" ]; then
    WMC_RESP=$(curl -s --max-time 10 \
        "${WOLF_SUPABASE_URL}/rest/v1/missions?created_at=gte.${TODAY}T00:00:00&select=id,status" \
        -H "apikey: ${WOLF_ANON_KEY}" \
        -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null || echo "[]")

    WMC_DATA=$(echo "$WMC_RESP" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        total = len(data)
        by_status = {}
        for m in data:
            s = m.get('status', '?')
            by_status[s] = by_status.get(s, 0) + 1
        parts = [f'{v} {k}' for k, v in sorted(by_status.items(), key=lambda x: -x[1])]
        print(f'{total} missoes: ' + ', '.join(parts) if parts else f'{total} missoes')
    else:
        print('Erro API')
except:
    print('Erro parse')
" 2>/dev/null || echo "Erro")
fi

# ============================================================
# SECAO 9 — CLICKUP TASKS
# ============================================================
CLICKUP_DATA="Nao consultado"
if [ -n "$CLICKUP_API_TOKEN" ] && [ -n "$CLICKUP_LIST_ID" ]; then
    TODAY_MS=$(python3 -c "import datetime; print(int(datetime.datetime.strptime('$TODAY', '%Y-%m-%d').timestamp() * 1000))" 2>/dev/null)
    CU_RESP=$(curl -s --max-time 10 \
        "https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/task?date_updated_gt=${TODAY_MS}&include_closed=true" \
        -H "Authorization: ${CLICKUP_API_TOKEN}" 2>/dev/null || echo '{"tasks":[]}')

    CLICKUP_DATA=$(echo "$CU_RESP" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tasks = data.get('tasks', [])
    total = len(tasks)
    by_status = {}
    for t in tasks:
        s = t.get('status', {}).get('status', '?')
        by_status[s] = by_status.get(s, 0) + 1
    parts = [f'{v} {k}' for k, v in sorted(by_status.items(), key=lambda x: -x[1])]
    print(f'{total} tasks: ' + ', '.join(parts) if total > 0 else 'Nenhuma task atualizada')
except:
    print('Erro parse')
" 2>/dev/null || echo "Erro")
fi

# ============================================================
# SECAO 10 — PENDENCIAS
# ============================================================
PENDING="Nenhuma pendencia registrada"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
if [ -f "$QUEUE" ]; then
    OPEN_COUNT=$(grep -c '^\- \[ \]' "$QUEUE" 2>/dev/null || echo 0)
    URGENT_COUNT=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c '^\- \[ \]' 2>/dev/null || echo 0)
    if [ "$OPEN_COUNT" -gt 0 ]; then
        PENDING_LIST=$(grep '^\- \[ \]' "$QUEUE" 2>/dev/null | head -5 | sed 's/^- \[ \] /  - /')
        PENDING="${OPEN_COUNT} em aberto (${URGENT_COUNT} urgentes)
  ${PENDING_LIST}"
    fi
fi

# ============================================================
# SECAO 11 — GATEWAY STATUS
# ============================================================
GW_PID=$(pgrep -f "openclaw" | head -1)
GW_STATUS="DOWN"
[ -n "$GW_PID" ] && GW_STATUS="UP"
DISCO=$(df -h / | awk 'NR==2{print $5}')

# ============================================================
# SECAO 12 — STRATEGIC BRAIN + CLIENT HEALTH
# ============================================================
BRAIN_SECTION=""
BRAIN_INSIGHT="$WORKSPACE/memory/brain/insight-evening-$TODAY.md"
BRAIN_MORNING="$WORKSPACE/memory/brain/insight-morning-$TODAY.md"
ACTIONS_FILE="$WORKSPACE/memory/brain/actions-$TODAY.md"

# Resumo do Brain (se pensou hoje)
if [ -f "$BRAIN_INSIGHT" ] || [ -f "$BRAIN_MORNING" ]; then
    BRAIN_THOUGHTS=0
    [ -f "$BRAIN_MORNING" ] && BRAIN_THOUGHTS=$((BRAIN_THOUGHTS + 1))
    [ -f "$BRAIN_INSIGHT" ] && BRAIN_THOUGHTS=$((BRAIN_THOUGHTS + 1))
    BRAIN_SECTION="
🧠 *Strategic Brain*
Sessoes de pensamento: ${BRAIN_THOUGHTS}/2"
fi

# Ações autônomas do dia
if [ -f "$ACTIONS_FILE" ]; then
    ACTIONS_COUNT=$(grep -c "^-\|^[0-9]" "$ACTIONS_FILE" 2>/dev/null || echo 0)
    [ "$ACTIONS_COUNT" -gt 0 ] && BRAIN_SECTION="${BRAIN_SECTION}
Acoes autonomas: ${ACTIONS_COUNT}"
fi

# Melhorias implementadas hoje
IMP_TODAY=$(grep -c "\[$TODAY\]" "$WORKSPACE/memory/improvement-log.md" 2>/dev/null || echo 0)
[ "$IMP_TODAY" -gt 0 ] && BRAIN_SECTION="${BRAIN_SECTION}
Melhorias implementadas: ${IMP_TODAY}"

# Client Health Summary
HEALTH_SECTION=""
for hf in "$WORKSPACE"/memory/clients/*/health.yaml; do
    [ -f "$hf" ] || continue
    H_NAME=$(grep "client:" "$hf" 2>/dev/null | awk -F'"' '{print $2}')
    H_SCORE=$(grep "  score:" "$hf" 2>/dev/null | awk '{print $2}')
    H_TREND=$(grep "  trend:" "$hf" 2>/dev/null | awk '{print $2}')
    H_EMOJI="🟢"; [ "${H_SCORE:-0}" -lt 70 ] 2>/dev/null && H_EMOJI="🟡"; [ "${H_SCORE:-0}" -lt 50 ] 2>/dev/null && H_EMOJI="🔴"
    HEALTH_SECTION="${HEALTH_SECTION}  ${H_EMOJI} ${H_NAME}: ${H_SCORE}/100 (${H_TREND})
"
done
if [ -n "$HEALTH_SECTION" ]; then
    BRAIN_SECTION="${BRAIN_SECTION}

🏥 *Saude dos Clientes*
${HEALTH_SECTION}"
fi

# ============================================================
# MONTAR RELATORIO
# ============================================================

# Status do sistema
if [ "$GW_STATUS" = "UP" ]; then GW_ICON="🟢"; else GW_ICON="🔴"; fi
if [ "$GIT_COMMITS" -gt 0 ]; then
    GIT_SECTION="
💾 *Commits do dia (${GIT_COMMITS})*
${GIT_LIST}"
else
    GIT_SECTION=""
fi

# Pendencias formatadas
if [ "$OPEN_COUNT" -gt 0 ] 2>/dev/null; then
    PENDING_HEADER="⏳ *Pendencias (${OPEN_COUNT} · ${URGENT_COUNT} urgentes)*"
else
    PENDING_HEADER="⏳ *Pendencias*"
fi

REPORT="🐺 *Wolf — Relatorio Diario | ${DATE} 20h*

👥 *Atividade*
${SENDERS}
Total: ${USER_MSGS} msgs · ${SESSIONS_COUNT} sessoes

💰 *Custo do dia*
\$${TOTAL_COST} total (${TOTAL_SESSIONS} sessoes)
${COST_BREAKDOWN}

⚙️ *Sistema*
GW: ${GW_ICON} ${GW_STATUS} · Disco: ${DISCO}
Erros: ${GW_ERRS} GW · ${GW_TIMEOUTS} timeouts · ${TG_ERRS} Telegram
Auto-Heal: ${HEAL_ACTIONS} acoes · Watchdog: ${WATCHDOG_SUMMARY}
Crons: ${CRON_LLM} LLM + ${CRON_SCRIPT} script${GIT_SECTION}

📋 *Missoes & Tarefas*
Mission Control: ${WMC_DATA}
ClickUp: ${CLICKUP_DATA}

${PENDING_HEADER}
${PENDING}${BRAIN_SECTION}"

# ============================================================
# ENVIAR + SALVAR
# ============================================================

wolf_notify "$REPORT"

echo "$REPORT" > "$REPORT_FILE"

wolf_log "ops-report" "Relatorio enviado — msgs=$USER_MSGS sessions=$SESSIONS_COUNT cost=$TOTAL_COST"
echo "OK: wolf-daily-ops-report completed at $(date '+%Y-%m-%d %H:%M:%S')"
