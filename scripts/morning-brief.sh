#!/bin/bash
# morning-brief.sh — Morning Brief do Netto
# Roda 08:30 todo dia — 3 mensagens separadas em sequência
# Bloco 1: Tasks | Bloco 2: Emails | Bloco 3: Financeiro

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ── Error trap — notifica via WhatsApp se script travar ────────────────────
LOG="$WORKSPACE/memory/logs/morning-brief.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$TIMESTAMP] $1" | tee -a "$LOG"; }
source "$WORKSPACE/scripts/lib-wolf.sh" 2>/dev/null || true
trap 'EXIT_CODE=$?; if [ $EXIT_CODE -ne 0 ]; then
  wolf_notify "⚠️ morning-brief.sh falhou (código $EXIT_CODE) às $(date +%H:%M). Ver log: memory/logs/morning-brief.log" 2>/dev/null || true
  log "ERRO: script falhou com código $EXIT_CODE"
fi' EXIT

log "Morning Brief iniciado"

# ── Bloco 0: Strategic Brain Insights (se disponível) ─────────────────────
BRAIN_FILE="$WORKSPACE/memory/brain/insight-morning-$(date +%Y-%m-%d).md"
if [ -f "$BRAIN_FILE" ]; then
  log "Bloco 0: Enviando Strategic Brain insights"

  # Extrair seções-chave do insight (primeiras 40 linhas, resumido)
  BRAIN_SUMMARY=$(head -40 "$BRAIN_FILE" | grep -E "^[0-9]+\.|RISCO|OPORTUNIDADE|INSIGHT|AÇÃO|ESTADO" | head -8)

  if [ -n "$BRAIN_SUMMARY" ]; then
    # Health scores dos clientes
    HEALTH_LINE=""
    for hf in "$WORKSPACE"/memory/clients/*/health.yaml; do
      [ -f "$hf" ] || continue
      H_NAME=$(grep "client:" "$hf" 2>/dev/null | awk -F'"' '{print $2}')
      H_SCORE=$(grep "  score:" "$hf" 2>/dev/null | awk '{print $2}')
      H_TREND=$(grep "  trend:" "$hf" 2>/dev/null | awk '{print $2}')
      H_EMOJI="🟢"; [ "${H_SCORE:-0}" -lt 70 ] 2>/dev/null && H_EMOJI="🟡"; [ "${H_SCORE:-0}" -lt 50 ] 2>/dev/null && H_EMOJI="🔴"
      HEALTH_LINE="${HEALTH_LINE}${H_EMOJI} ${H_NAME}: ${H_SCORE}/100 (${H_TREND})\n"
    done

    # Ações autônomas (se existirem)
    ACTIONS_FILE="$WORKSPACE/memory/brain/actions-$(date +%Y-%m-%d).md"
    ACTIONS_LINE=""
    if [ -f "$ACTIONS_FILE" ]; then
      ACTIONS_LINE="\n⚡ *Ações Autônomas*\n$(head -5 "$ACTIONS_FILE" | grep -v "^#")"
    fi

    BRAIN_MSG="🧠 *Visão Estratégica — $(date +%d/%m)*

🏥 *Saúde dos Clientes*
$(echo -e "$HEALTH_LINE")
💡 *Insights do Brain*
$BRAIN_SUMMARY${ACTIONS_LINE}"

    # Enviar via WhatsApp (canal principal)
    source "$WORKSPACE/scripts/lib-wolf.sh"
    wolf_notify_info "$BRAIN_MSG"
    log "Bloco 0: Brain insights enviados com health scores"
  else
    log "Bloco 0: Brain file existe mas sem insights extraíveis"
  fi
else
  log "Bloco 0: Sem insights do Strategic Brain hoje"
fi

# ── Bloco 1: Task Queue ────────────────────────────────────────────────────
log "Bloco 1: Task Queue"
bash "$WORKSPACE/scripts/morning_kickoff.sh" >> "$LOG" 2>&1 && log "Tasks OK" || log "WARN: Tasks falhou"

sleep 3

# ── Bloco 2: Email Briefing ───────────────────────────────────────────────
log "Bloco 2: Email Briefing"
cd "$WORKSPACE" && scripts/.venv/bin/python3 scripts/email-monitor.py briefing >> "$LOG" 2>&1 && log "Email OK" || log "WARN: Email falhou"

# ── Bloco 3: Financeiro — SUSPENSO (migrar para WhatsApp)
# log "Bloco 3: Financeiro"
# scripts/.venv/bin/python3 scripts/financeiro-morning.py >> "$LOG" 2>&1

log "Morning Brief concluído"
