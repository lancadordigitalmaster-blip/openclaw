#!/bin/bash
# Wolf Traffic Command — Meta Ads sync trigger (complementa o cron Vercel 1x/dia)
# Roda via crontab local 2x/dia extra (11h e 17h BRT)

ENDPOINT="https://wolf-traffic-command.vercel.app/api/sync/meta"
LOG="/Users/thomasgirotto/.openclaw/workspace/memory/logs/traffic-sync.log"

mkdir -p "$(dirname "$LOG")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering Meta Ads sync..." >> "$LOG"

RESULT=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" 2>&1)
HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | head -n -1)

STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null || echo "parse_error")
SYNCED=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(c.get('metrics_synced',0) for c in d.get('synced',[])))" 2>/dev/null || echo "0")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP=$HTTP_CODE status=$STATUS metrics=$SYNCED" >> "$LOG"

# Limitar log a 200 linhas
tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
