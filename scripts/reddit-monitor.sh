#!/bin/bash
# reddit-monitor.sh — Monitora subreddits e envia relatório diário via Telegram
# Uso: ./reddit-monitor.sh [CHAT_ID]
# Cron: rodar 1x/dia (ex: 09:00 BRT)

set -euo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

CHAT_IDS=("${TELEGRAM_CHAT_ID:-789352357}" "7073601150")
BOT_TOKEN=""
ANTHROPIC_API_KEY=""

# Carregar env
if [ -f /Users/thomasgirotto/.openclaw/.env ]; then
  source /Users/thomasgirotto/.openclaw/.env
fi
if [ -f /Users/thomasgirotto/openclaw/whatsapp-bridge/.env ]; then
  source /Users/thomasgirotto/openclaw/whatsapp-bridge/.env
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$BOT_TOKEN}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "ERRO: TELEGRAM_BOT_TOKEN ou ANTHROPIC_API_KEY não encontrados"
  exit 1
fi

LOG="/Users/thomasgirotto/.openclaw/workspace/memory/logs/reddit-monitor.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "Iniciando monitoramento Reddit"

# ── Subreddits para monitorar
SUBREDDITS=(
  "codex"
  "openclaw"
  "vibecoding"
  "ClaudeCode"
  "claude"
)

# ── Buscar posts das últimas 24h de cada subreddit
COMBINED_POSTS=""

for SUB in "${SUBREDDITS[@]}"; do
  log "Buscando r/$SUB..."

  RESPONSE=$(curl -s -A "Mozilla/5.0 (reddit-monitor/1.0)" \
    "https://www.reddit.com/r/${SUB}/new.json?limit=15&t=day" 2>/dev/null || echo "")

  if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"error"'; then
    log "WARN: Falha ao buscar r/$SUB"
    continue
  fi

  # Extrair posts (título, score, url, selftext resumido)
  POSTS=$(echo "$RESPONSE" | python3 -c "
import json, sys, time
try:
    data = json.load(sys.stdin)
    posts = data.get('data', {}).get('children', [])
    now = time.time()
    day_ago = now - 86400
    results = []
    for p in posts:
        d = p.get('data', {})
        created = d.get('created_utc', 0)
        if created < day_ago:
            continue
        title = d.get('title', '')[:120]
        score = d.get('score', 0)
        num_comments = d.get('num_comments', 0)
        selftext = d.get('selftext', '')[:300]
        url = d.get('url', '')
        permalink = 'https://reddit.com' + d.get('permalink', '')
        results.append(f'- [{score}pts|{num_comments}c] {title}')
        if selftext.strip():
            results.append(f'  {selftext[:200]}')
        results.append(f'  {permalink}')
    print('\n'.join(results))
except Exception as e:
    print(f'ERRO: {e}', file=sys.stderr)
" 2>/dev/null || echo "")

  if [ -n "$POSTS" ]; then
    COMBINED_POSTS="${COMBINED_POSTS}

## r/${SUB}
${POSTS}"
  fi

  # Rate limit do Reddit
  sleep 2
done

if [ -z "$COMBINED_POSTS" ]; then
  log "Nenhum post encontrado nas últimas 24h"
  # Silencioso quando nao ha novidades
  wolf_log "reddit" "Sem novidades relevantes nas ultimas 24h"
  exit 0
fi

log "Posts coletados, enviando para análise LLM..."

# ── Análise com Claude Haiku
PROMPT="Você é um analista de tecnologia da Wolf Agency (agência de marketing digital).

Analise os posts abaixo dos subreddits de IA/coding e gere um relatório conciso para Telegram.

FORMATO DO RELATÓRIO:
📡 *Reddit Daily Report*
📅 $(date '+%d/%m/%Y')

Para cada novidade relevante:
🔹 *[Título/Tema]*
Resumo: o que é e por que importa
💡 *Caso de uso:* como a Wolf Agency pode usar isso (automação, produção de conteúdo, propostas, atendimento, etc)
🔗 Link

Se houver algo MUITO importante (novo modelo, ferramenta game-changer, breaking change):
🚨 *DESTAQUE:* [explicação]

No final:
📊 *Resumo:* X novidades analisadas | Subreddits: r/codex, r/openclaw, r/vibecoding, r/ClaudeCode, r/claude

REGRAS:
- Máximo 10 itens mais relevantes (priorizar por impacto prático)
- Ignorar memes, reclamações genéricas, posts sem substância
- Focar em: novos modelos, ferramentas, técnicas, integrações, bugs conhecidos
- Texto em português BR
- Usar negrito com asterisco para Telegram (*texto*)
- Manter conciso — cada item max 3 linhas

POSTS DAS ÚLTIMAS 24H:
${COMBINED_POSTS}"

# Escapar o prompt para JSON
ESCAPED_PROMPT=$(python3 -c "
import json, sys
print(json.dumps(sys.stdin.read()))
" <<< "$PROMPT")

ANALYSIS=$(curl -s "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "{
    \"model\": \"claude-haiku-4-5-20251001\",
    \"max_tokens\": 2000,
    \"messages\": [{\"role\": \"user\", \"content\": ${ESCAPED_PROMPT}}]
  }" 2>/dev/null)

REPORT=$(echo "$ANALYSIS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data.get('content', [{}])[0].get('text', '')
    print(text)
except:
    print('Erro ao processar análise')
" 2>/dev/null)

if [ -z "$REPORT" ] || [ "$REPORT" = "Erro ao processar análise" ]; then
  log "ERRO: Falha na análise LLM"
  REPORT="📡 *Reddit Daily Report* — $(date '+%d/%m/%Y')

⚠️ Erro na análise automática. Posts coletados mas LLM falhou.

Subreddits monitorados: r/codex, r/openclaw, r/vibecoding, r/ClaudeCode, r/claude"
fi

log "Relatório gerado, enviando via WhatsApp..."

# Reddit roda 01:00 BRT — notificação movida para log (ninguém lê 1h da manhã)
wolf_log "reddit-monitor" "$REPORT"
log "Relatório registrado em log (sem notificação noturna)"
echo "OK — Relatório enviado"
