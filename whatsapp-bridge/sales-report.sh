#!/bin/bash
# Wolf WhatsApp Bridge — Sales Report Generator
# Gera relatórios de vendas (diário/semanal/quinzenal/mensal) a partir dos JSONL capturados
# Usa Haiku 4.5 para análise e formatação, envia via bridge API para grupo [VND]
#
# Uso: ./sales-report.sh [daily|weekly|biweekly|monthly]

set -euo pipefail

# ============================================================
# CONFIG
# ============================================================
BRIDGE_DIR="/Users/thomasgirotto/openclaw/whatsapp-bridge"
VND_GROUP_ID="557391484716-1615918812"
VND_GROUP_JID="${VND_GROUP_ID}@g.us"
GROUPS_DIR="$BRIDGE_DIR/groups/$VND_GROUP_ID"
SUMMARIES_DIR="$GROUPS_DIR/summaries"
ENV_FILE="/Users/thomasgirotto/.openclaw/.env"
BRIDGE_API="http://127.0.0.1:3002/send"
LOG_FILE="$BRIDGE_DIR/logs/sales-report.log"
REPORT_TYPE="${1:-daily}"
TODAY=$(TZ="America/Sao_Paulo" date +%Y-%m-%d)
WEEKDAY=$(TZ="America/Sao_Paulo" date +%u)  # 1=Mon, 7=Sun

mkdir -p "$SUMMARIES_DIR"

# ============================================================
# LOGGING
# ============================================================
log() {
  echo "[$(TZ='America/Sao_Paulo' date '+%Y-%m-%d %H:%M:%S')] [sales-report] $*" >> "$LOG_FILE"
}

# ============================================================
# LOAD API KEY
# ============================================================
ANTHROPIC_API_KEY=""
if [ -f "$ENV_FILE" ]; then
  ANTHROPIC_API_KEY=$(grep "^ANTHROPIC_API_KEY=" "$ENV_FILE" | cut -d= -f2 | tr -d ' \n\r')
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  log "ERRO: API key não encontrada em $ENV_FILE"
  exit 1
fi

# ============================================================
# DATE RANGE CALCULATION
# ============================================================
calc_date_range() {
  case "$REPORT_TYPE" in
    daily)
      DATE_FROM="$TODAY"
      DATE_TO="$TODAY"
      PERIOD_LABEL="$(TZ='America/Sao_Paulo' date '+%d/%m')"
      SUMMARY_FILE="$SUMMARIES_DIR/daily-${TODAY}.json"
      ;;
    weekly)
      # Last 7 days (Mon-Fri of current week)
      DATE_FROM=$(TZ="America/Sao_Paulo" date -v-6d +%Y-%m-%d)
      DATE_TO="$TODAY"
      WEEK_NUM=$(TZ="America/Sao_Paulo" date +%V)
      PERIOD_LABEL="Semana $WEEK_NUM ($(TZ='America/Sao_Paulo' date -v-6d '+%d/%m') a $(TZ='America/Sao_Paulo' date '+%d/%m'))"
      SUMMARY_FILE="$SUMMARIES_DIR/weekly-${TODAY}.json"
      ;;
    biweekly)
      # Last 15 days
      DATE_FROM=$(TZ="America/Sao_Paulo" date -v-14d +%Y-%m-%d)
      DATE_TO="$TODAY"
      PERIOD_LABEL="Quinzena $(TZ='America/Sao_Paulo' date -v-14d '+%d/%m') a $(TZ='America/Sao_Paulo' date '+%d/%m')"
      SUMMARY_FILE="$SUMMARIES_DIR/biweekly-${TODAY}.json"
      ;;
    monthly)
      # Full current month (or previous month if day 1)
      DAY_OF_MONTH=$(TZ="America/Sao_Paulo" date +%d)
      if [ "$DAY_OF_MONTH" = "01" ]; then
        # First of month: report on previous month
        DATE_FROM=$(TZ="America/Sao_Paulo" date -v-1m -v1d +%Y-%m-%d)
        DATE_TO=$(TZ="America/Sao_Paulo" date -v-1d +%Y-%m-%d)
        PERIOD_LABEL="$(TZ='America/Sao_Paulo' date -v-1m '+%B/%Y')"
      else
        # Mid-month: report on current month so far
        DATE_FROM=$(TZ="America/Sao_Paulo" date -v1d +%Y-%m-%d)
        DATE_TO="$TODAY"
        PERIOD_LABEL="$(TZ='America/Sao_Paulo' date '+%B/%Y') (parcial)"
      fi
      SUMMARY_FILE="$SUMMARIES_DIR/monthly-${TODAY}.json"
      ;;
    *)
      log "ERRO: Tipo inválido: $REPORT_TYPE (use daily|weekly|biweekly|monthly)"
      exit 1
      ;;
  esac
  log "Período: $DATE_FROM a $DATE_TO ($REPORT_TYPE)"
}

# ============================================================
# COLLECT MESSAGES FROM JSONL FILES
# ============================================================
collect_messages() {
  MESSAGES=""
  CURRENT="$DATE_FROM"
  while [[ "$CURRENT" < "$DATE_TO" || "$CURRENT" == "$DATE_TO" ]]; do
    FILE="$GROUPS_DIR/${CURRENT}.jsonl"
    if [ -f "$FILE" ]; then
      CONTENT=$(cat "$FILE")
      MESSAGES="${MESSAGES}${CONTENT}
"
    fi
    CURRENT=$(TZ="America/Sao_Paulo" date -j -f "%Y-%m-%d" "$CURRENT" -v+1d +%Y-%m-%d)
  done

  # Count messages
  MSG_COUNT=$(echo "$MESSAGES" | grep -c '^{' || echo "0")
  log "Coletadas $MSG_COUNT mensagens de $DATE_FROM a $DATE_TO"

  if [ "$MSG_COUNT" -eq 0 ]; then
    log "Nenhuma mensagem encontrada no período"
    echo ""
    return
  fi

  echo "$MESSAGES"
}

# ============================================================
# LOAD DAILY SUMMARIES (for weekly/biweekly/monthly aggregation)
# ============================================================
load_daily_summaries() {
  SUMMARIES_TEXT=""
  CURRENT="$DATE_FROM"
  while [[ "$CURRENT" < "$DATE_TO" || "$CURRENT" == "$DATE_TO" ]]; do
    SFILE="$SUMMARIES_DIR/daily-${CURRENT}.json"
    if [ -f "$SFILE" ]; then
      SUMMARIES_TEXT="${SUMMARIES_TEXT}
--- Resumo de ${CURRENT} ---
$(cat "$SFILE")
"
    fi
    CURRENT=$(TZ="America/Sao_Paulo" date -j -f "%Y-%m-%d" "$CURRENT" -v+1d +%Y-%m-%d)
  done
  echo "$SUMMARIES_TEXT"
}

# ============================================================
# CALL HAIKU TO GENERATE REPORT
# ============================================================
generate_report() {
  local RAW_DATA="$1"
  local SUMMARIES_DATA="${2:-}"

  # Build prompt based on report type
  local PERIOD_DESC=""
  local TEMPLATE_INSTRUCTION=""

  case "$REPORT_TYPE" in
    daily)
      PERIOD_DESC="DIÁRIO de $PERIOD_LABEL"
      TEMPLATE_INSTRUCTION='Use EXATAMENTE este template para o relatório diário:

📊 *RELATÓRIO DE FATURAMENTO* — DD/MM

━━━━━━━━━━━━━━

🗂️ *VENDAS DO DIA*

Para cada venda:
• NomeCliente
DescriçãoServiço
💰 Valor: R$ X.XXX,00
💵 Pago: R$ X.XXX,00 (XX%)
👤 Vendedor: Nome
💳 Conta: ContaPagamento
📍 Origem: OrigemVenda

━━━━━━━━━━━━━━

💰 *RESUMO DO DIA*

💵 Entrada hoje: R$ X.XXX,00
📦 Vendas realizadas: N
⏳ Valor pendente: R$ X.XXX,00

━━━━━━━━━━━━━━

📈 *ACUMULADO DO MÊS*

💰 Total negociado: R$ X.XXX,00
💵 Total recebido: R$ X.XXX,00

👥 Ranking de vendedores
🥇 Nome → R$ X.XXX
🥈 Nome → R$ X.XXX
🥉 Nome → R$ X.XXX

━━━━━━━━━━━━━━

🎯 *PROGRESSO DA META*

Meta do mês: R$ 30.000
Realizado: R$ X.XXX
📊 Progresso: XX,X% da meta

━━━━━━━━━━━━━━

⚠️ *PENDÊNCIAS*

• Cliente → R$ X.XXX,00 restante

━━━━━━━━━━━━━━

_Relatório atualizado até DD/MM._'
      ;;
    weekly)
      PERIOD_DESC="SEMANAL — $PERIOD_LABEL"
      TEMPLATE_INSTRUCTION='Gere um RESUMO SEMANAL consolidado com:
📊 *RESUMO SEMANAL DE FATURAMENTO* — Semana DD/MM a DD/MM
- Total de vendas da semana (quantidade e valor)
- Comparativo dia a dia (tabela simples)
- Ranking de vendedores da semana
- Clientes novos vs recorrentes
- Progresso da meta mensal
- Pendências acumuladas
- Destaques e observações
Use emojis e formatação WhatsApp (*negrito*, _itálico_).'
      ;;
    biweekly)
      PERIOD_DESC="QUINZENAL — $PERIOD_LABEL"
      TEMPLATE_INSTRUCTION='Gere um RESUMO QUINZENAL consolidado com:
📊 *RESUMO QUINZENAL DE FATURAMENTO* — DD/MM a DD/MM
- Total de vendas (quantidade e valor)
- Comparativo semana 1 vs semana 2
- Ranking de vendedores
- Análise de tendência (subindo/descendo?)
- Ticket médio
- Progresso da meta mensal
- Top 3 maiores vendas do período
- Pendências acumuladas
Use emojis e formatação WhatsApp (*negrito*, _itálico_).'
      ;;
    monthly)
      PERIOD_DESC="MENSAL — $PERIOD_LABEL"
      TEMPLATE_INSTRUCTION='Gere um RELATÓRIO MENSAL COMPLETO com:
📊 *RELATÓRIO MENSAL DE FATURAMENTO* — Mês/Ano
- Total faturado no mês
- Comparativo com meta (R$ 30.000)
- Ranking completo de vendedores com valores
- Semana a semana (performance)
- Ticket médio
- Top 5 maiores vendas
- Análise: clientes novos vs recorrentes
- Origens de venda (tráfego, indicação, casa)
- Contas de recebimento (CNPJ Mariana, MP Netto, etc.)
- Pendências totais
- Recomendações para próximo mês
Use emojis e formatação WhatsApp (*negrito*, _itálico_).'
      ;;
  esac

  # Build context with summaries if available
  local CONTEXT=""
  if [ -n "$SUMMARIES_DATA" ]; then
    CONTEXT="

RESUMOS DIÁRIOS JÁ GERADOS (use para consolidar):
$SUMMARIES_DATA"
  fi

  # Call Haiku
  local PROMPT="Você é o Alfred, assistente da Wolf Agency. Analise as mensagens do grupo de vendas e gere o relatório $PERIOD_DESC.

REGRAS:
1. Extraia TODAS as vendas das mensagens (campos: DATA, VENDEDOR, NOME DO GRUPO/cliente, DESCRIÇÃO, VALOR TOTAL, PAGAMENTO, CONTA, ORIGEM)
2. $TEMPLATE_INSTRUCTION
3. Se uma venda aparece com pagamento parcial (ex: 50%), calcule o valor pago e o pendente
4. NÃO invente dados — use APENAS o que está nas mensagens
5. Se não houver vendas no período, informe com o template vazio
6. Meta do mês: R\$ 30.000
7. Use formatação WhatsApp: *negrito* para títulos, _itálico_ para notas
$CONTEXT

MENSAGENS DO GRUPO [VND] - Vendas + Recebimentos ($DATE_FROM a $DATE_TO):

$RAW_DATA"

  # Truncate if too long (Haiku context ~200K but be safe)
  if [ ${#PROMPT} -gt 100000 ]; then
    PROMPT="${PROMPT:0:100000}

[... truncado por tamanho ...]"
  fi

  # Save prompt to temp file and call API via Python
  local PROMPT_FILE="/tmp/wolf-sales-prompt-$$.txt"
  local RESPONSE_FILE="/tmp/wolf-sales-response-$$.txt"
  echo "$PROMPT" > "$PROMPT_FILE"

  python3 - "$PROMPT_FILE" "$RESPONSE_FILE" "$ANTHROPIC_API_KEY" <<'PYEOF'
import json, sys, urllib.request, urllib.error

prompt_file = sys.argv[1]
response_file = sys.argv[2]
api_key = sys.argv[3]

with open(prompt_file) as f:
    prompt = f.read()

body = json.dumps({
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 4096,
    "messages": [{"role": "user", "content": prompt}]
}).encode()

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=body,
    headers={
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
)

try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read())
        if "content" in data and len(data["content"]) > 0:
            with open(response_file, "w") as f:
                f.write(data["content"][0]["text"])
        else:
            print("ERRO: resposta sem content", file=sys.stderr)
            sys.exit(1)
except urllib.error.HTTPError as e:
    error_body = e.read().decode()
    print(f"ERRO API ({e.code}): {error_body}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERRO: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

  local EXIT_CODE=$?
  rm -f "$PROMPT_FILE"

  if [ $EXIT_CODE -ne 0 ]; then
    log "ERRO ao chamar API Haiku"
    rm -f "$RESPONSE_FILE"
    return 1
  fi

  local REPORT
  REPORT=$(cat "$RESPONSE_FILE")
  rm -f "$RESPONSE_FILE"
  echo "$REPORT"
}

# ============================================================
# SAVE SUMMARY
# ============================================================
save_summary() {
  local REPORT="$1"
  local REPORT_TMP="/tmp/wolf-sales-summary-$$.txt"
  echo "$REPORT" > "$REPORT_TMP"
  python3 - "$REPORT_TMP" "$SUMMARY_FILE" "$REPORT_TYPE" "$TODAY" "$DATE_FROM" "$DATE_TO" "$PERIOD_LABEL" <<'PYEOF'
import json, sys
from datetime import datetime

report_file, summary_file, rtype, today, date_from, date_to, period_label = sys.argv[1:8]
with open(report_file) as f:
    report_text = f.read()

summary = {
    "type": rtype,
    "date": today,
    "period": f"{date_from} to {date_to}",
    "period_label": period_label,
    "report": report_text,
    "generated_at": datetime.now().isoformat()
}
with open(summary_file, "w") as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)
PYEOF
  rm -f "$REPORT_TMP"
  log "Resumo salvo: $SUMMARY_FILE"
}

# ============================================================
# SEND TO WHATSAPP GROUP
# ============================================================
send_to_group() {
  local TEXT="$1"

  # Check bridge is running
  local HEALTH
  HEALTH=$(curl -s --max-time 5 http://127.0.0.1:3002/health 2>/dev/null || echo "")
  if [ -z "$HEALTH" ]; then
    log "ERRO: Bridge não está respondendo"
    return 1
  fi

  # Send via bridge API
  local PAYLOAD_FILE="/tmp/wolf-sales-send-$$.json"
  python3 -c "
import json, sys
text = sys.stdin.read()
with open('$PAYLOAD_FILE', 'w') as f:
    json.dump({'to': '$VND_GROUP_JID', 'text': text}, f, ensure_ascii=False)
" <<< "$TEXT"

  local RESULT
  RESULT=$(curl -s --max-time 30 "$BRIDGE_API" \
    -H "Content-Type: application/json" \
    -d @"$PAYLOAD_FILE")
  rm -f "$PAYLOAD_FILE"

  local OK=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "False")

  if [ "$OK" = "True" ]; then
    log "Relatório enviado para grupo [VND]"
    return 0
  else
    log "ERRO ao enviar: $RESULT"
    return 1
  fi
}

# ============================================================
# MAIN
# ============================================================
main() {
  log "=== Início: relatório $REPORT_TYPE ==="

  # Skip weekends for daily reports
  if [ "$REPORT_TYPE" = "daily" ] && [ "$WEEKDAY" -gt 5 ]; then
    log "Fim de semana — pulando relatório diário"
    exit 0
  fi

  # Calculate date range
  calc_date_range

  # Collect raw messages
  RAW=$(collect_messages)
  if [ -z "$RAW" ]; then
    log "Sem mensagens — pulando"
    exit 0
  fi

  # For weekly/biweekly/monthly: also load daily summaries
  DAILY_SUMMARIES=""
  if [ "$REPORT_TYPE" != "daily" ]; then
    DAILY_SUMMARIES=$(load_daily_summaries)
  fi

  # Generate report via Haiku
  REPORT=$(generate_report "$RAW" "$DAILY_SUMMARIES")
  if [ -z "$REPORT" ]; then
    log "ERRO: relatório vazio"
    exit 1
  fi

  # Save summary locally
  save_summary "$REPORT"

  # Send to WhatsApp group
  send_to_group "$REPORT"

  log "=== Concluído: $REPORT_TYPE ==="
}

main
