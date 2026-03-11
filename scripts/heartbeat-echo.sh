#!/bin/bash
# heartbeat-echo.sh — Echo (Mobile/Webhooks) heartbeat diario 05h30
# Verifica: webhook receiver, portas, ngrok, endpoints
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="2c01996c-ff7f-46d4-99d6-310ecd5391a0"
AGENT="Echo"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de webhooks"

MID=$(wolf_mission_create "Echo — Verificacao de webhooks e endpoints" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando webhooks e endpoints." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Webhook receiver (porta 18790)
WH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:18790/" 2>/dev/null || echo "000")
if [ "$WH_STATUS" = "200" ] || [ "$WH_STATUS" = "404" ]; then
    METRICS="Webhook receiver: respondendo (HTTP $WH_STATUS)"
else
    WARNINGS+=("Webhook receiver nao responde (porta 18790)")
    METRICS="Webhook receiver: offline"
fi

# 2. Gateway (porta 18789)
GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
METRICS="$METRICS | Gateway: HTTP $GW_STATUS"
[ "$GW_STATUS" != "200" ] && ISSUES+=("Gateway nao responde (HTTP $GW_STATUS)")

# 3. Dashboard WMC (porta 8765)
WMC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:8765/" 2>/dev/null || echo "000")
METRICS="$METRICS | Dashboard WMC: HTTP $WMC_STATUS"
[ "$WMC_STATUS" != "200" ] && WARNINGS+=("Dashboard WMC nao responde (porta 8765)")

# 4. Portas em uso
PORTS_USED=$(lsof -iTCP -sTCP:LISTEN -P 2>/dev/null | grep -c "18789\|18790\|8765" || echo "0")
METRICS="$METRICS | Portas Wolf ativas: $PORTS_USED/3"

# 5. ngrok (se configurado)
if [ -n "${WOLF_API_URL:-}" ]; then
    NGROK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$WOLF_API_URL" 2>/dev/null || echo "000")
    METRICS="$METRICS | ngrok: HTTP $NGROK_STATUS"
    [ "$NGROK_STATUS" != "200" ] && WARNINGS+=("ngrok endpoint nao responde")
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, endpoints com ${#ISSUES[@]} problema(s)." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, endpoints OK com ${#WARNINGS[@]} aviso(s). $PORTS_USED/3 portas ativas." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, todos endpoints respondendo. $PORTS_USED/3 portas ativas." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: echo heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
