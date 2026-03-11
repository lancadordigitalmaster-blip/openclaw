#!/bin/bash
# heartbeat-vega.sh — Vega (QA) heartbeat diario 08h
# Verifica: resultados dos outros heartbeats, missoes falhadas, consistencia
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="0331da72-c816-44a2-9cda-4b3730fee1c2"
AGENT="Vega"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de QA"

MID=$(wolf_mission_create "Vega — Auditoria de qualidade do sistema" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando qualidade geral do sistema." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

TODAY=$(date +"%Y-%m-%d")

# 1. Missoes stuck (in_progress ha mais de 6h)
SIX_HOURS_AGO=$(date -v-6H +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "6 hours ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null)
STUCK=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?status=eq.in_progress&updated_at=lt.${SIX_HOURS_AGO}&select=id,title" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data))
" 2>/dev/null || echo "0")
METRICS="Missoes stuck (>6h): $STUCK"
[ "${STUCK:-0}" -gt 0 ] && WARNINGS+=("$STUCK missao(oes) parada(s) ha mais de 6h")

# 2. Missoes blocked sem resolucao
BLOCKED=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?status=eq.blocked&select=id" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json; print(len(json.load(sys.stdin)))
" 2>/dev/null || echo "0")
METRICS="$METRICS | Blocked: $BLOCKED"

# 3. Taxa de sucesso hoje
TODAY_STATS=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?created_at=gte.${TODAY}T00:00:00&select=status" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
from collections import Counter
data = json.load(sys.stdin)
c = Counter(m['status'] for m in data)
total = len(data)
done = c.get('done', 0)
rate = round(done/total*100) if total > 0 else 0
print(f'{done}/{total} ({rate}%)')
" 2>/dev/null || echo "?")
METRICS="$METRICS | Taxa sucesso hoje: $TODAY_STATS"

# 4. Heartbeats que rodaram hoje (verificar logs)
HB_RAN=0
for hb in shield bridge flux turbo craft quill titan ops atlas iris forge pixel echo vega; do
    if [ -f "$WOLF_WORKSPACE/scripts/heartbeat-${hb}.sh" ]; then
        HB_RAN=$((HB_RAN + 1))
    fi
done
METRICS="$METRICS | Heartbeats disponiveis: $HB_RAN"

# 5. Errors.md — novos erros hoje
ERRORS_FILE="$WOLF_WORKSPACE/memory/errors.md"
if [ -f "$ERRORS_FILE" ]; then
    ERRORS_TODAY=$(grep -c "$TODAY" "$ERRORS_FILE" 2>/dev/null || echo "0")
    METRICS="$METRICS | Erros registrados hoje: $ERRORS_TODAY"
    [ "${ERRORS_TODAY:-0}" -gt 3 ] && WARNINGS+=("$ERRORS_TODAY erros registrados hoje em errors.md")
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, QA encontrou ${#ISSUES[@]} problema(s). Sistema precisa de atencao." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, QA OK com ${#WARNINGS[@]} ponto(s). Taxa sucesso: $TODAY_STATS" "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, qualidade do sistema aprovada. Taxa sucesso: $TODAY_STATS" "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: vega heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
