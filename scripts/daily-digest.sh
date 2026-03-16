#!/bin/bash
# Wolf Daily Digest — 23h50 BRT
# Consolida TUDO do dia em UMA unica mensagem WhatsApp
# Absorve: daily_progress_report + nota_diaria + alfred-quality + trend-analysis
# Crontab: 50 23 * * * bash /path/to/daily-digest.sh >> ~/.openclaw/logs/daily-digest.log 2>&1

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

DATE=$(date '+%d/%m/%Y')
TODAY=$(date '+%Y-%m-%d')
LOGS="$HOME/.openclaw/logs"
WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
SESSIONS="$HOME/.openclaw/agents/main/sessions/sessions.json"

wolf_log "digest" "Iniciando Daily Digest consolidado"

# --- Tasks (absorvido de daily_progress_report + nota_diaria) ---
DONE="$(grep -icE '^\- \[x\]' "$QUEUE" 2>/dev/null || true)"
DONE="${DONE%%$'\n'*}"; DONE="${DONE:-0}"
OPEN="$(grep -c '^\- \[ \]' "$QUEUE" 2>/dev/null || true)"
OPEN="${OPEN%%$'\n'*}"; OPEN="${OPEN:-0}"
URGENT="$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c '^\- \[ \]' 2>/dev/null || true)"
URGENT="${URGENT%%$'\n'*}"; URGENT="${URGENT:-0}"

# --- Gateway ---
GW_PID=$(pgrep -f "openclaw" | head -1)
GW_STATUS="DOWN"; [ -n "$GW_PID" ] && GW_STATUS="UP"
DISCO=$(df -h / | awk 'NR==2{print $5}')

# --- Sessões ---
SESS_COUNT=0
[ -f "$SESSIONS" ] && SESS_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS')); print(len(d))" 2>/dev/null || echo 0)

# --- Backup ---
BACKUP="nao"; [ -f "$LOGS/backup-offsite.log" ] && grep -q "$TODAY" "$LOGS/backup-offsite.log" 2>/dev/null && BACKUP="ok"

# --- Erros ---
GW_ERRS=0
[ -f "$LOGS/gateway.log" ] && GW_ERRS=$(grep -c "$TODAY.*\(error\|ERROR\)" "$LOGS/gateway.log" 2>/dev/null || echo 0)
BR_ERRS=0
[ -f "$LOGS/whatsapp-bridge.log" ] && BR_ERRS=$(grep -c "$TODAY.*\(error\|ERROR\)" "$LOGS/whatsapp-bridge.log" 2>/dev/null || echo 0)

# --- Heartbeats ---
HB_COUNT=$(find "$WORKSPACE/memory/logs" -name "*.log" -mtime 0 2>/dev/null | wc -l | tr -d ' ')

# --- Auditoria ---
AUDIT="nao rodou"
if [ -f "$LOGS/audit-diario.log" ] && grep -q "$TODAY" "$LOGS/audit-diario.log" 2>/dev/null; then
  A_PROB=$(grep -c "$TODAY.*PROBLEMA" "$LOGS/audit-diario.log" 2>/dev/null || echo 0)
  A_AVIS=$(grep -c "$TODAY.*AVISO" "$LOGS/audit-diario.log" 2>/dev/null || echo 0)
  AUDIT="${A_PROB} problemas, ${A_AVIS} avisos"
fi

# --- Alertas do dia ---
ALERTAS=""
for logf in "$LOGS"/wolf-monitor.log "$LOGS"/watchdog.log "$LOGS"/kanban-guardian.log "$LOGS"/cost-tracker.log; do
  [ -f "$logf" ] || continue
  ALERT_LINE=$(grep "$TODAY.*\(ALERTA\|WARN\|CRITICAL\|PROBLEMA\)" "$logf" 2>/dev/null | tail -1)
  if [ -n "$ALERT_LINE" ]; then
    NOME=$(basename "$logf" .log)
    ALERTAS="${ALERTAS}
  - ${NOME}: $(echo "$ALERT_LINE" | sed "s/.*$TODAY [0-9:]*//" | cut -c1-80)"
  fi
done
[ -z "$ALERTAS" ] && ALERTAS="
  Nenhum alerta"

# --- Preparar contexto matinal (absorvido de nota_diaria) ---
cat > "$WORKSPACE/memory/morning_context.md" << EOFCTX
# Contexto Matinal — encerramento de $DATE
## Tasks em aberto: $OPEN
$(grep "^- \[ \]" "$QUEUE" 2>/dev/null | head -5 || echo "_Fila vazia_")
## Concluidas hoje: $DONE
## Ultima atualizacao: $(date '+%Y-%m-%d %H:%M:%S')
EOFCTX

# --- Montar mensagem unica ---
MSG="*Fechamento do dia — ${DATE}*

*Tasks:* ${DONE} concluida(s) | ${OPEN} abertas"
[ "$URGENT" -gt 0 ] && MSG="${MSG} | ${URGENT} urgentes"

MSG="${MSG}

*Sistema:* GW ${GW_STATUS} | Disco ${DISCO} | ${SESS_COUNT} sessoes | Backup ${BACKUP}
*Erros:* GW ${GW_ERRS} | Bridge ${BR_ERRS} | ${HB_COUNT} heartbeats ok
*Auditoria:* ${AUDIT}
*Alertas:*${ALERTAS}

Contexto de amanha preparado. Boa noite."

wolf_notify "$MSG"

# Marker para heartbeats
touch /tmp/.wolf-digest-mark

wolf_log "digest" "Digest enviado — done=$DONE open=$OPEN errs=$GW_ERRS/$BR_ERRS"
