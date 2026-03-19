#!/bin/bash
# integration-check.sh — Validacao semanal de todas as integracoes
# Crontab: 0 6 * * 1 bash ~/.openclaw/workspace/scripts/integration-check.sh >> ~/.openclaw/logs/integration-check.log 2>&1

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

TODAY=$(date '+%Y-%m-%d')
DATE=$(date '+%d/%m/%Y')
YAML="$HOME/.openclaw/workspace/shared/memory/integrations-status.yaml"

wolf_log "integration" "Iniciando validacao de integracoes"

OK=0
FAIL=0
FAILS=""

check() {
    local name="$1"
    local url="$2"
    local headers="$3"
    local expected="${4:-200}"

    local HTTP
    if [ -n "$headers" ]; then
        HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" -H "$headers" 2>/dev/null || echo "000")
    else
        HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    fi

    if [ "$HTTP" = "$expected" ] || ([ "$expected" = "any" ] && [ "$HTTP" != "000" ]); then
        OK=$((OK + 1))
        echo "  OK: $name (HTTP $HTTP)"
    else
        FAIL=$((FAIL + 1))
        FAILS="${FAILS}\n  - $name: HTTP $HTTP"
        echo "  FAIL: $name (HTTP $HTTP)"
    fi
}

echo "=== Integration Check $TODAY ==="

# LLM Providers
check "Anthropic" "https://api.anthropic.com/v1/messages" "x-api-key: ${ANTHROPIC_API_KEY:-}" "any"
check "OpenRouter" "https://openrouter.ai/api/v1/models" "Authorization: Bearer ${OPENROUTER_API_KEY:-}" "200"
check "Groq" "https://api.groq.com/openai/v1/models" "Authorization: Bearer ${GROQ_API_KEY:-}" "200"

# Comunicacao
check "Telegram" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN:-}/getMe" "" "200"
check "WA Bridge" "http://127.0.0.1:3002/health" "" "200"
check "Gateway" "http://127.0.0.1:18789/" "" "200"

# Projeto
check "Supabase" "${SUPABASE_URL:-https://dqhiafxbljujahmpcdhf.supabase.co}/rest/v1/agents?select=id&limit=1" "apikey: ${SUPABASE_ANON_KEY:-}" "200"
check "ClickUp" "https://api.clickup.com/api/v2/team" "Authorization: ${CLICKUP_API_TOKEN:-}" "200"

# Meta Ads
check "Meta Main" "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_ACCESS_TOKEN:-}" "" "200"
check "Meta Forlan" "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_TOKEN_FORLAN:-}" "" "200"
check "Meta Marcos" "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_TOKEN_MARCOS:-}" "" "200"
check "Meta Ticomia" "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_TOKEN_TICOMIA:-}" "" "200"
check "Meta GR" "https://graph.facebook.com/v21.0/me?access_token=${META_ADS_TOKEN_GR:-}" "" "200"
check "Meta GR Veiculos" "https://graph.facebook.com/v21.0/me?access_token=${META_TOKEN_GR_VEICULOS:-}" "" "200"

# Design
check "Figma" "https://api.figma.com/v1/me" "X-Figma-Token: ${FIGMA_TOKEN:-}" "200"

TOTAL=$((OK + FAIL))

# Update YAML timestamp
sed -i '' "s/^# Atualizado:.*/# Atualizado: $TODAY (automatico via integration-check.sh)/" "$YAML" 2>/dev/null || true

echo ""
echo "RESULTADO: $OK/$TOTAL OK | $FAIL falha(s)"

# Notify only if failures
if [ "$FAIL" -gt 0 ]; then
    MSG="*Integration Check — ${DATE}*

$OK/$TOTAL OK | $FAIL com problema$(echo -e "$FAILS")

Verificar tokens expirados no .env"
    wolf_notify_urgent "$MSG"
else
    wolf_notify_silent "integration" "Todas $TOTAL integracoes OK"
fi

wolf_log "integration" "Check concluido — OK=$OK FAIL=$FAIL"
