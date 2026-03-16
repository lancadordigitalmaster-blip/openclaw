#!/bin/bash
# modo-sono.sh — Rotina de fechamento diário autônomo
# Cron: 30 0 * * * (00:30 diário)
# Verifica changelog do dia, gera relatório via LLM, notifica Telegram
set -uo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
CHANGELOG_DIR="$WORKSPACE/changelogs"
DATE=$(date '+%Y-%m-%d')
CHANGELOG="$CHANGELOG_DIR/$DATE.md"
LOG="$CHANGELOG_DIR/modo-sono.log"
ENV_FILE="$HOME/.openclaw/.env"
GATEWAY_URL="http://127.0.0.1:18789"
TS=$(date '+%Y-%m-%d %H:%M:%S')

SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true
GATEWAY_TOKEN=$(grep '^GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

log() { echo "[$TS] $1" >> "$LOG"; }

# Verificar se changelog existe
if [[ ! -f "$CHANGELOG" ]]; then
  # Gerar changelog minimo baseado em git log e logs do dia
  {
    echo "# Changelog — $DATE"
    echo ""
    echo "## Atividades do dia"
    echo ""
    # Git activity
    cd "$WORKSPACE" 2>/dev/null
    GIT_LOG=$(git log --since="$DATE 00:00" --until="$DATE 23:59" --oneline 2>/dev/null | head -10)
    if [[ -n "$GIT_LOG" ]]; then
      echo "### Commits"
      echo "$GIT_LOG" | while read -r line; do echo "- $line"; done
    else
      echo "- Sem commits no repositório hoje"
    fi
    echo ""
    # Cron executions
    echo "### Crons executados"
    CRON_COUNT=$(find "$HOME/.openclaw/logs" -name "*.log" -newer /tmp/.modo-sono-marker 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo "- $CRON_COUNT logs atualizados hoje"
    echo ""
    echo "## AVALIACAO FINAL"
    echo "(pendente — será preenchida pelo modo-sono)"
  } > "$CHANGELOG"
  log "Changelog gerado automaticamente: $CHANGELOG"
fi

# Verificar se já foi fechado
if grep -q "Nota de saude:" "$CHANGELOG" 2>/dev/null; then
  log "Changelog já fechado — STOP"
  exit 0
fi

# Gerar avaliação via LLM (gateway/hooks)
CONTEUDO=$(cat "$CHANGELOG")

PROMPT="Você é o modo-sono do Alfred (Wolf Agency). Analise o changelog do dia e gere uma avaliação final.

CHANGELOG:
$CONTEUDO

Gere exatamente isso:
1. Resumo executivo (3-5 linhas)
2. Nota de saude: X/10 (ESTAVEL|ATENCAO|CRITICO)
3. Top 3 prioridades para amanhã
4. Frase de fechamento (técnica, honesta, 1 linha)

Seja direto. Máximo 200 palavras."

if [[ -n "$GATEWAY_TOKEN" ]]; then
  RESPOSTA=$(curl -s -X POST "$GATEWAY_URL/hooks/agent" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"message\": $(echo "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
      \"name\": \"ModoSono\",
      \"model\": \"claude-haiku-4-5\",
      \"deliver\": false,
      \"timeoutSeconds\": 120
    }" 2>/dev/null)

  ANALISE=$(echo "$RESPOSTA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
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
        print('Erro ao parsear resposta')
except Exception as e:
    print(f'Erro: {e}')
" 2>/dev/null)
else
  ANALISE="Gateway não disponível — avaliação manual necessária"
fi

# Escrever avaliação no changelog
{
  echo ""
  echo "---"
  echo "### Avaliação Final (Modo Sono — $TS)"
  echo ""
  echo "$ANALISE"
} >> "$CHANGELOG"

log "Avaliação escrita no changelog"

# Notificar Telegram
NOTA=$(echo "$ANALISE" | grep -oE '[0-9]+/10' | head -1)
RESUMO=$(echo "$ANALISE" | head -3 | tr '\n' ' ')
MSG="🌙 *Modo Sono — $DATE*
${RESUMO:0:200}
Nota: ${NOTA:-?/10}
_Wolf Modo Sono · 00h30_"

wolf_notify "$MSG"
log "Notificação enviada"

# Criar marker para próximo dia
touch /tmp/.modo-sono-marker

exit 0
