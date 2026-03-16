#!/bin/bash
# =============================================================================
# WOLF — Auditoria Técnica Semanal
# Roda: Sábado 10h00 (sem conflito com nenhum cron existente)
# Modelo: Haiku 4.5 via /hooks/agent
# Cobre: npm audit completo, análise de logs da semana, padrões de erro,
#         dependências Python, crons fantasma, relatório consolidado
# Autor: Wolf Agency / Claude — Março 2026
# =============================================================================

set -uo pipefail

SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y-%m-%d')
SEMANA=$(date '+%Y-W%V')
LOG="$HOME/.openclaw/logs/audit-semanal.log"
ENV_FILE="$HOME/.openclaw/.env"
GATEWAY_URL="http://127.0.0.1:18789"
TMP_DIR="/tmp/wolf-audit-semanal"
RELATORIO="$TMP_DIR/relatorio-$DATE.txt"

# Carregar tokens
GATEWAY_TOKEN=$(grep '^GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
TELEGRAM_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
TELEGRAM_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

if [[ -z "$TELEGRAM_TOKEN" ]]; then
  TELEGRAM_TOKEN=$(grep '^TELEGRAM_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
fi
if [[ -z "$TELEGRAM_CHAT" ]]; then
  TELEGRAM_CHAT=$(grep '^TELEGRAM_GROUP_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
fi

mkdir -p "$TMP_DIR"

log() {
  echo "[$TIMESTAMP] $1" >> "$LOG"
  echo "$1" >> "$RELATORIO"
}


log "=== Auditoria Técnica Semanal — $SEMANA ==="
log ""

# =============================================================================
# COLETA 1 — npm audit completo (WhatsApp Bridge)
# =============================================================================
log "## npm audit — WhatsApp Bridge"
WA_DIR="$HOME/openclaw/whatsapp-bridge"
NPM_RESULTADO="sem package.json encontrado"

if [[ -d "$WA_DIR" && -f "$WA_DIR/package.json" ]]; then
  NPM_RESULTADO=$(cd "$WA_DIR" && npm audit 2>&1 | tail -20)
fi
log "$NPM_RESULTADO"
log ""

# =============================================================================
# COLETA 2 — pip outdated completo
# =============================================================================
log "## pip outdated — Scripts Python"
VENV_PIP="$HOME/.openclaw/workspace/scripts/.venv/bin/pip"
PIP_RESULTADO="venv não encontrado"

if [[ -f "$VENV_PIP" ]]; then
  PIP_RESULTADO=$("$VENV_PIP" list --outdated 2>/dev/null || echo "erro ao executar pip list")
fi
log "$PIP_RESULTADO"
log ""

# =============================================================================
# COLETA 3 — Padrões de erro na semana (gateway.log)
# =============================================================================
log "## Erros recorrentes — gateway.log (últimos 7 dias)"
GATEWAY_ERROS=$(find "$HOME/.openclaw/logs" -name "gateway*.log*" -mtime -7 2>/dev/null | \
  xargs zcat -f 2>/dev/null | \
  grep -iE "error|warn|fail|exception|timeout" | \
  grep -oE '\[.*?\].*' | \
  sort | uniq -c | sort -rn | head -20)
log "${GATEWAY_ERROS:-nenhum erro encontrado}"
log ""

# =============================================================================
# COLETA 4 — Crons que não rodaram na semana (fantasmas)
# Compara o que está no crontab vs o que apareceu nos logs
# =============================================================================
log "## Crons sem execução na semana"
SCRIPTS_SEM_LOG=()
SCRIPTS_DIR="$HOME/.openclaw/workspace/scripts"

# Pegar scripts referenciados no crontab
SCRIPTS_NO_CRON=$(crontab -l 2>/dev/null | grep -oE 'scripts/[a-z_-]+\.sh' | sort -u)

while IFS= read -r script; do
  NOME=$(basename "$script" .sh)
  # Verificar se apareceu em algum log nos últimos 7 dias (ambos dirs de logs)
  APARECEU=$(find "$HOME/.openclaw/logs" "$HOME/.openclaw/workspace/memory/logs" -name "*.log" -mtime -7 2>/dev/null | \
    xargs grep -l "$NOME" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$APARECEU" -eq 0 ]]; then
    SCRIPTS_SEM_LOG+=("$script")
  fi
done <<< "$SCRIPTS_NO_CRON"

if [[ ${#SCRIPTS_SEM_LOG[@]} -gt 0 ]]; then
  log "Scripts sem registro de execução esta semana:"
  for s in "${SCRIPTS_SEM_LOG[@]}"; do
    log "  - $s"
  done
else
  log "Todos os scripts com registro de execução"
fi
log ""

# =============================================================================
# COLETA 5 — Tamanho dos logs (crescimento semanal)
# =============================================================================
log "## Crescimento de logs"
find "$HOME/.openclaw/logs" -name "*.log" -o -name "*.jsonl" 2>/dev/null | \
  xargs du -h 2>/dev/null | sort -rh | head -10 >> "$RELATORIO"
log ""

# =============================================================================
# COLETA 6 — Versão do OpenClaw vs disponível
# =============================================================================
log "## Versão OpenClaw"
VERSAO_ATUAL=$(/opt/homebrew/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/index.js --version 2>/dev/null || echo "não obtido")
VERSAO_LOG=$(grep "update available" "$HOME/.openclaw/logs/gateway.log" 2>/dev/null | tail -1)
log "Atual: $VERSAO_ATUAL"
log "Log: ${VERSAO_LOG:-sem update disponível}"
log ""

# =============================================================================
# ENVIAR PARA ANÁLISE DO HAIKU via /hooks/agent
# =============================================================================
CONTEUDO_RELATORIO=$(cat "$RELATORIO")

PROMPT="Você é o agente técnico do Wolf Agency. Analise o relatório de auditoria semanal abaixo e gere um resumo estruturado para o Telegram.

RELATÓRIO:
$CONTEUDO_RELATORIO

Gere uma mensagem formatada para Telegram com:
1. Classificação dos problemas encontrados: 🔴 CRÍTICO | 🟠 ALTO | 🟡 MÉDIO | 🟢 OK
2. Top 3 ações prioritárias para a semana (específicas e acionáveis)
3. Uma frase de status geral do sistema

Use Markdown simples (sem tabelas). Seja direto e objetivo. Máximo 300 palavras."

# Chamar Haiku via gateway
if [[ -n "$GATEWAY_TOKEN" ]]; then
  RESPOSTA=$(curl -s -X POST "$GATEWAY_URL/hooks/agent" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"message\": $(echo "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
      \"name\": \"AuditoriaSemanal\",
      \"model\": \"claude-haiku-4-5\",
      \"deliver\": false,
      \"timeoutSeconds\": 120
    }" 2>/dev/null)

  # Extrair texto da resposta
  ANALISE=$(echo "$RESPOSTA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Tentar diferentes estruturas de resposta do OpenClaw
    if 'content' in d:
        for block in d['content']:
            if block.get('type') == 'text':
                print(block['text'])
                break
    elif 'text' in d:
        print(d['text'])
    elif 'message' in d:
        print(d['message'])
    else:
        print('Erro ao parsear resposta do gateway')
except Exception as e:
    print(f'Erro: {e}')
" 2>/dev/null)
else
  ANALISE="⚠️ GATEWAY_TOKEN não configurado — análise LLM indisponível"
fi

log "Análise Haiku gerada"

# =============================================================================
# ENVIAR RESULTADO
# =============================================================================
MSG="📊 *Auditoria Técnica Semanal — $SEMANA*"
MSG+="\n\n$ANALISE"
MSG+="\n\n_Wolf Audit System · Haiku 4.5 · Sábado 10h_"

wolf_notify "$MSG"
log "Notificação semanal enviada"

# Limpar tmp antigos (>30 dias)
find "$TMP_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null

exit 0
