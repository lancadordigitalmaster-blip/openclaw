#!/bin/bash
# lib-wolf.sh — Funcoes comuns para scripts Wolf Agency
# Uso: source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

# Carregar .env
_WOLF_ENV="$HOME/.openclaw/.env"
[ -f "$_WOLF_ENV" ] && { set -a; source "$_WOLF_ENV"; set +a; }

WOLF_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
WOLF_CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"
WOLF_SUPABASE_URL="${SUPABASE_URL:-https://dqhiafxbljujahmpcdhf.supabase.co}"
WOLF_ANON_KEY="${SUPABASE_ANON_KEY:-}"
WOLF_SVC_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
WOLF_WORKSPACE="$HOME/.openclaw/workspace"

# Enviar mensagem Telegram (legado — usar wolf_notify para novo código)
wolf_telegram() {
    local msg="$1"
    local chat_id="${2:-$WOLF_CHAT_ID}"
    [ -z "$WOLF_BOT_TOKEN" ] && return 1
    curl -s -X POST "https://api.telegram.org/bot${WOLF_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$chat_id\", \"text\": $(echo "$msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
}

# Enviar mensagem WhatsApp via Bridge API (porta 3002)
# Uso: wolf_whatsapp "mensagem" ["557391484716"]
WOLF_WHATSAPP_BRIDGE="http://127.0.0.1:3002/send"
WOLF_NETTO_WHATSAPP="${NETTO_WHATSAPP:-557391484716}"

wolf_whatsapp() {
    local msg="$1"
    local to="${2:-$WOLF_NETTO_WHATSAPP}"
    local payload=$(python3 -c "import json; print(json.dumps({'to': '$to', 'text': '''$msg'''}))" 2>/dev/null)
    curl -s -X POST "$WOLF_WHATSAPP_BRIDGE" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 > /dev/null 2>&1
}

# Notificacao unificada: WhatsApp only (Telegram apenas para programar)
# Uso: wolf_notify "mensagem"
wolf_notify() {
    local msg="$1"
    local to="${2:-$WOLF_NETTO_WHATSAPP}"
    wolf_whatsapp "$msg" "$to"
}

# ================================================================
# NIVEIS DE PRIORIDADE — controla quando/como notificar
# ================================================================

# URGENTE — envia imediatamente por WhatsApp + Telegram (redundancia)
# Uso: wolf_notify_urgent "Sistema caiu!" ["numero"]
wolf_notify_urgent() {
    local msg="$1"
    local to="${2:-$WOLF_NETTO_WHATSAPP}"
    wolf_whatsapp "$msg" "$to"
    wolf_telegram "$msg"
}

# INFO — envia por WhatsApp apenas (reports, status)
# Uso: wolf_notify_info "Relatorio pronto"
wolf_notify_info() {
    local msg="$1"
    local to="${2:-$WOLF_NETTO_WHATSAPP}"
    wolf_whatsapp "$msg" "$to"
}

# SILENT — apenas registra no log, sem notificacao
# Uso: wolf_notify_silent "agent" "Heartbeat OK"
wolf_notify_silent() {
    local agent="${1:-system}"
    local msg="$2"
    wolf_log "$agent" "$msg"
}

# ================================================================
# NOTIFICACAO POR ROLE — envia para a pessoa certa + copia Netto
# ================================================================
WOLF_NATIELY_WHATSAPP="${NATIELY_WHATSAPP:-5573999840448}"
WOLF_MIRELLI_WHATSAPP="${MIRELLI_WHATSAPP:-}"  # Configurar no .env quando disponivel

# Envia para role especifica + copia Netto
# Uso: wolf_notify_role "natiely" "SLA alert: 3 tarefas vencidas"
# Roles: natiely (pendencias/SLA), mirelli (social media), netto (tudo)
wolf_notify_role() {
    local role="$1"
    local msg="$2"
    local skip_netto="${3:-}"  # "skip" para nao copiar Netto

    case "$role" in
        natiely)
            wolf_whatsapp "$msg" "$WOLF_NATIELY_WHATSAPP"
            ;;
        mirelli)
            if [ -n "$WOLF_MIRELLI_WHATSAPP" ]; then
                wolf_whatsapp "$msg" "$WOLF_MIRELLI_WHATSAPP"
            fi
            ;;
        netto)
            # Direto pro Netto, sem duplicar
            skip_netto="skip"
            wolf_whatsapp "$msg" "$WOLF_NETTO_WHATSAPP"
            ;;
        *)
            wolf_log "notify" "Role desconhecida: $role"
            ;;
    esac

    # Netto sempre recebe copia (exceto se for role=netto ou skip)
    [ "$skip_netto" != "skip" ] && wolf_whatsapp "$msg" "$WOLF_NETTO_WHATSAPP"
}

# ================================================================
# MISSION LIFECYCLE — cada funcao move o card 1 etapa no kanban
# Fluxo real: inbox → assigned → in_progress → done/blocked
# Cada chamada = 1 movimento visivel no dashboard
# ================================================================

# Criar missao (nasce como inbox no kanban)
# Uso: MISSION_ID=$(wolf_mission_create "titulo" "agent_uuid" "priority")
wolf_mission_create() {
    local title="$1"
    local agent_id="${2:-}"
    local priority="${3:-low}"

    [ -z "$WOLF_ANON_KEY" ] && return 1

    local payload=$(python3 -c "
import json
d = {'title': '''$title''', 'priority': '$priority', 'status': 'inbox'}
if '''$agent_id''': d['agent_id'] = '$agent_id'
print(json.dumps(d))
")

    local resp=$(curl -s -X POST "${WOLF_SUPABASE_URL}/rest/v1/missions" \
        -H "apikey: ${WOLF_ANON_KEY}" \
        -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=representation" \
        -d "$payload" 2>/dev/null)

    echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if isinstance(d,list) and d else d.get('id',''))" 2>/dev/null
}

# Mover missao para proximo status (1 etapa por chamada)
# Uso: wolf_mission_move "$MISSION_ID" "assigned"
wolf_mission_move() {
    local mission_id="$1"
    local new_status="$2"
    local description="${3:-}"

    [ -z "$mission_id" ] && return 1
    [ -z "$WOLF_ANON_KEY" ] && return 1

    local payload="{\"status\": \"$new_status\""
    if [ -n "$description" ]; then
        local desc_json=$(echo "$description" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null)
        payload="$payload, \"description\": $desc_json"
    fi
    if [ "$new_status" = "done" ]; then
        payload="$payload, \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    fi
    payload="$payload}"

    curl -s -X PATCH "${WOLF_SUPABASE_URL}/rest/v1/missions?id=eq.${mission_id}" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null 2>&1
}

# Wrapper legado — mantido para compatibilidade mas usa lifecycle real
# Uso: wolf_mission "titulo" "descricao" "agent_uuid" "priority" "status"
wolf_mission() {
    local title="$1"
    local description="${2:-}"
    local agent_id="${3:-}"
    local priority="${4:-low}"
    local final_status="${5:-done}"

    local mid=$(wolf_mission_create "$title" "$agent_id" "$priority")
    [ -z "$mid" ] && return 1

    sleep 1
    wolf_mission_move "$mid" "assigned"

    if [ "$final_status" != "assigned" ]; then
        sleep 1
        wolf_mission_move "$mid" "in_progress"
    fi

    if [ "$final_status" != "assigned" ] && [ "$final_status" != "in_progress" ]; then
        sleep 1
        wolf_mission_move "$mid" "$final_status" "$description"
    fi

    echo "$mid"
}

# Fechar missao existente por titulo (mais recente)
wolf_mission_close() {
    local title_pattern="$1"
    local resolution="${2:-Resolvido automaticamente}"

    [ -z "$WOLF_ANON_KEY" ] && return 1

    # Buscar ID da missao mais recente com esse titulo
    local id=$(curl -s "${WOLF_SUPABASE_URL}/rest/v1/missions?title=like.%25${title_pattern}%25&status=neq.done&select=id&order=created_at.desc&limit=1" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null)

    [ -z "$id" ] && return 0

    curl -s -X PATCH "${WOLF_SUPABASE_URL}/rest/v1/missions?id=eq.${id}" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"status\": \"done\", \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /dev/null 2>&1
}

# Comunicacao entre agentes (aparece no chat do Mission Control)
# Uso: wolf_handoff "agent_from_uuid" "agent_to_uuid" "mensagem" "tipo"
wolf_handoff() {
    local from_id="$1"
    local to_id="${2:-a1abe880-f1e3-40aa-bb62-0f748f5ac2c2}"  # default: Alfred
    local message="$3"
    local signal_type="${4:-signal}"

    [ -z "$WOLF_ANON_KEY" ] && return 1

    local payload=$(python3 -c "
import json
d = {
    'from_agent_id': '$from_id',
    'to_agent_id': '$to_id',
    'signal_type': '$signal_type',
    'payload': {'message': '''$message'''},
    'status': 'delivered'
}
print(json.dumps(d))
" 2>/dev/null)

    curl -s -X POST "${WOLF_SUPABASE_URL}/rest/v1/handoffs" \
        -H "apikey: ${WOLF_ANON_KEY}" -H "Authorization: Bearer ${WOLF_SVC_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=minimal" \
        -d "$payload" > /dev/null 2>&1
}

# Log padrao
wolf_log() {
    local agent="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$agent] $msg"
}

# Input sanitization — strip shell metacaracteres perigosos
# Uso: SAFE=$(wolf_sanitize "$INPUT")
# Remove: ` $ ( ) { } | ; & < > ! \ e limita a 200 chars
wolf_sanitize() {
    local input="$1"
    local max_len="${2:-200}"
    # Remove metacaracteres shell
    local clean=$(echo "$input" | tr -d '`$(){}|;&<>!\\' | tr -d "'" | tr '"' ' ')
    # Truncar ao limite
    echo "${clean:0:$max_len}"
}

# Validar tipo de input
# Uso: wolf_validate "slug" "$valor" || echo "invalido"
wolf_validate() {
    local type="$1"
    local value="$2"
    case "$type" in
        slug)   echo "$value" | grep -qE '^[a-z0-9][a-z0-9-]*$' ;;
        id)     echo "$value" | grep -qE '^[0-9]+$' ;;
        url)    echo "$value" | grep -qE '^https?://' ;;
        name)   echo "$value" | grep -qE '^[a-zA-ZÀ-ú .-]+$' ;;
        date)   echo "$value" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ;;
        *)      return 1 ;;
    esac
}
