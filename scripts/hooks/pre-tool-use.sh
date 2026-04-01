#!/usr/bin/env bash
# =============================================================================
# WOLF AGENCY — PreToolUse Hook
# Classifica risco de cada ação antes de executar.
# L0 → executa | L1 → notifica Telegram | L2 → bloqueia + alerta
# =============================================================================

set -euo pipefail

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"
ACTIVITY_LOG="/Users/thomasgirotto/.openclaw/workspace/memory/activity.log"
HOOK_LOG="/Users/thomasgirotto/.openclaw/workspace/memory/hooks.log"

# Lê input JSON do Claude Code (stdin)
INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo 'unknown')"
TOOL_INPUT="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo '{}')"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

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
# Função: Log
# -----------------------------------------------------------------------------
log_hook() {
  local level="$1"
  local msg="$2"
  echo "[$TIMESTAMP] [PRE] [$level] $TOOL_NAME — $msg" >> "$HOOK_LOG" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Função: Bloquear ação
# -----------------------------------------------------------------------------
block_action() {
  local reason="$1"
  log_hook "L2-BLOCKED" "$reason"
  echo '{"action": "block", "message": "'"$reason"'"}'
  exit 0
}

# =============================================================================
# CLASSIFICAÇÃO DE RISCO POR TOOL
# =============================================================================

case "$TOOL_NAME" in

  # --------------------------------------------------------------------------
  # L2 — ALTO RISCO: Bloqueia + Alerta imediato
  # --------------------------------------------------------------------------

  "Bash")
    CMD="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || echo '')"

    # Padrões perigosos
    DANGER_PATTERNS=(
      "rm -rf"
      "rm -r"
      "DROP TABLE"
      "DELETE FROM"
      "truncate"
      "mkfs"
      "dd if="
      "chmod 777"
      "> /dev/sda"
      "curl.*|.*bash"
      "wget.*|.*bash"
    )

    for pattern in "${DANGER_PATTERNS[@]}"; do
      if echo "$CMD" | grep -qi "$pattern" 2>/dev/null; then
        MSG="🚨 *AÇÃO BLOQUEADA — L2*

🔧 Tool: \`$TOOL_NAME\`
⚠️ Padrão perigoso detectado: \`$pattern\`
📋 Comando: \`$(echo "$CMD" | head -c 200)\`

❌ Execução cancelada automaticamente.
Se necessário, autorize manualmente."
        send_telegram "$MSG"
        block_action "Padrão perigoso detectado: $pattern"
      fi
    done

    # Operações em arquivos de cliente
    CLIENT_PATHS=("clients/" "shared/memory/clients" "assets/clients")
    for cpath in "${CLIENT_PATHS[@]}"; do
      if echo "$CMD" | grep -q "$cpath" && echo "$CMD" | grep -qE "rm |mv |delete|overwrite"; then
        MSG="🚨 *AÇÃO BLOQUEADA — L2*

⚠️ Tentativa de modificar arquivos de cliente
📋 Comando: \`$(echo "$CMD" | head -c 200)\`

Requer aprovação do Netto."
        send_telegram "$MSG"
        block_action "Operação em arquivos de cliente requer aprovação"
      fi
    done
    ;;

  "computer_20241022"|"computer")
    # Qualquer automação de computador é L1 — notifica
    MSG="⚠️ *Notificação — L1*

🖥️ Alfred está usando automação de computador
📋 Input: \`$(echo "$TOOL_INPUT" | head -c 150)\`"
    send_telegram "$MSG"
    log_hook "L1-NOTIFY" "computer use"
    ;;

esac

# --------------------------------------------------------------------------
# Arquivos críticos — edição requer notificação L1
# --------------------------------------------------------------------------
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "MultiEdit" ]]; then
  FILE_PATH="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path', d.get('path', d.get('file',''))))" 2>/dev/null || echo '')"

  CRITICAL_FILES=("SOUL.md" "CLAUDE.md" "AGENTS.md" "ORCHESTRATOR.md" "openclaw.json" "settings.json")
  for cf in "${CRITICAL_FILES[@]}"; do
    if echo "$FILE_PATH" | grep -q "$cf"; then
      MSG="ℹ️ *Edição de arquivo crítico — L1*

📄 Arquivo: \`$FILE_PATH\`
🔧 Tool: $TOOL_NAME

Alfred está editando um arquivo crítico do sistema."
      send_telegram "$MSG"
      log_hook "L1-NOTIFY" "edição de $FILE_PATH"
      break
    fi
  done
fi

# --------------------------------------------------------------------------
# L0 — Tudo o mais: passa direto, só loga
# --------------------------------------------------------------------------
log_hook "L0-PASS" "tool=$TOOL_NAME"

# Retorna sem bloquear
exit 0
