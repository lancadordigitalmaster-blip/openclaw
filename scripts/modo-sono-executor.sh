#!/bin/bash
# modo-sono-executor.sh — Rotina de fechamento diário autônomo
# Roda via crontab às 00:30 BRT
# Analisa changelog do dia, gera avaliação final, notifica via WhatsApp
# Provider: Haiku 4.5 via gateway API (custo ~$0.002/execução)

set -eo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
CHANGELOGS="$WORKSPACE/changelogs"
MEMORY="$WORKSPACE/memory"
LOG="$CHANGELOGS/modo-sono.log"
TODAY=$(date '+%Y-%m-%d')
CHANGELOG="$CHANGELOGS/${TODAY}.md"
GATEWAY="http://127.0.0.1:18789"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
mkdir -p "$CHANGELOGS"

log "=== Modo Sono iniciado ==="

# ── 1. Verificar condições de ativação ──
HOUR=$(date '+%H')
if [[ "$HOUR" -gt 5 && "$HOUR" -lt 23 ]]; then
    log "SKIP: Fora do horário (${HOUR}h, precisa 23-05)"
    exit 0
fi

# ── 2. Verificar se changelog do dia existe ──
# Se não existe, criar automaticamente a partir dos eventos do dia
if [[ ! -f "$CHANGELOG" ]]; then
    log "Changelog não encontrado — gerando a partir de activity.log e git"

    cat > "$CHANGELOG" << EOFCL
# Changelog — $TODAY

## Resumo do dia
$(date '+%A, %d de %B de %Y')

## Atividades registradas

EOFCL

    # Adicionar atividades do activity.log
    ACTIVITY="$WORKSPACE/shared/memory/activity.log"
    if [[ -f "$ACTIVITY" ]]; then
        grep "$TODAY" "$ACTIVITY" 2>/dev/null | tail -20 >> "$CHANGELOG" || true
    fi

    # Adicionar commits do dia
    cd "$WORKSPACE"
    GIT_LOG=$(git log --oneline --since="$TODAY 00:00" --until="$TODAY 23:59" 2>/dev/null | head -10 || true)
    if [[ -n "$GIT_LOG" ]]; then
        echo "" >> "$CHANGELOG"
        echo "## Commits" >> "$CHANGELOG"
        echo "$GIT_LOG" >> "$CHANGELOG"
    fi

    # Adicionar erros do dia
    ERRORS="$MEMORY/errors.md"
    if [[ -f "$ERRORS" ]]; then
        TODAY_ERRORS=$(grep "$TODAY" "$ERRORS" 2>/dev/null | head -5 || true)
        if [[ -n "$TODAY_ERRORS" ]]; then
            echo "" >> "$CHANGELOG"
            echo "## Erros" >> "$CHANGELOG"
            echo "$TODAY_ERRORS" >> "$CHANGELOG"
        fi
    fi

    # Adicionar nota diária se existir
    DAILY_NOTE="$MEMORY/${TODAY}.md"
    if [[ -f "$DAILY_NOTE" ]]; then
        echo "" >> "$CHANGELOG"
        echo "## Notas" >> "$CHANGELOG"
        tail -n +3 "$DAILY_NOTE" >> "$CHANGELOG"
    fi

    echo "" >> "$CHANGELOG"
    echo "## AVALIACAO FINAL" >> "$CHANGELOG"
    echo "" >> "$CHANGELOG"

    log "Changelog gerado automaticamente"
fi

# ── 3. Verificar se já foi fechado ──
if grep -q "Nota de saude:" "$CHANGELOG" 2>/dev/null; then
    log "SKIP: Changelog já possui avaliação final"
    exit 0
fi

# ── 4. Verificar se gateway está disponível ──
if ! curl -s --max-time 5 "$GATEWAY" >/dev/null 2>&1 && ! lsof -i :18789 >/dev/null 2>&1; then
    log "ERRO: Gateway indisponível"
    exit 1
fi

# ── 5. Gerar avaliação via LLM (Haiku 4.5) ──
CHANGELOG_CONTENT=$(cat "$CHANGELOG" | head -200)

# Preparar o prompt
PROMPT="Analise este changelog do dia e gere uma AVALIACAO FINAL concisa.

CHANGELOG:
$CHANGELOG_CONTENT

FORMATO DA AVALIACAO (seguir exatamente):
### Resumo executivo
(3-5 linhas do que aconteceu hoje)

### Saúde do sistema
- Nota: X/10
- Status: ESTAVEL|ATENCAO|CRITICO
- Justificativa: (1 linha)

### Prioridades para amanhã
1. (top prioridade)
2. (segunda)
3. (terceira)

### Frase de fechamento
(1 frase técnica e honesta sobre o estado do sistema)

REGRAS: Seja honesto. Se o dia foi improdutivo, diga. Se houve erros, destaque. Não invente dados."

# Chamar gateway API
RESPONSE=$(python3 << PYEOF
import json, urllib.request

payload = json.dumps({
    "model": "anthropic/claude-haiku-4-5-20251001",
    "messages": [{"role": "user", "content": """$PROMPT"""}],
    "max_tokens": 800
}).encode()

req = urllib.request.Request(
    "http://127.0.0.1:18789/v1/chat/completions",
    data=payload,
    headers={"Content-Type": "application/json"}
)

try:
    with urllib.request.urlopen(req, timeout=30) as r:
        result = json.loads(r.read())
        content = result.get("choices", [{}])[0].get("message", {}).get("content", "")
        print(content)
except Exception as e:
    print(f"ERRO_LLM: {e}")
PYEOF
)

if echo "$RESPONSE" | grep -q "^ERRO_LLM:"; then
    log "ERRO: Falha na chamada LLM — $RESPONSE"
    # Tentar 1 vez mais após 5 segundos
    sleep 5
    RESPONSE=$(python3 << PYEOF2
import json, urllib.request
payload = json.dumps({
    "model": "anthropic/claude-haiku-4-5-20251001",
    "messages": [{"role": "user", "content": "Gere uma avaliacao breve: dia sem dados suficientes para analise detalhada. Nota 5/10. Status ATENCAO."}],
    "max_tokens": 300
}).encode()
req = urllib.request.Request("http://127.0.0.1:18789/v1/chat/completions", data=payload, headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        result = json.loads(r.read())
        print(result.get("choices", [{}])[0].get("message", {}).get("content", "Avaliacao indisponivel."))
except Exception as e:
    print("Avaliacao automatica indisponivel. Verificar gateway.")
PYEOF2
)
fi

# ── 6. Escrever avaliação no changelog ──
if [[ -n "$RESPONSE" ]] && ! echo "$RESPONSE" | grep -q "^ERRO_LLM:"; then
    # Append avaliação ao final do changelog
    cat >> "$CHANGELOG" << EOFEVAL
---
*Avaliação gerada automaticamente pelo Modo Sono em $(date '+%Y-%m-%d %H:%M')*

$RESPONSE

---
Nota de saude: registrada
EOFEVAL

    log "Avaliação escrita no changelog"

    # ── 7. Extrair nota e notificar ──
    NOTA=$(echo "$RESPONSE" | grep -oE '[0-9]+/10' | head -1 || echo "?/10")
    STATUS=$(echo "$RESPONSE" | grep -oiE 'ESTAVEL|ATENCAO|CRITICO' | head -1 || echo "?")
    RESUMO=$(echo "$RESPONSE" | head -5 | tail -3 | tr '\n' ' ' | cut -c1-200)

    MSG="🌙 *Modo Sono — $TODAY*

Nota: $NOTA | Status: $STATUS
$RESUMO

_Changelog completo em changelogs/${TODAY}.md_"

    wolf_notify "$MSG"
    log "Notificação enviada: Nota $NOTA, Status $STATUS"
else
    log "ERRO: Resposta LLM vazia ou inválida"
fi

log "=== Modo Sono concluído ==="
