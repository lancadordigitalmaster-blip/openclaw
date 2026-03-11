#!/bin/bash
# heartbeat-atlas.sh — Atlas (DB) heartbeat diario 04h
# Verifica: Supabase health, tabelas, row counts, tamanho
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="2ccfa51e-eda1-49b1-967d-6fb423cb4448"
AGENT="Atlas"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de banco de dados"

MID=$(wolf_mission_create "Atlas — Verificacao de banco de dados" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando saude do Supabase." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Supabase REST health
SB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "${WOLF_SUPABASE_URL}/rest/v1/" \
    -H "apikey: ${WOLF_ANON_KEY}" 2>/dev/null || echo "000")
if [ "$SB_STATUS" = "200" ]; then
    METRICS="Supabase REST: OK"
else
    ISSUES+=("Supabase REST: HTTP $SB_STATUS")
    METRICS="Supabase REST: ERRO $SB_STATUS"
fi

# 2. Row counts das tabelas principais
for table in missions agents handoffs; do
    COUNT=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/${table}?select=id&limit=0" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Prefer: count=exact" \
        -I 2>/dev/null | grep -i "content-range" | grep -oE '/[0-9]+' | tr -d '/' || echo "?")
    METRICS="$METRICS | ${table}: ${COUNT:-?} rows"
done

# 3. Missions por status
STATUS_DIST=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?select=status" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
from collections import Counter
data = json.load(sys.stdin)
c = Counter(m['status'] for m in data)
parts = [f'{s}:{n}' for s,n in sorted(c.items())]
print(' '.join(parts))
" 2>/dev/null || echo "?")
METRICS="$METRICS | Distribuicao: $STATUS_DIST"

# 4. Agents sem UUID (orfaos)
ORPHAN_AGENTS=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/agents?status=eq.error&select=name" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data))
" 2>/dev/null || echo "0")
[ "${ORPHAN_AGENTS:-0}" -gt 0 ] && WARNINGS+=("$ORPHAN_AGENTS agente(s) em estado de erro")

# 5. Handoffs nas ultimas 24h
YESTERDAY=$(date -v-1d +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "yesterday" +%Y-%m-%dT%H:%M:%S 2>/dev/null)
RECENT_HANDOFFS=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/handoffs?created_at=gte.${YESTERDAY}&select=id" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json
print(len(json.load(sys.stdin)))
" 2>/dev/null || echo "?")
METRICS="$METRICS | Handoffs 24h: $RECENT_HANDOFFS"

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, Supabase com ${#ISSUES[@]} problema(s). Verificar conexao." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, banco OK com ${#WARNINGS[@]} aviso(s). $RECENT_HANDOFFS handoffs nas ultimas 24h." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, Supabase saudavel. $RECENT_HANDOFFS handoffs nas ultimas 24h." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: atlas heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
