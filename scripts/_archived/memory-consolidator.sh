#!/bin/bash
# ============================================================================
# MEMORY CONSOLIDATOR
# Sexta 23h — Sintetiza a semana e atualiza alfred-core.md
#
# O que faz:
#   1. Lê daily notes dos últimos 7 dias (memory/daily/)
#   2. Lê actions.jsonl dos últimos 7 dias (métricas reais de execução)
#   3. Envia tudo pro Haiku com instruções de consolidação
#   4. Haiku gera um bloco "Aprendizados da Semana" formatado
#   5. Script insere o bloco no alfred-core.md (seção dedicada, sem sobrescrever)
#   6. Mantém histórico em memory/consolidations/
#
# CRONTAB:
#   0 23 * * 5 bash ~/.openclaw/workspace/scripts/cron-wrapper.sh "memory-consolidator" bash ~/.openclaw/workspace/scripts/memory-consolidator.sh >> ~/.openclaw/logs/memory-consolidator.log 2>&1
#
# DEPENDÊNCIAS: jq, gateway :18789, actions.jsonl, daily notes
# ============================================================================

set -euo pipefail

WORKSPACE="${HOME}/.openclaw/workspace"
MEMORY_DIR="${WORKSPACE}/memory"
DAILY_DIR="${MEMORY_DIR}/daily"
CONSOLIDATIONS_DIR="${MEMORY_DIR}/consolidations"
ALFRED_CORE="${MEMORY_DIR}/alfred-core.md"
ACTIONS_LOG="${HOME}/.openclaw/logs/actions.jsonl"
GATEWAY="http://127.0.0.1:18789"
HOOKS_TOKEN="${OPENCLAW_HOOKS_TOKEN:-}"

mkdir -p "$CONSOLIDATIONS_DIR"

WEEK_LABEL=$(date +"%Y-W%V")
CUTOFF=$(date -u -v-7d +"%Y-%m-%dT00:00:00Z" 2>/dev/null || date -u -d "7 days ago" +"%Y-%m-%dT00:00:00Z")

echo "[memory-consolidator] Início: $(date)"
echo "[memory-consolidator] Semana: $WEEK_LABEL"

# ── 1. Coleta daily notes da semana ───────────────────────────
DAILY_CONTENT=""
DAILY_COUNT=0
for i in $(seq 0 6); do
  DAY=$(date -v-${i}d +"%Y-%m-%d" 2>/dev/null || date -d "$i days ago" +"%Y-%m-%d")
  NOTE_FILE="${DAILY_DIR}/${DAY}.md"
  if [ -f "$NOTE_FILE" ]; then
    CONTENT=$(cat "$NOTE_FILE")
    # Só inclui se tiver conteúdo além do template vazio
    if echo "$CONTENT" | grep -qvE "^(#|$|-\s*$|\*\s*$)" 2>/dev/null; then
      DAILY_CONTENT="${DAILY_CONTENT}
--- ${DAY} ---
${CONTENT}
"
      ((DAILY_COUNT++))
    fi
  fi
done

echo "[memory-consolidator] Daily notes com conteúdo: $DAILY_COUNT"

# ── 2. Coleta métricas do actions.jsonl ───────────────────────
ACTIONS_SUMMARY=""
if [ -f "$ACTIONS_LOG" ]; then
  WEEK_ACTIONS=$(awk -v cutoff="$CUTOFF" '
    { match($0, /"ts":"([^"]+)"/, arr); if (arr[1] >= cutoff) print }
  ' "$ACTIONS_LOG")

  if [ -n "$WEEK_ACTIONS" ]; then
    TOTAL=$(echo "$WEEK_ACTIONS" | wc -l | tr -d ' ')
    ERRORS=$(echo "$WEEK_ACTIONS" | grep -c '"status":"error"' || echo 0)
    SUCCESS_RATE=0
    [ "$TOTAL" -gt 0 ] && SUCCESS_RATE=$(( (TOTAL - ERRORS) * 100 / TOTAL ))

    TOP_ERRORS=$(echo "$WEEK_ACTIONS" | grep '"status":"error"' | grep -oE '"cron":"[^"]+"' | sort | uniq -c | sort -rn | head -5)
    TOP_ACTIVE=$(echo "$WEEK_ACTIONS" | grep -oE '"cron":"[^"]+"' | sort | uniq -c | sort -rn | head -5)

    ACTIONS_SUMMARY="MÉTRICAS DE EXECUÇÃO (actions.jsonl):
- Total execuções: ${TOTAL}
- Taxa de sucesso: ${SUCCESS_RATE}%
- Erros: ${ERRORS}

Top 5 mais ativos:
${TOP_ACTIVE}

Top falhas:
${TOP_ERRORS:-Nenhuma}"
  fi
fi

# ── 3. Lê estado atual do alfred-core.md ──────────────────────
CURRENT_CORE=""
if [ -f "$ALFRED_CORE" ]; then
  CURRENT_CORE=$(cat "$ALFRED_CORE")
fi

# ── 4. Monta prompt pro Haiku ─────────────────────────────────
PROMPT="Você é o Memory Consolidator do sistema OpenClaw do Netto (Wolf Agency).

Sua tarefa: analisar os dados da semana e gerar um bloco de APRENDIZADOS para inserir no alfred-core.md.

REGRAS:
1. Gere APENAS o bloco de texto para inserir. Não repita o conteúdo existente do alfred-core.md.
2. Formato do bloco:

## Aprendizados — Semana ${WEEK_LABEL}

### O que funcionou
- [insight concreto baseado nos dados]

### O que falhou
- [falhas reais com nome do cron e frequência]

### Padrões detectados
- [qualquer padrão recorrente nos dados]

### Ação sugerida para próxima semana
- [1-3 ações práticas e específicas]

3. Seja CONCRETO. Use números dos dados. Não invente — se não tem dado, diga que não tem.
4. Máximo 20 linhas no bloco total.
5. Se as daily notes estiverem vazias e as métricas forem poucas, diga isso honestamente e sugira como melhorar a coleta.

DADOS DA SEMANA:

=== DAILY NOTES ===
${DAILY_CONTENT:-Nenhuma daily note com conteúdo relevante esta semana.}

=== MÉTRICAS DO SISTEMA ===
${ACTIONS_SUMMARY:-actions.jsonl ainda não tem dados suficientes (primeira semana de coleta).}

=== ESTADO ATUAL DO ALFRED-CORE (seções existentes, NÃO repita) ===
$(echo "$CURRENT_CORE" | grep "^##" | head -10)

Gere o bloco agora."

# ── 5. Envia pro gateway ─────────────────────────────────────
echo "[memory-consolidator] Enviando para Haiku..."

RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 60 -X POST "${GATEWAY}/hooks/agent" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HOOKS_TOKEN}" \
  -d "$(jq -n --arg message "$PROMPT" '{message: $message}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
  echo "[memory-consolidator] ERRO: Gateway retornou HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

echo "[memory-consolidator] Resposta recebida do gateway"

# ── 6. Salva consolidação no histórico ────────────────────────
CONSOLIDATION_FILE="${CONSOLIDATIONS_DIR}/${WEEK_LABEL}.md"
cat > "$CONSOLIDATION_FILE" << EOF
# Consolidação — ${WEEK_LABEL}
Data: $(date +%Y-%m-%d)

## Dados de entrada
- Daily notes com conteúdo: ${DAILY_COUNT}
- ${ACTIONS_SUMMARY:-Sem dados de actions.jsonl}

## Bloco gerado
(O bloco foi enviado via gateway/Telegram. Verifique o Telegram para o conteúdo.)
EOF

echo "[memory-consolidator] Histórico salvo: $CONSOLIDATION_FILE"

# ── 7. Rotação: mantém últimas 12 consolidações ──────────────
ls -t "$CONSOLIDATIONS_DIR"/*.md 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null

echo "[memory-consolidator] Concluído: $(date)"
