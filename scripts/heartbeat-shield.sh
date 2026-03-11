#!/bin/bash
# heartbeat-shield.sh — Shield (Seguranca) heartbeat diario 02h
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a"  # Shield UUID
AGENT="Shield"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
CHECKS_OK=0

wolf_log "$AGENT" "Iniciando heartbeat de seguranca"

# ── ETAPA 1: Missao nasce no kanban (inbox) ──
PRIORITY="low"
MID=$(wolf_mission_create "Shield — Scan de seguranca" "$AGENT_ID" "$PRIORITY")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando scan de seguranca do sistema." "signal"

# ── ETAPA 2: Shield pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Shield comeca a trabalhar (in_progress) ──
wolf_mission_move "$MID" "in_progress"

# 1. Verificar permissoes de .env
if [ -f "$HOME/.openclaw/.env" ]; then
    PERMS=$(stat -f '%Lp' "$HOME/.openclaw/.env" 2>/dev/null || echo "?")
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "640" ]; then
        CHECKS_OK=$((CHECKS_OK + 1))
    else
        ISSUES+=("Permissao .env: $PERMS (deveria ser 600)")
    fi
fi

# 2. Verificar se API keys estao validas (Anthropic primario)
ANTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: ${ANTHROPIC_API_KEY:-}" \
    -H "anthropic-version: 2023-06-01" 2>/dev/null || echo "000")
if [ "$ANTH_STATUS" != "000" ]; then
    CHECKS_OK=$((CHECKS_OK + 1))
else
    WARNINGS+=("Anthropic API: sem conectividade")
fi

OR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "https://openrouter.ai/api/v1/models" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY:-}" 2>/dev/null || echo "000")
if [ "$OR_STATUS" = "200" ]; then
    CHECKS_OK=$((CHECKS_OK + 1))
else
    WARNINGS+=("OpenRouter API: HTTP $OR_STATUS")
fi

SB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "${WOLF_SUPABASE_URL}/rest/v1/agents?select=id&limit=1" \
    -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null || echo "000")
if [ "$SB_STATUS" = "200" ]; then
    CHECKS_OK=$((CHECKS_OK + 1))
else
    ISSUES+=("Supabase API: HTTP $SB_STATUS")
fi

# 2b. Credential Monitor — testar tokens que podem expirar
# Meta Ads token
if [ -n "${META_ADS_ACCESS_TOKEN:-}" ]; then
    META_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_ACCESS_TOKEN}" 2>/dev/null || echo "000")
    if [ "$META_STATUS" = "200" ]; then
        CHECKS_OK=$((CHECKS_OK + 1))
    else
        ISSUES+=("Meta Ads token EXPIRADO (HTTP $META_STATUS) — Netto precisa renovar em developers.facebook.com")
    fi
else
    WARNINGS+=("META_ADS_ACCESS_TOKEN nao configurado no .env")
fi

# Telegram Bot token
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
    TG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null || echo "000")
    if [ "$TG_STATUS" = "200" ]; then
        CHECKS_OK=$((CHECKS_OK + 1))
    else
        ISSUES+=("Telegram Bot token invalido (HTTP $TG_STATUS)")
    fi
fi

# Supabase service key (já testa acima, mas checa se existe)
[ -z "${WOLF_SVC_KEY:-}" ] && WARNINGS+=("WOLF_SVC_KEY nao configurada no .env")

# 3. Tokens expostos em logs
LOG_DIR="$WOLF_WORKSPACE/memory/logs"
if [ -d "$LOG_DIR" ]; then
    EXPOSED=$(grep -rl 'bot[0-9]\{10\}:\|sk-or-v1-\|gsk_\|AIzaSy' "$LOG_DIR" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${EXPOSED:-0}" -gt 0 ] 2>/dev/null; then
        ISSUES+=("$EXPOSED arquivo(s) de log com tokens expostos")
    else
        CHECKS_OK=$((CHECKS_OK + 1))
    fi
fi

# 4. .env em locais inesperados
STRAY_ENV=$(find "$WOLF_WORKSPACE" -maxdepth 3 -name ".env*" -not -path "*/.openclaw/*" -not -path "*/_archive/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "${STRAY_ENV:-0}" -gt 0 ] 2>/dev/null; then
    WARNINGS+=("$STRAY_ENV arquivo(s) .env no workspace (deveriam estar em ~/.openclaw/)")
fi

# 5. Sessoes acumuladas
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [ -f "$SESSIONS_FILE" ]; then
    SESSION_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS_FILE')); print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo "0")
    if [ "$SESSION_COUNT" -gt 15 ]; then
        WARNINGS+=("$SESSION_COUNT sessoes acumuladas (risco de leak de contexto)")
    else
        CHECKS_OK=$((CHECKS_OK + 1))
    fi
fi

# 6. Gateway respondendo
GW_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
if [ "$GW_HTTP" = "200" ]; then
    CHECKS_OK=$((CHECKS_OK + 1))
else
    ISSUES+=("Gateway nao responde (HTTP $GW_HTTP)")
fi

# ── ETAPA 4: Resultado — mover para done ou manter in_progress ──
TOTAL_CHECKS=$((CHECKS_OK + ${#ISSUES[@]} + ${#WARNINGS[@]}))
DESCRIPTION="Checks OK: $CHECKS_OK/$TOTAL_CHECKS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    # Problema critico — card fica em in_progress (precisa atencao)
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Shield detectou ${#ISSUES[@]} problema(s) de seguranca:"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, detectei ${#ISSUES[@]} problema(s) de seguranca. Preciso de atencao." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    # Avisos — card vai pra done mas reporta
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, scan concluido com ${#WARNINGS[@]} aviso(s). Nada critico." "signal"
else
    # Tudo limpo — card vai pra done
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, seguranca verificada. Tudo limpo." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — OK:$CHECKS_OK issues:${#ISSUES[@]} warnings:${#WARNINGS[@]}"
echo "OK: shield heartbeat — checks=$CHECKS_OK issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
