#!/bin/bash
# heartbeat-bridge.sh — Bridge (Integracoes) heartbeat diario 05h
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="eb1709c4-9ea1-4665-9cd3-e9c96d543972"  # Bridge UUID
AGENT="Bridge"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
CHECKS_OK=0

wolf_log "$AGENT" "Iniciando heartbeat de integracoes"

# ── ETAPA 1: Missao nasce (inbox) ──
MID=$(wolf_mission_create "Bridge — Verificacao de integracoes" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando verificacao de todas integracoes externas." "signal"

# ── ETAPA 2: Bridge pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Bridge comeca a verificar (in_progress) ──
wolf_mission_move "$MID" "in_progress"

# 1. ClickUp API
if [ -n "${CLICKUP_API_TOKEN:-}" ]; then
    CU_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://api.clickup.com/api/v2/team" \
        -H "Authorization: ${CLICKUP_API_TOKEN}" 2>/dev/null || echo "000")
    if [ "$CU_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
    else WARNINGS+=("ClickUp API: HTTP $CU_STATUS"); fi
else
    WARNINGS+=("ClickUp API token nao configurado")
fi

# 2. Supabase
SB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "${WOLF_SUPABASE_URL}/rest/v1/missions?select=id&limit=1" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null || echo "000")
if [ "$SB_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
else ISSUES+=("Supabase REST: HTTP $SB_STATUS"); fi

# 3. Telegram Bot API
if [ -n "$WOLF_BOT_TOKEN" ]; then
    TG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://api.telegram.org/bot${WOLF_BOT_TOKEN}/getMe" 2>/dev/null || echo "000")
    if [ "$TG_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
    else ISSUES+=("Telegram Bot API: HTTP $TG_STATUS"); fi
fi

# 4. Evolution API (WhatsApp)
if [ -n "${WOLF_API_URL:-}" ]; then
    EVO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "$WOLF_API_URL" 2>/dev/null || echo "000")
    if [ "$EVO_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
    else WARNINGS+=("W.O.L.F. API: HTTP $EVO_STATUS"); fi
fi

# 5. Meta Ads token
if [ -n "${META_ADS_ACCESS_TOKEN:-}" ]; then
    META_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://graph.facebook.com/v19.0/me?access_token=${META_ADS_ACCESS_TOKEN}" 2>/dev/null || echo "000")
    if [ "$META_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
    else WARNINGS+=("Meta Ads token: HTTP $META_STATUS (provavelmente expirado)"); fi
fi

# 6. Anthropic API
ANTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: ${ANTHROPIC_API_KEY:-}" \
    -H "anthropic-version: 2023-06-01" 2>/dev/null || echo "000")
if [ "$ANTH_STATUS" != "000" ]; then CHECKS_OK=$((CHECKS_OK + 1))
else WARNINGS+=("Anthropic API: sem conectividade"); fi

# 7. OpenRouter
OR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "https://openrouter.ai/api/v1/models" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY:-}" 2>/dev/null || echo "000")
if [ "$OR_STATUS" = "200" ]; then CHECKS_OK=$((CHECKS_OK + 1))
else WARNINGS+=("OpenRouter API: HTTP $OR_STATUS"); fi

# ── ETAPA 4: Resultado ──
TOTAL_CHECKS=$((CHECKS_OK + ${#ISSUES[@]} + ${#WARNINGS[@]}))
DESCRIPTION="Integracoes verificadas: $CHECKS_OK/$TOTAL_CHECKS OK"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Bridge detectou ${#ISSUES[@]} integracao(oes) com problema:"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, ${#ISSUES[@]} integracao(oes) com problema. Verificar urgente." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, integracoes verificadas — ${#WARNINGS[@]} aviso(s), nada critico." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, todas integracoes respondendo normalmente." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — OK:$CHECKS_OK issues:${#ISSUES[@]} warnings:${#WARNINGS[@]}"
echo "OK: bridge heartbeat — checks=$CHECKS_OK issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
