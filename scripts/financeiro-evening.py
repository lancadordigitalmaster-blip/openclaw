#!/usr/bin/env python3
"""
financeiro-evening.py — Fechamento financeiro noturno
Wolf Agency | Bot @wolffinanceiro_bot
Envia resumo do dia: o que foi recebido hoje + o que venceu e não foi pago
"""

import urllib.request
import urllib.parse
import json
import datetime
import subprocess
import sys
import os

def _load_env():
    env = {}
    try:
        for line in open(os.path.expanduser("~/.openclaw/.env")):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); env[k] = v
    except Exception: pass
    return env

TOKEN = _load_env().get("CLICKUP_API_TOKEN", "")
LISTS_RECEBER = ["901305981568", "901324962491"]
TELEGRAM_TARGET = _load_env().get("TELEGRAM_CHAT_ID", os.environ.get("TELEGRAM_CHAT_ID", "789352357"))
TELEGRAM_ACCOUNT = "financeiro"

def fetch_tasks(list_id, extra_params=""):
    url = f"https://api.clickup.com/api/v2/list/{list_id}/task?order_by=due_date{extra_params}"
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
                except (ValueError, TypeError):
                    pass
    return None

def fmt_brl(v):
    if v is None:
        return "—"
    return f"R$ {v:,.0f}".replace(",", ".")

def send_whatsapp(message, to=None):
    """Envia via WhatsApp Bridge API (porta 3002)"""
    to = to or os.environ.get("NETTO_WHATSAPP", "557391484716")
    payload = json.dumps({"to": to, "text": message}).encode()
    req = urllib.request.Request("http://127.0.0.1:3002/send", data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except Exception as e:
        print(f"[ERRO] WhatsApp Bridge: {e}", file=sys.stderr)
        return False

def send_telegram(message):
    """Envia via WhatsApp (sem fallback Telegram)"""
    return send_whatsapp(message)

def main():
    now = datetime.datetime.now()
    tz_offset = datetime.timezone(datetime.timedelta(hours=-3))
    today = datetime.datetime.now(tz_offset).replace(hour=0, minute=0, second=0, microsecond=0)
    today_ms = int(today.timestamp() * 1000)
    today_end_ms = today_ms + 86400000 - 1

    recebidos_hoje = []
    venceu_hoje_nao_pago = []
    seen = set()

    for list_id in LISTS_RECEBER:
        # Tarefas atualizadas hoje com status recebida
        tasks_recebidas = fetch_tasks(
            list_id,
            f"&statuses[]=recebida&date_updated_gt={today_ms}&date_updated_lt={today_end_ms}"
        )
        for t in tasks_recebidas:
            key = t.get("id", t.get("name"))
            if key in seen:
                continue
            seen.add(key)
            valor = get_valor(t)
            recebidos_hoje.append({
                "name": t.get("name", "—"),
                "valor": valor
            })

        # Tarefas que venceram hoje e não foram pagas
        tasks_venceu = fetch_tasks(
            list_id,
            f"&due_date_gt={today_ms - 1}&due_date_lt={today_end_ms}"
        )
        for t in tasks_venceu:
            status = t.get("status", {}).get("status", "").lower()
            if status in ["recebida", "pago", "concluído", "concluido"]:
                continue
            key = t.get("id", t.get("name"))
            if key in seen:
                continue
            seen.add(key)
            valor = get_valor(t)
            venceu_hoje_nao_pago.append({
                "name": t.get("name", "—"),
                "valor": valor
            })

    total_recebido = sum(i["valor"] for i in recebidos_hoje if i["valor"])
    total_pendente_hoje = sum(i["valor"] for i in venceu_hoje_nao_pago if i["valor"])

    lines = []
    lines.append(f"📋 *Fechamento do Dia — {now.strftime('%d/%m/%Y')}*")
    lines.append("")

    # Recebidos hoje
    if recebidos_hoje:
        lines.append(f"✅ *RECEBIDO HOJE — {fmt_brl(total_recebido)}*")
        for item in recebidos_hoje:
            lines.append(f"• {item['name']} — {fmt_brl(item['valor'])}")
    else:
        lines.append("✅ *RECEBIDO HOJE — R$ 0*")
        lines.append("• Nenhum pagamento registrado hoje.")

    # Venceu hoje e não foi pago
    if venceu_hoje_nao_pago:
        lines.append("")
        lines.append(f"⚠️ *VENCEU HOJE — NÃO RECEBIDO ({len(venceu_hoje_nao_pago)} itens — {fmt_brl(total_pendente_hoje)})*")
        for item in venceu_hoje_nao_pago:
            lines.append(f"• {item['name']} — {fmt_brl(item['valor'])}")

    # Resumo
    lines.append("")
    if recebidos_hoje or venceu_hoje_nao_pago:
        if venceu_hoje_nao_pago:
            lines.append(f"💡 Recebeu {fmt_brl(total_recebido)} hoje. Ainda pendente do dia: {fmt_brl(total_pendente_hoje)}.")
        else:
            lines.append(f"💡 Recebeu {fmt_brl(total_recebido)} hoje. Tudo em dia! ✓")
    else:
        lines.append("💡 Nenhum vencimento registrado para hoje.")

    message = "\n".join(lines)

    if len(message) > 3800:
        message = message[:3800] + "\n\n_[truncado]_"

    ok = send_telegram(message)
    if ok:
        print("Fechamento noturno enviado com sucesso.")
    else:
        print("ERRO ao enviar fechamento noturno.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
