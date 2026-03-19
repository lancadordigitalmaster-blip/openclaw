#!/bin/bash
# wmc-monitor.sh — Monitor inteligente do Mission Control
# Analisa logs e crons, registra eventos importantes no kanban Supabase
# Atualiza status dos agentes automaticamente
# Roda via LaunchAgent a cada 10 minutos

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

OPENCLAW_HOME="$HOME/.openclaw"
LOG_DIR="/tmp/openclaw"
TODAY_LOG="$LOG_DIR/openclaw-$(date +%Y-%m-%d).log"
MARKER_FILE="$LOG_DIR/wmc-monitor-offset"
CRON_FILE="$OPENCLAW_HOME/cron/jobs.json"

source "$OPENCLAW_HOME/.env" 2>/dev/null

# Funcao: registrar missao no Supabase
register_mission() {
  local title="$1"
  local description="$2"
  local agent="${3:-alfred}"
  local status="${4:-done}"
  local priority="${5:-medium}"

  bash "$OPENCLAW_HOME/workspace/scripts/wmc-register.sh" \
    "$title" "$description" "$agent" "$status" "$priority" 2>/dev/null
}

# Funcao: registrar handoff (chat entre agentes)
register_handoff() {
  local from_id="$1"
  local to_id="$2"
  local signal_type="$3"
  local message="$4"

  [ -z "$SUPABASE_URL" ] && return

  # Escapar aspas na mensagem
  local safe_msg=$(echo "$message" | sed 's/"/\\"/g' | head -c 300)

  curl -s -o /dev/null \
    "$SUPABASE_URL/rest/v1/handoffs" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{
      \"from_agent_id\": \"$from_id\",
      \"to_agent_id\": \"$to_id\",
      \"signal_type\": \"$signal_type\",
      \"payload\": {\"message\": \"$safe_msg\"},
      \"status\": \"delivered\"
    }" 2>/dev/null
}

# Funcao: atualizar status de um agente no Supabase
update_agent_status() {
  local agent_id="$1"
  local status="$2"

  [ -z "$SUPABASE_URL" ] && return

  curl -s -o /dev/null \
    "$SUPABASE_URL/rest/v1/agents?id=eq.$agent_id" \
    -X PATCH \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{\"status\": \"$status\", \"last_active\": \"$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')\"}" 2>/dev/null
}

# UUIDs dos agentes
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
GABI_ID="800e7e7a-5c54-4aad-a8d2-8b4a4b147a51"
TITAN_ID="10c5e66f-d2c2-4bef-a3ff-c604c1070882"
SHIELD_ID="5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a"
ATLAS_ID="2ccfa51e-eda1-49b1-967d-6fb423cb4448"
ECHO_ID="2c01996c-ff7f-46d4-99d6-310ecd5391a0"

# --- Offset: processar apenas linhas novas do log ---
OFFSET=0
if [ -f "$MARKER_FILE" ]; then
  OFFSET=$(cat "$MARKER_FILE" 2>/dev/null)
fi

if [ ! -f "$TODAY_LOG" ]; then
  echo "0" > "$MARKER_FILE"
  # Atualizar Alfred como ativo (gateway esta rodando)
  GW_PID=$(pgrep -f "openclaw-gateway" | head -1)
  if [ -n "$GW_PID" ]; then
    update_agent_status "$ALFRED_ID" "active"
  fi
  exit 0
fi

TOTAL_LINES=$(wc -l < "$TODAY_LOG" | tr -d ' ')
NEW_LINES=$((TOTAL_LINES - OFFSET))

# Atualizar offset
echo "$TOTAL_LINES" > "$MARKER_FILE"

# --- 0. ATUALIZAR STATUS DOS AGENTES ---
# Alfred sempre ativo se gateway esta rodando
GW_PID=$(pgrep -f "openclaw-gateway" | head -1)
if [ -n "$GW_PID" ]; then
  update_agent_status "$ALFRED_ID" "active"
fi

# --- 1. CRONS EXECUTADOS ---
if [ -f "$CRON_FILE" ]; then
  python3 << 'PYEOF'
import json, subprocess, os
from datetime import datetime

marker_dir = os.environ.get('LOG_DIR', '/tmp/openclaw')
openclaw_home = os.environ.get('HOME', '') + '/.openclaw'
now = datetime.now()

# Agent name -> UUID mapping for cron attribution
agent_map = {
    'design': '2ccfa51e-eda1-49b1-967d-6fb423cb4448',  # Atlas
    'report': '2c01996c-ff7f-46d4-99d6-310ecd5391a0',  # Echo
    'youtube': 'ca48acd3-ad6d-45b6-88aa-5e123dae95ef',  # Sage
    'weather': 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2',  # Alfred
    'kickoff': 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2',  # Alfred
    'watchdog': '5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a', # Shield
    'audit': '5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a',    # Shield
    'overnight': 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2', # Alfred
    'progress': '2ccfa51e-eda1-49b1-967d-6fb423cb4448',  # Atlas
    'nota': 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2',     # Alfred
    'consolida': 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2', # Alfred
    'update': '10c5e66f-d2c2-4bef-a3ff-c604c1070882',   # Titan
}

def get_agent_for_cron(name):
    nl = name.lower()
    for key, uuid in agent_map.items():
        if key in nl:
            return uuid
    return 'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2'  # Alfred default

cron_file = openclaw_home + '/cron/jobs.json'
try:
    with open(cron_file) as f:
        data = json.load(f)
except:
    exit(0)

jobs = data.get('jobs', [])

for job in jobs:
    if not job.get('enabled', True):
        continue
    name = job.get('name', '?')
    state = job.get('state', {})
    last_status = state.get('lastRunStatus', '')
    last_ms = state.get('lastRunAtMs', 0)
    last_error = state.get('lastError', '')
    duration_ms = state.get('lastDurationMs', 0)

    if last_ms == 0:
        continue

    last_dt = datetime.fromtimestamp(last_ms / 1000)

    # So registrar se executou nos ultimos 15 minutos
    if (now - last_dt).total_seconds() > 900:
        continue

    # Marker para nao duplicar
    marker = os.path.join(marker_dir, f'wmc-cron-{last_ms}')
    if os.path.exists(marker):
        continue
    open(marker, 'w').close()

    duration_s = duration_ms / 1000
    agent_uuid = get_agent_for_cron(name)

    # Mapear agent UUID para nome
    agent_names = {
        'a1abe880-f1e3-40aa-bb62-0f748f5ac2c2': 'alfred',
        '2ccfa51e-eda1-49b1-967d-6fb423cb4448': 'atlas',
        '2c01996c-ff7f-46d4-99d6-310ecd5391a0': 'echo',
        'ca48acd3-ad6d-45b6-88aa-5e123dae95ef': 'sage',
        '5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a': 'shield',
        '10c5e66f-d2c2-4bef-a3ff-c604c1070882': 'titan',
    }
    agent_name = agent_names.get(agent_uuid, 'alfred')

    if last_status == 'ok':
        title = f'Cron: {name}'
        desc = f'Executado com sucesso em {duration_s:.1f}s.'
        status = 'done'
        priority = 'low'
    elif last_status == 'error':
        title = f'ERRO cron: {name}'
        desc = f'Erro: {last_error[:200]}. Duracao: {duration_s:.1f}s.'
        status = 'blocked'
        priority = 'high'
    else:
        continue

    subprocess.run([
        'bash', openclaw_home + '/workspace/scripts/wmc-register.sh',
        title, desc, agent_name, status, priority
    ], capture_output=True, timeout=10)

    # Atualizar status do agente que executou
    import urllib.request
    supabase_url = os.environ.get('SUPABASE_URL', '')
    anon_key = os.environ.get('SUPABASE_ANON_KEY', '')
    service_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
    if supabase_url and agent_uuid:
        try:
            req = urllib.request.Request(
                f'{supabase_url}/rest/v1/agents?id=eq.{agent_uuid}',
                data=json.dumps({"status": "active", "last_active": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+00:00")}).encode(),
                method='PATCH',
                headers={
                    'apikey': anon_key,
                    'Authorization': f'Bearer {service_key}',
                    'Content-Type': 'application/json',
                    'Prefer': 'return=minimal'
                }
            )
            urllib.request.urlopen(req, timeout=5)
        except:
            pass

    print(f'  Registrado: {title} [{status}] (agente: {agent_name})')
PYEOF
fi

# So processar checks de log se houver linhas novas
if [ "${NEW_LINES:-0}" -le 0 ]; then
  exit 0
fi

# Extrair apenas linhas novas
CHUNK=$(tail -n "$NEW_LINES" "$TODAY_LOG")

# --- 2. ERROS CRITICOS ---
CRITICAL_ERRORS=$(echo "$CHUNK" | grep -c "FailoverError\|Context overflow\|FATAL\|ECONNREFUSED" 2>/dev/null)
if [ "${CRITICAL_ERRORS:-0}" -gt 0 ]; then
  MARKER="$LOG_DIR/wmc-critical-$(date +%Y%m%d%H)"
  if [ ! -f "$MARKER" ]; then
    touch "$MARKER"
    register_mission \
      "Alerta: $CRITICAL_ERRORS erros criticos" \
      "FailoverError, Context overflow ou conexao recusada detectados." \
      "alfred" "blocked" "high"

    register_handoff "$ALFRED_ID" "$SHIELD_ID" "alert" \
      "$CRITICAL_ERRORS erros criticos detectados. Verificar logs."
  fi
fi

# --- 3. LLM TIMEOUTS ---
TIMEOUTS=$(echo "$CHUNK" | grep -c "timed out" 2>/dev/null)
if [ "${TIMEOUTS:-0}" -gt 2 ]; then
  MARKER="$LOG_DIR/wmc-timeout-$(date +%Y%m%d%H)"
  if [ ! -f "$MARKER" ]; then
    touch "$MARKER"
    register_mission \
      "Alerta: $TIMEOUTS LLM timeouts" \
      "Provider primario com timeouts. Verificar saude." \
      "alfred" "in_progress" "high"

    register_handoff "$ALFRED_ID" "$TITAN_ID" "alert" \
      "LLM timeout ($TIMEOUTS vezes). Provider instavel."
  fi
fi

# --- 4. RESET AGENTES INATIVOS (1x por hora) ---
HOUR_MARKER="$LOG_DIR/wmc-agent-reset-$(date +%Y%m%d%H)"
if [ ! -f "$HOUR_MARKER" ] && [ -n "$SUPABASE_URL" ]; then
  touch "$HOUR_MARKER"
  # Agentes sem atividade recente voltam para idle
  curl -s -o /dev/null \
    "$SUPABASE_URL/rest/v1/agents?status=eq.active&last_active=lt.$(date -u -v-30M '+%Y-%m-%dT%H:%M:%S+00:00' 2>/dev/null || date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%S+00:00' 2>/dev/null)" \
    -X PATCH \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d '{"status": "idle"}' 2>/dev/null
fi

# --- 5. LIMPAR MARKERS ANTIGOS (>24h) ---
find "$LOG_DIR" -name "wmc-*" -mtime +1 -delete 2>/dev/null

echo "OK"
