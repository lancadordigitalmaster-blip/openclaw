#!/bin/bash
# natiely.sh — Executor do agente Natiely (integrado com ClickUp)
# Uso: ./natiely.sh [comando] [args]
# Atualizado: 2026-03-18 — integração real com ClickUp API

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$HOME/.openclaw/workspace"

# Carregar lib-wolf se disponível
source "$WORKSPACE/scripts/lib-wolf.sh" 2>/dev/null || true

# Carregar .env
set -a
source "$HOME/.openclaw/.env" 2>/dev/null
set +a

TOKEN="${CLICKUP_API_TOKEN:-}"
TEAM_ID="3076130"
LIST_PRODUCAO="901306028132"
LIST_CRIATIVO="901306028133"
DESIGN_FIELD="b9b3676c-f119-48cf-851d-8ebd83e5011f"

COMMAND=${1:-help}

if [[ -z "$TOKEN" && "$COMMAND" != "help" ]]; then
  echo "ERRO: CLICKUP_API_TOKEN nao definido no ~/.openclaw/.env"
  exit 1
fi

case $COMMAND in
  relatorio)
    python3 << 'PYEOF'
import urllib.request, json, os, sys
from datetime import datetime, timezone, timedelta

# Load env
for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v

TOKEN = os.environ.get("CLICKUP_API_TOKEN", "")
TEAM_ID = "3076130"
LIST_IDS = ["901306028132", "901306028133"]
DESIGN_FIELD = "b9b3676c-f119-48cf-851d-8ebd83e5011f"

BRT = timezone(timedelta(hours=-3))
now = datetime.now(BRT)
today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
today_start_ms = int(today_start.timestamp() * 1000)
now_ms = int(now.timestamp() * 1000)

DESIGNER_MAP = {1: "Eliedson", 2: "Rodrigo Bispo", 3: "Leoneli", 4: "Felipe",
                5: "Levi", 6: "Pedro", 7: "Rodrigo Web", 11: "Abilio"}
METAS = {"Pedro": 17, "Leoneli": 12, "Abilio": 14, "Eliedson": 8, "Levi": 2}

def api(path, params=""):
    url = f"https://api.clickup.com/api/v2/{path}"
    if params:
        url += f"?{params}"
    req = urllib.request.Request(url, headers={"Authorization": TOKEN})
    return json.loads(urllib.request.urlopen(req, timeout=15).read())

# Fetch active tasks
all_tasks = []
for lid in LIST_IDS:
    page = 0
    while True:
        data = api(f"list/{lid}/task", f"include_closed=false&subtasks=false&page={page}")
        tasks = data.get("tasks", [])
        all_tasks.extend(tasks)
        if data.get("last_page", True) or not tasks:
            break
        page += 1

# Fetch produção do dia
# Regra: "finalizada", "enviado ao cliente", "conferência interna" = produção do designer
# "em alteração" criada hoje = demanda nova | criada outro dia = alteração (não conta como nova)
done_today = []
alteracoes_hoje = []
for lid in LIST_IDS:
    page = 0
    while True:
        data = api(f"list/{lid}/task", f"include_closed=true&date_updated_gt={today_start_ms}&subtasks=false&page={page}")
        tasks = data.get("tasks", [])
        for t in tasks:
            status = (t.get("status", {}).get("status") or "").lower()
            if status == "finalizada":
                dc = int(t.get("date_closed") or 0)
                if dc >= today_start_ms:
                    done_today.append(t)
            elif status in ["enviado ao cliente", u"confer\u00eancia interna", "conferencia interna"]:
                done_today.append(t)
            elif "alterac" in status or "altera\u00e7" in status:
                date_created = int(t.get("date_created") or 0)
                if date_created >= today_start_ms:
                    done_today.append(t)  # Criada e produzida no mesmo dia = demanda nova
                else:
                    alteracoes_hoje.append(t)  # Veio de outro dia = alteração
        if data.get("last_page", True) or not tasks:
            break
        page += 1

# Map designer per task
def get_designer(task):
    for cf in task.get("custom_fields", []):
        if cf.get("id") == DESIGN_FIELD:
            val = cf.get("value")
            if val is not None:
                return DESIGNER_MAP.get(int(val), f"ID:{val}")
    return None

# Count per designer
designer_active = {}
designer_done = {}
designer_alter = {}
for t in all_tasks:
    d = get_designer(t)
    if d:
        designer_active[d] = designer_active.get(d, 0) + 1
for t in done_today:
    d = get_designer(t)
    if d:
        designer_done[d] = designer_done.get(d, 0) + 1
for t in alteracoes_hoje:
    d = get_designer(t)
    if d:
        designer_alter[d] = designer_alter.get(d, 0) + 1

total_alter = len(alteracoes_hoje)

# Output
print(f"📊 RELATÓRIO DE DEMANDA – DESIGNERS")
print(f"📅 {now.strftime('%d/%m/%Y')} | ⏰ {now.strftime('%H:%M')}")
print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(f"📦 Total ativas: {len(all_tasks)} | Produção hoje: {len(done_today)} | Alterações: {total_alter}")
print()
print(f"👤 CARGA POR DESIGNER")

for name in ["Pedro", "Leoneli", "Abilio", "Eliedson", "Levi"]:
    ativas = designer_active.get(name, 0)
    feitas = designer_done.get(name, 0)
    alter = designer_alter.get(name, 0)
    meta = METAS.get(name, 0)
    alter_str = f" +{alter}alt" if alter > 0 else ""
    if meta > 0:
        pct = int(feitas / meta * 100)
        icon = "✅" if feitas >= meta else ("⚠️" if feitas >= meta * 0.7 else "🚨")
    else:
        pct = 0
        icon = "—"
    print(f"  {icon} {name:12s} {feitas:2d}/{meta:2d} prod ({pct}%){alter_str} | {ativas} ativas")

# Freelancers
for name in ["Felipe", "Rodrigo Bispo", "Rodrigo Web"]:
    ativas = designer_active.get(name, 0)
    feitas = designer_done.get(name, 0)
    alter = designer_alter.get(name, 0)
    alter_str = f" +{alter}alt" if alter > 0 else ""
    if ativas > 0 or feitas > 0:
        print(f"  — {name:12s} {feitas:2d} prod{alter_str} | {ativas} ativas (freelancer)")

print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
PYEOF
    ;;

  validar)
    python3 << 'PYEOF'
import urllib.request, json, os
from datetime import datetime, timezone, timedelta

for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v

TOKEN = os.environ.get("CLICKUP_API_TOKEN", "")
LIST_IDS = ["901306028132", "901306028133"]
DESIGN_FIELD = "b9b3676c-f119-48cf-851d-8ebd83e5011f"

def api(path, params=""):
    url = f"https://api.clickup.com/api/v2/{path}"
    if params:
        url += f"?{params}"
    req = urllib.request.Request(url, headers={"Authorization": TOKEN})
    return json.loads(urllib.request.urlopen(req, timeout=15).read())

all_tasks = []
for lid in LIST_IDS:
    data = api(f"list/{lid}/task", "include_closed=false&subtasks=false&page=0")
    all_tasks.extend(data.get("tasks", []))

sem_designer = []
sem_descricao = []
sem_prazo = []

for t in all_tasks:
    status = (t.get("status", {}).get("status") or "").lower()
    if "congelado" in status or "backlog" in status:
        continue

    # Sem designer
    has_designer = False
    for cf in t.get("custom_fields", []):
        if cf.get("id") == DESIGN_FIELD and cf.get("value") is not None:
            has_designer = True
    if not has_designer:
        sem_designer.append(t["name"][:50])

    # Sem descrição
    desc = t.get("description") or ""
    if len(desc.strip()) < 20:
        sem_descricao.append(t["name"][:50])

    # Sem prazo
    if not t.get("due_date"):
        sem_prazo.append(t["name"][:50])

BRT = timezone(timedelta(hours=-3))
now = datetime.now(BRT)
print(f"🔍 VALIDAÇÃO DE TAREFAS")
print(f"📅 {now.strftime('%d/%m/%Y')} | Total verificadas: {len(all_tasks)}")
print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

if sem_designer:
    print(f"\n👤 SEM DESIGNER ({len(sem_designer)}):")
    for n in sem_designer[:10]:
        print(f"  • {n}")

if sem_descricao:
    print(f"\n📝 SEM DESCRIÇÃO ({len(sem_descricao)}):")
    for n in sem_descricao[:10]:
        print(f"  • {n}")

if sem_prazo:
    print(f"\n📅 SEM PRAZO ({len(sem_prazo)}):")
    for n in sem_prazo[:10]:
        print(f"  • {n}")

if not sem_designer and not sem_descricao and not sem_prazo:
    print("✅ Todas as tarefas estão completas!")

print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
PYEOF
    ;;

  alertas)
    python3 << 'PYEOF'
import urllib.request, json, os
from datetime import datetime, timezone, timedelta

for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v

TOKEN = os.environ.get("CLICKUP_API_TOKEN", "")
LIST_IDS = ["901306028132", "901306028133"]
DESIGN_FIELD = "b9b3676c-f119-48cf-851d-8ebd83e5011f"
DESIGNER_MAP = {1: "Eliedson", 2: "Rodrigo Bispo", 3: "Leoneli", 4: "Felipe",
                5: "Levi", 6: "Pedro", 7: "Rodrigo Web", 11: "Abilio"}

def api(path, params=""):
    url = f"https://api.clickup.com/api/v2/{path}"
    if params:
        url += f"?{params}"
    req = urllib.request.Request(url, headers={"Authorization": TOKEN})
    return json.loads(urllib.request.urlopen(req, timeout=15).read())

def get_designer(task):
    for cf in task.get("custom_fields", []):
        if cf.get("id") == DESIGN_FIELD:
            val = cf.get("value")
            if val is not None:
                return DESIGNER_MAP.get(int(val), f"ID:{val}")
    return "?"

all_tasks = []
for lid in LIST_IDS:
    data = api(f"list/{lid}/task", "include_closed=false&subtasks=false&page=0")
    all_tasks.extend(data.get("tasks", []))

BRT = timezone(timedelta(hours=-3))
now = datetime.now(BRT)
now_ms = int(now.timestamp() * 1000)

# SLA checks
dead = []       # >14 dias backlog
sem_data = []   # para fazer sem due_date
alteracao = []  # em alteração >48h
bloqueio = []   # pausado/bloqueado >7d
fluxo = []      # conferência interna >2h
followup = []   # enviado ao cliente >24h
vencidas = []   # due_date passada

for t in all_tasks:
    status = (t.get("status", {}).get("status") or "").lower()
    updated = int(t.get("date_updated") or 0)
    hours_since = (now_ms - updated) / 3600000 if updated else 0
    designer = get_designer(t)
    name = t["name"][:45]

    if "congelado" in status and hours_since > 336:
        dead.append(f"{name} — {designer} — {int(hours_since/24)}d")
    if "para fazer" in status and not t.get("due_date"):
        sem_data.append(f"{name} — {designer}")
    if "alterac" in status and hours_since > 48:
        alteracao.append(f"{name} — {designer} — {int(hours_since)}h")
    if ("pausado" in status or "bloqueado" in status) and hours_since > 168:
        bloqueio.append(f"{name} — {designer} — {int(hours_since/24)}d")
    if "conferencia" in status or "conferência" in status:
        if hours_since > 2:
            fluxo.append(f"{name} — {designer} — {int(hours_since)}h")
    if "enviado" in status and "cliente" in status and hours_since > 24:
        followup.append(f"{name} — {designer} — {int(hours_since)}h")

    due = int(t.get("due_date") or 0)
    if due > 0 and due < now_ms:
        days_late = int((now_ms - due) / 86400000)
        vencidas.append(f"{name} — {designer} — {days_late}d atraso")

print(f"🚨 ALERTAS DE SLA")
print(f"📅 {now.strftime('%d/%m/%Y %H:%M')}")
print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

total_alerts = 0
for label, icon, items in [
    ("Tarefas mortas (>14d backlog)", "☠️", dead),
    ("Sem data (para fazer)", "📅", sem_data),
    ("Alterações esquecidas (>48h)", "✏️", alteracao),
    ("Bloqueios críticos (>7d)", "🔒", bloqueio),
    ("Fluxo travado (conf.interna >2h)", "⚡", fluxo),
    ("Follow-ups pendentes (>24h)", "📬", followup),
    ("Tarefas vencidas", "🔴", vencidas),
]:
    if items:
        total_alerts += len(items)
        print(f"\n{icon} {label} ({len(items)}):")
        for item in items[:8]:
            print(f"  • {item}")

if total_alerts == 0:
    print("\n✅ Nenhum alerta ativo — operação fluindo!")

print(f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(f"Total: {total_alerts} alertas | {len(all_tasks)} tarefas analisadas")
PYEOF
    ;;

  metricas)
    python3 << 'PYEOF'
import urllib.request, json, os
from datetime import datetime, timezone, timedelta

for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v

TOKEN = os.environ.get("CLICKUP_API_TOKEN", "")
LIST_IDS = ["901306028132", "901306028133"]

def api(path, params=""):
    url = f"https://api.clickup.com/api/v2/{path}"
    if params:
        url += f"?{params}"
    req = urllib.request.Request(url, headers={"Authorization": TOKEN})
    return json.loads(urllib.request.urlopen(req, timeout=15).read())

BRT = timezone(timedelta(hours=-3))
now = datetime.now(BRT)
now_ms = int(now.timestamp() * 1000)
week_ago_ms = now_ms - (7 * 86400000)

# Active tasks
all_tasks = []
for lid in LIST_IDS:
    data = api(f"list/{lid}/task", "include_closed=false&subtasks=false&page=0")
    all_tasks.extend(data.get("tasks", []))

# Completed this week
done_week = []
for lid in LIST_IDS:
    data = api(f"list/{lid}/task", f"include_closed=true&statuses[]=finalizada&date_updated_gt={week_ago_ms}&page=0")
    for t in data.get("tasks", []):
        dc = int(t.get("date_closed") or 0)
        if dc >= week_ago_ms:
            done_week.append(t)

# WIP (em andamento, em produção, etc)
wip_statuses = ["em andamento", "em producao", "em produção", "produzindo"]
wip = [t for t in all_tasks if (t.get("status", {}).get("status") or "").lower() in wip_statuses]

# Aging (>3 dias sem update)
aging = [t for t in all_tasks if (now_ms - int(t.get("date_updated") or now_ms)) > 259200000]

# Evidence coverage (tarefas com descrição)
with_desc = [t for t in all_tasks if len((t.get("description") or "").strip()) >= 20]
coverage = int(len(with_desc) / len(all_tasks) * 100) if all_tasks else 0

print(f"📈 MÉTRICAS DE FLUXO")
print(f"📅 {now.strftime('%d/%m/%Y %H:%M')}")
print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(f"📦 Ativas:              {len(all_tasks)}")
print(f"✅ Finalizadas (7d):    {len(done_week)}")
print(f"🔄 WIP (em andamento):  {len(wip)}")
print(f"⏳ Aging (>3d paradas): {len(aging)}")
print(f"📝 Evidence Coverage:   {coverage}%")
print(f"📊 Throughput semanal:  {len(done_week)} tarefas")
if done_week:
    avg_per_day = len(done_week) / 7
    print(f"📊 Média diária:        {avg_per_day:.1f} tarefas/dia")
print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
PYEOF
    ;;

  help|*)
    echo "🎯 Natiely — Project Ops Agent (ClickUp integrado)"
    echo ""
    echo "Uso: natiely.sh [comando]"
    echo ""
    echo "Comandos:"
    echo "  relatorio    Relatório de demanda por designer (com metas)"
    echo "  validar      Validação de tarefas (campos obrigatórios)"
    echo "  alertas      Alertas de SLA (deadlines, gargalos)"
    echo "  metricas     KPIs de fluxo (WIP, throughput, aging)"
    echo "  help         Mostra esta ajuda"
    echo ""
    echo "Requisitos: CLICKUP_API_TOKEN no ~/.openclaw/.env"
    echo ""
    ;;
esac
