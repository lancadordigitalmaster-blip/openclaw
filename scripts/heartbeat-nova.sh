#!/bin/bash
# heartbeat-nova.sh — Nova (Estrategia) heartbeat semanal (segunda 10h)
# Verifica: dados de clientes, metas, documentos estrategicos
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="2990278a-26bb-4f10-a056-03bcbc74d058"
AGENT="Nova"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de estrategia"

MID=$(wolf_mission_create "Nova — Revisao estrategica semanal" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando dados estrategicos da Wolf." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Clientes cadastrados
CLIENTS_YAML="$WOLF_WORKSPACE/shared/memory/clients.yaml"
if [ -f "$CLIENTS_YAML" ]; then
    CLIENTS=$(grep -c "name:" "$CLIENTS_YAML" 2>/dev/null || echo "0")
    METRICS="Clientes: $CLIENTS"
else
    WARNINGS+=("clients.yaml ausente — base de clientes vazia")
    METRICS="Clientes: 0"
fi

# 2. Equipe cadastrada
TEAM_YAML="$WOLF_WORKSPACE/shared/memory/team.yaml"
if [ -f "$TEAM_YAML" ]; then
    MEMBERS=$(grep -c "nome:" "$TEAM_YAML" 2>/dev/null || echo "0")
    METRICS="$METRICS | Equipe: $MEMBERS membros"
else
    WARNINGS+=("team.yaml ausente")
fi

# 3. Metas documentadas
METAS_FILE="$WOLF_WORKSPACE/memory/metas-wolf.md"
if [ -f "$METAS_FILE" ]; then
    META_LINES=$(wc -l < "$METAS_FILE" | tr -d ' ')
    METRICS="$METRICS | Metas: $META_LINES linhas"
else
    WARNINGS+=("metas-wolf.md nao encontrado")
fi

# 4. Missoes completadas esta semana
WEEK_AGO=$(date -v-7d +%Y-%m-%dT00:00:00 2>/dev/null || date -d "7 days ago" +%Y-%m-%dT00:00:00 2>/dev/null)
WEEK_DONE=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?status=eq.done&completed_at=gte.${WEEK_AGO}&select=id" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null | python3 -c "
import sys, json; print(len(json.load(sys.stdin)))
" 2>/dev/null || echo "?")
METRICS="$METRICS | Missoes semana: $WEEK_DONE concluidas"

# 5. Skills de estrategia
STRATEGY_SKILL="$WOLF_WORKSPACE/agents/strategy/SKILL.md"
if [ -f "$STRATEGY_SKILL" ]; then
    LINES=$(wc -l < "$STRATEGY_SKILL" | tr -d ' ')
    METRICS="$METRICS | Nova SKILL.md: $LINES linhas"
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

wolf_mission_move "$MID" "done" "$DESCRIPTION"
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, revisao estrategica: $WEEK_DONE missoes concluidas esta semana. $CLIENTS clientes cadastrados." "signal"

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: nova heartbeat — warnings=${#WARNINGS[@]}"
