#!/bin/bash
# heartbeat-ops.sh — Ops (DevOps) heartbeat diario 03h
# Verifica: LaunchAgents, crontab, processos, gateway, disk
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="dd80a08b-9f08-478c-acd3-610414fb3bff"
AGENT="Ops"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de infraestrutura"

MID=$(wolf_mission_create "Ops — Verificacao de infraestrutura" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando infraestrutura local." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. LaunchAgents ativos
LA_DIR="$HOME/Library/LaunchAgents"
LA_WOLF=$(find "$LA_DIR" -name "ai.openclaw.*" -o -name "com.wolf.*" 2>/dev/null | wc -l | tr -d ' ')
METRICS="LaunchAgents Wolf: $LA_WOLF"

# 2. Gateway rodando
GW_PID=$(pgrep -f "openclaw" 2>/dev/null | head -1)
if [ -n "$GW_PID" ]; then
    GW_MEM=$(ps -o rss= -p "$GW_PID" 2>/dev/null | tr -d ' ')
    GW_MB=$((${GW_MEM:-0} / 1024))
    METRICS="$METRICS | Gateway PID:$GW_PID (${GW_MB}MB)"
    [ "$GW_MB" -gt 500 ] && WARNINGS+=("Gateway usando ${GW_MB}MB de RAM")
else
    ISSUES+=("Gateway nao esta rodando")
fi

# 3. Crontab entries
CRON_COUNT=$(crontab -l 2>/dev/null | grep -v '^#' | grep -c '.' || echo "0")
CRON_ERRORS=0
while IFS= read -r line; do
    script_path=$(echo "$line" | grep -oE '/[^ ]+\.sh' | head -1)
    [ -n "$script_path" ] && [ ! -f "$script_path" ] && CRON_ERRORS=$((CRON_ERRORS + 1))
done < <(crontab -l 2>/dev/null | grep -v '^#' | grep '\.sh')
METRICS="$METRICS | Crontab: $CRON_COUNT jobs"
[ "$CRON_ERRORS" -gt 0 ] && ISSUES+=("$CRON_ERRORS scripts no crontab nao existem")

# 4. OpenClaw crons ativos
OC_CRONS=$(python3 -c "
import json
data = json.load(open('$HOME/.openclaw/cron/jobs.json'))
active = sum(1 for j in data.get('jobs',[]) if j.get('enabled'))
total = len(data.get('jobs',[]))
print(f'{active}/{total}')
" 2>/dev/null || echo "?/?")
METRICS="$METRICS | OpenClaw crons: $OC_CRONS ativos"

# 5. Processos Python/Node consumindo
PROC_COUNT=$(ps aux 2>/dev/null | grep -c '[p]ython3\|[n]ode' || echo "0")
METRICS="$METRICS | Processos node/python: $PROC_COUNT"

# 6. Delivery queue
DQ_DIR="$HOME/.openclaw/delivery-queue"
if [ -d "$DQ_DIR" ]; then
    DQ_COUNT=$(find "$DQ_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    METRICS="$METRICS | Delivery queue: $DQ_COUNT"
    [ "${DQ_COUNT:-0}" -gt 10 ] && WARNINGS+=("Delivery queue com $DQ_COUNT items acumulados")
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, infra com ${#ISSUES[@]} problema(s). Verificar urgente." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, infra OK com ${#WARNINGS[@]} aviso(s)." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, infraestrutura saudavel. Gateway rodando, $CRON_COUNT crons ativos." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: ops heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
