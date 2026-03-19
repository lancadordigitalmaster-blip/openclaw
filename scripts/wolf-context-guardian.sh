#!/bin/bash
# wolf-context-guardian.sh — Never-Forget Protocol para Wolf
# Monitora sessões ativas, detecta contexto cheio, cria checkpoints graduais
# Crontab: */15 * * * * bash ~/.openclaw/workspace/scripts/wolf-context-guardian.sh
#
# 5 níveis:
#   GREEN  (<50%) — normal, silêncio
#   YELLOW (50-69%) — log warning
#   ORANGE (70-84%) — checkpoint automático
#   RED    (85-94%) — checkpoint + notifica Telegram
#   CRITICAL (95%+) — checkpoint + notifica + sugere restart

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
CHECKPOINTS_DIR="$WORKSPACE/memory/checkpoints"
HEALTH_FILE="$WORKSPACE/memory/context-health.md"
LOG="$WORKSPACE/memory/logs/context-guardian.log"

# Sonnet 4.6 context: 200K tokens ≈ 800K chars
# Margem conservadora: usamos 700K como 100%
CONTEXT_MAX_CHARS=700000

mkdir -p "$CHECKPOINTS_DIR" "$(dirname "$LOG")"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"; }

# ─── Detectar sessão ativa (mais recente modificada nos últimos 30min) ───
ACTIVE_SESSION=""
ACTIVE_SIZE=0

if [ -d "$SESSIONS_DIR" ]; then
    ACTIVE_SESSION=$(find "$SESSIONS_DIR" -name "*.jsonl" -mmin -30 2>/dev/null \
        | while read f; do echo "$(wc -c < "$f" | tr -d ' ') $f"; done \
        | sort -rn | head -1 | awk '{print $2}')

    if [ -n "$ACTIVE_SESSION" ] && [ -f "$ACTIVE_SESSION" ]; then
        ACTIVE_SIZE=$(wc -c < "$ACTIVE_SESSION" | tr -d ' ')
    fi
fi

# Incluir sessions.json no cálculo (estado persistido)
SESSIONS_JSON="$SESSIONS_DIR/sessions.json"
SESSIONS_JSON_SIZE=0
if [ -f "$SESSIONS_JSON" ]; then
    SESSIONS_JSON_SIZE=$(wc -c < "$SESSIONS_JSON" | tr -d ' ')
fi

# Total = sessão ativa + overhead do sessions.json
TOTAL_SIZE=$((ACTIVE_SIZE + SESSIONS_JSON_SIZE / 10))  # sessions.json pesa menos (10%)

# ─── Calcular porcentagem ───
if [ "$CONTEXT_MAX_CHARS" -gt 0 ]; then
    PCT=$((TOTAL_SIZE * 100 / CONTEXT_MAX_CHARS))
else
    PCT=0
fi

# Cap at 100
[ "$PCT" -gt 100 ] && PCT=100

# ─── Determinar nível ───
if [ "$PCT" -lt 50 ]; then
    LEVEL="GREEN"
    EMOJI="🟢"
    ACTION="none"
elif [ "$PCT" -lt 70 ]; then
    LEVEL="YELLOW"
    EMOJI="🟡"
    ACTION="log"
elif [ "$PCT" -lt 85 ]; then
    LEVEL="ORANGE"
    EMOJI="🟠"
    ACTION="checkpoint"
elif [ "$PCT" -lt 95 ]; then
    LEVEL="RED"
    EMOJI="🔴"
    ACTION="checkpoint+notify"
else
    LEVEL="CRITICAL"
    EMOJI="⛔"
    ACTION="checkpoint+notify+restart"
fi

# ─── Atualizar context-health.md ───
cat > "$HEALTH_FILE" << EOF
# Context Health — Never-Forget Protocol
**Atualizado:** $(date '+%Y-%m-%d %H:%M:%S')
**Nível:** $EMOJI $LEVEL ($PCT%)
**Sessão ativa:** $(basename "${ACTIVE_SESSION:-nenhuma}" 2>/dev/null)
**Tamanho sessão:** $((ACTIVE_SIZE / 1024))KB
**sessions.json:** $((SESSIONS_JSON_SIZE / 1024))KB
**Contexto estimado:** ${PCT}% de ${CONTEXT_MAX_CHARS} chars

## Ação recomendada
EOF

# Append ação por nível
case "$LEVEL" in
    GREEN)    echo "Operação normal. Nenhuma ação necessária." >> "$HEALTH_FILE" ;;
    YELLOW)   echo "Monitorar. Considerar consolidar contexto em breve." >> "$HEALTH_FILE" ;;
    ORANGE)   echo "Checkpoint criado automaticamente. Evitar carregar arquivos grandes." >> "$HEALTH_FILE" ;;
    RED)      echo "URGENTE: Salvar contexto e considerar nova sessão." >> "$HEALTH_FILE" ;;
    CRITICAL) echo "EMERGÊNCIA: Contexto quase esgotado. Restart recomendado." >> "$HEALTH_FILE" ;;
esac

cat >> "$HEALTH_FILE" << EOF

## Último checkpoint
$(ls -t "$CHECKPOINTS_DIR"/*.md 2>/dev/null | head -1 | sed 's/.*\///' || echo "Nenhum")
EOF

# ─── Executar ações por nível ───

# GREEN: silêncio total
if [ "$ACTION" = "none" ]; then
    log "$LEVEL ($PCT%) — OK"
    echo "OK: $LEVEL ($PCT%)"
    exit 0
fi

# YELLOW: só log
if [ "$ACTION" = "log" ]; then
    log "$LEVEL ($PCT%) — monitorando"
    echo "OK: $LEVEL ($PCT%)"
    exit 0
fi

# ORANGE+: criar checkpoint
CHECKPOINT_FILE="$CHECKPOINTS_DIR/$(date '+%Y-%m-%d-%H%M%S').md"

create_checkpoint() {
    cat > "$CHECKPOINT_FILE" << CKEOF
# Checkpoint — Never-Forget Protocol
**Data:** $(date '+%Y-%m-%d %H:%M:%S')
**Nível:** $EMOJI $LEVEL ($PCT%)
**Sessão:** $(basename "${ACTIVE_SESSION:-?}")
**Tamanho:** $((ACTIVE_SIZE / 1024))KB

## Estado do Sistema
- Gateway: $(curl -s --max-time 2 http://localhost:18789/health 2>/dev/null | grep -q "ok" && echo "UP" || echo "DOWN")
- Bridge: $(curl -s --max-time 2 http://localhost:3002/health 2>/dev/null | grep -q "ok" && echo "UP" || echo "DOWN")
- Erros recentes: $(grep -c "^###" "$WORKSPACE/memory/errors.md" 2>/dev/null || echo 0)
- Lições pendentes: $(grep -c "pendente\|PENDENTE" "$WORKSPACE/memory/lessons.md" 2>/dev/null || echo 0)

## Últimas ações (boot-context)
$(head -20 "$WORKSPACE/memory/boot-context.md" 2>/dev/null || echo "Sem boot-context")

## Agenda ativa
$(head -15 "$WORKSPACE/memory/agenda.md" 2>/dev/null || echo "Sem agenda")

## Recuperação
Para retomar após restart:
1. Ler este checkpoint
2. Ler memory/boot-context.md
3. Verificar tasks/QUEUE.md
4. Continuar de onde parou
CKEOF
    log "Checkpoint criado: $(basename "$CHECKPOINT_FILE")"
}

create_checkpoint

# Limpar checkpoints antigos (manter últimos 10)
ls -t "$CHECKPOINTS_DIR"/*.md 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

# RED+: notificar Telegram
if [ "$ACTION" = "checkpoint+notify" ] || [ "$ACTION" = "checkpoint+notify+restart" ]; then
    MSG="$EMOJI Never-Forget Protocol — $LEVEL ($PCT%)

Sessao ativa: $((ACTIVE_SIZE / 1024))KB
sessions.json: $((SESSIONS_JSON_SIZE / 1024))KB

Checkpoint salvo automaticamente.
$([ "$LEVEL" = "CRITICAL" ] && echo "
ACAO: Considerar restart da sessao para evitar perda de contexto." || echo "
Monitorando. Proximo check em 15min.")"

    wolf_notify_info "$MSG"
fi

# CRITICAL: também atualizar last-context.md
if [ "$ACTION" = "checkpoint+notify+restart" ]; then
    cp "$CHECKPOINT_FILE" "$WORKSPACE/memory/last-context.md"
    log "CRITICAL: last-context.md atualizado com checkpoint"
fi

echo "OK: $LEVEL ($PCT%) — $ACTION"
