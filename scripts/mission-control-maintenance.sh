#!/bin/bash
# mission-control-maintenance.sh — Manutencao diaria do Mission Control (8h BRT)
# Arquiva done >24h, verifica edge functions, reporta inconsistencias. Zero LLM.

set -euo pipefail

ENV_FILE="$HOME/.openclaw/.env"
if [ -f "$ENV_FILE" ]; then set -a; source "$ENV_FILE"; set +a; fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

SUPABASE_URL="${SUPABASE_URL:-https://dqhiafxbljujahmpcdhf.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-}"
SVC_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ -z "$ANON_KEY" ] || [ -z "$SVC_KEY" ]; then
    echo "[wmc-maint] Supabase keys nao configuradas"
    exit 0
fi

HEADERS="-H \"apikey: $ANON_KEY\" -H \"Authorization: Bearer $SVC_KEY\" -H \"Content-Type: application/json\""
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
YESTERDAY=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

REPORT=""

# ---------------------------------------------------------------
# 1. Arquivar missions done >24h → status "archived"
# ---------------------------------------------------------------
DONE_OLD=$(curl -s "$SUPABASE_URL/rest/v1/missions?status=eq.done&completed_at=lt.$YESTERDAY&select=id,title" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SVC_KEY" 2>/dev/null)

ARCHIVE_COUNT=$(echo "$DONE_OLD" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")

if [ "$ARCHIVE_COUNT" -gt 0 ]; then
    # Archive them
    ARCHIVED=0
    for ID in $(echo "$DONE_OLD" | python3 -c "import sys,json; [print(m['id']) for m in json.load(sys.stdin)]" 2>/dev/null); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -X PATCH "$SUPABASE_URL/rest/v1/missions?id=eq.$ID" \
            -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SVC_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"archived\"}" 2>/dev/null)
        [ "$STATUS" = "204" ] && ARCHIVED=$((ARCHIVED + 1))
    done
    REPORT="$REPORT\nArquivei $ARCHIVED missoes concluidas ha mais de 24h."
fi

# ---------------------------------------------------------------
# 2. Contar missoes por status
# ---------------------------------------------------------------
STATUS_SUMMARY=$(curl -s "$SUPABASE_URL/rest/v1/missions?select=status,id" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SVC_KEY" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
counts = {}
for m in data:
    s = m.get('status','?')
    counts[s] = counts.get(s,0) + 1
active = counts.get('in_progress',0) + counts.get('blocked',0) + counts.get('inbox',0)
print(f'Ativas: {active} (blocked: {counts.get(\"blocked\",0)}, inbox: {counts.get(\"inbox\",0)}, in_progress: {counts.get(\"in_progress\",0)})')
print(f'Total: {len(data)}')
" 2>/dev/null)

# ---------------------------------------------------------------
# 3. Verificar edge functions
# ---------------------------------------------------------------
EDGE_PROBLEMS=""
for fn in trigger-mission alfred-router quality-gate memory-writer telegram-notifier; do
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/functions/v1/$fn" \
        -H "Authorization: Bearer $ANON_KEY" 2>/dev/null)
    if [ "$HTTP" = "500" ]; then
        EDGE_PROBLEMS="$EDGE_PROBLEMS $fn(500)"
    fi
done

if [ -n "$EDGE_PROBLEMS" ]; then
    REPORT="$REPORT\nEdge functions com erro:$EDGE_PROBLEMS"
fi

# ---------------------------------------------------------------
# 4. Verificar missoes stale (in_progress >48h sem update)
# ---------------------------------------------------------------
TWO_DAYS_AGO=$(date -u -v-48H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "48 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
STALE=$(curl -s "$SUPABASE_URL/rest/v1/missions?status=eq.in_progress&updated_at=lt.$TWO_DAYS_AGO&select=id,title" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SVC_KEY" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data:
    for m in data:
        print(f\"- {m['title']}\")
" 2>/dev/null)

if [ -n "$STALE" ]; then
    REPORT="$REPORT\nMissoes paradas ha mais de 48h:\n$STALE"
fi

# ---------------------------------------------------------------
# Decidir se notifica
# ---------------------------------------------------------------
if [ -z "$REPORT" ]; then
    echo "[wmc-maint] Mission Control OK — $STATUS_SUMMARY"
    exit 0
fi

MSG="Netto, fiz a manutencao do Mission Control.\n\n$STATUS_SUMMARY\n$REPORT"

echo -e "$MSG"

if [ -n "$BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": $(echo -e "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
        > /dev/null 2>&1
fi
