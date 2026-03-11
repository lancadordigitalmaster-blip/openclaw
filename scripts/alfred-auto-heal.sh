#!/bin/bash
# alfred-auto-heal.sh — Auto-correcao do Alfred/OpenClaw
# Detecta travamentos e aplica fixes automaticamente.
# Registra cada incidente no Mission Control (Supabase).
#
# Roda via LaunchAgent a cada 5 minutos.
# REGRA: maximo 3 restarts por hora para evitar loop destrutivo.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

# --- Config ---
OPENCLAW_HOME="$HOME/.openclaw"
LOG_DIR="/tmp/openclaw"
HEAL_LOG="$LOG_DIR/auto-heal.log"
HEAL_MARKER="$LOG_DIR/auto-heal-last-restart"
SESSIONS_FILE="$OPENCLAW_HOME/agents/main/sessions/sessions.json"
GATEWAY_PORT=18789
MAX_SESSIONS=10
MAX_RESTARTS_PER_HOUR=3

# Carregar .env (tokens, Supabase, etc)
source "$OPENCLAW_HOME/.env" 2>/dev/null
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"

send_telegram() {
  [ -z "$TELEGRAM_TOKEN" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT}" -d "text=$1" --max-time 10 2>/dev/null || true
}
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
ALFRED_AGENT_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
WOLF_CLIENT_ID="a5a2cb8a-7dd8-4455-9145-39be35b1afda"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HEAL_LOG"
}

# --- Anti-loop: contar restarts na ultima hora ---
check_restart_budget() {
  if [ ! -f "$HEAL_MARKER" ]; then
    echo "0"
    return
  fi
  # Contar linhas com timestamp na ultima hora
  local cutoff=$(date -v-1H '+%Y-%m-%d %H:%M' 2>/dev/null || date -d '1 hour ago' '+%Y-%m-%d %H:%M' 2>/dev/null)
  local count=$(awk -v cutoff="$cutoff" '$0 >= cutoff' "$HEAL_MARKER" 2>/dev/null | wc -l | tr -d ' ')
  echo "${count:-0}"
}

record_restart() {
  date '+%Y-%m-%d %H:%M:%S' >> "$HEAL_MARKER"
  # Manter apenas ultimas 24h
  if [ -f "$HEAL_MARKER" ]; then
    local cutoff=$(date -v-24H '+%Y-%m-%d %H:%M' 2>/dev/null || date -d '24 hours ago' '+%Y-%m-%d %H:%M' 2>/dev/null)
    awk -v cutoff="$cutoff" '$0 >= cutoff' "$HEAL_MARKER" > "$HEAL_MARKER.tmp" 2>/dev/null
    mv "$HEAL_MARKER.tmp" "$HEAL_MARKER" 2>/dev/null
  fi
}

safe_restart() {
  local reason="$1"
  local restarts=$(check_restart_budget)
  if [ "$restarts" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
    log "SKIP: $reason — ja fez $restarts restarts na ultima hora (max: $MAX_RESTARTS_PER_HOUR)"
    return 1
  fi
  log "HEAL: $reason"
  bash "$SCRIPT_DIR/save-context.sh" >> "$HEAL_LOG" 2>&1
  echo '{}' > "$SESSIONS_FILE"
  launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null
  record_restart
  HEALED=1
  sleep 5
  return 0
}

# --- Mission Control Integration ---
report_to_mission_control() {
  local title="$1"
  local description="$2"
  local priority="${3:-medium}"

  [ -z "$SUPABASE_URL" ] && return

  curl -s -o /dev/null -w "%{http_code}" \
    "$SUPABASE_URL/rest/v1/missions" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{
      \"title\": \"[Auto-Heal] $title\",
      \"description\": \"$description\",
      \"status\": \"done\",
      \"priority\": \"$priority\",
      \"priority_score\": 0.9,
      \"agent_id\": \"$ALFRED_AGENT_ID\",
      \"client_id\": \"$WOLF_CLIENT_ID\",
      \"tags\": [\"auto-heal\", \"system\"],
      \"created_by\": \"auto-heal\",
      \"completed_at\": \"$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')\"
    }" 2>/dev/null
}

HEALED=0
ACTIONS=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Check 1: Gateway alive? ---
GW_PID=$(pgrep -f "openclaw-gateway" | head -1)
if [ -z "$GW_PID" ]; then
  safe_restart "Gateway morto — reiniciando" && \
    ACTIONS="${ACTIONS}Gateway morto: reiniciado. "
fi

# --- Check 2: HTTP port responding? ---
if [ "$HEALED" -eq 0 ]; then
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:$GATEWAY_PORT/" 2>/dev/null)
  if [ "$HTTP" != "200" ] && [ -n "$GW_PID" ]; then
    safe_restart "Porta $GATEWAY_PORT nao responde ($HTTP)" && \
      ACTIONS="${ACTIONS}Porta sem resposta ($HTTP): restart. "
  fi
fi

# --- Check 3: Stale sessions accumulating? ---
if [ "$HEALED" -eq 0 ] && [ -f "$SESSIONS_FILE" ]; then
  SESSION_COUNT=$(python3 -c "
import json
try:
    d = json.load(open('$SESSIONS_FILE'))
    print(len(d) if isinstance(d, dict) else 0)
except:
    print(0)
" 2>/dev/null)

  if [ "${SESSION_COUNT:-0}" -gt "$MAX_SESSIONS" ]; then
    safe_restart "$SESSION_COUNT sessoes acumuladas (max: $MAX_SESSIONS)" && \
      ACTIONS="${ACTIONS}$SESSION_COUNT sessoes: limpas. "
  fi
fi

# --- Check 4: Telegram BOT_COMMANDS fix (one-time, no restart needed) ---
TODAY_LOG="$LOG_DIR/openclaw-$(date +%Y-%m-%d).log"
if [ -f "$TODAY_LOG" ]; then
  BOT_CMD_ERR=$(grep -c "BOT_COMMANDS_TOO_MUCH" "$TODAY_LOG" 2>/dev/null; true)
  if [ "${BOT_CMD_ERR:-0}" -gt 0 ]; then
    CURRENT=$(python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    d = json.load(f)
print('false' if d.get('channels',{}).get('telegram',{}).get('commands',{}).get('native') is False else 'true')
" 2>/dev/null)
    if [ "$CURRENT" = "true" ]; then
      python3 -c "
import json
with open('$HOME/.openclaw/openclaw.json') as f:
    d = json.load(f)
d.setdefault('channels',{}).setdefault('telegram',{})['commands'] = {'native': False}
with open('$HOME/.openclaw/openclaw.json','w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null
      log "FIX: BOT_COMMANDS — native commands desabilitados (sem restart)"
      ACTIONS="${ACTIONS}Telegram commands: native=false. "
    fi
  fi
fi

# --- Report ---
if [ "$HEALED" -gt 0 ] || [ -n "$ACTIONS" ]; then
  log "REPORT: Acoes tomadas: $ACTIONS"
  report_to_mission_control \
    "Sistema auto-corrigido ($(date '+%d/%m %H:%M'))" \
    "$ACTIONS" \
    "high"
  HEAL_MSG=$(python3 -c "
actions = '''$ACTIONS'''.strip()
lines = []
lines.append('Alfred Auto-Heal')
lines.append('')
lines.append('Problema detectado e corrigido automaticamente:')
lines.append(actions)
lines.append('')
lines.append('Sistema operacional. Nenhuma acao necessaria.')
print('\n'.join(lines))
" 2>/dev/null || echo "[Auto-Heal] $ACTIONS")
  send_telegram "$HEAL_MSG"
  echo "HEALED: $ACTIONS"
else
  echo "HEALTHY"
fi
