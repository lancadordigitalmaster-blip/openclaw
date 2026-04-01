#!/usr/bin/env python3
"""
financeiro-morning.py — Briefing financeiro matinal
Wolf Agency | Bot @wolffinanceiro_bot
Envia resumo de contas a receber: vencidas, vence hoje, próximos 7 dias
"""

import urllib.request
import urllib.parse
import json
import datetime
import subprocess
import sys

TOKEN = "pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP"
LISTS = ["901305981568", "901324962491"]
TELEGRAM_TARGET = "789352357"
TELEGRAM_ACCOUNT = "financeiro"

def fetch_tasks(list_id, params=""):
    url = f"https://api.clickup.com/api/v2/list/{list_id}/task?order_by=due_date&reverse=false{params}"
    req = urllib.request.Request(url, headers={"Authorization": TOKEN})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read()).get("tasks", [])
    except Exception as e:
        print(f"[ERRO] fetch_tasks list={list_id}: {e}", file=sys.stderr)
        return []

def get_valor(task):
    for cf in task.get("custom_fields", []):
        if "valor" in cf.get("name", "").lower():
            v = cf.get("value")
            if v is not None:
                try:
                    return float(v)
                except:
                    pass
    return None

def fmt_brl(v):
    if v is None:
        return "—"
    return f"R$ {v:,.0f}".replace(",", ".")

def send_telegram(message):
    cmd = [
        "openclaw", "message", "send",
        "--channel", "telegram",
        "--account", TELEGRAM_ACCOUNT,
        "--target", TELEGRAM_TARGET,
        "--message", message
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[ERRO] Telegram: {result.stderr}", file=sys.stderr)
        return False
    return True

def main():
    now = datetime.datetime.now()
    tz_offset = datetime.timezone(datetime.timedelta(hours=-3))
    today = datetime.datetime.now(tz_offset).replace(hour=0, minute=0, second=0, microsecond=0)
    today_ms = int(today.timestamp() * 1000)
    today_end_ms = today_ms + 86400000 - 1
    week_end_ms = today_ms + 7 * 86400000

    vencidas = []
    hoje = []
    proximos = []
    sem_data = []

    seen = set()

    for list_id in LISTS:
        tasks = fetch_tasks(list_id)
        for t in tasks:
            due = t.get("due_date")
            status = t.get("status", {}).get("status", "").lower()
            name = t.get("name", "—")
            tid = t.get("id")

            if status in ["recebida", "pago", "concluído", "concluido"]:
                continue

            key = f"{name}|{due}"
            if key in seen:
                continue
            seen.add(key)

            valor = get_valor(t)

            if not due:
                sem_data.append({"name": name, "valor": valor})
            elif int(due) < today_ms:
                due_dt = datetime.datetime.fromtimestamp(int(due) / 1000)
                vencidas.append({"name": name, "valor": valor, "due": due_dt.strftime("%d/%m")})
            elif int(due) <= today_end_ms:
                hoje.append({"name": name, "valor": valor})
            elif int(due) <= week_end_ms:
                due_dt = datetime.datetime.fromtimestamp(int(due) / 1000)
                proximos.append({"name": name, "valor": valor, "due": due_dt.strftime("%d/%m")})

    total_vencidas = sum(i["valor"] for i in vencidas if i["valor"])
    total_hoje = sum(i["valor"] for i in hoje if i["valor"])
    total_proximos = sum(i["valor"] for i in proximos if i["valor"])
    total_geral = total_vencidas + total_hoje + total_proximos

    lines = []
    lines.append(f"💰 *Briefing Financeiro — {now.strftime('%d/%m/%Y')}*")
    lines.append("")

    # Resumo
    lines.append(f"📊 *RESUMO*")
    lines.append(f"• Vencidas: {len(vencidas)} itens — {fmt_brl(total_vencidas)}")
    lines.append(f"• Vencem hoje: {len(hoje)} itens — {fmt_brl(total_hoje)}")
    lines.append(f"• Próximos 7 dias: {len(proximos)} itens — {fmt_brl(total_proximos)}")
    if sem_data:
        lines.append(f"• Sem data: {len(sem_data)} itens")
    lines.append(f"• *TOTAL PENDENTE: {fmt_brl(total_geral)}*")

    # Vence hoje
    if hoje:
        lines.append("")
        lines.append(f"🔔 *VENCEM HOJE ({len(hoje)})*")
        for item in hoje:
            lines.append(f"• {item['name']} — {fmt_brl(item['valor'])}")

    # Vencidas (top 10 mais recentes)
    if vencidas:
        lines.append("")
        vencidas_sorted = sorted(vencidas, key=lambda x: x["due"], reverse=True)
        top = vencidas_sorted[:10]
        lines.append(f"🔴 *VENCIDAS — {len(vencidas)} itens*")
        for item in top:
            lines.append(f"• {item['due']} · {item['name']} — {fmt_brl(item['valor'])}")
        if len(vencidas) > 10:
            restante = sum(i["valor"] for i in vencidas_sorted[10:] if i["valor"])
            lines.append(f"• _...+ {len(vencidas)-10} itens ({fmt_brl(restante)})_")

    # Próximos 7 dias
    if proximos:
        lines.append("")
        lines.append(f"🟡 *PRÓXIMOS 7 DIAS ({len(proximos)})*")
        for item in sorted(proximos, key=lambda x: x["due"]):
            lines.append(f"• {item['due']} · {item['name']} — {fmt_brl(item['valor'])}")

    message = "\n".join(lines)

    # Telegram tem limite de 4096 chars
    if len(message) > 3800:
        message = message[:3800] + "\n\n_[truncado — muitos itens]_"

    ok = send_telegram(message)
    if ok:
        print("Briefing matinal enviado com sucesso.")
    else:
        print("ERRO ao enviar briefing matinal.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
