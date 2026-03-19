#!/bin/bash
# gabi-proactive-alerts.sh — Alertas proativos de trafego
# Roda 4x/dia (6h, 10h, 14h, 18h) — verifica metricas de todos os clientes
# Crontab: 0 6,10,14,18 * * * bash ~/.openclaw/workspace/scripts/gabi-proactive-alerts.sh

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
ENV_FILE="$HOME/.openclaw/.env"
ALERTS_LOG="$WORKSPACE/memory/gabi/alerts-log.md"
STATE_FILE="$WORKSPACE/memory/gabi/alert-state.json"
LOG="$WORKSPACE/memory/logs/gabi-alerts.log"

mkdir -p "$(dirname "$ALERTS_LOG")" "$(dirname "$LOG")"

set -a; source "$ENV_FILE" 2>/dev/null; set +a

wolf_log "gabi-alerts" "Verificando alertas proativos"

# Initialize state file if needed
[ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"

# Initialize alerts log if needed
if [ ! -f "$ALERTS_LOG" ]; then
  cat > "$ALERTS_LOG" << 'HEADER'
# Gabi — Log de Alertas Proativos
> Registro automatico de todos os alertas disparados

| Data | Cliente | Tipo | Mensagem |
|------|---------|------|----------|
HEADER
fi

TMP_PY=$(mktemp /tmp/gabi-alerts-XXXXXX.py)

cat > "$TMP_PY" << 'PYEOF'
import os, sys, json, urllib.request, urllib.parse
from datetime import datetime, timedelta

TODAY = datetime.now().strftime("%Y-%m-%d")
STATE_FILE = os.path.expanduser("~/.openclaw/workspace/memory/gabi/alert-state.json")

# Load state (tracks last alert per client+type to avoid spam)
try:
    with open(STATE_FILE) as f:
        state = json.load(f)
except:
    state = {}

# Carregar clientes dinamicamente dos health cards
# Qualquer cliente com health.yaml + meta_ad_account_id entra automaticamente
HEALTH_DIR = os.path.expanduser("~/.openclaw/workspace/memory/clients")
CLIENTS = {}
TOKEN_EXPIRY = {}

for slug in os.listdir(HEALTH_DIR):
    health_file = os.path.join(HEALTH_DIR, slug, "health.yaml")
    if not os.path.isfile(health_file):
        continue
    with open(health_file) as f:
        content = f.read()
    # Parsear YAML manualmente (sem dependência externa)
    nome = ""
    account_id = ""
    token_var = ""
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("client:"):
            nome = line.split('"')[1] if '"' in line else line.split(":")[1].strip()
        if line.startswith("meta_ad_account_id:"):
            val = line.split('"')[1] if '"' in line else line.split(":")[1].strip()
            if val and val != "null":
                account_id = val
        if line.startswith("meta_token_var:"):
            val = line.split('"')[1] if '"' in line else line.split(":")[1].strip()
            if val and val != "null":
                token_var = val
    if account_id and token_var:
        CLIENTS[slug] = {"nome": nome, "account_id": account_id, "token_env": token_var}

# Token expiration dates — detectar do .env ou hardcoded conhecidos
# TODO: ler datas de expiração de um arquivo centralizado quando disponível
_known_expiry = {
    "META_TOKEN_GR_VEICULOS": "2026-05-12",
    "META_ADS_TOKEN_TICOMIA": "2026-05-12",
    "META_ADS_TOKEN_FORLAN": "2026-05-12",
}
for c in CLIENTS.values():
    tv = c["token_env"]
    if tv in _known_expiry:
        TOKEN_EXPIRY[tv] = _known_expiry[tv]

API_BASE = "https://graph.facebook.com/v21.0"
alerts = []

def should_alert(client_slug, alert_type, cooldown_days=1):
    """Check if we should fire this alert (cooldown based)"""
    key = f"{client_slug}:{alert_type}"
    last = state.get(key, "")
    if last:
        try:
            last_date = datetime.strptime(last, "%Y-%m-%d")
            if (datetime.now() - last_date).days < cooldown_days:
                return False
        except:
            pass
    state[key] = TODAY
    return True

def get_insights(account_id, token, since, until):
    params = {
        "fields": "campaign_name,campaign_id,spend,impressions,clicks,ctr,actions",
        "level": "campaign",
        "time_range": json.dumps({"since": since, "until": until}),
        "limit": "50",
    }
    url = f"{API_BASE}/act_{account_id}/insights?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())

# Check each client
for slug, info in CLIENTS.items():
    token = os.environ.get(info["token_env"], "")
    if not token:
        if should_alert(slug, "no_token", 7):
            alerts.append(f"🔑 {info['nome']}: Token {info['token_env']} nao configurado")
        continue

    try:
        # Last 3 days vs last 14 days
        now = datetime.now()
        d3_since = (now - timedelta(days=3)).strftime("%Y-%m-%d")
        d14_since = (now - timedelta(days=14)).strftime("%Y-%m-%d")
        d1_since = (now - timedelta(days=1)).strftime("%Y-%m-%d")
        today_str = now.strftime("%Y-%m-%d")

        # Get recent data (3 days)
        recent = get_insights(info["account_id"], token, d3_since, today_str)
        recent_data = recent.get("data", [])

        # Get baseline (14 days)
        baseline = get_insights(info["account_id"], token, d14_since, today_str)
        baseline_data = baseline.get("data", [])

        if not recent_data and not baseline_data:
            continue  # No campaigns, skip

        # Aggregate recent metrics
        r_spend = sum(float(c.get("spend", 0)) for c in recent_data)
        r_clicks = sum(int(c.get("clicks", 0)) for c in recent_data)
        r_impressions = sum(int(c.get("impressions", 0)) for c in recent_data)
        r_ctr = (r_clicks / r_impressions * 100) if r_impressions > 0 else 0

        # Aggregate baseline
        b_spend = sum(float(c.get("spend", 0)) for c in baseline_data)
        b_clicks = sum(int(c.get("clicks", 0)) for c in baseline_data)
        b_impressions = sum(int(c.get("impressions", 0)) for c in baseline_data)
        b_ctr = (b_clicks / b_impressions * 100) if b_impressions > 0 else 0

        # Calculate CPAs
        r_conv = 0
        b_conv = 0
        for c in recent_data:
            for a in (c.get("actions") or []):
                if "conversation" in a.get("action_type","") or "lead" in a.get("action_type",""):
                    r_conv += int(a.get("value", 0))
        for c in baseline_data:
            for a in (c.get("actions") or []):
                if "conversation" in a.get("action_type","") or "lead" in a.get("action_type",""):
                    b_conv += int(a.get("value", 0))

        r_cpa = r_spend / r_conv if r_conv > 0 else 0
        b_cpa = b_spend / b_conv if b_conv > 0 else 0

        # ALERT: CPA Spike (30%+ increase)
        if r_cpa > 0 and b_cpa > 0 and r_cpa > b_cpa * 1.3:
            pct = int((r_cpa / b_cpa - 1) * 100)
            if should_alert(slug, "cpa_spike", 1):
                alerts.append(f"🚨 {info['nome']}: CPA subiu {pct}% (R${r_cpa:.2f} vs media R${b_cpa:.2f})")

        # ALERT: CTR Drop (30%+ decrease)
        if r_ctr > 0 and b_ctr > 0 and r_ctr < b_ctr * 0.7:
            pct = int((1 - r_ctr / b_ctr) * 100)
            if should_alert(slug, "ctr_drop", 3):
                alerts.append(f"📉 {info['nome']}: CTR caiu {pct}% ({r_ctr:.2f}% vs media {b_ctr:.2f}%). Possivel fadiga criativa.")

        # ALERT: Campaign with 0 impressions (yesterday)
        yesterday = get_insights(info["account_id"], token, d1_since, d1_since)
        for c in yesterday.get("data", []):
            if int(c.get("impressions", 0)) == 0 and float(c.get("spend", 0)) > 0:
                cname = c.get("campaign_name", "?")
                if should_alert(slug, f"zero_imp_{c.get('campaign_id','')}", 1):
                    alerts.append(f"🔴 {info['nome']}: Campanha '{cname[:40]}' zerou impressoes ontem")

    except Exception as e:
        if should_alert(slug, "api_error", 1):
            alerts.append(f"⚠️ {info['nome']}: Erro ao verificar metricas: {str(e)[:80]}")

# ALERT: Token expiring in <= 7 days
for env_var, expiry_str in TOKEN_EXPIRY.items():
    try:
        expiry = datetime.strptime(expiry_str, "%Y-%m-%d")
        days_left = (expiry - datetime.now()).days
        if days_left <= 7 and should_alert("system", f"token_{env_var}", 1):
            alerts.append(f"🔑 Token {env_var} expira em {days_left} dias ({expiry_str}). Renovar agora.")
    except:
        pass

# ALERT: Token Netto principal — validade
netto_token = os.environ.get("META_ADS_ACCESS_TOKEN", "")
if netto_token:
    try:
        req = urllib.request.Request(f"https://graph.facebook.com/v21.0/me?access_token={netto_token}")
        with urllib.request.urlopen(req, timeout=10) as r:
            resp = json.loads(r.read())
            if "error" in resp and should_alert("system", "netto_token_invalid", 1):
                alerts.append(f"🔴 Token Netto principal INVALIDO — renovar imediatamente")
    except urllib.error.HTTPError as e:
        if should_alert("system", "netto_token_invalid", 1):
            alerts.append(f"🔴 Token Netto principal EXPIRADO (HTTP {e.code}) — renovar imediatamente")
    except Exception as e:
        if should_alert("system", "netto_token_check_error", 1):
            alerts.append(f"⚠️ Erro ao verificar token Netto: {str(e)[:60]}")
elif should_alert("system", "netto_token_missing", 7):
    alerts.append(f"🔑 META_ADS_ACCESS_TOKEN nao configurado no .env")

# ALERT: Funil — CPL alto mas CPA bom (possivel otimizacao de captacao)
for slug, info in CLIENTS.items():
    token = os.environ.get(info["token_env"], "")
    if not token:
        continue
    try:
        d7_since = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        today_str = datetime.now().strftime("%Y-%m-%d")
        week_data = get_insights(info["account_id"], token, d7_since, today_str)

        total_spend = 0
        total_leads = 0
        total_purchases = 0
        for c in week_data.get("data", []):
            total_spend += float(c.get("spend", 0))
            for a in (c.get("actions") or []):
                at = a.get("action_type", "")
                val = int(a.get("value", 0))
                if at in ("lead", "onsite_web_lead", "offsite_conversion.fb_pixel_lead"):
                    total_leads += val
                if at in ("purchase", "onsite_web_purchase", "offsite_conversion.fb_pixel_purchase"):
                    total_purchases += val

        if total_leads > 0 and total_purchases > 0 and total_spend > 0:
            cpl = total_spend / total_leads
            cpa_purchase = total_spend / total_purchases
            # Se CPL > 3x CPA compra, o funil de captacao esta ineficiente
            if cpl > cpa_purchase * 3 and should_alert(slug, "funnel_gap", 7):
                alerts.append(
                    f"📊 {info['nome']}: CPL R${cpl:.2f} vs CPA compra R${cpa_purchase:.2f} — "
                    f"funil de captacao ineficiente (leads caros mas conversao boa). "
                    f"Sugestao: otimizar formularios/landing pages ou focar budget em campanhas de venda direta."
                )
    except:
        pass  # Erros de API ja capturados no loop principal

# Save state
with open(STATE_FILE, "w") as f:
    json.dump(state, f, indent=2)

# Output
if alerts:
    print("ALERTS=" + json.dumps(alerts))
else:
    print("ALERTS=[]")
PYEOF

RESULT=$(python3 "$TMP_PY" 2>&1)
rm -f "$TMP_PY"

ALERTS_JSON=$(echo "$RESULT" | grep "^ALERTS=" | cut -d= -f2-)
ALERT_COUNT=$(echo "$ALERTS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [ "$ALERT_COUNT" -gt 0 ]; then
    # Format and send alerts
    ALERT_MSG=$(echo "$ALERTS_JSON" | python3 -c "
import json, sys
alerts = json.load(sys.stdin)
print('🐺 Gabi — Alertas de Trafego\n')
for a in alerts:
    print(a)
")

    wolf_notify_urgent "$ALERT_MSG"

    # Log alerts
    echo "$ALERTS_JSON" | python3 -c "
import json, sys
from datetime import datetime
alerts = json.load(sys.stdin)
today = datetime.now().strftime('%Y-%m-%d %H:%M')
for a in alerts:
    # Parse type from emoji
    tipo = 'info'
    if '🚨' in a: tipo = 'CPA Spike'
    elif '📉' in a: tipo = 'CTR Drop'
    elif '🔴' in a: tipo = 'Zero Impressions'
    elif '🔑' in a: tipo = 'Token'
    elif '⚠️' in a: tipo = 'API Error'
    # Extract client name
    parts = a.split(':',1)
    client = parts[0].replace('🚨','').replace('📉','').replace('🔴','').replace('🔑','').replace('⚠️','').strip()
    msg = parts[1].strip() if len(parts)>1 else a
    print(f'| {today} | {client} | {tipo} | {msg[:80]} |')
" >> "$ALERTS_LOG"

    wolf_log "gabi-alerts" "Enviou $ALERT_COUNT alertas"
else
    wolf_log "gabi-alerts" "Nenhum alerta — tudo OK"
fi

echo "OK: gabi-proactive-alerts completed ($ALERT_COUNT alerts) at $(date '+%Y-%m-%d %H:%M:%S')"
