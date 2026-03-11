#!/bin/bash
# wmc-register.sh — Registra missao no Wolf Mission Control (Supabase)
# Uso: bash scripts/wmc-register.sh "titulo" "descricao" [agent] [status] [priority] [client_slug]
#
# Exemplos:
#   bash scripts/wmc-register.sh "Analise CPA campanha" "CPA analisado..." gabi done medium
#   bash scripts/wmc-register.sh "Briefing social media" "Criado briefing..." luna in_progress high giovani-calcados

export PATH="/opt/homebrew/bin:$PATH"
source "$HOME/.openclaw/.env" 2>/dev/null

TITLE="${1:?Uso: wmc-register.sh TITULO DESCRICAO [AGENT] [STATUS] [PRIORITY] [CLIENT_SLUG]}"
DESC="${2:-}"
AGENT="${3:-alfred}"
STATUS="${4:-done}"
PRIORITY="${5:-medium}"
CLIENT_SLUG="${6:-}"

# Agent UUIDs
# Agent UUID lookup (compatible with sh/zsh/bash)
case "$AGENT" in
  alfred|oracle) AGENT_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2" ;;
  rex|gabi-old) AGENT_ID="2917064f-c5e0-488a-85fa-e1ee494dd74e" ;;  # backward compat
  gabi)   AGENT_ID="800e7e7a-5c54-4aad-a8d2-8b4a4b147a51" ;;
  luna)   AGENT_ID="62013484-3fae-4c0f-b767-50862aace334" ;;
  sage)   AGENT_ID="ca48acd3-ad6d-45b6-88aa-5e123dae95ef" ;;
  nova)   AGENT_ID="2990278a-26bb-4f10-a056-03bcbc74d058" ;;
  titan)  AGENT_ID="10c5e66f-d2c2-4bef-a3ff-c604c1070882" ;;
  pixel)  AGENT_ID="a80ea966-4c6d-49a0-863e-7420ca5d82b3" ;;
  forge)  AGENT_ID="c106b8d2-b0a5-47e9-ab06-baf2885ef423" ;;
  shield) AGENT_ID="5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a" ;;
  *)      AGENT_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2" ;;
esac

# Priority score
case "$PRIORITY" in
  critical) PSCORE=1.0 ;;
  high) PSCORE=0.8 ;;
  medium) PSCORE=0.5 ;;
  low) PSCORE=0.3 ;;
  *) PSCORE=0.5 ;;
esac

# Client ID (lookup if slug provided)
CLIENT_ID="null"
if [ -n "$CLIENT_SLUG" ]; then
  CLIENT_ID=$(curl -s "$SUPABASE_URL/rest/v1/clients?select=id&slug=eq.$CLIENT_SLUG" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'\"{d[0][\"id\"]}\"' if d else 'null')" 2>/dev/null)
fi

# Completed timestamp if done
COMPLETED="null"
if [ "$STATUS" = "done" ]; then
  COMPLETED="\"$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')\""
fi

# Escape JSON strings
TITLE_ESC=$(echo "$TITLE" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null)
DESC_ESC=$(echo "$DESC" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null)

HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  "$SUPABASE_URL/rest/v1/missions" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d "{
    \"title\": $TITLE_ESC,
    \"description\": $DESC_ESC,
    \"status\": \"$STATUS\",
    \"priority\": \"$PRIORITY\",
    \"priority_score\": $PSCORE,
    \"agent_id\": \"$AGENT_ID\",
    \"client_id\": $CLIENT_ID,
    \"created_by\": \"telegram\",
    \"completed_at\": $COMPLETED
  }" 2>/dev/null)

if [ "$HTTP" = "201" ]; then
  echo "OK — Missao registrada: $TITLE ($STATUS)"
else
  echo "ERRO $HTTP — Falha ao registrar missao"
fi
