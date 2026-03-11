#!/bin/bash
# ============================================================
# WOLF QUEUE — Processador de fila (LLM condicional)
# Roda a cada 30 min via LaunchAgent
# So chama LLM se ha trabalho real na fila ou na agenda
# ============================================================
set -euo pipefail

LOG="/tmp/wolf-queue.log"
AGENDA="$HOME/.openclaw/workspace/memory/agenda-alfred.md"
QUEUE_FILE="$HOME/.openclaw/workspace/tasks/QUEUE.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
GATEWAY_TOKEN="b52639408a26e05b9170423402be3068db69ae001d4b0610"

# ============================================================
# GUARD — So continua se ha trabalho real
# ============================================================

# 1. Verificar QUEUE.md
QUEUE_ITEMS=0
QUEUE_CONTENT=""
if [[ -f "$QUEUE_FILE" ]]; then
  # Contar itens urgentes e this-week (nao backlog/blocked)
  QUEUE_URGENT=$(sed -n '/^## URGENT/,/^## /p' "$QUEUE_FILE" 2>/dev/null | grep -c "^\- \[ \]" 2>/dev/null | tr -d '[:space:]' || echo 0)
  QUEUE_WEEK=$(sed -n '/^## THIS WEEK/,/^## /p' "$QUEUE_FILE" 2>/dev/null | grep -c "^\- \[ \]" 2>/dev/null | tr -d '[:space:]' || echo 0)
  QUEUE_ITEMS=$((QUEUE_URGENT + QUEUE_WEEK))
  if [[ "$QUEUE_ITEMS" -gt 0 ]]; then
    QUEUE_CONTENT=$(sed -n '/^## URGENT/,/^## BACKLOG/p' "$QUEUE_FILE" | head -20)
  fi
fi

# 2. Verificar agenda-alfred.md
TASK_COUNT=0
TASKS=""
if [[ -f "$AGENDA" ]]; then
  TASKS=$(grep -B1 "status: pendente" "$AGENDA" 2>/dev/null \
    | grep "descricao:" \
    | sed 's/.*descricao: *"//;s/"$//' || true)
  if [[ -n "$TASKS" ]]; then
    TASK_COUNT=$(echo "$TASKS" | wc -l | tr -d ' ')
  fi
fi

# 3. Verificar self-reflection pendente
SELF_REFLECTION_BIN="$HOME/.openclaw/workspace/skills/self-reflection/bin/self-reflection"
REFLECTION_PENDING=false
if [[ -x "$SELF_REFLECTION_BIN" ]]; then
  REFLECTION_STATUS=$("$SELF_REFLECTION_BIN" check --quiet 2>/dev/null || true)
  if [[ "$REFLECTION_STATUS" == "ALERT" ]]; then
    REFLECTION_PENDING=true
  fi
fi

# Guard: se nada para fazer, sai silenciosamente
if [[ "$QUEUE_ITEMS" -eq 0 ]] && [[ "$TASK_COUNT" -eq 0 ]] && [[ "$REFLECTION_PENDING" == "false" ]]; then
  echo "[$TIMESTAMP] Fila vazia — sem LLM" >> "$LOG"
  exit 0
fi

# ============================================================
# TRABALHO REAL — Montar contexto e chamar LLM
# ============================================================
echo "[$TIMESTAMP] Trabalho encontrado: queue=$QUEUE_ITEMS agenda=$TASK_COUNT reflection=$REFLECTION_PENDING" >> "$LOG"

# Ler erros recentes para contexto
ERRORS_LOG=""
ERRORS_LOG_FILE="$HOME/.openclaw/workspace/memory/errors.md"
if [[ -f "$ERRORS_LOG_FILE" ]]; then
  ERRORS_LOG=$(tail -5 "$ERRORS_LOG_FILE" 2>/dev/null || true)
fi

# Ler agenda completa
AGENDA_CONTENT=""
if [[ -f "$AGENDA" ]]; then
  AGENDA_CONTENT=$(head -30 "$AGENDA" 2>/dev/null || true)
fi

PAYLOAD="Queue worker automatico — contexto real (NAO inventar dados):

TIMESTAMP: $TIMESTAMP
FILA DE TRABALHO (QUEUE.md): $QUEUE_ITEMS itens ativos
$QUEUE_CONTENT

AGENDA ALFRED (agenda-alfred.md): $TASK_COUNT tarefas pendentes
$AGENDA_CONTENT

ULTIMOS ERROS (errors.md):
$ERRORS_LOG"

if [[ "$REFLECTION_PENDING" == "true" ]]; then
  PAYLOAD="$PAYLOAD

KAIZEN: Self-reflection pendente — analise memory/errors.md, identifique 1 erro recente, registre reflexao."
fi

PAYLOAD="$PAYLOAD

Com base APENAS nos dados acima:
1. Se ha itens URGENT na fila: executa o mais prioritario
2. Se ha tarefas pendentes na agenda com autonomia total: executa a primeira
3. Se KAIZEN pendente: analise errors.md, registre reflexao
4. Registre o que fez em memory/agenda-alfred.md
5. Envie resumo via Telegram para Netto (chat 789352357) APENAS se executou algo relevante."

# Send to Alfred via gateway API
ESCAPED_PAYLOAD=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$PAYLOAD")
curl -s -X POST http://127.0.0.1:18789/api/agent/message \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"message\": $ESCAPED_PAYLOAD}" \
  --max-time 90 >/dev/null 2>&1 || true

echo "[$TIMESTAMP] LLM chamado (queue=$QUEUE_ITEMS agenda=$TASK_COUNT reflection=$REFLECTION_PENDING)" >> "$LOG"

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 500 ]]; then
  tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

echo "OK: wolf-queue — queue=$QUEUE_ITEMS agenda=$TASK_COUNT"
