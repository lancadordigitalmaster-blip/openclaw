#!/bin/bash
# ============================================================================
# MONTHLY EVOLUTION REPORT
# Dia 1 de cada mês, 10h — Consolida o mês inteiro e gera relatório evolutivo
#
# Fontes de dados:
#   1. actions.jsonl — métricas brutas dos últimos 30 dias
#   2. weekly-digest-*.md — resumos semanais (se existirem)
#   3. failure-report-*.md — relatórios de falha (se existirem)
#   4. consolidations/*.md — aprendizados semanais (se existirem)
#
# Output:
#   - reports/monthly-YYYY-MM.md (relatório completo local)
#   - Resumo executivo via Telegram (Haiku)
#
# CRONTAB:
#   0 10 1 * * bash ~/.openclaw/workspace/scripts/cron-wrapper.sh "monthly-report" bash ~/.openclaw/workspace/scripts/monthly-report.sh >> ~/.openclaw/logs/monthly-report.log 2>&1
# ============================================================================

set -euo pipefail

ACTIONS_LOG="${HOME}/.openclaw/logs/actions.jsonl"
REPORTS_DIR="${HOME}/.openclaw/workspace/reports"
CONSOLIDATIONS_DIR="${HOME}/.openclaw/workspace/memory/consolidations"
GATEWAY="http://127.0.0.1:18789"
HOOKS_TOKEN="${OPENCLAW_HOOKS_TOKEN:-}"

mkdir -p "$REPORTS_DIR"

# Mês anterior (o relatório do dia 1 cobre o mês que acabou)
if date -v-1m +%Y 2>/dev/null >&2; then
  MONTH_LABEL=$(date -v-1m +"%Y-%m")
  MONTH_NAME=$(date -v-1m +"%B %Y")
  CUTOFF_START=$(date -v-1m -v1d +"%Y-%m-01T00:00:00Z")
  CUTOFF_END=$(date -v1d +"%Y-%m-01T00:00:00Z")
else
  MONTH_LABEL=$(date -d "last month" +"%Y-%m")
  MONTH_NAME=$(date -d "last month" +"%B %Y")
  CUTOFF_START=$(date -d "last month" +"%Y-%m-01T00:00:00Z")
  CUTOFF_END=$(date +"%Y-%m-01T00:00:00Z")
fi

echo "[monthly-report] Início: $(date)"
echo "[monthly-report] Cobrindo: $MONTH_LABEL ($MONTH_NAME)"

# ── 1. Métricas brutas do mês (actions.jsonl) ─────────────────
MONTH_METRICS="Sem dados de actions.jsonl para este mês."
TOTAL=0
if [ -f "$ACTIONS_LOG" ]; then
  MONTH_DATA=$(awk -v start="$CUTOFF_START" -v end="$CUTOFF_END" '
    { match($0, /"ts":"([^"]+)"/, arr); if (arr[1] >= start && arr[1] < end) print }
  ' "$ACTIONS_LOG")

  TOTAL=$(echo "$MONTH_DATA" | grep -c . || echo 0)

  if [ "$TOTAL" -gt 0 ]; then
    OK=$(echo "$MONTH_DATA" | grep -c '"status":"ok"' || echo 0)
    ERRORS=$(echo "$MONTH_DATA" | grep -c '"status":"error"' || echo 0)
    SUCCESS_RATE=$(( OK * 100 / TOTAL ))

    # Crons únicos que executaram
    UNIQUE_CRONS=$(echo "$MONTH_DATA" | grep -oE '"cron":"[^"]+"' | sort -u | wc -l | tr -d ' ')

    # Dia com mais erros
    WORST_DAY=$(echo "$MONTH_DATA" | grep '"status":"error"' | \
      grep -oE '"ts":"[^T]+"' | sed 's/"ts":"//' | sort | uniq -c | sort -rn | head -1)

    # Top 5 crons mais ativos
    TOP5=$(echo "$MONTH_DATA" | grep -oE '"cron":"[^"]+"' | sed 's/"cron":"//;s/"//' | \
      sort | uniq -c | sort -rn | head -5)

    # Top falhas
    TOP_FAILS=$(echo "$MONTH_DATA" | grep '"status":"error"' | \
      grep -oE '"cron":"[^"]+"' | sed 's/"cron":"//;s/"//' | \
      sort | uniq -c | sort -rn | head -5)

    # Execuções por dia (média)
    DAYS_WITH_DATA=$(echo "$MONTH_DATA" | grep -oE '"ts":"[^T]+"' | sort -u | wc -l | tr -d ' ')
    AVG_PER_DAY=0
    [ "$DAYS_WITH_DATA" -gt 0 ] && AVG_PER_DAY=$(( TOTAL / DAYS_WITH_DATA ))

    MONTH_METRICS="MÉTRICAS DO MÊS:
- Total de execuções: ${TOTAL}
- Sucesso: ${OK} (${SUCCESS_RATE}%)
- Erros: ${ERRORS}
- Crons únicos ativos: ${UNIQUE_CRONS}
- Média por dia: ~${AVG_PER_DAY} execuções
- Dias com dados: ${DAYS_WITH_DATA}
- Pior dia: ${WORST_DAY:-nenhum erro}

TOP 5 CRONS MAIS ATIVOS:
${TOP5}

TOP FALHAS DO MÊS:
${TOP_FAILS:-Nenhuma falha}"
  fi
fi

# ── 2. Weekly digests do mês ──────────────────────────────────
WEEKLY_SUMMARIES=""
WEEKLY_COUNT=0
for f in "$REPORTS_DIR"/weekly-digest-${MONTH_LABEL}*.md "$REPORTS_DIR"/weekly-digest-$(date +%Y)-W*.md; do
  if [ -f "$f" ] 2>/dev/null; then
    WEEKLY_SUMMARIES="${WEEKLY_SUMMARIES}
--- $(basename "$f") ---
$(head -20 "$f")
"
    ((WEEKLY_COUNT++))
  fi
done 2>/dev/null

# ── 3. Failure reports do mês ─────────────────────────────────
FAILURE_SUMMARIES=""
FAILURE_COUNT=0
for f in "$REPORTS_DIR"/failure-report-${MONTH_LABEL}*.md; do
  if [ -f "$f" ] 2>/dev/null; then
    FAILURE_SUMMARIES="${FAILURE_SUMMARIES}
--- $(basename "$f") ---
$(head -15 "$f")
"
    ((FAILURE_COUNT++))
  fi
done 2>/dev/null

# ── 4. Consolidações do mês ──────────────────────────────────
CONSOLIDATION_SUMMARIES=""
CONSOL_COUNT=0
for f in "$CONSOLIDATIONS_DIR"/${MONTH_LABEL}*.md "$CONSOLIDATIONS_DIR"/*${MONTH_LABEL}*.md; do
  if [ -f "$f" ] 2>/dev/null; then
    CONSOLIDATION_SUMMARIES="${CONSOLIDATION_SUMMARIES}
--- $(basename "$f") ---
$(head -15 "$f")
"
    ((CONSOL_COUNT++))
  fi
done 2>/dev/null

# ── 5. Monta relatório bruto completo ────────────────────────
RAW_REPORT="# Monthly Evolution Report — ${MONTH_NAME}
Gerado em: $(date +%Y-%m-%d)

## Fontes de dados
- actions.jsonl: ${TOTAL:-0} registros
- Weekly digests: ${WEEKLY_COUNT}
- Failure reports: ${FAILURE_COUNT}
- Memory consolidations: ${CONSOL_COUNT}

## ${MONTH_METRICS}

## Weekly Digests
${WEEKLY_SUMMARIES:-Nenhum weekly digest disponível para este mês.}

## Failure Reports
${FAILURE_SUMMARIES:-Nenhum failure report disponível para este mês.}

## Memory Consolidations
${CONSOLIDATION_SUMMARIES:-Nenhuma consolidação disponível para este mês.}
"

# Salva relatório bruto local
REPORT_FILE="${REPORTS_DIR}/monthly-${MONTH_LABEL}.md"
echo "$RAW_REPORT" > "$REPORT_FILE"
echo "[monthly-report] Relatório bruto salvo: $REPORT_FILE"

# ── 6. Envia pro Haiku gerar resumo executivo ────────────────
PROMPT="Você é o analista de sistemas do Netto (Wolf Agency). Gere um RESUMO EXECUTIVO MENSAL do OpenClaw.

REGRAS:
1. Máximo 20 linhas
2. Formato para Telegram:

📊 MONTHLY REPORT — ${MONTH_NAME}

📈 Visão geral
[2-3 linhas: volume, taxa sucesso, saúde geral]

🏆 Destaques positivos
[2-3 coisas que funcionaram bem]

⚠️ Problemas recorrentes
[2-3 issues que apareceram mais de uma vez]

📐 Evolução vs mês anterior
[Se não tem dados do mês anterior, diga que é o primeiro relatório]

🎯 Plano sugerido para $(date +%B)
[3 ações concretas baseadas nos dados]

3. Use números reais. Não invente.
4. Se dados estão incompletos (primeiro mês), seja honesto.

DADOS:
${RAW_REPORT}"

RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 60 -X POST "${GATEWAY}/hooks/agent" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HOOKS_TOKEN}" \
  -d "$(jq -n --arg message "$PROMPT" '{message: $message}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "[monthly-report] Resumo executivo enviado via Telegram"
else
  echo "[monthly-report] AVISO: Gateway retornou HTTP $HTTP_CODE. Relatório salvo localmente."
fi

# ── 7. Rotação: mantém últimos 12 relatórios mensais ─────────
ls -t "$REPORTS_DIR"/monthly-*.md 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null

echo "[monthly-report] Concluído: $(date)"
