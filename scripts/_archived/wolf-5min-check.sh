#!/bin/bash
# wolf-5min-check.sh — Health check rapido do sistema Wolf
# Uso manual: wolfcheck (alias) ou bash scripts/wolf-5min-check.sh
# Sem cron — roda sob demanda

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.openclaw/.env" 2>/dev/null

echo "=== Wolf Quick Check ==="

# 1. Gateway
GW=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
[ "$GW" = "200" ] && echo "  Gateway:  OK" || echo "  Gateway:  DOWN (HTTP $GW)"

# 2. WhatsApp Bridge
BR=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://127.0.0.1:3002/health" 2>/dev/null || echo "000")
[ "$BR" = "200" ] && echo "  WA Bridge: OK" || echo "  WA Bridge: DOWN (HTTP $BR)"

# 3. Disco
DISCO=$(df -h / | awk 'NR==2{print $5}')
echo "  Disco:     $DISCO"

# 4. Sessoes
SESS=0
SESS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
[ -f "$SESS_FILE" ] && SESS=$(python3 -c "import json; print(len(json.load(open('$SESS_FILE'))))" 2>/dev/null || echo "?")
echo "  Sessoes:   $SESS"

# 5. Erros recentes (ultima hora)
HOUR_AGO=$(date -v-1H '+%Y-%m-%d %H' 2>/dev/null || date -d '1 hour ago' '+%Y-%m-%d %H')
GW_ERRS=0
[ -f "$HOME/.openclaw/logs/gateway.log" ] && GW_ERRS=$(grep -c "$HOUR_AGO.*\(error\|ERROR\)" "$HOME/.openclaw/logs/gateway.log" 2>/dev/null || echo 0)
echo "  Erros GW (1h): $GW_ERRS"

# 6. Crons
CRON_TOTAL=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l | tr -d ' ')
echo "  Crons:     $CRON_TOTAL entries"

# 7. Anthropic API
ANTH=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://api.anthropic.com/v1/messages" -H "x-api-key: ${ANTHROPIC_API_KEY:-}" -H "anthropic-version: 2023-06-01" 2>/dev/null || echo "000")
[ "$ANTH" != "000" ] && echo "  Anthropic: OK" || echo "  Anthropic: FAIL"

echo "=== Done ==="
