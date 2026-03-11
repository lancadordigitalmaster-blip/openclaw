#!/usr/bin/env python3
"""
guardiao-produtividade-semanal.py — Módulo 13: Produtividade Real (consolidação semanal).

Roda às 08h de segunda via crontab (após guardiao-relatorio-semanal.py).
Consolida todos os dias da semana anterior, compara com semana anterior,
gera ranking com tendências e alertas de padrão.

Herda SILENT_MODE de guardiao-produtividade.py.
Quando SILENT_MODE = True: gera mas não envia.
"""

import urllib.request, json, os, sys, time
from datetime import datetime, timezone, timedelta

ENV_FILE     = os.path.expanduser("~/.openclaw/.env")
MEMORY_FILE  = os.path.expanduser("~/.openclaw/guardiao-memory.json")
LOG_FILE     = os.path.expanduser("~/openclaw/whatsapp-bridge/logs/guardiao.log")
BRIDGE_API   = "http://127.0.0.1:3002/send"

BRT = timezone(timedelta(hours=-3))

# Herdar fase da produtividade diária
# Semana 1-2: True | Semana 3+: False
SILENT_MODE = True

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

def log(msg):
    ts = datetime.now(BRT).strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] [prod-semanal] {msg}"
    print(line)
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a") as f: f.write(line + "\n")

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

def load_memory():
    if not os.path.exists(MEMORY_FILE): return {}
    try:
        with open(MEMORY_FILE) as f: return json.load(f)
    except: return {}

def week_range_str(monday_date):
    """Retorna string 'dd/mm – dd/mm' para a semana."""
    friday = monday_date + timedelta(days=4)
    return f"{monday_date.strftime('%d/%m')} – {friday.strftime('%d/%m')}"

def get_week_points_from_history(daily_history, week_start_str, week_end_str):
    """Soma pontos de um range de datas no histórico diário."""
    total_pts = 0
    total_qty = 0
    for entry in daily_history:
        d = entry.get("date", "")
        if week_start_str <= d <= week_end_str:
            total_pts += entry.get("points", 0)
            total_qty += entry.get("deliveries", entry.get("briefings", 0))
    return total_pts, total_qty

def trend_arrow(pts_this, pts_prev):
    """Retorna seta de tendência e diferença."""
    if pts_prev == 0:
        return "→", "+0"
    diff = pts_this - pts_prev
    pct  = diff / pts_prev * 100
    if pct >= 15:  return "↑", f"+{round(diff, 1)}"
    if pct <= -15: return "↓", f"{round(diff, 1)}"
    return "→",    f"{'+' if diff >= 0 else ''}{round(diff, 1)}"

def get_top_type(by_type_data):
    """Retorna o tipo de material mais produzido."""
    if not by_type_data:
        return None
    top = max(by_type_data.items(), key=lambda x: x[1].get("count", 0))
    return top[0], top[1].get("count", 0)

def check_type_diversity(by_type_data, total):
    """
    Retorna True se > 78% da produção é de um único tipo (baixa diversidade).
    """
    if not by_type_data or total == 0:
        return False, None
    top_type, top_count = max(by_type_data.items(), key=lambda x: x[1].get("count", 0))
    if top_count / total > 0.78:
        return True, top_type
    return False, None

def main():
    now = datetime.now(BRT)

    # Calcular range da semana anterior (seg a sex)
    # hoje é segunda, semana anterior = últimos 7 dias
    last_monday  = now - timedelta(days=7)
    last_friday  = last_monday + timedelta(days=4)
    prev_monday  = last_monday - timedelta(days=7)
    prev_friday  = prev_monday + timedelta(days=4)

    week_start     = last_monday.strftime("%Y-%m-%d")
    week_end       = last_friday.strftime("%Y-%m-%d")
    prev_week_start = prev_monday.strftime("%Y-%m-%d")
    prev_week_end  = prev_friday.strftime("%Y-%m-%d")

    week_label     = week_range_str(last_monday)
    log(f"=== Guardião Produtividade Semanal M13 — semana {week_label} (silent={SILENT_MODE}) ===")

    mem = load_memory()

    if not mem.get("designers") and not mem.get("atendentes"):
        log("Sem dados de produtividade em memória — M13 não ativado ainda")
        return

    # ── Construir ranking de designers ────────────────────────────────────────
    designer_rows = []
    pattern_alerts = []
    highlight_alerts = []

    for dname in sorted(DESIGNERS.values()):
        if not dname: continue
        drec = mem.get("designers", {}).get(dname, {})
        prod = drec.get("productivity", {})
        if not prod: continue

        history = prod.get("daily_history", [])
        pts_this, qty_this = get_week_points_from_history(history, week_start, week_end)
        pts_prev, qty_prev = get_week_points_from_history(history, prev_week_start, prev_week_end)

        if pts_this == 0 and pts_prev == 0:
            continue  # nunca teve dados

        arrow, diff = trend_arrow(pts_this, pts_prev)
        by_type = prod.get("by_type", {})
        top_t   = get_top_type(by_type)

        # Complexidade principal
        nota_tipo = ""
        if top_t:
            nota_tipo = f"(maior: {top_t[1]}× {top_t[0]})"

        designer_rows.append({
            "name":     dname,
            "pts":      pts_this,
            "qty":      qty_this,
            "arrow":    arrow,
            "diff":     diff,
            "nota":     nota_tipo,
            "pts_prev": pts_prev,
        })

        # Alerta de diversidade
        low_div, dom_type = check_type_diversity(by_type, qty_this)
        if low_div and dom_type == "post_static" and qty_this >= 5:
            pattern_alerts.append(
                f"⚠️ *{dname}*: {int(qty_this * 0.78)}+ entregas foram posts estáticos — baixa diversidade de material"
            )

        # Alerta de alta produtividade semanal
        avg_30 = prod.get("avg_points_30d", 0)
        if avg_30 > 0 and pts_this >= avg_30 * 5 * 1.4:  # 5 dias × média × 1.4
            highlight_alerts.append(
                f"🌟 Destaque: *{dname}* entregou 40%+ acima da média histórica esta semana!"
            )

    designer_rows.sort(key=lambda x: -x["pts"])

    # ── Construir ranking de atendentes ────────────────────────────────────────
    atd_rows = []
    atd_pattern_alerts = []

    for aname in sorted(ATENDIMENTO.values()):
        if not aname: continue
        arec = mem.get("atendentes", {}).get(aname, {})
        prod = arec.get("productivity", {})
        if not prod: continue

        history = prod.get("daily_history", [])
        pts_this, qty_this = get_week_points_from_history(history, week_start, week_end)
        pts_prev, qty_prev = get_week_points_from_history(history, prev_week_start, prev_week_end)

        if pts_this == 0 and pts_prev == 0:
            continue

        arrow, diff = trend_arrow(pts_this, pts_prev)

        # Qualidade média da semana
        week_entries = [e for e in history if week_start <= e.get("date","") <= week_end]
        quality_vals = [e.get("quality", 1.0) for e in week_entries if e.get("quality") is not None]
        avg_quality  = sum(quality_vals) / len(quality_vals) if quality_vals else 1.0
        q_pct        = int(avg_quality * 100 / 1.2 * 100)  # normaliza para %
        q_emoji      = " ⚠️" if q_pct < 70 else ""

        # Clientes ativos (proxy: quantidade de briefings distintos — não temos client field ainda)
        active_clients = prod.get("active_clients_month", 0)
        clients_txt    = f"{active_clients} cliente(s) ativos" if active_clients else ""

        atd_rows.append({
            "name":    aname,
            "pts":     pts_this,
            "qty":     qty_this,
            "arrow":   arrow,
            "diff":    diff,
            "q_pct":   q_pct,
            "q_emoji": q_emoji,
            "clients": clients_txt,
        })

        # Alerta: qualidade de briefing < 70% pela 2ª semana seguida
        prev_entries = [e for e in history if prev_week_start <= e.get("date","") <= prev_week_end]
        prev_quality = [e.get("quality", 1.0) for e in prev_entries if e.get("quality") is not None]
        prev_q_avg   = sum(prev_quality) / len(prev_quality) if prev_quality else 1.0
        prev_q_pct   = int(prev_q_avg * 100 / 1.2 * 100)

        if q_pct < 70 and prev_q_pct < 70:
            atd_pattern_alerts.append(
                f"⚠️ *{aname}*: qualidade de briefing abaixo de 70% pela 2ª semana seguida"
            )

        # Alta produtividade
        avg_30 = prod.get("avg_points_30d", 0)
        if avg_30 > 0 and pts_this >= avg_30 * 5 * 1.4:
            highlight_alerts.append(
                f"🌟 Destaque: *{aname}* entregou 40%+ acima da média histórica esta semana!"
            )

    atd_rows.sort(key=lambda x: -x["pts"])

    # ── Montar mensagem ────────────────────────────────────────────────────────
    lines = [
        f"➖➖➖➖➖➖➖➖",
        f"*GUARDIÃO | Produtividade Semanal — {week_label}*",
        f"➖➖➖➖➖➖➖➖",
    ]

    if designer_rows:
        lines += ["", "🎨 *DESIGNERS — pontuação ponderada*",
                  "────────────────────────────────"]
        for row in designer_rows:
            pts_fmt = f"{round(row['pts'], 1)}pts"
            vs_txt  = f"{row['arrow']} {row['diff']} vs semana passada"
            nota    = f"  {row['nota']}" if row["nota"] else ""
            lines.append(f"*{row['name']:10s}*  {pts_fmt:8s}  {vs_txt}{nota}")
    else:
        lines += ["", "🎨 *DESIGNERS*: sem dados de produção ainda"]

    if atd_rows:
        lines += ["", "👥 *ATENDIMENTO — pontuação ponderada*",
                  "──────────────────────────────────────"]
        for row in atd_rows:
            pts_fmt  = f"{round(row['pts'], 1)}pts"
            vs_txt   = f"{row['arrow']} {row['diff']} vs semana passada"
            q_txt    = f"qual. {row['q_pct']}%{row['q_emoji']}"
            clients  = f" · {row['clients']}" if row["clients"] else ""
            lines.append(f"*{row['name']:10s}*  {pts_fmt:8s}  {vs_txt}  ({q_txt}{clients})")
    else:
        lines += ["", "👥 *ATENDIMENTO*: sem dados de briefing ainda"]

    # Alertas de padrão
    all_alerts = pattern_alerts + atd_pattern_alerts
    if all_alerts:
        lines += [""]
        lines += all_alerts

    # Destaques
    if highlight_alerts:
        lines += [""]
        lines += highlight_alerts

    lines += [
        "",
        "🐺 _Guardião — Módulo 13 Produtividade Real_",
    ]

    msg = "\n".join(lines)

    if SILENT_MODE:
        log(f"SILENT_MODE: relatório semanal gerado mas NÃO enviado\n{msg}")
    else:
        ok = send_whatsapp(ATD_GESTAO_GROUP, msg)
        log(f"Relatório produtividade semanal {'enviado' if ok else 'FALHOU'}")

    log(f"=== Prod. semanal concluída — {len(designer_rows)} designers, {len(atd_rows)} atendentes ===")

if __name__ == "__main__":
    main()
