#!/bin/bash
# ============================================================
# KANBAN GUARDIAN — Gestor de Projeto Automatico (zero-token)
# Verifica missoes stale no Supabase e fecha automaticamente
# Roda a cada 2h via LaunchAgent
# ============================================================

set -euo pipefail

LOG="/tmp/kanban-guardian.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --- Config ---
STALE_HOURS=3          # missoes in_progress sem update por mais de Xh = stale
SUPABASE_URL="https://dqhiafxbljujahmpcdhf.supabase.co"

# Load keys from .env
ENV_FILE="$HOME/.openclaw/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[$TIMESTAMP] ERROR: .env not found" >> "$LOG"
  exit 1
fi

ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
SERVICE_KEY=$(grep '^SUPABASE_SERVICE_ROLE_KEY=' "$ENV_FILE" | cut -d'=' -f2-)

if [[ -z "$ANON_KEY" || -z "$SERVICE_KEY" ]]; then
  echo "[$TIMESTAMP] ERROR: Supabase keys missing in .env" >> "$LOG"
  exit 1
fi

# --- Helpers ---
supabase_get() {
  curl -s "$SUPABASE_URL/rest/v1/$1" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY"
}

supabase_patch() {
  local table="$1" filter="$2" body="$3"
  curl -s -o /dev/null -w "%{http_code}" \
    -X PATCH "$SUPABASE_URL/rest/v1/${table}?${filter}" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "$body"
}

# --- 1. Find stale in_progress missions ---
# Use %2B instead of + for URL-safe timezone encoding
CUTOFF=$(date -u -v-${STALE_HOURS}H '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || \
         date -u -d "${STALE_HOURS} hours ago" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null)
CUTOFF_URL="${CUTOFF}%2B00:00"

MISSIONS_JSON=$(supabase_get "missions?status=eq.in_progress&updated_at=lt.${CUTOFF_URL}&select=id,title,updated_at,agent_id")

STALE_COUNT=$(echo "$MISSIONS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list):
    print(len(data))
else:
    print(0)
" 2>/dev/null || echo "0")

# --- 1b. Session counter (always runs) ---
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [[ -f "$SESSIONS_FILE" ]]; then
  SESSION_COUNT=$(python3 -c "
import json, os
sf = os.path.expanduser('~/.openclaw/agents/main/sessions/sessions.json')
with open(sf) as f:
    data = json.load(f)
print(len(data) if isinstance(data, dict) else 0)
" 2>/dev/null || echo "0")
  MAX_SESSIONS=20
  echo "[$TIMESTAMP] Sessions: $SESSION_COUNT/$MAX_SESSIONS" >> "$LOG"
  if [[ "$SESSION_COUNT" -gt "$MAX_SESSIONS" ]]; then
    echo "[$TIMESTAMP] WARNING: sessions exceed limit" >> "$LOG"
  fi
fi

if [[ "$STALE_COUNT" == "0" || "$STALE_COUNT" == "" ]]; then
  echo "[$TIMESTAMP] OK — Kanban limpo. 0 missoes stale." >> "$LOG"
  exit 0
fi

echo "[$TIMESTAMP] FOUND $STALE_COUNT stale mission(s)" >> "$LOG"

# --- 2. Close stale missions ---
CLOSED=0
STALE_IDS=$(echo "$MISSIONS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    sys.exit(0)
for m in data:
    if isinstance(m, dict):
        print(f\"{m['id']}|{m.get('title','?')}|{m.get('updated_at','?')}\")
" 2>/dev/null)

while IFS='|' read -r MID MTITLE MUPDATED; do
  [[ -z "$MID" ]] && continue

  HTTP=$(supabase_patch "missions" "id=eq.$MID" \
    "{\"status\":\"cancelled\",\"blocked_reason\":\"Kanban Guardian: stale in_progress (>${STALE_HOURS}h sem update)\"}")

  if [[ "$HTTP" == "204" ]]; then
    CLOSED=$((CLOSED + 1))
    echo "  CLOSED: $MTITLE (last update: $MUPDATED)" >> "$LOG"
  else
    echo "  FAIL ($HTTP): $MTITLE" >> "$LOG"
  fi
done <<< "$STALE_IDS"

echo "[$TIMESTAMP] DONE — $CLOSED/$STALE_COUNT stale missions closed." >> "$LOG"

# --- 3. Alert via Telegram if any were closed ---
if [[ "$CLOSED" -gt 0 ]]; then
  TELEGRAM_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$HOME/.openclaw/openclaw.json" 2>/dev/null | cut -d'"' -f4 || true)

  # Try to get bot token from openclaw config
  if [[ -z "$TELEGRAM_TOKEN" ]]; then
    TELEGRAM_TOKEN=$(python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
plugins = cfg.get('plugins', [])
for p in plugins:
    if p.get('name') == 'telegram':
        print(p.get('config', {}).get('botToken', ''))
        break
" 2>/dev/null || true)
  fi

  CHAT_ID="-1003441388244"  # Wolf | Kaizen group

  if [[ -n "$TELEGRAM_TOKEN" ]]; then
    MSG="Kanban Guardian | $TIMESTAMP%0A%0A$CLOSED missao(oes) stale fechada(s) automaticamente (>${STALE_HOURS}h sem update).%0AVerifique no Mission Control se alguma precisava continuar."

    curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=${MSG}" 2>/dev/null || true
  fi
fi

# --- 4. Trim log (keep last 200 lines) ---
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
