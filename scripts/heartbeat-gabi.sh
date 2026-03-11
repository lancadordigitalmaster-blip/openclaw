#!/bin/bash
# heartbeat-gabi.sh — Gabi (Trafego) heartbeat diario 09h
# Verifica: Meta Ads token, configs de campanha, dados de trafego
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="800e7e7a-5c54-4aad-a8d2-8b4a4b147a51"
AGENT="Gabi"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de trafego"

MID=$(wolf_mission_create "Gabi — Status de trafego e ads" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando status de trafego pago." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Meta Ads token
if [ -n "${META_ADS_ACCESS_TOKEN:-}" ]; then
    META_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://graph.facebook.com/v19.0/me?access_token=${META_ADS_ACCESS_TOKEN}" 2>/dev/null || echo "000")
    if [ "$META_STATUS" = "200" ]; then
        METRICS="Meta Ads token: valido"
    else
        WARNINGS+=("Meta Ads token expirado (HTTP $META_STATUS) — Netto precisa gerar novo")
        METRICS="Meta Ads token: EXPIRADO"
    fi
else
    WARNINGS+=("META_ADS_ACCESS_TOKEN nao configurado no .env")
    METRICS="Meta Ads token: nao configurado"
fi

# 2. Skill de Meta Ads existe
SKILL_FILE="$WOLF_WORKSPACE/skills/meta-ads/SKILL.md"
if [ -f "$SKILL_FILE" ]; then
    SKILL_LINES=$(wc -l < "$SKILL_FILE" | tr -d ' ')
    METRICS="$METRICS | Skill meta-ads: $SKILL_LINES linhas"
else
    WARNINGS+=("Skill meta-ads nao encontrada")
fi

# 3. Framework de trafego disponivel
FW_FILE="$WOLF_WORKSPACE/shared/memory/framework-newton-trafego.md"
if [ -f "$FW_FILE" ]; then
    FW_LINES=$(wc -l < "$FW_FILE" | tr -d ' ')
    METRICS="$METRICS | Framework Newton: $FW_LINES linhas"
else
    WARNINGS+=("Framework de trafego nao encontrado")
fi

# 4. Dados de clientes (tem campanhas para rodar?)
CLIENTS_FILE="$WOLF_WORKSPACE/shared/memory/clients.yaml"
if [ -f "$CLIENTS_FILE" ]; then
    CLIENT_COUNT=$(grep -c "^  - name:" "$CLIENTS_FILE" 2>/dev/null || echo "0")
    METRICS="$METRICS | Clientes cadastrados: $CLIENT_COUNT"
else
    WARNINGS+=("clients.yaml nao existe — sem base de clientes")
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, trafego com ${#ISSUES[@]} problema(s)." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, trafego com ${#WARNINGS[@]} aviso(s). Token Meta Ads precisa de atencao." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, trafego pronto. Meta Ads operacional." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: gabi heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
