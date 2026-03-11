#!/usr/bin/env python3
"""
guardiao-produtividade.py — Módulo 13: Produtividade Real (coleta diária).

Roda às 07h45 seg-sex via crontab (junto com guardiao-analytics.py).

Fase 1 — SILENT_MODE = True:
  Coleta e registra em memory.json, NÃO envia mensagem.
  Objetivo: calibrar pesos e validar números por 1 semana.

Fase 2 — SILENT_MODE = False:
  Ativa relatório diário para [ATD] Gestão.

TIPO_MATERIAL_FIELD_ID: deixar vazio até o campo ser criado no ClickUp.
  Quando vazio: todas entregas contam com peso DEFAULT_WEIGHT = 2.
  Quando configurado: usa tabela de pesos por tipo.
"""

import urllib.request, json, os, sys, time
from datetime import datetime, timezone, timedelta

# ── Configuração ──────────────────────────────────────────────────────────────
ENV_FILE     = os.path.expanduser("~/.openclaw/.env")
MEMORY_FILE  = os.path.expanduser("~/.openclaw/guardiao-memory.json")
HISTORY_FILE = os.path.expanduser("~/openclaw/whatsapp-bridge/clickup-history.jsonl")
LOG_FILE     = os.path.expanduser("~/openclaw/whatsapp-bridge/logs/guardiao.log")
BRIDGE_API   = "http://127.0.0.1:3002/send"

BRT   = timezone(timedelta(hours=-3))
LISTS = ["901306028132", "901306028133"]

# ── Fase de ativação ──────────────────────────────────────────────────────────
# Semana 1: True (coleta silenciosa, sem mensagem)
# Semana 2+: False (ativa relatório)
SILENT_MODE = True

# ── Campo tipo_material ───────────────────────────────────────────────────────
# Preencher após criar o campo no ClickUp (Settings > Custom Fields)
TIPO_MATERIAL_FIELD_ID = ""   # ex: "abc123-..."
DEFAULT_WEIGHT = 2             # peso conservador quando campo não existe/preenchido

# Campos existentes
DESIGN_FIELD = "b9b3676c-f119-48cf-851d-8ebd83e5011f"
ATD_FIELD    = "00e6513e-ef48-4262-aa2f-1288f8ebed72"

DESIGNERS = {
    0:"Bruno", 1:"Eliedson", 2:"Rodrigo", 3:"Leoneli",
    4:"Felipe", 5:"Levi", 6:"Pedro", 7:"Rodrigo Web",
    8:"Lucas", 9:"Matheus", 10:"Vinicius", 11:"Abilio"
}
ATENDIMENTO = {
    0:"Mirelli", 1:"Mariana", 2:"Natiely",
    5:"Sindy", 6:"Thalita", 7:"Marina", 8:"Cibele", 9:"Yasmin",
    10:"Matheus", 12:"Gabriela"
}

ATD_GESTAO_GROUP = "120363163709134922@g.us"

# ── Tabela de pesos — Designer ─────────────────────────────────────────────────
WEIGHT_DESIGNER = {
    "post_static":    1,
    "carousel":       2,
    "branding_elem":  2,
    "reels_short":    3,
    "copy_ad":        3,
    "motion":         4,
    "reels_long":     4,
    "copy_page":      5,
    "presentation":   5,
    "email_seq":      5,
    "report":         3,
    "video_youtube":  6,
    "branding_logo":  7,
    "branding_iv":   10,
    "other":          2,
}

# ── Tabela de pesos — Atendimento ──────────────────────────────────────────────
WEIGHT_ATD = {
    "post_static":    1,
    "carousel":       1,
    "copy_ad":        2,
    "reels_short":    2,
    "reels_long":     3,
    "motion":         3,
    "email_seq":      4,
    "copy_page":      4,
    "presentation":   4,
    "video_youtube":  5,
    "report":         3,
    "branding_logo":  6,
    "branding_iv":    9,
    "branding_elem":  2,
    "other":          2,
}

WEEKDAY_PT = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

# ── Utilitários ───────────────────────────────────────────────────────────────
def log(msg):
    ts = datetime.now(BRT).strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] [produtividade] {msg}"
    print(line)
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a") as f: f.write(line + "\n")

def load_env():
    env = {}
    try:
        for line in open(ENV_FILE):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); env[k] = v
    except: pass
    return env

def api_get(url, token):
    req = urllib.request.Request(url, headers={"Authorization": token})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)

def send_whatsapp(jid, text):
    payload = {"to": jid, "text": text}
    data = json.dumps(payload).encode()
    req = urllib.request.Request(BRIDGE_API, data=data,
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r).get("ok", False)
    except Exception as e:
        log(f"ERRO WhatsApp: {e}"); return False

# ── Memory ────────────────────────────────────────────────────────────────────
def load_memory():
    if not os.path.exists(MEMORY_FILE): return {}
    try:
        with open(MEMORY_FILE) as f: return json.load(f)
    except: return {}

def save_memory(mem):
    os.makedirs(os.path.dirname(MEMORY_FILE), exist_ok=True)
    mem["last_updated"] = datetime.now(BRT).strftime("%Y-%m-%d %H:%M:%S")
    with open(MEMORY_FILE, "w") as f:
        json.dump(mem, f, indent=2, ensure_ascii=False)

def _prod_record_designer(mem, name):
    """Garante estrutura de produtividade para um designer."""
    if "designers" not in mem:
        mem["designers"] = {}
    if name not in mem["designers"]:
        mem["designers"][name] = {}
    rec = mem["designers"][name]
    if "productivity" not in rec:
        rec["productivity"] = {
            "deliveries_today": 0, "points_today": 0,
            "deliveries_week": 0,  "points_week": 0,
            "deliveries_month": 0, "points_month": 0,
            "by_type": {},
            "daily_history": [],
            "avg_points_30d": 0,
            "score_productivity": 50,  # começa neutro
        }
    return rec["productivity"]

def _prod_record_atd(mem, name):
    """Garante estrutura de produtividade para um atendente."""
    if "atendentes" not in mem:
        mem["atendentes"] = {}
    if name not in mem["atendentes"]:
        mem["atendentes"][name] = {}
    rec = mem["atendentes"][name]
    if "productivity" not in rec:
        rec["productivity"] = {
            "briefings_today": 0, "points_today": 0,
            "briefings_week": 0,  "points_week": 0,
            "briefings_month": 0, "points_month": 0,
            "active_clients_month": 0,
            "quality_rate": 1.0,
            "by_type": {},
            "daily_history": [],
            "avg_points_30d": 0,
            "score_productivity": 50,
        }
    return rec["productivity"]

# ── ClickUp helpers ────────────────────────────────────────────────────────────
def get_field_value(task, field_id):
    for f in task.get("custom_fields", []):
        if f.get("id") == field_id:
            return f.get("value")
    return None

def get_designer_name(task):
    val = get_field_value(task, DESIGN_FIELD)
    if val is not None:
        try: return DESIGNERS.get(int(val))
        except: pass
    return None

def get_atd_name(task):
    val = get_field_value(task, ATD_FIELD)
    if val is not None:
        try: return ATENDIMENTO.get(int(val))
        except: pass
    return None

def get_tipo_material(task):
    """Retorna o tipo_material da tarefa, ou None se campo não configurado/preenchido."""
    if not TIPO_MATERIAL_FIELD_ID:
        return None
    val = get_field_value(task, TIPO_MATERIAL_FIELD_ID)
    if val is None:
        return None
    # O campo dropdown retorna o nome da opção ou um índice
    if isinstance(val, str):
        return val.lower().replace(" ", "_")
    return None

def get_weight_designer(tipo):
    if not tipo:
        return DEFAULT_WEIGHT
    return WEIGHT_DESIGNER.get(tipo, DEFAULT_WEIGHT)

def get_weight_atd(tipo, quality_ok=True):
    base = WEIGHT_ATD.get(tipo, DEFAULT_WEIGHT) if tipo else DEFAULT_WEIGHT
    if quality_ok:
        return base
    return base  # multiplicador aplicado depois (× 0.8 ou × 1.2)

# ── Busca tarefas entregues ontem ─────────────────────────────────────────────
def load_history_deliveries(yesterday_str):
    """
    Lê clickup-history.jsonl e retorna set de task_ids que mudaram para
    'enviado ao cliente' ou 'finalizado' na data de ontem.

    Formato confirmado do JSONL:
      {"task_id": "...", "event": "taskStatusUpdated",
       "status_before": "...", "status_after": "...",
       "timestamp": 1773199837056, "date": "2026-03-11"}
    """
    DELIVERY_STATUSES = {"enviado ao cliente", "finalizado", "concluído", "done"}
    delivered_ids = set()

    if not os.path.exists(HISTORY_FILE):
        log("History file não encontrado — usando apenas ClickUp API")
        return delivered_ids

    try:
        with open(HISTORY_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                    if (ev.get("date") == yesterday_str and
                            ev.get("status_after", "").lower() in DELIVERY_STATUSES):
                        delivered_ids.add(ev["task_id"])
                except:
                    pass
    except Exception as e:
        log(f"ERRO lendo history: {e}")

    log(f"History: {len(delivered_ids)} task_ids entregues ontem ({yesterday_str})")
    return delivered_ids

def load_history_briefings(yesterday_str):
    """
    Retorna set de task_ids que entraram em 'produzindo' ontem (início de produção = briefing criado).
    """
    PRODUCTION_START = {"produzindo", "em produção"}
    briefing_ids = set()

    if not os.path.exists(HISTORY_FILE):
        return briefing_ids

    try:
        with open(HISTORY_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                    if (ev.get("date") == yesterday_str and
                            ev.get("status_after", "").lower() in PRODUCTION_START and
                            ev.get("status_before", "").lower() == "para fazer"):
                        briefing_ids.add(ev["task_id"])
                except:
                    pass
    except Exception as e:
        log(f"ERRO lendo history briefings: {e}")

    log(f"History: {len(briefing_ids)} task_ids com novo briefing ontem ({yesterday_str})")
    return briefing_ids

def fetch_tasks_by_ids(task_ids, token):
    """Busca detalhes de tarefas por ID (para enriquecer dados do history)."""
    tasks = []
    for tid in task_ids:
        try:
            t = api_get(f"https://api.clickup.com/api/v2/task/{tid}", token)
            tasks.append(t)
        except Exception as e:
            log(f"ERRO busca task {tid}: {e}")
    return tasks

def fetch_delivered_yesterday(token):
    """
    Retorna lista de tarefas entregues ontem.
    Fonte primária: clickup-history.jsonl (status_after = enviado/finalizado, date = ontem)
    Fallback: ClickUp API com filtro date_done (apenas tarefas fechadas)
    """
    now       = datetime.now(BRT)
    yesterday = now - timedelta(days=1)
    yesterday_str = yesterday.strftime("%Y-%m-%d")

    day_start = datetime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0, tzinfo=BRT)
    day_end   = day_start + timedelta(days=1)
    start_ms  = int(day_start.timestamp() * 1000)
    end_ms    = int(day_end.timestamp()   * 1000)

    delivered = []
    seen_ids  = set()

    # 1. Fonte primária: history file
    history_ids = load_history_deliveries(yesterday_str)
    if history_ids:
        tasks = fetch_tasks_by_ids(history_ids, token)
        for t in tasks:
            t["_delivery_type"] = "history"
            delivered.append(t)
            seen_ids.add(t["id"])

    # 2. Fallback API: tarefas fechadas com date_done de ontem (complementa history)
    for list_id in LISTS:
        try:
            url = (f"https://api.clickup.com/api/v2/list/{list_id}/task"
                   f"?include_closed=true&subtasks=true&page=0"
                   f"&date_done_gt={start_ms}&date_done_lt={end_ms}")
            data = api_get(url, token)
            for t in data.get("tasks", []):
                if t["id"] not in seen_ids:
                    t["_delivery_type"] = "api_closed"
                    delivered.append(t)
                    seen_ids.add(t["id"])
        except Exception as e:
            log(f"ERRO busca fechadas lista {list_id}: {e}")

    log(f"Total entregas ontem: {len(delivered)} (history:{len(history_ids)} + api complementar)")
    return delivered

def fetch_briefings_yesterday(token):
    """
    Retorna tarefas com briefing criado ontem.
    Fonte primária: history file (para fazer → produzindo = briefing criado)
    Fallback: tarefas criadas ontem via ClickUp API
    """
    now           = datetime.now(BRT)
    yesterday     = now - timedelta(days=1)
    yesterday_str = yesterday.strftime("%Y-%m-%d")

    day_start = datetime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0, tzinfo=BRT)
    day_end   = day_start + timedelta(days=1)
    start_ms  = int(day_start.timestamp() * 1000)
    end_ms    = int(day_end.timestamp()   * 1000)

    briefings = []
    seen_ids  = set()

    # 1. Fonte primária: history (para fazer → produzindo ontem)
    history_ids = load_history_briefings(yesterday_str)
    if history_ids:
        tasks = fetch_tasks_by_ids(history_ids, token)
        for t in tasks:
            briefings.append(t)
            seen_ids.add(t["id"])

    # 2. Fallback: tarefas criadas ontem (sem history ou complementar)
    for list_id in LISTS:
        try:
            url = (f"https://api.clickup.com/api/v2/list/{list_id}/task"
                   f"?include_closed=false&subtasks=true&page=0"
                   f"&date_created_gt={start_ms}&date_created_lt={end_ms}")
            data = api_get(url, token)
            for t in data.get("tasks", []):
                if t["id"] not in seen_ids:
                    briefings.append(t)
                    seen_ids.add(t["id"])
        except Exception as e:
            log(f"ERRO busca briefings lista {list_id}: {e}")

    log(f"Briefings ontem: {len(briefings)}")
    return briefings

# ── Verificação de qualidade de briefing ──────────────────────────────────────
def briefing_quality_multiplier(task, memory):
    """
    Verifica se a tarefa teve alertas de higiene.
    Retorna 1.2 (briefing limpo), 1.0 (normal), 0.8 (teve higiene).
    """
    task_id = task["id"]
    # Checar se há registro de higiene no state
    state_file = os.path.expanduser("~/.openclaw/guardiao-state.json")
    try:
        with open(state_file) as f:
            state = json.load(f)
        hygiene_key = f"hygiene_{task_id}"
        if hygiene_key in state:
            failures = state[hygiene_key].get("alert_count", 0)
            if failures > 0:
                return 0.8   # teve higiene — penalidade
    except: pass

    # Verificar se tem todos os campos preenchidos desde o início (proxy: sem falhas)
    # Bônus para tarefas sem nenhum alerta
    return 1.2   # briefing limpo

# ── Cálculo de score de produtividade ─────────────────────────────────────────
def calc_productivity_score(daily_history, points_today):
    """
    Score 0-100 baseado na média móvel 30 dias.
    """
    if len(daily_history) < 3:
        return 50  # dados insuficientes — neutro

    last_30 = daily_history[-30:] if len(daily_history) >= 30 else daily_history
    avg = sum(d.get("points", 0) for d in last_30) / len(last_30)

    if avg == 0:
        return 50

    ratio = points_today / avg

    if ratio >= 1.4:   return 100
    if ratio >= 1.1:   return 85
    if ratio >= 0.9:   return 70
    if ratio >= 0.75:  return 55
    if ratio >= 0.5:   return 40
    return 25

def update_avg_30d(daily_history):
    """Recalcula média móvel dos últimos 30 dias."""
    last_30 = daily_history[-30:] if len(daily_history) >= 30 else daily_history
    if not last_30: return 0
    return round(sum(d.get("points", 0) for d in last_30) / len(last_30), 1)

# ── Detecção de baixa produtividade (3 dias consecutivos < 50% da média) ─────
def check_low_productivity_alert(name, daily_history, is_designer=True):
    """
    Retorna True se os últimos 3 dias tiveram < 50% da média histórica.
    """
    if len(daily_history) < 6:
        return False  # dados insuficientes

    avg = update_avg_30d(daily_history[:-3])  # média antes dos últimos 3 dias
    if avg == 0:
        return False

    last3 = daily_history[-3:]
    threshold = avg * 0.5

    for day in last3:
        pts = day.get("points", 0)
        # Ignorar fins de semana (0 é normal)
        date_str = day.get("date", "")
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d")
            if d.weekday() >= 5:  # sábado/domingo
                return False
        except: pass
        if pts >= threshold:
            return False

    return True

# ── Detecção de alta produtividade (40%+ acima da média) ─────────────────────
def check_high_productivity(daily_history, points_today):
    """Retorna True se hoje está 40%+ acima da média histórica."""
    if len(daily_history) < 5:
        return False
    avg = update_avg_30d(daily_history)
    if avg == 0:
        return False
    return points_today >= avg * 1.4

# ── Reset semanal/mensal ───────────────────────────────────────────────────────
def reset_today_counters(mem):
    """Zera contadores _today para nova coleta."""
    for records in [mem.get("designers", {}), mem.get("atendentes", {})]:
        for rec in records.values():
            prod = rec.get("productivity", {})
            prod["deliveries_today"] = 0
            prod["points_today"] = 0
            if "briefings_today" in prod:
                prod["briefings_today"] = 0

def check_week_reset(mem, today_str):
    """Reseta contadores _week se mudou a semana."""
    now = datetime.now(BRT)
    week_start = (now - timedelta(days=now.weekday())).strftime("%Y-%m-%d")
    prod_meta = mem.setdefault("productivity_meta", {})

    if prod_meta.get("week_start") != week_start:
        log(f"Nova semana detectada ({week_start}) — resetando contadores semanais")
        for records in [mem.get("designers", {}), mem.get("atendentes", {})]:
            for rec in records.values():
                prod = rec.get("productivity", {})
                prod["deliveries_week"] = 0
                prod["points_week"]     = 0
                if "briefings_week" in prod:
                    prod["briefings_week"] = 0
        prod_meta["week_start"] = week_start

def check_month_reset(mem):
    """Reseta contadores _month se mudou o mês."""
    now = datetime.now(BRT)
    month_key = now.strftime("%Y-%m")
    prod_meta = mem.setdefault("productivity_meta", {})

    if prod_meta.get("month") != month_key:
        log(f"Novo mês detectado ({month_key}) — resetando contadores mensais")
        for records in [mem.get("designers", {}), mem.get("atendentes", {})]:
            for rec in records.values():
                prod = rec.get("productivity", {})
                prod["deliveries_month"] = 0
                prod["points_month"]     = 0
                prod["active_clients_month"] = 0
                if "briefings_month" in prod:
                    prod["briefings_month"] = 0
        prod_meta["month"] = month_key

# ── MAIN ──────────────────────────────────────────────────────────────────────
def main():
    env   = load_env()
    token = env.get("CLICKUP_API_TOKEN", "")
    if not token:
        log("ERRO: CLICKUP_API_TOKEN não encontrado"); sys.exit(1)

    now = datetime.now(BRT)
    today_str  = now.strftime("%Y-%m-%d")
    yesterday  = (now - timedelta(days=1)).strftime("%Y-%m-%d")
    weekday    = WEEKDAY_PT[now.weekday()]

    log(f"=== Guardião Produtividade M13 {now.strftime('%H:%M')} === (silent={SILENT_MODE})")

    mem = load_memory()
    reset_today_counters(mem)
    check_week_reset(mem, today_str)
    check_month_reset(mem)

    # ── Coleta de entregas de designers ────────────────────────────────────────
    delivered = fetch_delivered_yesterday(token)

    designer_day   = {}  # {nome: {"deliveries": N, "points": N, "by_type": {}}}
    atd_day        = {}  # {nome: {"briefings": N, "points": N, "by_type": {}}}

    for task in delivered:
        designer = get_designer_name(task)
        if not designer:
            continue

        tipo    = get_tipo_material(task)
        peso    = get_weight_designer(tipo)
        tipo_key = tipo or "other"

        if designer not in designer_day:
            designer_day[designer] = {"deliveries": 0, "points": 0, "by_type": {}}
        dd = designer_day[designer]
        dd["deliveries"] += 1
        dd["points"]     += peso
        dd["by_type"].setdefault(tipo_key, {"count": 0, "points": 0})
        dd["by_type"][tipo_key]["count"]  += 1
        dd["by_type"][tipo_key]["points"] += peso

        # Atualizar memória
        prod = _prod_record_designer(mem, designer)
        prod["deliveries_today"]  += 1
        prod["points_today"]      += peso
        prod["deliveries_week"]   += 1
        prod["points_week"]       += peso
        prod["deliveries_month"]  += 1
        prod["points_month"]      += peso
        prod["by_type"].setdefault(tipo_key, {"count": 0, "points": 0})
        prod["by_type"][tipo_key]["count"]  += 1
        prod["by_type"][tipo_key]["points"] += peso

    # ── Coleta de briefings de atendimento ─────────────────────────────────────
    briefings = fetch_briefings_yesterday(token)

    for task in briefings:
        atd = get_atd_name(task)
        if not atd:
            continue

        tipo     = get_tipo_material(task)
        mult     = briefing_quality_multiplier(task, mem)
        peso_base = get_weight_atd(tipo)
        peso     = round(peso_base * mult, 1)
        tipo_key  = tipo or "other"

        if atd not in atd_day:
            atd_day[atd] = {"briefings": 0, "points": 0, "by_type": {}, "quality_rates": []}
        ad = atd_day[atd]
        ad["briefings"] += 1
        ad["points"]    += peso
        ad["by_type"].setdefault(tipo_key, {"count": 0, "points": 0})
        ad["by_type"][tipo_key]["count"]  += 1
        ad["by_type"][tipo_key]["points"] += peso
        ad["quality_rates"].append(mult)

        # Atualizar memória
        prod = _prod_record_atd(mem, atd)
        prod["briefings_today"]  += 1
        prod["points_today"]     += peso
        prod["briefings_week"]   += 1
        prod["points_week"]      += peso
        prod["briefings_month"]  += 1
        prod["points_month"]     += peso
        prod["by_type"].setdefault(tipo_key, {"count": 0, "points": 0})
        prod["by_type"][tipo_key]["count"]  += 1
        prod["by_type"][tipo_key]["points"] += peso

    # ── Salvar histórico diário e atualizar scores ─────────────────────────────
    low_prod_alerts   = []
    high_prod_alerts  = []

    # Designers
    for designer, dd in designer_day.items():
        prod = _prod_record_designer(mem, designer)
        prod["daily_history"].append({
            "date":       yesterday,
            "deliveries": dd["deliveries"],
            "points":     dd["points"],
        })
        # Manter só últimos 90 dias
        prod["daily_history"] = prod["daily_history"][-90:]
        prod["avg_points_30d"]     = update_avg_30d(prod["daily_history"])
        prod["score_productivity"] = calc_productivity_score(
            prod["daily_history"], dd["points"])

        if check_low_productivity_alert(designer, prod["daily_history"]):
            low_prod_alerts.append(("designer", designer))
        if check_high_productivity(prod["daily_history"], dd["points"]):
            high_prod_alerts.append(("designer", designer, dd["points"]))

    # Adicionar zero-delivery para designers sem entrega ontem
    for dname in DESIGNERS.values():
        if dname and dname not in designer_day:
            prod = _prod_record_designer(mem, dname)
            prod["daily_history"].append({
                "date": yesterday, "deliveries": 0, "points": 0})
            prod["daily_history"] = prod["daily_history"][-90:]
            prod["avg_points_30d"] = update_avg_30d(prod["daily_history"])

    # Atendentes
    for atd, ad in atd_day.items():
        prod = _prod_record_atd(mem, atd)
        rates = ad.get("quality_rates", [])
        quality_rate = round(sum(rates) / len(rates), 2) if rates else 1.0
        prod["quality_rate"] = quality_rate
        prod["daily_history"].append({
            "date":      yesterday,
            "briefings": ad["briefings"],
            "points":    round(ad["points"], 1),
            "quality":   quality_rate,
        })
        prod["daily_history"] = prod["daily_history"][-90:]
        prod["avg_points_30d"]     = update_avg_30d(prod["daily_history"])
        prod["score_productivity"] = calc_productivity_score(
            prod["daily_history"], ad["points"])

        if check_low_productivity_alert(atd, prod["daily_history"], is_designer=False):
            low_prod_alerts.append(("atd", atd))
        if check_high_productivity(prod["daily_history"], ad["points"]):
            high_prod_alerts.append(("atd", atd, ad["points"]))

    # Adicionar zero-briefing para atendentes sem criação ontem
    for aname in ATENDIMENTO.values():
        if aname and aname not in atd_day:
            prod = _prod_record_atd(mem, aname)
            prod["daily_history"].append({
                "date": yesterday, "briefings": 0, "points": 0, "quality": 1.0})
            prod["daily_history"] = prod["daily_history"][-90:]
            prod["avg_points_30d"] = update_avg_30d(prod["daily_history"])

    # ── Score integrado (compliance 50% + produtividade 50%) ──────────────────
    for dname, drec in mem.get("designers", {}).items():
        compliance_score = drec.get("score", 100)
        prod_score       = drec.get("productivity", {}).get("score_productivity", 50)
        drec["score_integrated"] = round((compliance_score * 0.5) + (prod_score * 0.5))

    for aname, arec in mem.get("atendentes", {}).items():
        # Atendentes: buscar em "atendimento" (legado) ou "atendentes"
        compliance_score = mem.get("atendimento", {}).get(aname, {}).get("score", 100)
        prod_score       = arec.get("productivity", {}).get("score_productivity", 50)
        arec["score_integrated"] = round((compliance_score * 0.5) + (prod_score * 0.5))

    save_memory(mem)
    log(f"Memória atualizada: {len(designer_day)} designers, {len(atd_day)} atendentes com produção ontem")

    # ── Gerar relatório ────────────────────────────────────────────────────────
    if not designer_day and not atd_day:
        log("Sem produção registrada ontem — relatório não enviado")
        return

    # Montar mensagem
    total_pts_design = sum(v["points"] for v in designer_day.values())
    total_pts_atd    = sum(v["points"] for v in atd_day.values())

    week_pts_design = sum(
        mem.get("designers", {}).get(n, {}).get("productivity", {}).get("points_week", 0)
        for n in DESIGNERS.values() if n
    )
    week_pts_atd = sum(
        mem.get("atendentes", {}).get(n, {}).get("productivity", {}).get("points_week", 0)
        for n in ATENDIMENTO.values() if n
    )

    lines = [
        f"➖➖➖➖➖➖➖➖",
        f"*GUARDIÃO | Produtividade — {weekday} {(now - timedelta(days=1)).strftime('%d/%m')}*",
        f"➖➖➖➖➖➖➖➖",
    ]

    # Designers
    sorted_designers = sorted(designer_day.items(), key=lambda x: -x[1]["points"])
    if sorted_designers:
        lines += ["", "🎨 *DESIGNERS*"]
        medals = ["🥇", "🥈", "🥉"]
        for i, (name, dd) in enumerate(sorted_designers):
            medal = medals[i] if i < 3 else "  "
            # Top tipos do dia
            top_tipos = sorted(dd["by_type"].items(), key=lambda x: -x[1]["count"])[:2]
            tipo_txt  = " · ".join(f"{v['count']}× {k}" for k, v in top_tipos) if top_tipos and TIPO_MATERIAL_FIELD_ID else ""
            pts_txt   = f"{dd['points']}pt{'s' if dd['points'] != 1 else ''}"
            line = f"{medal} *{name}* — {dd['deliveries']} entrega(s) · {pts_txt}"
            if tipo_txt:
                line += f"  ({tipo_txt})"
            lines.append(line)
    else:
        lines += ["", "🎨 *DESIGNERS*: sem entregas registradas ontem"]

    # Atendimento
    sorted_atd = sorted(atd_day.items(), key=lambda x: -x[1]["points"])
    if sorted_atd:
        lines += ["", "👥 *ATENDIMENTO*"]
        medals = ["🥇", "🥈", "🥉"]
        for i, (name, ad) in enumerate(sorted_atd):
            medal   = medals[i] if i < 3 else "  "
            quality = ad.get("quality_rates", [])
            q_avg   = sum(quality) / len(quality) if quality else 1.0
            q_pct   = int(q_avg * 100 / 1.2 * 100)  # normaliza para %
            q_emoji = "⚠️" if q_pct < 70 else ""
            pts_txt = f"{round(ad['points'], 1)}pt{'s' if ad['points'] != 1 else ''}"
            lines.append(f"{medal} *{name}* — {ad['briefings']} briefing(s) · {pts_txt} (qual. {q_pct}%) {q_emoji}")
    else:
        lines += ["", "👥 *ATENDIMENTO*: sem briefings registrados ontem"]

    # Semana acumulada
    lines += [
        "",
        f"📊 Semana acumulada: *{round(week_pts_design)}pts* (designers) · *{round(week_pts_atd)}pts* (atendimento)",
    ]

    # Alertas de alta produtividade
    for tipo, nome, pts in high_prod_alerts:
        role = "Designer" if tipo == "designer" else "Atendimento"
        lines.append(f"🌟 Destaque: *{nome}* entregou 40%+ acima da sua média histórica!")

    if TIPO_MATERIAL_FIELD_ID == "":
        lines += ["", "_⚙️ campo tipo\\_material não configurado — pesos padrão=2 aplicados_"]

    lines.append("\n🐺 _Guardião — Módulo 13 Produtividade Real_")

    msg = "\n".join(lines)

    if SILENT_MODE:
        log(f"SILENT_MODE: relatório gerado mas NÃO enviado\n{msg}")
    else:
        ok = send_whatsapp(ATD_GESTAO_GROUP, msg)
        log(f"Relatório produtividade {'enviado' if ok else 'FALHOU'}")

        # Alertas de baixa produtividade — mensagem privada para gestão
        for tipo, nome in low_prod_alerts:
            alert_msg = (
                f"⚠️ *Atenção — Produtividade*\n\n"
                f"*{nome}* está com produção abaixo de 50% da média histórica "
                f"há 3 dias consecutivos.\n\n"
                f"Pode ser um indicativo de travamento, sobrecarga ou contexto fora do ClickUp.\n"
                f"Recomendado: verificar pessoalmente antes de qualquer cobrança.\n\n"
                f"🐺 _Guardião — M13_"
            )
            send_whatsapp(ATD_GESTAO_GROUP, alert_msg)
            time.sleep(5)

    log(f"=== M13 concluído — designers:{len(designer_day)} atd:{len(atd_day)} "
        f"pts_design:{total_pts_design} pts_atd:{round(total_pts_atd, 1)} ===")

if __name__ == "__main__":
    main()
