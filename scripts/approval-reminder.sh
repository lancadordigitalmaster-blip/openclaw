#!/bin/bash
# approval-reminder.sh — Lembra Netto de propostas pendentes (substitui Brain reminder)
# Cron: 15h BRT | Zero LLM | Silencioso se nao houver pendencias

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
ENV_FILE="$HOME/.openclaw/.env"

if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

PENDING_FILE="$WORKSPACE/memory/pending-approvals.json"

# Se nao existe arquivo de pendencias, nada a fazer
if [ ! -f "$PENDING_FILE" ]; then
    echo "[approval-reminder] Nenhum arquivo de pendencias"
    exit 0
fi

# Contar pendencias
PENDING_COUNT=$(python3 -c "
import json, sys
try:
    data = json.load(open('$PENDING_FILE'))
    pending = [p for p in data if p.get('status') == 'pending']
    if not pending:
        sys.exit(0)
    print(len(pending))
    for p in pending:
        print(f\"- {p.get('actionName', p.get('name', 'sem nome'))}\")
except:
    sys.exit(0)
" 2>/dev/null)

if [ -z "$PENDING_COUNT" ]; then
    echo "[approval-reminder] Nenhuma pendencia"
    exit 0
fi

# Primeira linha e o count, resto sao os nomes
COUNT=$(echo "$PENDING_COUNT" | head -1)
NAMES=$(echo "$PENDING_COUNT" | tail -n +2)

MSG="Netto, tem $COUNT proposta(s) esperando tua resposta:

$NAMES

Responde SIM ou NAO pra cada uma no Telegram."

echo "[approval-reminder] $COUNT pendencia(s) — notificando"

if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
fi
