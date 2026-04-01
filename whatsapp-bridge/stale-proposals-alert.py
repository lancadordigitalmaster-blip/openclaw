#!/usr/bin/env python3
"""
stale-proposals-alert.py
Verifica propostas abertas sem movimentação há mais de 7 dias
e envia alerta no Telegram para o vendedor responsável.

Roda via crontab: 0 9 * * 1-5 (seg-sex às 9h)
"""

import os, json, sys, requests
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────────
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://dqhiafxbljujahmpcdhf.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxaGlhZnhibGp1amFobXBjZGhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2ODUyNzAsImV4cCI6MjA4ODI2MTI3MH0._eYfSa0stwIysa12_AObw52hugijfMetzLzkaeNCt2g"
)
TELEGRAM_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT  = os.environ.get("TELEGRAM_CHAT_ID", "789352357")  # Netto

STALE_DAYS = 7  # dias sem movimentação para considerar parada

# ── Helpers ─────────────────────────────────────────────────────────────────
def sb_get(path, params=""):
    url = f"{SUPABASE_URL}/rest/v1/{path}{params}"
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    r = requests.get(url, headers=headers, timeout=15)
    r.raise_for_status()
    return r.json()

def sb_insert(table, data):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    requests.post(url, headers=headers, json=data, timeout=10)

def send_telegram(msg):
    if not TELEGRAM_TOKEN:
        print("[WARN] TELEGRAM_BOT_TOKEN não configurado — sem notificação")
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    requests.post(url, json={
        "chat_id": TELEGRAM_CHAT,
        "text": msg,
        "parse_mode": "Markdown",
    }, timeout=10)

# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    now = datetime.now(timezone.utc)
    cutoff = (now - timedelta(days=STALE_DAYS)).isoformat()

    # Busca propostas abertas cuja última atualização foi antes do cutoff
    proposals = sb_get("proposals",
        f"?select=id,client_name,service_type,amount,seller,created_at,updated_at,expected_close_date"
        f"&status=eq.open"
        f"&updated_at=lt.{cutoff}"
        f"&order=updated_at.asc"
    )

    if not proposals:
        print(f"[{now.strftime('%Y-%m-%d %H:%M')}] Nenhuma proposta parada. Tudo limpo ✅")
        return

    # Agrupar por vendedor
    by_seller = {}
    for p in proposals:
        seller = p.get("seller") or "Sem vendedor"
        by_seller.setdefault(seller, []).append(p)

    def fmt_brl(v):
        try: return f"R$ {float(v):,.0f}".replace(",",".")
        except: return "—"

    def days_stale(p):
        try:
            upd = datetime.fromisoformat(p["updated_at"].replace("Z","+00:00"))
            return (now - upd).days
        except: return "?"

    lines = [f"⚠️ *{len(proposals)} proposta{'s' if len(proposals)!=1 else ''} parada{'s' if len(proposals)!=1 else ''} — sem movimento há {STALE_DAYS}+ dias*\n"]

    for seller, props in sorted(by_seller.items()):
        lines.append(f"👤 *{seller}* ({len(props)})")
        for p in props:
            close = f" | fecha {p['expected_close_date']}" if p.get("expected_close_date") else ""
            lines.append(
                f"  • {p['client_name']} — {fmt_brl(p.get('amount'))} "
                f"({days_stale(p)} dias parada{close})"
            )
        lines.append("")

    lines.append("_Acesse o pipeline para registrar andamento ou mover para Perdida._")
    msg = "\n".join(lines)

    send_telegram(msg)
    print(f"[{now.strftime('%Y-%m-%d %H:%M')}] Alerta enviado: {len(proposals)} propostas paradas")

    # Log de atividade no Supabase para cada proposta parada
    for p in proposals:
        try:
            sb_insert("proposal_activities", {
                "proposal_id": p["id"],
                "type": "stale",
                "description": f"Proposta sem movimentação há {days_stale(p)} dias — alerta enviado",
                "actor": "Sistema",
            })
        except Exception as e:
            print(f"[WARN] activity log error: {e}")


if __name__ == "__main__":
    main()
