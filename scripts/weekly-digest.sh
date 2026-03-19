#!/bin/bash
# ============================================================================
# WEEKLY SYSTEM DIGEST
# Lê actions.jsonl dos últimos 7 dias e gera resumo executivo do sistema.
# Envia via Haiku (hooks/agent) para Telegram.
#
# CRONTAB: 0 9 * * 1 bash ~/.openclaw/workspace/scripts/cron-wrapper.sh "weekly-digest" bash ~/.openclaw/workspace/scripts/weekly-digest.sh
#
# DEPENDÊNCIAS:
#   - actions.jsonl populado pelo cron-wrapper.sh
#   - Gateway OpenClaw rodando na porta 18789
#   - jq instalado (brew install jq)
# ============================================================================

set -euo pipefail

ACTIONS_LOG="${HOME}/.openclaw/logs/actions.jsonl"
REPORTS_DIR="${HOME}/.openclaw/workspace/reports"
GATEWAY="http://127.0.0.1:18789"
HOOKS_TOKEN="${OPENCLAW_HOOKS_TOKEN:-}"

mkdir -p "$REPORTS_DIR"

# ── Data range: últimos 7 dias ─────────────────────────────────
CUTOFF=$(date -u -v-7d +"%Y-%m-%dT00:00:00Z" 2>/dev/null || date -u -d "7 days ago" +"%Y-%m-%dT00:00:00Z")
TODAY=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
WEEK_LABEL=$(date +"%Y-W%V")

if [ ! -f "$ACTIONS_LOG" ]; then
  echo "ERRO: $ACTIONS_LOG não encontrado. O cron-wrapper.sh está ativo?"
  exit 1
fi

# ── Filtra últimos 7 dias ──────────────────────────────────────
WEEK_DATA=$(awk -v cutoff="$CUTOFF" '
  {
    match($0, /"ts":"([^"]+)"/, arr)
    if (arr[1] >= cutoff) print
  }
' "$ACTIONS_LOG")

if [ -z "$WEEK_DATA" ]; then
  echo "Nenhum registro nos últimos 7 dias."
  exit 0
fi

# ── Métricas brutas ───────────────────────────────────────────
TOTAL=$(echo "$WEEK_DATA" | wc -l | tr -d ' ')
OK_COUNT=$(echo "$WEEK_DATA" | grep -c '"status":"ok"' || echo 0)
ERROR_COUNT=$(echo "$WEEK_DATA" | grep -c '"status":"error"' || echo 0)

if [ "$TOTAL" -gt 0 ]; then
  SUCCESS_RATE=$(( OK_COUNT * 100 / TOTAL ))
else
  SUCCESS_RATE=0
fi

# ── Top 5 crons mais executados ────────────────────────────────
TOP_CRONS=$(echo "$WEEK_DATA" | grep -oE '"cron":"[^"]+"' | sort | uniq -c | sort -rn | head -5)

# ── Top falhas (crons com mais erros) ─────────────────────────
TOP_FAILURES=$(echo "$WEEK_DATA" | grep '"status":"error"' | grep -oE '"cron":"[^"]+"' | sort | uniq -c | sort -rn | head -5)

# ── Crons que nunca executaram essa semana ─────────────────────
# Pega todos os crons conhecidos do crontab
ALL_CRONS=$(crontab -l 2>/dev/null | grep "cron-wrapper.sh" | grep -oE '"[^"]+"\s' | tr -d '" ' | sort -u)
ACTIVE_CRONS=$(echo "$WEEK_DATA" | grep -oE '"cron":"[^"]+"' | sed 's/"cron":"//;s/"//' | sort -u)
DORMANT_CRONS=$(comm -23 <(echo "$ALL_CRONS") <(echo "$ACTIVE_CRONS") 2>/dev/null || echo "")

# ── Duração média ─────────────────────────────────────────────
AVG_DURATION=$(echo "$WEEK_DATA" | grep -oE '"duration_ms":[0-9]+' | sed 's/"duration_ms"://' | awk '{sum+=$1; n++} END {if(n>0) printf "%.0f", sum/n; else print 0}')

# ── Erros recentes (últimos 5) ────────────────────────────────
RECENT_ERRORS=$(echo "$WEEK_DATA" | grep '"status":"error"' | tail -5)

# ── Monta relatório de texto bruto ────────────────────────────
REPORT="WEEKLY SYSTEM DIGEST — ${WEEK_LABEL}
Período: $(echo $CUTOFF | cut -dT -f1) a $(date +%Y-%m-%d)

MÉTRICAS GERAIS:
- Total de execuções: ${TOTAL}
- Sucesso: ${OK_COUNT} (${SUCCESS_RATE}%)
- Erros: ${ERROR_COUNT}
- Duração média: ${AVG_DURATION}ms

TOP 5 CRONS MAIS ATIVOS:
${TOP_CRONS}

TOP FALHAS DA SEMANA:
${TOP_FAILURES:-Nenhuma falha registrada}

CRONS DORMENTES (no crontab mas sem execução na semana):
${DORMANT_CRONS:-Todos executaram pelo menos 1x}

ÚLTIMOS ERROS:
${RECENT_ERRORS:-Nenhum}"

# ── Salva relatório local ─────────────────────────────────────
REPORT_FILE="${REPORTS_DIR}/weekly-digest-${WEEK_LABEL}.md"
echo "$REPORT" > "$REPORT_FILE"
echo "Relatório salvo: $REPORT_FILE"

# ── Envia pro Haiku via Gateway para gerar resumo humano ──────
PROMPT="Você é o assistente de sistemas do Netto. Analise este relatório semanal do OpenClaw e gere um resumo executivo curto (máximo 15 linhas) para enviar no Telegram.

Formato:
📊 WEEKLY DIGEST — [semana]
✅ [total] execuções, [taxa]% sucesso
⚠️ [número] falhas — [quais crons falharam e quantas vezes]
🔇 [crons dormentes, se houver]
💡 [1-2 recomendações práticas baseadas nos dados]

Dados brutos:
${REPORT}"

# Envia via hooks/agent
RESPONSE=$(curl -s -X POST "${GATEWAY}/hooks/agent" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HOOKS_TOKEN}" \
  -d "$(jq -n --arg prompt "$PROMPT" '{prompt: $prompt}')" \
  2>/dev/null)

if [ $? -eq 0 ]; then
  echo "Weekly digest enviado via gateway"
else
  echo "AVISO: Falha ao enviar via gateway. Relatório salvo localmente em $REPORT_FILE"
fi

# ── Rotação: mantém últimos 12 relatórios ─────────────────────
ls -t "$REPORTS_DIR"/weekly-digest-*.md 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null

echo "Done."
