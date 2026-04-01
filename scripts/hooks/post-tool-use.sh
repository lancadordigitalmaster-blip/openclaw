#!/usr/bin/env bash
# =============================================================================
# WOLF AGENCY — PostToolUse Hook
# Loga toda ação executada + detecta padrões + registra erros
# =============================================================================

set -euo pipefail

ACTIVITY_LOG="/Users/thomasgirotto/.openclaw/workspace/memory/activity.log"
LESSONS_LOG="/Users/thomasgirotto/.openclaw/workspace/memory/lessons.md"
HOOK_LOG="/Users/thomasgirotto/.openclaw/workspace/memory/hooks.log"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

# Lê input JSON do Claude Code (stdin)
INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo 'unknown')"
TOOL_INPUT="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo '{}')"
TOOL_RESPONSE="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('tool_response',{}); print(json.dumps(r) if isinstance(r,dict) else str(r))" 2>/dev/null || echo '{}')"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
DATE="$(date '+%Y-%m-%d')"

# -----------------------------------------------------------------------------
# Função: Enviar mensagem Telegram
# -----------------------------------------------------------------------------
send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "parse_mode=Markdown" \
      --data-urlencode "text=${msg}" \
      > /dev/null 2>&1 || true
  fi
}

# -----------------------------------------------------------------------------
# Função: Log de atividade
# -----------------------------------------------------------------------------
log_activity() {
  local action="$1"
  local detail="$2"
  echo "[$TIMESTAMP] $action | $detail" >> "$ACTIVITY_LOG" 2>/dev/null || true
}

log_hook() {
  local level="$1"
  local msg="$2"
  echo "[$TIMESTAMP] [POST] [$level] $TOOL_NAME — $msg" >> "$HOOK_LOG" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Detectar erro na resposta
# -----------------------------------------------------------------------------
HAS_ERROR="$(echo "$TOOL_RESPONSE" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    if isinstance(r, dict):
        err = r.get('error', r.get('stderr', ''))
        print('yes' if err and len(str(err)) > 5 else 'no')
    else:
        print('no')
except:
    print('no')
" 2>/dev/null || echo 'no')"

if [[ "$HAS_ERROR" == "yes" ]]; then
  ERROR_MSG="$(echo "$TOOL_RESPONSE" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    print(r.get('error', r.get('stderr', 'erro desconhecido'))[:300])
except:
    print('erro ao parsear resposta')
" 2>/dev/null || echo 'erro desconhecido')"

  log_activity "ERROR" "tool=$TOOL_NAME | erro=$ERROR_MSG"
  log_hook "ERROR" "$ERROR_MSG"

  # Registra em lessons.md para aprendizado
  cat >> "$LESSONS_LOG" 2>/dev/null << LESSON || true

## [$DATE] Erro em $TOOL_NAME
- **Tool:** $TOOL_NAME
- **Erro:** $ERROR_MSG
- **Input:** $(echo "$TOOL_INPUT" | head -c 200)
- **Status:** pendente análise
LESSON
fi

# -----------------------------------------------------------------------------
# Log de ações relevantes por tool
# -----------------------------------------------------------------------------
case "$TOOL_NAME" in

  "Write"|"Edit"|"MultiEdit")
    FILE_PATH="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path', d.get('path', d.get('file',''))))" 2>/dev/null || echo 'arquivo desconhecido')"
    log_activity "WRITE" "arquivo=$FILE_PATH"
    log_hook "L0-LOGGED" "escreveu $FILE_PATH"
    ;;

  "Bash")
    CMD="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command','')[:200])" 2>/dev/null || echo '')"
    log_activity "BASH" "cmd=$(echo "$CMD" | head -c 100)"
    log_hook "L0-LOGGED" "bash executado"
    ;;

  "WebSearch"|"web_search")
    QUERY="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('query',''))" 2>/dev/null || echo '')"
    log_activity "SEARCH" "query=$QUERY"
    ;;

  "WebFetch"|"web_fetch")
    URL="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))" 2>/dev/null || echo '')"
    log_activity "FETCH" "url=$URL"
    ;;

  "cron")
    log_activity "CRON" "operação em cron jobs"
    log_hook "L1-LOGGED" "cron modificado"
    ;;

esac

# -----------------------------------------------------------------------------
# Detectar padrão repetitivo — mesma tool 5x no mesmo minuto
# -----------------------------------------------------------------------------
RECENT_COUNT="$(grep -c "\[$TIMESTAMP\]" "$HOOK_LOG" 2>/dev/null || echo 0)"
if [[ "${RECENT_COUNT:-0}" -gt 5 ]]; then
  MSG="⚠️ *Padrão repetitivo detectado*

🔁 Tool \`$TOOL_NAME\` executou $RECENT_COUNT vezes recentemente.
Pode ser loop ou automação desnecessária — verificando."
  send_telegram "$MSG"
fi

exit 0
