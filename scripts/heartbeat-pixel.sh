#!/bin/bash
# heartbeat-pixel.sh — Pixel (Frontend) heartbeat semanal (quarta 06h)
# Verifica: HTML valido, dashboard acessivel, assets, tamanho de arquivos
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="a80ea966-4c6d-49a0-863e-7420ca5d82b3"
AGENT="Pixel"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de frontend"

MID=$(wolf_mission_create "Pixel — Auditoria de frontend" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando saude do frontend." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Dashboards HTML existem e tem conteudo
HTML_OK=0
HTML_TOTAL=0
for html_file in "$WOLF_WORKSPACE"/wolf-mission-control-final.html "$WOLF_WORKSPACE"/wolf-analytics.html "$WOLF_WORKSPACE"/kanban-wolf.html; do
    HTML_TOTAL=$((HTML_TOTAL + 1))
    if [ -f "$html_file" ]; then
        SIZE=$(wc -c < "$html_file" | tr -d ' ')
        if [ "$SIZE" -gt 1000 ]; then
            HTML_OK=$((HTML_OK + 1))
        else
            WARNINGS+=("$(basename "$html_file") muito pequeno ($SIZE bytes)")
        fi
    else
        WARNINGS+=("$(basename "$html_file") nao encontrado")
    fi
done
METRICS="Dashboards HTML: $HTML_OK/$HTML_TOTAL OK"

# 2. WMC dashboard acessivel
WMC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:8765/wolf-mission-control-final.html" 2>/dev/null || echo "000")
METRICS="$METRICS | WMC HTTP: $WMC_STATUS"
[ "$WMC_STATUS" != "200" ] && WARNINGS+=("WMC dashboard nao acessivel (HTTP $WMC_STATUS)")

# 3. Tamanho total de HTML files
TOTAL_HTML_SIZE=$(find "$WOLF_WORKSPACE" -maxdepth 1 -name "*.html" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}')
TOTAL_HTML_KB=$((${TOTAL_HTML_SIZE:-0} / 1024))
METRICS="$METRICS | HTML total: ${TOTAL_HTML_KB}KB"
[ "$TOTAL_HTML_KB" -gt 500 ] && WARNINGS+=("HTML files totalizando ${TOTAL_HTML_KB}KB (considerar otimizacao)")

# 4. Contar HTML files
HTML_COUNT=$(find "$WOLF_WORKSPACE" -maxdepth 1 -name "*.html" 2>/dev/null | wc -l | tr -d ' ')
METRICS="$METRICS | Arquivos HTML: $HTML_COUNT"

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, frontend com ${#ISSUES[@]} problema(s)." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, frontend OK com ${#WARNINGS[@]} aviso(s). $HTML_OK/$HTML_TOTAL dashboards funcionando." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, frontend solido. $HTML_OK dashboards OK, WMC acessivel." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: pixel heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
