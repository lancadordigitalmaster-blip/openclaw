#!/bin/bash
# heartbeat-iris.sh — Iris (Data/Analytics) heartbeat diario 07h30
# Compila metricas do sistema: tokens, custos, missoes, uptime
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="f9ee60e7-2fda-47b4-b49f-893b2b987b23"
AGENT="Iris"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de analytics"

MID=$(wolf_mission_create "Iris — Relatorio de metricas diario" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, compilando metricas do sistema." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Token telemetry
TELEMETRY="$HOME/.openclaw/logs/token-telemetry.jsonl"
TODAY=$(date +"%Y-%m-%d")
if [ -f "$TELEMETRY" ]; then
    TEL_TOTAL=$(wc -l < "$TELEMETRY" | tr -d ' ')
    TEL_TODAY=$(grep -c "$TODAY" "$TELEMETRY" 2>/dev/null || echo "0")
    METRICS="Telemetria: $TEL_TOTAL entries ($TEL_TODAY hoje)"
else
    METRICS="Telemetria: arquivo nao encontrado"
    WARNINGS+=("token-telemetry.jsonl nao existe")
fi

# 2. Missoes hoje
MISSIONS_TODAY=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?created_at=gte.${TODAY}T00:00:00&select=id,status" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
from collections import Counter
data = json.load(sys.stdin)
c = Counter(m['status'] for m in data)
total = len(data)
done = c.get('done', 0)
print(f'{total} total ({done} done)')
" 2>/dev/null || echo "?")
METRICS="$METRICS | Missoes hoje: $MISSIONS_TODAY"

# 3. Handoffs hoje (comunicacao entre agentes)
HANDOFFS_TODAY=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/handoffs?created_at=gte.${TODAY}T00:00:00&select=id" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json; print(len(json.load(sys.stdin)))
" 2>/dev/null || echo "?")
METRICS="$METRICS | Comunicacoes hoje: $HANDOFFS_TODAY"

# 4. Gateway uptime (tempo desde ultimo restart)
GW_PID=$(pgrep -f "openclaw" 2>/dev/null | head -1)
if [ -n "$GW_PID" ]; then
    GW_START=$(ps -o lstart= -p "$GW_PID" 2>/dev/null)
    METRICS="$METRICS | Gateway up desde: $GW_START"
fi

# 5. Logs gerados hoje
LOG_DIR="$WOLF_WORKSPACE/memory/logs"
LOGS_TODAY=0
if [ -d "$LOG_DIR" ]; then
    LOGS_TODAY=$(find "$LOG_DIR" -type f -newer "$LOG_DIR" -mtime 0 2>/dev/null | wc -l | tr -d ' ')
fi
METRICS="$METRICS | Logs hoje: $LOGS_TODAY"

# 6. Memory files atualizados hoje
MEM_TODAY=$(find "$WOLF_WORKSPACE/memory" -maxdepth 1 -type f -name "*.md" -newer /tmp -mtime 0 2>/dev/null | wc -l | tr -d ' ')
METRICS="$METRICS | Memory updates hoje: $MEM_TODAY"

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

wolf_mission_move "$MID" "done" "$DESCRIPTION"
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, metricas do dia: $MISSIONS_TODAY missoes, $HANDOFFS_TODAY comunicacoes entre agentes." "signal"

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: iris heartbeat — missions=$MISSIONS_TODAY handoffs=$HANDOFFS_TODAY"
