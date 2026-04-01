#!/bin/bash
# auto-avaliacao.sh — Auto-avaliacao diaria do sistema (7h BRT)
# Analisa logs, crons falhados, sessions, disco, e corrige o que puder sozinho.
# Envia resumo humanizado pro Telegram. Zero LLM.

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OPENCLAW_DIR="$HOME/.openclaw"
ENV_FILE="$OPENCLAW_DIR/.env"
CRON_FILE="$OPENCLAW_DIR/cron/jobs.json"
SESSIONS_FILE="$OPENCLAW_DIR/agents/main/sessions/sessions.json"
GATEWAY_LOG="$OPENCLAW_DIR/logs/gateway.log"
UPGRADE_LOG="$WORKSPACE/memory/UPGRADE_LOG.md"
HEALTH_FILE="$WORKSPACE/memory/SYSTEM_HEALTH.md"

if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"
TODAY=$(date +"%Y-%m-%d")
NOW=$(date +"%H:%M")

PROBLEMAS=""
CORRIGIDOS=""
AVISOS=""
SAUDE_OK=true

# ---------------------------------------------------------------
# 1. Crons com erro
# ---------------------------------------------------------------
CRON_ERRORS=$(python3 -c "
import json
data = json.load(open('$CRON_FILE'))
jobs = data.get('jobs', [])
errors = []
for j in jobs:
    if not j.get('enabled'): continue
    state = j.get('state', {})
    ce = state.get('consecutiveErrors', 0)
    if ce >= 2:
        errors.append(f\"{j['name']} ({ce}x seguidas)\")
    elif state.get('lastRunStatus') == 'error':
        errors.append(f\"{j['name']} (ultima falhou)\")
print('\n'.join(errors))
" 2>/dev/null)

if [ -n "$CRON_ERRORS" ]; then
    SAUDE_OK=false
    PROBLEMAS="$PROBLEMAS\nCrons com problema:\n$CRON_ERRORS"

    # Self-heal: reset consecutiveErrors para crons com 3+ erros
    python3 -c "
import json
data = json.load(open('$CRON_FILE'))
fixed = 0
for j in data.get('jobs', []):
    state = j.get('state', {})
    if state.get('consecutiveErrors', 0) >= 3:
        state['consecutiveErrors'] = 0
        fixed += 1
if fixed > 0:
    json.dump(data, open('$CRON_FILE', 'w'), indent=2, ensure_ascii=False)
    print(f'{fixed}')
" 2>/dev/null
    RESET_COUNT=$(python3 -c "
import json
data = json.load(open('$CRON_FILE'))
print(sum(1 for j in data.get('jobs',[]) if j.get('state',{}).get('consecutiveErrors',0) == 0 and j.get('enabled')))
" 2>/dev/null)
    if [ -n "$RESET_COUNT" ]; then
        CORRIGIDOS="$CORRIGIDOS\nResetei contadores de erro dos crons travados"
    fi
fi

# ---------------------------------------------------------------
# 2. Sessions acumuladas
# ---------------------------------------------------------------
if [ -f "$SESSIONS_FILE" ]; then
    SESSION_COUNT=$(python3 -c "
import json
d = json.load(open('$SESSIONS_FILE'))
print(len(d) if isinstance(d, dict) else 0)
" 2>/dev/null || echo "0")

    if [ "$SESSION_COUNT" -gt 10 ]; then
        SAUDE_OK=false
        PROBLEMAS="$PROBLEMAS\n$SESSION_COUNT sessoes acumuladas (limite: 10)"
        # Self-heal: limpar sessions
        echo '{}' > "$SESSIONS_FILE"
        CORRIGIDOS="$CORRIGIDOS\nLimpei sessions acumuladas ($SESSION_COUNT -> 0)"
    fi
fi

# ---------------------------------------------------------------
# 3. Disco
# ---------------------------------------------------------------
DISK_PCT=$(df "$WORKSPACE" | awk 'NR==2 {print $5}' | tr -d '%' 2>/dev/null || echo "0")
if [ "$DISK_PCT" -gt 85 ]; then
    SAUDE_OK=false
    PROBLEMAS="$PROBLEMAS\nDisco em ${DISK_PCT}% — critico"
elif [ "$DISK_PCT" -gt 70 ]; then
    AVISOS="$AVISOS\nDisco em ${DISK_PCT}%"
fi

# ---------------------------------------------------------------
# 4. Gateway rodando
# ---------------------------------------------------------------
if ! pgrep -f "openclaw" > /dev/null 2>&1; then
    SAUDE_OK=false
    PROBLEMAS="$PROBLEMAS\nGateway nao esta rodando"
    # Self-heal: restart
    launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
    CORRIGIDOS="$CORRIGIDOS\nRestartei o gateway"
fi

# ---------------------------------------------------------------
# 5. Erros no log das ultimas 24h
# ---------------------------------------------------------------
if [ -f "$GATEWAY_LOG" ]; then
    ERROR_COUNT=$(grep -c "error\|Error\|ERROR\|timeout\|TIMEOUT" "$GATEWAY_LOG" 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 20 ]; then
        AVISOS="$AVISOS\n$ERROR_COUNT erros no log do gateway nas ultimas 24h"
    fi
fi

# ---------------------------------------------------------------
# 6. Workspace size
# ---------------------------------------------------------------
WS_SIZE=$(du -sh "$WORKSPACE" 2>/dev/null | awk '{print $1}')
if echo "$WS_SIZE" | grep -qE '^[0-9]+G'; then
    GB=$(echo "$WS_SIZE" | tr -d 'G')
    if [ "${GB%%.*}" -gt 1 ]; then
        AVISOS="$AVISOS\nWorkspace cresceu pra $WS_SIZE — verificar se tem lixo"
    fi
fi

# ---------------------------------------------------------------
# Salvar health report
# ---------------------------------------------------------------
mkdir -p "$(dirname "$HEALTH_FILE")"
cat > "$HEALTH_FILE" << EOF
# System Health — $TODAY $NOW

## Status: $([ "$SAUDE_OK" = true ] && echo "SAUDAVEL" || echo "COM PROBLEMAS")

### Metricas
- Disco: ${DISK_PCT}%
- Sessions: ${SESSION_COUNT:-0}
- Workspace: ${WS_SIZE:-?}
- Gateway: $(pgrep -f openclaw > /dev/null 2>&1 && echo "rodando" || echo "parado")

### Problemas encontrados
$([ -n "$PROBLEMAS" ] && echo -e "$PROBLEMAS" || echo "Nenhum")

### Corrigidos automaticamente
$([ -n "$CORRIGIDOS" ] && echo -e "$CORRIGIDOS" || echo "Nenhum")

### Avisos
$([ -n "$AVISOS" ] && echo -e "$AVISOS" || echo "Nenhum")
EOF

# ---------------------------------------------------------------
# Montar mensagem Telegram
# ---------------------------------------------------------------
if [ "$SAUDE_OK" = true ] && [ -z "$AVISOS" ]; then
    # Tudo ok — mensagem silenciosa (nao envia)
    echo "[auto-avaliacao] Sistema saudavel — nada a reportar"
    exit 0
fi

MSG="Netto, fiz a avaliacao matinal do sistema."

if [ -n "$PROBLEMAS" ]; then
    MSG="$MSG\n\nEncontrei alguns problemas:$(echo -e "$PROBLEMAS")"
fi

if [ -n "$CORRIGIDOS" ]; then
    MSG="$MSG\n\nJa corrigi sozinho:$(echo -e "$CORRIGIDOS")"
fi

if [ -n "$AVISOS" ]; then
    MSG="$MSG\n\nPontos de atencao:$(echo -e "$AVISOS")"
fi

MSG="$MSG\n\nRelatorio completo em memory/SYSTEM_HEALTH.md"

echo -e "$MSG"

if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo -e "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
fi
