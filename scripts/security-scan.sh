#!/bin/bash
# security-scan.sh — Varredura de seguranca diaria (substitui Brain security.agent)
# Cron: 18h BRT | Zero LLM | Notifica Telegram se encontrar problemas

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
OPENCLAW_DIR="$HOME/.openclaw"
ENV_FILE="$OPENCLAW_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

ISSUES=""
WARNINGS=""

# 1. Verificar permissoes de .env
if [ -f "$OPENCLAW_DIR/.env" ]; then
    PERMS=$(stat -f '%Lp' "$OPENCLAW_DIR/.env" 2>/dev/null || echo "unknown")
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "640" ]; then
        WARNINGS="$WARNINGS\nAtencao: .env com permissao $PERMS (recomendado 600)"
    fi
fi

# 2. Verificar tokens expostos em logs
LOG_DIR="$WORKSPACE/memory/logs"
if [ -d "$LOG_DIR" ]; then
    EXPOSED=$(grep -rl 'bot[0-9]\{10\}:' "$LOG_DIR" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${EXPOSED:-0}" -gt 0 ] 2>/dev/null; then
        ISSUES="$ISSUES\nCritico: Token de bot possivelmente exposto em $EXPOSED arquivo(s) de log"
    fi
fi

# 3. Verificar arquivos .env world-readable
WORLD_READABLE=$(find "$WORKSPACE" -maxdepth 2 -name "*.env*" -perm +004 2>/dev/null | wc -l | tr -d ' ')
if [ "${WORLD_READABLE:-0}" -gt 0 ] 2>/dev/null; then
    WARNINGS="$WARNINGS\nAtencao: $WORLD_READABLE arquivo(s) .env com permissao world-readable"
fi

# 4. Verificar sessoes acumuladas
SESSIONS_FILE="$OPENCLAW_DIR/agents/main/sessions/sessions.json"
if [ -f "$SESSIONS_FILE" ]; then
    SESSION_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS_FILE')); print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo "0")
    if [ "$SESSION_COUNT" -gt 10 ]; then
        WARNINGS="$WARNINGS\nAtencao: $SESSION_COUNT sessoes acumuladas (max recomendado: 10)"
    fi
fi

# 5. Verificar disco
DISK_PCT=$(df "$WORKSPACE" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
if [ "$DISK_PCT" -gt 85 ] 2>/dev/null; then
    ISSUES="$ISSUES\nCritico: Disco em ${DISK_PCT}%"
elif [ "$DISK_PCT" -gt 70 ] 2>/dev/null; then
    WARNINGS="$WARNINGS\nAtencao: Disco em ${DISK_PCT}%"
fi

# 6. Verificar se gateway esta rodando
GW_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
if [ "$GW_HTTP" != "200" ]; then
    ISSUES="$ISSUES\nCritico: Gateway OpenClaw nao esta rodando"
fi

# Montar mensagem
if [ -z "$ISSUES" ] && [ -z "$WARNINGS" ]; then
    echo "[security-scan] Tudo limpo — nenhum problema encontrado"
    exit 0
fi

MSG="Netto, fiz a varredura de seguranca do sistema."
[ -n "$ISSUES" ] && MSG="$MSG$(echo -e "$ISSUES")"
[ -n "$WARNINGS" ] && MSG="$MSG$(echo -e "$WARNINGS")"

echo "[security-scan] Problemas encontrados — notificando"
echo -e "$MSG"

if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo -e "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
fi
