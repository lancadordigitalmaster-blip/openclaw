#!/bin/bash
# watchdog_system.sh — Wolf Agency
# Cron: 07:00 diario | Verifica saude do sistema (arquivos, disco, fila)

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
LOG_FILE="$WORKSPACE/memory/logs/watchdog_system.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
ISSUES=()
WARNINGS=()

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/.env" 2>/dev/null
send_telegram() {
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "parse_mode=Markdown" -d "text=$1" --max-time 10 2>/dev/null || true
}

# 1. Arquivos criticos
for f in "$WORKSPACE/SOUL.md" "$WORKSPACE/tasks/QUEUE.md" "$WORKSPACE/orchestrator/ORCHESTRATOR.md" "$WORKSPACE/CLAUDE.md"; do
  [ ! -f "$f" ] && ISSUES+=("Arquivo critico ausente: $(basename "$f")")
done

# 2. Disco
DISK=$(df "$WORKSPACE" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
[ "$DISK" -gt 85 ] && ISSUES+=("Disco em ${DISK}% — critico")
[ "$DISK" -gt 70 ] && [ "$DISK" -le 85 ] && WARNINGS+=("Disco em ${DISK}% — atencao")

# 3. Gateway ativo (via HTTP check — mais confiavel que pgrep em sessao isolada)
GW_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
[ "$GW_HTTP" != "200" ] && ISSUES+=("Gateway nao responde (HTTP $GW_HTTP) — pode estar parado")

# 4. Sessions acumuladas
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [ -f "$SESSIONS_FILE" ]; then
  SESSION_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS_FILE')); print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo "0")
  [ "$SESSION_COUNT" -gt 10 ] && WARNINGS+=("$SESSION_COUNT sessoes acumuladas (max recomendado: 10)")
fi

# 5. QUEUE status
OPEN=$(grep -c "^- \[ \]" "$WORKSPACE/tasks/QUEUE.md" 2>/dev/null || echo "0")
[ "$OPEN" -eq 0 ] && WARNINGS+=("QUEUE.md vazio — sem tasks na fila")

# 6. morning_context.md atualizado
if [ -f "$WORKSPACE/memory/morning_context.md" ]; then
  MC_AGE=$(( $(date +%s) - $(stat -f%m "$WORKSPACE/memory/morning_context.md" 2>/dev/null || echo "0") ))
  [ "$MC_AGE" -gt 86400 ] && WARNINGS+=("morning_context.md desatualizado (>24h)")
fi

# 7. Montar relatorio
if [ ${#ISSUES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
  log "OK: Sistema saudavel — Disco ${DISK}% | Queue $OPEN tasks | Gateway PID $GW_PID"
  # Silencio quando tudo OK (regra do SOUL.md)
else
  MSG="Netto, detectei alguns problemas no sistema."
  for i in "${ISSUES[@]}"; do MSG="$MSG
Critico: $i"; done
  for w in "${WARNINGS[@]}"; do MSG="$MSG
Atencao: $w"; done
  MSG="$MSG

Disco esta em ${DISK}% e temos $OPEN tasks na fila."
  send_telegram "$MSG"
  for i in "${ISSUES[@]}"; do log "ISSUE: $i"; done
  for w in "${WARNINGS[@]}"; do log "WARNING: $w"; done
fi

echo "OK: watchdog completed — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
