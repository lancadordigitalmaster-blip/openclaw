#!/bin/bash
# wolf-client-report.sh — Relatorio diario/semanal/mensal de trafego por cliente
# Usa Meta Ads API diretamente (sem plugin) — funciona standalone
# Uso: bash wolf-client-report.sh <client_slug> [daily|weekly|monthly]
# Crontab examples:
#   0 7 * * *   bash ~/.openclaw/workspace/scripts/wolf-client-report.sh ticomia daily
#   0 7 * * 1   bash ~/.openclaw/workspace/scripts/wolf-client-report.sh ticomia weekly
#   0 7 1 * *   bash ~/.openclaw/workspace/scripts/wolf-client-report.sh ticomia monthly

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

CLIENT_SLUG="${1:?Uso: wolf-client-report.sh <client_slug> [daily|weekly|monthly]}"
PERIOD="${2:-daily}"

WORKSPACE="$HOME/.openclaw/workspace"
ENV_FILE="$HOME/.openclaw/.env"
REPORT_DIR="$WORKSPACE/memory/reports"
LOG="$WORKSPACE/memory/logs/client-reports.log"

mkdir -p "$REPORT_DIR" "$(dirname "$LOG")"

# ── Load env ──
set -a; source "$ENV_FILE" 2>/dev/null; set +a

wolf_log "client-report" "Iniciando report $PERIOD para $CLIENT_SLUG"

# ── Client config lookup ──
TMP_PY=$(mktemp /tmp/wolf-report-XXXXXX.py)

cat > "$TMP_PY" << 'PYEOF'
import sys, os, json
from datetime import datetime, timedelta
import urllib.request, urllib.parse

client_slug = sys.argv[1]
period = sys.argv[2]

# Client config — hardcoded to avoid yaml dependency
CLIENTS = {
    "gr-veiculos": {"nome": "GR Veiculos", "account_id": "1221676633470141"},
    "ticomia": {"nome": "Ticomia", "account_id": "1336968033454787"},
    "william-forlan": {"nome": "William Forlan", "account_id": "702342462816996"},
    "wolf-pack": {"nome": "WOLF PACK", "account_id": "1583430182930723"},
}

client = CLIENTS.get(client_slug)
if not client:
    print(json.dumps({"error": f"Cliente '{client_slug}' nao encontrado. Disponiveis: {list(CLIENTS.keys())}"}))
    sys.exit(1)

nome = client["nome"]
account_id = client["account_id"]

if not account_id:
    print(json.dumps({"error": f"Cliente '{client_slug}' sem account_id Meta"}))
    sys.exit(1)

# Token resolution — try client-specific then default
TOKEN_MAP = {
    "gr-veiculos": "META_TOKEN_GR_VEICULOS",
    "ticomia": "META_ADS_TOKEN_TICOMIA",
    "william-forlan": "META_ADS_TOKEN_FORLAN",
    "wolf-pack": "META_ADS_ACCESS_TOKEN",
}
token_env = TOKEN_MAP.get(client_slug, "META_ADS_ACCESS_TOKEN")
token = os.environ.get(token_env, "")
if not token:
    print(json.dumps({"error": f"Token '{token_env}' nao definido no .env"}))
    sys.exit(1)

# Date range
today = datetime.now()
if period == "weekly":
    since = (today - timedelta(days=7)).strftime("%Y-%m-%d")
    until = today.strftime("%Y-%m-%d")
    period_label = f"Semana ({since} a {until})"
elif period == "monthly":
    since = today.replace(day=1).strftime("%Y-%m-%d")
    until = today.strftime("%Y-%m-%d")
    period_label = f"Mes ({since} a {until})"
else:
    yesterday = today - timedelta(days=1)
    since = yesterday.strftime("%Y-%m-%d")
    until = yesterday.strftime("%Y-%m-%d")
    period_label = f"Ontem ({since})"

# Meta API call
API_BASE = "https://graph.facebook.com/v21.0"
params = {
    "fields": "campaign_name,campaign_id,spend,impressions,clicks,cpc,cpm,ctr,reach,actions,cost_per_action_type",
    "level": "campaign",
    "time_range": json.dumps({"since": since, "until": until}),
    "limit": "100",
}
url = f"{API_BASE}/act_{account_id}/insights?{urllib.parse.urlencode(params)}"

req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        result = json.loads(r.read())
except Exception as e:
    print(json.dumps({"error": f"Meta API erro: {str(e)}"}))
    sys.exit(1)

campaigns = result.get("data", [])
if not campaigns:
    # No data — still send a report
    report = f"📊 Report {period.title()} — {nome} — {period_label}\n\nSem dados de campanha no periodo."
    print(json.dumps({"report": report, "nome": nome, "period": period_label}))
    sys.exit(0)

# Aggregate
total_spend = 0
total_impressions = 0
total_clicks = 0
total_reach = 0
total_conversions = 0
campaign_lines = []

for c in campaigns:
    spend = float(c.get("spend", 0))
    impressions = int(c.get("impressions", 0))
    clicks = int(c.get("clicks", 0))
    reach = int(c.get("reach", 0))
    ctr = c.get("ctr", "0")

    total_spend += spend
    total_impressions += impressions
    total_clicks += clicks
    total_reach += reach

    # Extract conversions
    conv = 0
    cpconv = 0
    for a in (c.get("actions") or []):
        at = a.get("action_type", "")
        if "conversation" in at or "lead" in at or "conversion" in at:
            conv += int(a.get("value", 0))
    for a in (c.get("cost_per_action_type") or []):
        at = a.get("action_type", "")
        if "conversation" in at or "lead" in at or "conversion" in at:
            cpconv = float(a.get("value", 0))

    total_conversions += conv

    name_short = c.get("campaign_name", "?")
    if len(name_short) > 40:
        name_short = name_short[:37] + "..."

    if spend > 0:
        campaign_lines.append(f"  {name_short}\n    R${spend:.2f} | {impressions:,} imp | {clicks} cliques | {conv} conv")

# Totals
avg_cpc = total_spend / total_clicks if total_clicks else 0
avg_ctr = (total_clicks / total_impressions * 100) if total_impressions else 0
cpa = total_spend / total_conversions if total_conversions else 0

# Alertas
alerts = []
if total_conversions == 0 and total_spend > 10:
    alerts.append("Zero conversoes com spend ativo — verificar pixel/eventos")
if avg_ctr < 0.5 and total_impressions > 1000:
    alerts.append(f"CTR baixo ({avg_ctr:.2f}%) — possivel fadiga criativa")
if cpa > 0 and cpa > 50:
    alerts.append(f"CPA alto (R${cpa:.2f}) — revisar segmentacao")

alert_section = ""
if alerts:
    alert_section = "\n⚡ Alertas:\n" + "\n".join(f"- {a}" for a in alerts)
else:
    alert_section = "\n✅ Sem alertas"

# Build report
report = f"""📊 Report {period.title()} — {nome} — {period_label}

💰 Spend: R${total_spend:,.2f}
📈 Impressoes: {total_impressions:,}
👁️ Alcance: {total_reach:,}
🖱️ Cliques: {total_clicks:,} (CTR: {avg_ctr:.2f}%)
💵 CPC: R${avg_cpc:.2f}
🎯 Conversoes: {total_conversions}"""

if total_conversions > 0:
    report += f"\n📍 CPA: R${cpa:.2f}"

report += alert_section

if campaign_lines:
    report += "\n\n📋 Campanhas:\n" + "\n".join(campaign_lines[:5])

if len(campaigns) > 5:
    report += f"\n  ... +{len(campaigns)-5} campanhas"

print(json.dumps({"report": report, "nome": nome, "period": period_label, "spend": total_spend, "conversions": total_conversions}))
PYEOF

RESULT=$(python3 "$TMP_PY" "$CLIENT_SLUG" "$PERIOD" 2>&1)
rm -f "$TMP_PY"

# Parse result
ERROR=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null)
if [ -n "$ERROR" ]; then
    wolf_log "client-report" "ERRO $CLIENT_SLUG: $ERROR"
    wolf_notify_urgent "Report $CLIENT_SLUG falhou: $ERROR"
    exit 1
fi

REPORT=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('report','Sem report'))" 2>/dev/null)
NOME=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('nome','?'))" 2>/dev/null)

# Enviar
wolf_notify_info "$REPORT"

# Salvar
TODAY=$(date '+%Y-%m-%d')
echo "$REPORT" > "$REPORT_DIR/${CLIENT_SLUG}-${PERIOD}-${TODAY}.txt"

wolf_log "client-report" "Report $PERIOD $CLIENT_SLUG enviado"
echo "OK: wolf-client-report $CLIENT_SLUG $PERIOD completed at $(date '+%Y-%m-%d %H:%M:%S')"
