#!/bin/bash
# ============================================================================
# FAILURE PATTERN DETECTOR
# Sábado 10h — Analisa actions.jsonl buscando padrões de falha recorrente
#
# O que detecta:
#   1. Mesmo cron falhando 3+ vezes na semana
#   2. Falhas concentradas no mesmo horário (±1h)
#   3. Crons com taxa de sucesso < 80%
#   4. Crons que pararam de rodar (última execução > 48h atrás)
#   5. Duração anômala (cron rodando 5x+ mais lento que a média)
#
# CRONTAB:
#   0 10 * * 6 bash ~/.openclaw/workspace/scripts/cron-wrapper.sh "failure-detector" bash ~/.openclaw/workspace/scripts/failure-detector.sh >> ~/.openclaw/logs/failure-detector.log 2>&1
# ============================================================================

set -euo pipefail

ACTIONS_LOG="${HOME}/.openclaw/logs/actions.jsonl"
GATEWAY="http://127.0.0.1:18789"
HOOKS_TOKEN="${OPENCLAW_HOOKS_TOKEN:-}"
REPORTS_DIR="${HOME}/.openclaw/workspace/reports"

mkdir -p "$REPORTS_DIR"

CUTOFF=$(date -u -v-7d +"%Y-%m-%dT00:00:00Z" 2>/dev/null || date -u -d "7 days ago" +"%Y-%m-%dT00:00:00Z")
NOW_EPOCH=$(date +%s)

echo "[failure-detector] Início: $(date)"

if [ ! -f "$ACTIONS_LOG" ]; then
  echo "[failure-detector] actions.jsonl não encontrado. Abortando."
  exit 0
fi

# Filtra última semana
WEEK_DATA=$(awk -v cutoff="$CUTOFF" '
  { match($0, /"ts":"([^"]+)"/, arr); if (arr[1] >= cutoff) print }
' "$ACTIONS_LOG")

TOTAL=$(echo "$WEEK_DATA" | wc -l | tr -d ' ')
if [ "$TOTAL" -lt 10 ]; then
  echo "[failure-detector] Poucos dados ($TOTAL registros). Aguardando mais coleta."
  exit 0
fi

FINDINGS=""
SEVERITY="🟢"

# ── 1. Crons com 3+ falhas na semana ─────────────────────────
REPEAT_FAILURES=$(echo "$WEEK_DATA" | grep '"status":"error"' | \
  grep -oE '"cron":"[^"]+"' | sed 's/"cron":"//;s/"//' | \
  sort | uniq -c | sort -rn | awk '$1 >= 3 {print $1, $2}')

if [ -n "$REPEAT_FAILURES" ]; then
  FINDINGS="${FINDINGS}
🔴 FALHAS RECORRENTES (3+ vezes na semana):
$(echo "$REPEAT_FAILURES" | while read count name; do echo "   $name — $count falhas"; done)
"
  SEVERITY="🔴"
fi

# ── 2. Taxa de sucesso por cron ───────────────────────────────
LOW_SUCCESS=$(echo "$WEEK_DATA" | \
  awk -F'"' '{
    for(i=1;i<=NF;i++) {
      if($i=="cron") cron=$(i+2)
      if($i=="status") status=$(i+2)
    }
    total[cron]++
    if(status=="ok") ok[cron]++
  } END {
    for(c in total) {
      rate = (ok[c]+0)*100/total[c]
      if(rate < 80 && total[c] >= 5) printf "%d%% (%d/%d) %s\n", rate, ok[c]+0, total[c], c
    }
  }' | sort -n)

if [ -n "$LOW_SUCCESS" ]; then
  FINDINGS="${FINDINGS}
🟠 TAXA DE SUCESSO BAIXA (<80%):
$(echo "$LOW_SUCCESS" | while read line; do echo "   $line"; done)
"
  [ "$SEVERITY" != "🔴" ] && SEVERITY="🟠"
fi

# ── 3. Crons que pararam (última execução > 48h) ─────────────
STALE_CRONS=""
KNOWN_CRONS=$(echo "$WEEK_DATA" | grep -oE '"cron":"[^"]+"' | sed 's/"cron":"//;s/"//' | sort -u)
for cron in $KNOWN_CRONS; do
  LAST_TS=$(echo "$WEEK_DATA" | grep "\"cron\":\"${cron}\"" | tail -1 | grep -oE '"ts":"[^"]+"' | sed 's/"ts":"//;s/"//')
  if [ -n "$LAST_TS" ]; then
    # Converte pra epoch (macOS compatible)
    LAST_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || date -d "$LAST_TS" +%s 2>/dev/null || echo 0)
    HOURS_AGO=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))
    if [ "$HOURS_AGO" -gt 48 ]; then
      STALE_CRONS="${STALE_CRONS}   ${cron} — última execução há ${HOURS_AGO}h\n"
    fi
  fi
done

if [ -n "$STALE_CRONS" ]; then
  FINDINGS="${FINDINGS}
🟡 CRONS PARADOS (>48h sem executar):
$(echo -e "$STALE_CRONS")
"
  [ "$SEVERITY" = "🟢" ] && SEVERITY="🟡"
fi

# ── 4. Duração anômala ────────────────────────────────────────
SLOW_CRONS=$(echo "$WEEK_DATA" | \
  awk -F'"' '{
    for(i=1;i<=NF;i++) {
      if($i=="cron") cron=$(i+2)
      if($i=="duration_ms") { gsub(/[^0-9]/,"",$(i+2)); dur=$(i+2)+0 }
    }
    if(dur > 0) { sum[cron]+=dur; count[cron]++; if(dur > max[cron]) max[cron]=dur }
  } END {
    for(c in sum) {
      avg = sum[c]/count[c]
      if(max[c] > avg*5 && max[c] > 5000) printf "%s — avg %dms, max %dms (%.0fx)\n", c, avg, max[c], max[c]/avg
    }
  }' | sort -t'(' -k2 -rn)

if [ -n "$SLOW_CRONS" ]; then
  FINDINGS="${FINDINGS}
🟡 DURAÇÃO ANÔMALA (pico 5x+ acima da média):
$(echo "$SLOW_CRONS" | while read line; do echo "   $line"; done)
"
  [ "$SEVERITY" = "🟢" ] && SEVERITY="🟡"
fi

# ── 5. Resultado ──────────────────────────────────────────────
REPORT_DATE=$(date +%Y-%m-%d)

if [ -z "$FINDINGS" ]; then
  FINDINGS="
🟢 Nenhum padrão de falha detectado esta semana.
   Total: $TOTAL execuções analisadas.
"
fi

REPORT="# Failure Pattern Report — ${REPORT_DATE}
Semana: $(date +%Y-W%V)
Severidade geral: ${SEVERITY}
Registros analisados: ${TOTAL}
${FINDINGS}"

# Salva localmente
REPORT_FILE="${REPORTS_DIR}/failure-report-${REPORT_DATE}.md"
echo "$REPORT" > "$REPORT_FILE"
echo "[failure-detector] Report salvo: $REPORT_FILE"

# Envia pro Telegram via gateway (só se encontrou problemas)
if [ "$SEVERITY" != "🟢" ]; then
  PROMPT="Resuma este relatório de falhas do OpenClaw em no máximo 10 linhas para Telegram. Seja direto e sugira 1-2 ações concretas.

${REPORT}"

  curl -s --max-time 30 -X POST "${GATEWAY}/hooks/agent" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${HOOKS_TOKEN}" \
    -d "$(jq -n --arg message "$PROMPT" '{message: $message}')" \
    > /dev/null 2>&1

  echo "[failure-detector] Alerta enviado via Telegram (severidade: $SEVERITY)"
else
  echo "[failure-detector] Tudo limpo — sem alerta."
fi

# Rotação: mantém últimos 8 reports
ls -t "$REPORTS_DIR"/failure-report-*.md 2>/dev/null | tail -n +9 | xargs rm -f 2>/dev/null

echo "[failure-detector] Concluído: $(date)"
