#!/bin/bash
# heartbeat-template.sh — Template universal para heartbeats Wolf Agency
# Uso: ./heartbeat-template.sh <agent_name> <agent_uuid> <check_functions...>
#
# Exemplo de uso em crontab:
#   0 2 * * * /path/to/heartbeat-shield.sh
#   (que internamente chama este template com os checks específicos)
#
# Ou diretamente:
#   ./heartbeat-template.sh Shield 5fa9ee7e "check_env_perms" "check_api_keys"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT="${1:?Uso: $0 <agent_name> <agent_uuid>}"
AGENT_ID="${2:?Uso: $0 <agent_name> <agent_uuid>}"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
shift 2

ISSUES=()
WARNINGS=()
CHECKS_OK=0
CHECKS_TOTAL=0

# ── Helpers ──
check_pass() { CHECKS_OK=$((CHECKS_OK + 1)); CHECKS_TOTAL=$((CHECKS_TOTAL + 1)); }
check_warn() { WARNINGS+=("$1"); CHECKS_TOTAL=$((CHECKS_TOTAL + 1)); }
check_fail() { ISSUES+=("$1"); CHECKS_TOTAL=$((CHECKS_TOTAL + 1)); }

wolf_log "$AGENT" "Iniciando heartbeat"

# ── Missão no WMC ──
PRIORITY="low"
MID=$(wolf_mission_create "$AGENT — Heartbeat $(date +%Y-%m-%d)" "$AGENT_ID" "$PRIORITY" 2>/dev/null)
[ -n "$MID" ] && wolf_mission_move "$MID" "in_progress" 2>/dev/null

# ── Executar checks passados como argumentos ──
# Cada check é uma função definida no script chamador
for CHECK_FN in "$@"; do
  if type "$CHECK_FN" &>/dev/null; then
    "$CHECK_FN"
  else
    check_warn "Check function '$CHECK_FN' not found"
  fi
done

# ── Resultado ──
if [ ${#ISSUES[@]} -gt 0 ]; then
  STATUS="blocked"
  MSG="⚠️ $AGENT Heartbeat: ${#ISSUES[@]} problemas encontrados\n"
  for issue in "${ISSUES[@]}"; do MSG+="❌ $issue\n"; done
  for warn in "${WARNINGS[@]}"; do MSG+="⚡ $warn\n"; done
  MSG+="\n✅ $CHECKS_OK/$CHECKS_TOTAL checks OK"
  wolf_notify "$MSG"
  wolf_log "$AGENT" "Heartbeat: ${#ISSUES[@]} issues, ${#WARNINGS[@]} warnings, $CHECKS_OK/$CHECKS_TOTAL OK"
else
  STATUS="done"
  MSG="✅ $AGENT: $CHECKS_OK/$CHECKS_TOTAL checks OK"
  [ ${#WARNINGS[@]} -gt 0 ] && MSG+=" (${#WARNINGS[@]} warnings)"
  wolf_log "$AGENT" "$MSG"
fi

# ── Fechar missão ──
[ -n "$MID" ] && wolf_mission_move "$MID" "$STATUS" 2>/dev/null

# ── Log rotation ──
LOG_FILE="$WOLF_WORKSPACE/memory/logs/heartbeat-${AGENT,,}.log"
[ -f "$LOG_FILE" ] && tail -200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
