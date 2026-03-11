#!/bin/bash
# ============================================================
# WOLF CLICKUP CHECK — Auditoria deterministica (sem LLM)
# Busca tarefas do ClickUp, calcula metricas, envia Telegram
# ============================================================
set -euo pipefail

set -a
source "$HOME/.openclaw/.env"
set +a
TOKEN="${CLICKUP_API_TOKEN:-}"
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="789352357"  # Netto DM
LOG="/tmp/wolf-clickup-check.log"
TEAM_ID="3076130"
LIST_IDS="901306028132,901306028133"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ClickUp Check iniciado" > "$LOG"

if [[ -z "$TOKEN" ]]; then
  echo "ERRO: CLICKUP_API_TOKEN nao definido no .env" >> "$LOG"
  exit 1
fi

# Fetch and analyze via Python (deterministic, no LLM)
RESULT=$(python3 << 'PYEOF'
import urllib.request, json, os, sys
from datetime import datetime, timezone, timedelta

# Load .env if not already in environment
if not os.environ.get("CLICKUP_API_TOKEN"):
    env_path = os.path.expanduser("~/.openclaw/.env")
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k] = v

TOKEN = os.environ.get("CLICKUP_API_TOKEN", "")
TEAM_ID = "3076130"
LIST_IDS = ["901306028132", "901306028133"]
DESIGN_FIELD = "b9b3676c-f119-48cf-851d-8ebd83e5011f"

# Designer index -> name mapping
DESIGNERS = {1: "Eliedson", 2: "Rodrigo Bispo", 3: "Leoneli", 4: "Felipe",
             5: "Levi", 6: "Pedro", 7: "Rodrigo Web", 11: "Abilio"}
# Daily goals
GOALS = {"Pedro": 17, "Leoneli": 12, "Abilio": 14, "Eliedson": 8, "Levi": 2}

now = datetime.now(timezone(timedelta(hours=-3)))  # BRT
today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
today_start_ms = int(today_start.timestamp() * 1000)

headers = {"Authorization": TOKEN, "Content-Type": "application/json"}

def api_get(path):
    url = f"https://api.clickup.com/api/v2/{path}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except Exception as e:
        print(f"ERRO API: {e}", file=sys.stderr)
        return None

# PASSO 1 — Active tasks
active_tasks = []
for lid in LIST_IDS:
    data = api_get(f"list/{lid}/task?include_closed=false&subtasks=false&page=0")
    if data and "tasks" in data:
        active_tasks.extend(data["tasks"])

# PASSO 2 — Completed today
completed_tasks = []
for lid in LIST_IDS:
    data = api_get(f"list/{lid}/task?include_closed=true&subtasks=false&page=0&statuses%5B%5D=finalizada&order_by=updated&reverse=true")
    if data and "tasks" in data:
        for t in data["tasks"]:
            date_closed = t.get("date_closed")
            if date_closed and int(date_closed) >= today_start_ms:
                completed_tasks.append(t)

# Extract designer from custom fields
def get_designer(task):
    for cf in task.get("custom_fields", []):
        if cf.get("id") == DESIGN_FIELD:
            val = cf.get("value")
            if val is not None:
                try:
                    return DESIGNERS.get(int(val), f"#{val}")
                except (ValueError, TypeError):
                    pass
    # Fallback to assignees
    assignees = task.get("assignees", [])
    if assignees:
        return assignees[0].get("username", "?")
    return "Sem designer"

# Per-designer stats
designer_active = {}
designer_done = {}
for t in active_tasks:
    d = get_designer(t)
    designer_active[d] = designer_active.get(d, 0) + 1
for t in completed_tasks:
    d = get_designer(t)
    designer_done[d] = designer_done.get(d, 0) + 1

# SLA alerts
now_ms = int(now.timestamp() * 1000)
alerts = {"mortas": 0, "sem_data": 0, "alteracao_esquecida": 0,
          "bloqueio": 0, "fluxo_travado": 0, "followup": 0}
overdue = []
at_risk = []

for t in active_tasks:
    status = (t.get("status", {}).get("status", "") or "").lower().replace("ã", "a").replace("ç", "c").replace("ê", "e")
    updated = int(t.get("date_updated", "0") or "0")
    hours_in_status = (now_ms - updated) / 3600000 if updated else 0
    due = t.get("due_date")

    if "backlog" in status and "congelado" in status and hours_in_status > 336:
        alerts["mortas"] += 1
    if "para fazer" in status and not due:
        alerts["sem_data"] += 1
    if "alterac" in status and hours_in_status > 48:
        alerts["alteracao_esquecida"] += 1
    if ("pausado" in status or "bloqueado" in status) and hours_in_status > 168:
        alerts["bloqueio"] += 1
    if "conferencia" in status and hours_in_status > 2:
        alerts["fluxo_travado"] += 1
    if "enviado" in status and "cliente" in status and hours_in_status > 24:
        alerts["followup"] += 1

    if due:
        due_ms = int(due)
        if due_ms < now_ms:
            days_late = (now_ms - due_ms) / 86400000
            overdue.append((t["name"][:30], get_designer(t), f"{days_late:.0f}d"))
        elif due_ms <= now_ms + 86400000:
            at_risk.append((t["name"][:30], get_designer(t)))

# Build report
date_str = now.strftime("%d/%m %H:%M")
total_active = len(active_tasks)
total_done = len(completed_tasks)
total_alerts = sum(alerts.values())

lines = []
lines.append(f"AUDITORIA WOLF -- {date_str}")
lines.append("=" * 30)
lines.append(f"Ativas: {total_active} | Finalizadas hoje: {total_done}")
lines.append("")

# Designer performance
lines.append("DESIGNERS vs META")
all_designers = sorted(set(list(GOALS.keys()) + list(designer_active.keys()) + list(designer_done.keys())))
for d in all_designers:
    done = designer_done.get(d, 0)
    active = designer_active.get(d, 0)
    goal = GOALS.get(d)
    if goal:
        pct = (done / goal * 100) if goal else 0
        icon = "OK" if done >= goal else ("BAIXO" if done < goal * 0.7 else "ATENCAO")
        lines.append(f"  {d}: [{icon}] {done}fin/{goal} | {active} ativas")
    elif d in DESIGNERS.values():
        lines.append(f"  {d}: {done}fin | {active} ativas (freelancer)")

if total_alerts > 0:
    lines.append("")
    lines.append("ALERTAS SLA")
    if alerts["mortas"]: lines.append(f"  Tarefas mortas (>14d backlog): {alerts['mortas']}")
    if alerts["sem_data"]: lines.append(f"  Sem data (para fazer): {alerts['sem_data']}")
    if alerts["alteracao_esquecida"]: lines.append(f"  Alteracoes esquecidas (>48h): {alerts['alteracao_esquecida']}")
    if alerts["bloqueio"]: lines.append(f"  Bloqueios criticos (>7d): {alerts['bloqueio']}")
    if alerts["fluxo_travado"]: lines.append(f"  Fluxo travado (conf.interna>2h): {alerts['fluxo_travado']}")
    if alerts["followup"]: lines.append(f"  Follow-ups pendentes (>24h): {alerts['followup']}")

if overdue:
    lines.append("")
    lines.append(f"VENCIDOS: {len(overdue)}")
    for name, designer, late in overdue[:5]:
        lines.append(f"  {name} -- {designer} -- {late} atraso")

if at_risk:
    lines.append("")
    lines.append(f"EM RISCO (<=24h): {len(at_risk)}")
    for name, designer in at_risk[:5]:
        lines.append(f"  {name} -- {designer}")

lines.append("")
lines.append("=" * 30)

print("\n".join(lines))
PYEOF
)

echo "$RESULT" >> "$LOG"

# Check for errors
if echo "$RESULT" | grep -q "ERRO API"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Falha na API do ClickUp" >> "$LOG"
  exit 1
fi

# Send via Telegram
if [[ -z "$TELEGRAM_TOKEN" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: TELEGRAM_BOT_TOKEN nao definido" >> "$LOG"
  exit 1
fi

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  --data-urlencode "text=$RESULT" \
  >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enviado com sucesso" >> "$LOG"
