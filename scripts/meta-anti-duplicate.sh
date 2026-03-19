#!/usr/bin/env bash
# meta-anti-duplicate.sh — Monitor de campanhas duplicadas Meta Ads
# Zero LLM. Bash + Python + Meta API.
# Roda via cron a cada 30min (08h-22h).
# Se detectar 2+ campanhas ativas com mesmo nome: pausa as mais antigas + alerta Telegram.
# Wolf Agency — 2026-03-17

set -uo pipefail

ENV_FILE="$HOME/.openclaw/.env"
LOG_FILE="$HOME/.openclaw/workspace/memory/meta-anti-duplicate.log"
TELEGRAM_CHAT_ID="789352357"
TMP=$(mktemp /tmp/meta-dup-XXXXXX.json)
trap 'rm -f "$TMP"' EXIT

# Carregar variáveis de ambiente
[[ -f "$ENV_FILE" ]] && set -a && source "$ENV_FILE" 2>/dev/null && set +a || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh" 2>/dev/null || true

# Contas a monitorar: "account_id:token_value"
declare -a ACCOUNTS=(
  "act_1583430182930723:${META_ADS_ACCESS_TOKEN:-}"
  "act_1221676633470141:${META_TOKEN_GR_VEICULOS:-}"
)

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# send_telegram removido — usando wolf_notify via lib-wolf.sh

TOTAL_PAUSED=0
ALERT_LINES=""

for ENTRY in "${ACCOUNTS[@]}"; do
  ACCOUNT_ID="${ENTRY%%:*}"
  TOKEN="${ENTRY#*:}"

  if [[ -z "$TOKEN" ]]; then
    log "SKIP $ACCOUNT_ID — token não configurado"
    continue
  fi

  # Buscar campanhas ativas → salvar em arquivo temporário
  HTTP_STATUS=$(curl -s --max-time 15 -w "%{http_code}" -o "$TMP" \
    "https://graph.facebook.com/v21.0/${ACCOUNT_ID}/campaigns?fields=id,name,effective_status,created_time&limit=100&access_token=${TOKEN}" \
    2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" != "200" ]] || grep -q '"error"' "$TMP" 2>/dev/null; then
    ERR=$(python3 -c "import json; d=json.load(open('$TMP')); print(d.get('error',{}).get('message','HTTP $HTTP_STATUS'))" 2>/dev/null || echo "HTTP $HTTP_STATUS")
    log "ERRO API $ACCOUNT_ID: $ERR"
    continue
  fi

  # Detectar e pausar duplicatas
  RESULT=$(python3 - "$TMP" "$TOKEN" << 'PYEOF'
import sys, json, urllib.request, urllib.parse
from collections import defaultdict

resp_file = sys.argv[1]
token = sys.argv[2]

data = json.load(open(resp_file))
camps = [c for c in data.get('data', []) if c.get('effective_status') == 'ACTIVE']

by_name = defaultdict(list)
for c in camps:
    by_name[c['name']].append(c)

paused = []
for name, group in by_name.items():
    if len(group) <= 1:
        continue
    group.sort(key=lambda x: x.get('created_time', ''), reverse=True)
    for c in group[1:]:
        try:
            payload = urllib.parse.urlencode({'status': 'PAUSED', 'access_token': token}).encode()
            req = urllib.request.Request(
                f"https://graph.facebook.com/v21.0/{c['id']}",
                data=payload, method='POST'
            )
            with urllib.request.urlopen(req, timeout=10) as r:
                res = json.loads(r.read())
            if res.get('success'):
                paused.append(name[:60])
        except Exception as e:
            pass

print(json.dumps({'paused': len(paused), 'names': paused}))
PYEOF
  )

  PAUSED=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('paused',0))" 2>/dev/null || echo "0")
  NAMES=$(echo "$RESULT" | python3 -c "import sys,json; [print('  •',n) for n in json.load(sys.stdin).get('names',[])]" 2>/dev/null || echo "")

  if [[ "${PAUSED:-0}" -gt 0 ]]; then
    log "DUPLICATA $ACCOUNT_ID — $PAUSED campanhas pausadas"
    [[ -n "$NAMES" ]] && while IFS= read -r line; do log "$line"; done <<< "$NAMES"
    TOTAL_PAUSED=$((TOTAL_PAUSED + PAUSED))
    ALERT_LINES="${ALERT_LINES}⚠️ Conta: ${ACCOUNT_ID} — ${PAUSED} duplicata(s)\n${NAMES}\n"
  else
    log "OK $ACCOUNT_ID — sem duplicatas"
  fi
done

if [[ "${TOTAL_PAUSED:-0}" -gt 0 ]]; then
  wolf_notify_urgent "🐺 *Wolf — Alerta Meta Ads*

🔴 *Campanhas duplicadas pausadas*

$(echo -e "$ALERT_LINES")

_Duplicatas pausadas automaticamente. Confere se as campanhas ativas estão corretas._"
  log "Alerta enviado. Total pausadas: $TOTAL_PAUSED"
else
  log "HEARTBEAT_OK"
fi
