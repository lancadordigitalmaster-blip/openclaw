#!/bin/bash
# alfred-health.sh — Diagnóstico rápido do Alfred
# Uso: bash workspace/scripts/alfred-health.sh
#
# Mostra se Alfred está travado, ocupado ou morto.

export PATH="/opt/homebrew/bin:$PATH"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Alfred Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Gateway vivo?
GW_PID=$(pgrep -f "openclaw" | head -1)
if [ -z "$GW_PID" ]; then
  echo "🔴 GATEWAY: MORTO — não tem processo rodando"
  echo "   Fix: launchctl kickstart -k gui/\$(id -u)/ai.openclaw.gateway"
  exit 1
else
  echo "🟢 GATEWAY: PID $GW_PID"
fi

# 2. Porta respondendo?
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/ 2>/dev/null)
if [ "$HTTP" = "200" ]; then
  echo "🟢 HTTP: porta 18789 respondendo ($HTTP)"
else
  echo "🔴 HTTP: porta 18789 não responde ($HTTP)"
  echo "   Fix: launchctl kickstart -k gui/\$(id -u)/ai.openclaw.gateway"
fi

# 3. Browser server?
BROWSER=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18791/ 2>/dev/null)
echo "🟢 BROWSER: porta 18791 ($BROWSER)"

# 4. Telegram conectado?
LAST_MSG=$(grep "sendMessage ok" ~/.openclaw/logs/gateway.log 2>/dev/null | tail -1 | grep -o '2026-[^ ]*')
if [ -n "$LAST_MSG" ]; then
  echo "🟢 TELEGRAM: última msg enviada $LAST_MSG"
else
  echo "🟡 TELEGRAM: sem msgs recentes no log"
fi

# 5. Sessões acumuladas?
SESSIONS=$(python3 -c "
import json
d = json.load(open('$HOME/.openclaw/agents/main/sessions/sessions.json'))
if isinstance(d, dict):
    count = len(d)
    for k,v in d.items():
        msgs = len(v.get('messages',[])) if isinstance(v,dict) else 0
        print(f'   {k}: {msgs} msgs')
    print(f'Total: {count} sessões')
" 2>/dev/null || echo "   Erro lendo sessões")
echo "📦 SESSÕES:"
echo "$SESSIONS"

# 6. Erros recentes?
LOG_FILE="/tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
ERRORS_TODAY=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null; true)
ERRORS_TODAY=${ERRORS_TODAY:-0}
RATE_LIMITS=$(grep -c "rate_limit" "$LOG_FILE" 2>/dev/null; true)
RATE_LIMITS=${RATE_LIMITS:-0}
STALE=$(grep -c "stale-socket" "$LOG_FILE" 2>/dev/null; true)
STALE=${STALE:-0}
echo ""
echo "📊 ERROS HOJE:"
echo "   Erros totais: $ERRORS_TODAY"
echo "   Rate limits: $RATE_LIMITS"
echo "   Stale-socket: $STALE"

# 7. Crons recentes?
echo ""
echo "⏰ CRONS (últimos runs):"
python3 -c "
import json
data = json.load(open('$HOME/.openclaw/cron/jobs.json'))
for j in data.get('jobs', []):
    name = j['name'][:35]
    enabled = '✅' if j.get('enabled') else '⬛'
    state = j.get('state', {})
    status = state.get('lastRunStatus', 'never')
    errs = state.get('consecutiveErrors', 0)
    icon = '🟢' if status == 'ok' else ('🔴' if status == 'error' else '⚪')
    print(f'   {enabled} {icon} {name} ({status}, errs:{errs})')
" 2>/dev/null

# 8. Recomendação
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS_TODAY" -gt 50 ]; then
  echo "⚠️  Muitos erros hoje. Considere reiniciar:"
  echo "   launchctl kickstart -k gui/\$(id -u)/ai.openclaw.gateway"
elif [ "$RATE_LIMITS" -gt 10 ]; then
  echo "⚠️  Rate limits frequentes. Os modelos estão sobrecarregados."
  echo "   Alfred pode parecer travado quando todos os modelos batem rate limit."
else
  echo "✅ Sistema parece saudável."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
