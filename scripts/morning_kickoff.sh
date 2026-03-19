#!/bin/bash
# morning_kickoff.sh — Wolf Agency
# Cron: 07:30 diario | Briefing matinal baseado na fila de trabalho

set -eo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
LOG_FILE="$WORKSPACE/memory/logs/morning_kickoff.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_DISPLAY=$(date '+%d/%m/%Y')
DAY_NAME=$(LANG=pt_BR.UTF-8 date '+%A' 2>/dev/null || date '+%A' | sed 's/Monday/Segunda/;s/Tuesday/Terca/;s/Wednesday/Quarta/;s/Thursday/Quinta/;s/Friday/Sexta/;s/Saturday/Sabado/;s/Sunday/Domingo/')

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$TIMESTAMP] $1" >> "$LOG_FILE"; }

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh" 2>/dev/null || true

if [ ! -f "$QUEUE" ]; then
  wolf_notify "Netto, nao encontrei o QUEUE.md. Algo pode ter saido do lugar — preciso de uma olhada."
  log "ERROR: QUEUE.md not found"
  exit 1
fi

TOTAL_OPEN=$(grep -c "^- \[ \]" "$QUEUE" 2>/dev/null || echo "0")
URGENT_LIST=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null \
  | grep "^- \[ \]" | head -3 \
  | sed 's/- \[ \] /- /' | sed 's/ | agente:.*//' || true)
BLOCKED=$(awk '/## BLOCKED/,/## METRICAS/' "$QUEUE" 2>/dev/null \
  | grep -c "^- \[ \]" || echo "0")

MSG="Bom dia, Netto. $DAY_NAME, $DATE_DISPLAY.

Temos *$TOTAL_OPEN tasks* na fila hoje."

if [ -n "$URGENT_LIST" ]; then
  MSG="$MSG

Prioridade pra hoje:
$URGENT_LIST"
else
  MSG="$MSG Nada urgente no momento."
fi

[ "$BLOCKED" -gt 0 ] && MSG="$MSG

Tem $BLOCKED coisa(s) travada(s) esperando input teu."

# ── Verificar licoes recentes e alertas ──────────────────────────────────
LESSONS_FILE="$WORKSPACE/memory/lessons.md"
ALERTS=""
if [ -f "$LESSONS_FILE" ]; then
  # Licoes dos ultimos 7 dias com status pendente
  RECENT_LESSONS=$(grep -A 4 "^\*\*Data:\*\*" "$LESSONS_FILE" 2>/dev/null | grep -B 1 "pendente\|PENDENTE\|investigar\|INVESTIGAR" | grep "Data:" | tail -3 || true)
  if [ -n "$RECENT_LESSONS" ]; then
    ALERTS="
Atencao hoje:
$(echo "$RECENT_LESSONS" | sed 's/.*\*\*Data:\*\* /- Licao de /' | head -3)"
  fi
fi

# Verificar errors.md recentes
ERRORS_FILE="$WORKSPACE/memory/errors.md"
if [ -f "$ERRORS_FILE" ]; then
  PENDING_ERRORS=$(grep -c "pendente\|PENDENTE" "$ERRORS_FILE" 2>/dev/null || echo "0")
  [ "$PENDING_ERRORS" -gt 0 ] && ALERTS="$ALERTS
$PENDING_ERRORS erro(s) pendente(s) em errors.md"
fi

# ── Strategic Brain Insights (se Morning Think rodou às 06h30) ────────────
BRAIN_FILE="$WORKSPACE/memory/brain/insight-morning-$(date +%Y-%m-%d).md"
if [ -f "$BRAIN_FILE" ]; then
  # Extrair riscos e oportunidades do Brain (primeiras linhas de cada seção)
  BRAIN_RISKS=$(awk '/RISCOS/,/OPORTUNIDADES/' "$BRAIN_FILE" 2>/dev/null | grep -E "^[0-9-]" | head -2 | sed 's/^/  /' || true)
  BRAIN_OPPS=$(awk '/OPORTUNIDADES/,/PADRAO/' "$BRAIN_FILE" 2>/dev/null | grep -E "^[0-9-]" | head -2 | sed 's/^/  /' || true)
  BRAIN_ACTIONS=$(cat "$WORKSPACE/memory/brain/actions-$(date +%Y-%m-%d).md" 2>/dev/null | head -3 || true)

  if [ -n "$BRAIN_RISKS" ] || [ -n "$BRAIN_OPPS" ]; then
    ALERTS="$ALERTS

Visao Estrategica (Brain):"
    [ -n "$BRAIN_RISKS" ] && ALERTS="$ALERTS
Riscos:
$BRAIN_RISKS"
    [ -n "$BRAIN_OPPS" ] && ALERTS="$ALERTS
Oportunidades:
$BRAIN_OPPS"
  fi

  [ -n "$BRAIN_ACTIONS" ] && ALERTS="$ALERTS
Acoes autonomas: $BRAIN_ACTIONS"
fi

# ── Client Health Summary (se rodou às 07h) ──────────────────────────────
HEALTH_ALERTS=""
for hf in "$WORKSPACE"/memory/clients/*/health.yaml; do
  [ -f "$hf" ] || continue
  HSCORE=$(grep "score:" "$hf" 2>/dev/null | head -1 | awk '{print $2}')
  [ "$HSCORE" = "null" ] && continue
  [ -z "$HSCORE" ] && continue
  HNAME=$(grep "client:" "$hf" 2>/dev/null | awk -F'"' '{print $2}')
  if [ "$HSCORE" -lt 50 ] 2>/dev/null; then
    HEALTH_ALERTS="$HEALTH_ALERTS
  🔴 $HNAME: score $HSCORE/100"
  fi
done
[ -n "$HEALTH_ALERTS" ] && ALERTS="$ALERTS

Clientes em risco:$HEALTH_ALERTS"

[ -n "$ALERTS" ] && MSG="$MSG
$ALERTS"

wolf_notify "$MSG"

# Atualizar metricas no QUEUE.md
sed -i '' "s/- Total pendente: .*/- Total pendente: $TOTAL_OPEN/" "$QUEUE" 2>/dev/null || true
sed -i '' "s/- Ultima atualizacao: .*/- Ultima atualizacao: $TIMESTAMP/" "$QUEUE" 2>/dev/null || true

log "Morning Kickoff concluido — $TOTAL_OPEN tasks abertas"
echo "OK: morning_kickoff completed at $TIMESTAMP"
