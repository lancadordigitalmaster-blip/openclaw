#!/bin/bash
# Wolf Traffic Command — Meta Ads sync trigger
# Roda via crontab local 2x/dia (14h e 20h BRT)
# Fix 2026-03-21: validação JSON + log descritivo quando Vercel retorna lixo

ENDPOINT="https://wolf-traffic-command.vercel.app/api/sync/meta"
LOG="/Users/thomasgirotto/.openclaw/workspace/memory/logs/traffic-sync.log"

mkdir -p "$(dirname "$LOG")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering Meta Ads sync..." >> "$LOG"

HTTP_CODE=$(curl -s -o /tmp/wolf-sync-body.txt -w "%{http_code}" -X POST "$ENDPOINT" --max-time 30 2>/dev/null)
BODY=$(cat /tmp/wolf-sync-body.txt 2>/dev/null)
rm -f /tmp/wolf-sync-body.txt

# Validar que resposta é JSON válido antes de parsear
IS_VALID_JSON=$(echo "$BODY" | python3 -c "import sys,json; json.load(sys.stdin); print('ok')" 2>/dev/null)

if [ "$IS_VALID_JSON" = "ok" ]; then
  STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
  SYNCED=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(c.get('metrics_synced',0) for c in d.get('synced',[])))" 2>/dev/null || echo "0")
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP=$HTTP_CODE status=$STATUS metrics=$SYNCED" >> "$LOG"
else
  # Vercel retornando pseudo-JSON ou HTML — endpoint precisa redeploy
  PREVIEW=$(echo "$BODY" | head -c 120 | tr '\n' ' ')
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP=$HTTP_CODE status=VERCEL_BROKEN preview='$PREVIEW'" >> "$LOG"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] FIX: Redeploy wolf-traffic-command no Vercel. Sync funciona via crons LLM (Wolf Ads 12h/18h/23h50)." >> "$LOG"
fi

# Limitar log a 200 linhas
tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
