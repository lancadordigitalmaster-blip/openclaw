#!/bin/bash
# smoke-test.sh — Teste rápido de saúde de todos os serviços OpenClaw
# Uso: ./smoke-test.sh [--notify] (com --notify envia resultado via WhatsApp)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh" 2>/dev/null

NOTIFY="${1:-}"
PASS=0
FAIL=0
WARN=0
RESULTS=""

check() {
  local name="$1" cmd="$2" expected="$3"
  local result
  result=$(eval "$cmd" 2>/dev/null)
  if echo "$result" | grep -q "$expected"; then
    PASS=$((PASS + 1))
    RESULTS+="✅ $name\n"
  else
    FAIL=$((FAIL + 1))
    RESULTS+="❌ $name (got: $(echo "$result" | head -c 50))\n"
  fi
}

warn_check() {
  local name="$1" cmd="$2" threshold="$3"
  local result
  result=$(eval "$cmd" 2>/dev/null)
  if [ "$result" -lt "$threshold" ] 2>/dev/null; then
    PASS=$((PASS + 1))
    RESULTS+="✅ $name ($result)\n"
  else
    WARN=$((WARN + 1))
    RESULTS+="⚡ $name ($result, threshold: $threshold)\n"
  fi
}

echo "🔍 OpenClaw Smoke Test — $(date '+%Y-%m-%d %H:%M')"
echo ""

# Core Services
check "Gateway (18789)" \
  "curl -s --max-time 5 http://localhost:18789/health" \
  '"ok":true'

check "WhatsApp Bridge (3002)" \
  "curl -s --max-time 5 http://localhost:3002/health" \
  '"status":"ok"'

check "WMC Dashboard (8765)" \
  "curl -s --max-time 5 http://localhost:8765/" \
  "DOCTYPE"

check "Webhook Receiver (18790)" \
  "curl -s --max-time 5 http://localhost:18790/" \
  ""

# External APIs
check "Anthropic API" \
  "curl -s --max-time 10 -H 'x-api-key: $ANTHROPIC_API_KEY' -H 'anthropic-version: 2023-06-01' https://api.anthropic.com/v1/messages -d '{\"model\":\"claude-haiku-4-5-20251001\",\"max_tokens\":5,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}' -H 'Content-Type: application/json'" \
  '"content"'

check "Meta Ads Sync (Vercel)" \
  "curl -s --max-time 15 -X POST https://wolf-traffic-command.vercel.app/api/sync/meta" \
  '"status"'

check "Supabase" \
  "curl -s --max-time 5 '$SUPABASE_URL/rest/v1/' -H 'apikey: $SUPABASE_ANON_KEY'" \
  ""

# Files & Config
check "SOUL.md exists" \
  "[ -f $HOME/.openclaw/workspace/SOUL.md ] && echo ok" \
  "ok"

check "jobs.json valid" \
  "python3 -c 'import json; json.load(open(\"$HOME/.openclaw/cron/jobs.json\")); print(\"ok\")'" \
  "ok"

check "openclaw.json valid" \
  "python3 -c 'import json; json.load(open(\"$HOME/.openclaw/openclaw.json\")); print(\"ok\")'" \
  "ok"

# Resource checks
warn_check "Sessions.json size (KB)" \
  "du -k $HOME/.openclaw/agents/main/sessions/sessions.json 2>/dev/null | cut -f1" \
  5000

warn_check "Disk usage (%)" \
  "df / | tail -1 | awk '{print int(\$5)}'" \
  80

echo ""
echo -e "$RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL + WARN))
echo "Result: $PASS/$TOTAL passed, $FAIL failed, $WARN warnings"

# Notify if requested and there are failures
if [ "$NOTIFY" = "--notify" ] && [ $FAIL -gt 0 ]; then
  MSG="🚨 Smoke Test FAILED ($FAIL/$TOTAL)\n\n$(echo -e "$RESULTS" | grep '❌')"
  wolf_whatsapp "$MSG" 2>/dev/null || wolf_telegram "$MSG" 2>/dev/null
fi

exit $FAIL
