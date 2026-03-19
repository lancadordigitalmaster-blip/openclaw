#!/bin/bash
# WOLF — Trend Analysis (diário 23h40)
# Coleta métricas, armazena histórico, detecta tendências preocupantes
set -uo pipefail

ENV_FILE="$HOME/.openclaw/.env"
HISTORY="$HOME/.openclaw/logs/trend-history.jsonl"
SESSIONS_JSON="$HOME/.openclaw/agents/main/sessions/sessions.json"
GW_LOG="$HOME/.openclaw/logs/gateway.log"
WA_LOG="$HOME/.openclaw/logs/whatsapp-bridge.log"
TEL_LOG="$HOME/.openclaw/logs/token-telemetry.jsonl"
TODAY=$(date '+%Y-%m-%d')


# --- 1. Collect metrics ---
DISK_PCT=$(df -h "$HOME/.openclaw/workspace" 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}')
GW_PID=$(lsof -ti :18789 2>/dev/null | head -1)
GW_RAM=$([ -n "$GW_PID" ] && echo "$(ps -o rss= -p "$GW_PID" 2>/dev/null | tr -d ' ') / 1024" | bc 2>/dev/null || echo 0)
SESSIONS=$([ -f "$SESSIONS_JSON" ] && python3 -c "import json;d=json.load(open('$SESSIONS_JSON'));print(len(d))" 2>/dev/null || echo 0)

file_mb() { [ -f "$1" ] && du -m "$1" 2>/dev/null | cut -f1 || echo 0; }
GW_LOG_MB=$(file_mb "$GW_LOG")
WA_LOG_MB=$(file_mb "$WA_LOG")
TEL_LOG_MB=$(file_mb "$TEL_LOG")

GW_ERRORS=$([ -f "$GW_LOG" ] && grep -c "$TODAY.*[Ee]rror" "$GW_LOG" 2>/dev/null || echo 0)

# API cost from telemetry (simplified)
COST=$(python3 -c "
import json,os
today='$TODAY'; total=0; path=os.path.expanduser('$TEL_LOG')
if not os.path.exists(path): print('N/A'); exit()
latest={}
for line in open(path):
    try:
        e=json.loads(line)
        if not e.get('ts','').startswith(today): continue
        for s in e.get('sessions',[]):
            k=s.get('key',''); latest[k]={'i':s.get('inputTokens',0),'o':s.get('outputTokens',0)}
    except: pass
for v in latest.values(): total+=(v['i']*0.8+v['o']*4.0)/1e6
print(f'{total:.4f}')
" 2>/dev/null || echo "N/A")

# --- 2. Append to history ---
mkdir -p "$(dirname "$HISTORY")"
echo "{\"date\":\"$TODAY\",\"disk_pct\":$DISK_PCT,\"gw_ram_mb\":$GW_RAM,\"sessions\":$SESSIONS,\"gw_log_mb\":$GW_LOG_MB,\"wa_log_mb\":$WA_LOG_MB,\"tel_log_mb\":$TEL_LOG_MB,\"gw_errors\":$GW_ERRORS,\"cost\":\"$COST\"}" >> "$HISTORY"

# --- 3. Analyze trends (today vs 7 days ago) ---
WEEK_AGO=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null)
OLD=$(grep "\"date\":\"$WEEK_AGO\"" "$HISTORY" 2>/dev/null | tail -1)
[ -z "$OLD" ] && { echo "[$TODAY] No data from $WEEK_AGO for comparison"; exit 0; }

ALERTS=$(python3 -c "
import json,sys
old=json.loads('$OLD')
new={'disk_pct':$DISK_PCT,'gw_ram_mb':$GW_RAM,'sessions':$SESSIONS,'gw_log_mb':$GW_LOG_MB,'wa_log_mb':$WA_LOG_MB,'tel_log_mb':$TEL_LOG_MB,'gw_errors':$GW_ERRORS}
alerts=[]
if new['disk_pct']-old['disk_pct']>5: alerts.append(f\"📀 Disco: {old['disk_pct']}% → {new['disk_pct']}% (+{new['disk_pct']-old['disk_pct']}%/sem)\")
if new['gw_ram_mb']-old['gw_ram_mb']>50: alerts.append(f\"🧠 RAM Gateway: {old['gw_ram_mb']}MB → {new['gw_ram_mb']}MB (+{new['gw_ram_mb']-old['gw_ram_mb']}MB/sem)\")
if new['sessions']>old['sessions'] and old['sessions']>0: alerts.append(f\"📂 Sessions crescendo: {old['sessions']} → {new['sessions']} (nunca diminui?)\")
for k,label in [('gw_log_mb','gateway.log'),('wa_log_mb','wa-bridge.log'),('tel_log_mb','telemetry.jsonl')]:
    if old[k]>0 and new[k]>=old[k]*2: alerts.append(f\"📁 {label} dobrou: {old[k]}MB → {new[k]}MB\")
if old['gw_errors']>0 and new['gw_errors']>old['gw_errors']*1.5: alerts.append(f\"❌ Erros gateway: {old['gw_errors']} → {new['gw_errors']} (+{((new['gw_errors']-old['gw_errors'])/old['gw_errors']*100):.0f}%)\")
print('\n'.join(alerts))
" 2>/dev/null)

# --- 4. Alert only on concerning trends ---
if [[ -n "$ALERTS" ]]; then
  MSG="📊 *Wolf Trend Analysis — $TODAY*"$'\n'$'\n'"$ALERTS"$'\n'$'\n'"_Comparação: $WEEK_AGO → $TODAY_"
  wolf_log "trend-analysis" "$MSG"
  echo "[$TODAY] Alerts sent: $(echo "$ALERTS" | wc -l | tr -d ' ') trends"
else
  echo "[$TODAY] All trends stable — no alert"
fi
