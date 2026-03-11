#!/bin/bash
# cobrar-pendencias.sh — Cobra pendencias que dependem do Netto (10h + 14h BRT)
# Consulta Mission Control + pendencias conhecidas do sistema. Zero LLM.

set -euo pipefail

ENV_FILE="$HOME/.openclaw/.env"
if [ -f "$ENV_FILE" ]; then set -a; source "$ENV_FILE"; set +a; fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

SUPABASE_URL="${SUPABASE_URL:-https://dqhiafxbljujahmpcdhf.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-}"
SVC_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

PENDENCIAS=""
COUNT=0

# ---------------------------------------------------------------
# 1. Mission Control — blocked + inbox
# ---------------------------------------------------------------
if [ -n "$ANON_KEY" ] && [ -n "$SVC_KEY" ]; then
    MC_PENDING=$(curl -s "$SUPABASE_URL/rest/v1/missions?status=in.(\"blocked\",\"inbox\")&select=title,status,priority&order=priority.desc" \
        -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SVC_KEY" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data:
    prio = m.get('priority','?')
    icon = '!' if prio == 'critical' else '>' if prio == 'high' else '-'
    print(f\"{icon} {m['title']} [{m['status']}]\")
print(f'__COUNT__:{len(data)}')
" 2>/dev/null)

    MC_COUNT=$(echo "$MC_PENDING" | grep '__COUNT__' | cut -d: -f2)
    MC_ITEMS=$(echo "$MC_PENDING" | grep -v '__COUNT__')

    if [ -n "$MC_ITEMS" ] && [ "$MC_COUNT" -gt 0 ]; then
        PENDENCIAS="$PENDENCIAS\nNo Mission Control:\n$MC_ITEMS"
        COUNT=$((COUNT + MC_COUNT))
    fi
fi

# ---------------------------------------------------------------
# 2. Pendencias conhecidas do sistema (hardcoded checks)
# ---------------------------------------------------------------

# Meta Ads token
if grep -q "EXPIRADO\|expirado\|expired" "$HOME/.openclaw/workspace/CLAUDE.md" 2>/dev/null; then
    if ! grep -q "META_ADS_TOKEN" "$HOME/.openclaw/.env" 2>/dev/null || \
       grep -q "EXPIRADO" "$HOME/.openclaw/.env" 2>/dev/null; then
        # Only add if not already in MC list
        if ! echo "$PENDENCIAS" | grep -q "Meta Ads"; then
            PENDENCIAS="$PENDENCIAS\n! Token Meta Ads continua expirado — preciso que voce gere um novo no Facebook Business"
            COUNT=$((COUNT + 1))
        fi
    fi
fi

# clients.yaml vazio
CLIENTS_FILE="$HOME/.openclaw/workspace/shared/memory/clients.yaml"
if [ -f "$CLIENTS_FILE" ]; then
    LINES=$(grep -c "^[^#]" "$CLIENTS_FILE" 2>/dev/null || echo "0")
    if [ "$LINES" -lt 5 ]; then
        if ! echo "$PENDENCIAS" | grep -q "clients.yaml"; then
            PENDENCIAS="$PENDENCIAS\n> clients.yaml ainda ta vazio — preciso dos dados reais dos clientes pra os relatorios funcionarem"
            COUNT=$((COUNT + 1))
        fi
    fi
fi

# ---------------------------------------------------------------
# Decidir se envia
# ---------------------------------------------------------------
if [ "$COUNT" -eq 0 ]; then
    echo "[cobrar-pendencias] Nenhuma pendencia — silencioso"
    exit 0
fi

HORA=$(date +"%H")
if [ "$HORA" -lt 12 ]; then
    SAUDACAO="Netto, bom dia"
else
    SAUDACAO="Netto, boa tarde"
fi

MSG="$SAUDACAO. Tem $COUNT coisa(s) travada(s) no sistema que dependem de voce:\n$PENDENCIAS\n\nQuando puder resolver qualquer uma, o sistema destrava automaticamente."

echo -e "$MSG"

if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo -e "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
fi
