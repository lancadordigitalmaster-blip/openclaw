#!/usr/bin/env python3
"""
Alfred Email Monitor — Wolf Agency
Monitora inbox do Netto e alerta no Telegram sobre e-mails críticos.
Zero LLM. Roda via cron a cada 15 min.
"""

import imaplib
import email
from email.header import decode_header
import json
import os
import requests
from datetime import datetime
from pathlib import Path
from dotenv import dotenv_values

# ── Configuração ─────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).parent.parent
STATE_FILE = BASE_DIR / "memory" / "email-monitor-state.json"
ENV_FILE = Path.home() / ".openclaw" / ".env"

env = dotenv_values(ENV_FILE)

GMAIL_USER = env.get("GMAIL_USER", "")
GMAIL_PASS = env.get("GMAIL_APP_PASSWORD", "")
BOT_TOKEN  = env.get("TELEGRAM_BOT_TOKEN", "")
CHAT_ID    = env.get("TELEGRAM_CHAT_ID", "")

# ── Palavras-chave críticas ──────────────────────────────────────────────────
CRITICAL_PATTERNS = [
    # Pagamentos gerais
    {"keywords": ["unsuccessful", "payment failed", "pagamento", "cobrança", "fatura", "invoice", "overdue", "vencida", "vencimento"], "emoji": "💳", "label": "Pagamento"},
    # Conta de luz — Neoenergia/Coelba (Bahia)
    {"keywords": ["neoenergia", "coelba", "conta de luz", "energia elétrica", "fatura de energia", "segunda via energia"], "emoji": "⚡", "label": "Conta de Luz"},
    # Internet — Nio
    {"keywords": ["nio internet", "nio fibra", "nio.com", "fatura nio", "cobrança nio", "fatura internet", "banda larga"], "emoji": "📡", "label": "Internet"},
    # Cartão de crédito
    {"keywords": ["fatura do cartão", "fatura cartão", "fechamento da fatura", "limite do cartão", "nubank", "itaucard", "bradesco cartão", "santander cartão", "c6 bank", "inter cartão", "xp cartão", "cartão de crédito", "credit card statement"], "emoji": "💳", "label": "Cartão de Crédito"},
    # Meta Ads
    {"keywords": ["rejeitado", "rejected", "anúncio", "campanha pausada", "account restricted"], "emoji": "📢", "label": "Meta Ads"},
    # Segurança
    {"keywords": ["security alert", "alerta de segurança", "suspicious", "unauthorized", "senha", "password changed"], "emoji": "🔐", "label": "Segurança"},
    # Serviços críticos
    {"keywords": ["subscription", "assinatura", "expiring", "expirando", "trial ending", "acesso bloqueado"], "emoji": "⚠️", "label": "Serviço"},
]

# Remetentes que sempre ignoramos (lixo)
IGNORE_SENDERS = [
    "aliexpress", "magalu", "smartfit", "queimadiaria", "shopee",
    "americanas", "submarino", "amazon.com.br", "mercadolivre",
    "newsletter", "noreply@marketing", "promos@"
]

# ── Funções ──────────────────────────────────────────────────────────────────
def load_state():
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_uid": 0, "alerted_ids": []}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

def decode_str(raw):
    try:
        parts = decode_header(raw or "")
        result = ""
        for part, enc in parts:
            if isinstance(part, bytes):
                result += part.decode(enc or "utf-8", errors="ignore")
            else:
                result += str(part)
        return result.strip()
    except:
        return str(raw or "")

def is_spam(sender):
    sender_lower = sender.lower()
    return any(s in sender_lower for s in IGNORE_SENDERS)

def classify_email(subject, sender):
    text = (subject + " " + sender).lower()
    for pattern in CRITICAL_PATTERNS:
        if any(k.lower() in text for k in pattern["keywords"]):
            return pattern["emoji"], pattern["label"]
    return None, None

def send_telegram(message):
    if not BOT_TOKEN or not CHAT_ID:
        print("Telegram não configurado.")
        return
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {"chat_id": CHAT_ID, "text": message, "parse_mode": "Markdown"}
    try:
        r = requests.post(url, json=payload, timeout=10)
        r.raise_for_status()
        print(f"Telegram enviado: {r.status_code}")
    except Exception as e:
        print(f"Erro Telegram: {e}")

def check_emails(mode="monitor"):
    """
    mode='monitor' — verifica novos emails e alerta criticamente
    mode='briefing' — gera resumo diário completo
    """
    state = load_state()
    mail = imaplib.IMAP4_SSL("imap.gmail.com", 993)
    mail.login(GMAIL_USER, GMAIL_PASS)
    mail.select("INBOX")

    # Buscar e-mails das últimas 24h (evita varrer 91k não lidos)
    from datetime import timedelta
    since_date = (datetime.now() - timedelta(days=1)).strftime("%d-%b-%Y")
    status, data = mail.search(None, f'(SINCE "{since_date}")')

    ids = data[0].split() if data[0] else []

    if mode == "briefing":
        ids = ids[-100:]  # últimos 100 para o briefing

    alerts = []
    briefing_items = []

    for eid in ids:
        uid = int(eid)

        # Pular já alertados
        if uid in state.get("alerted_ids", []):
            continue

        status2, data2 = mail.fetch(eid, "(RFC822)")
        if status2 != "OK":
            continue

        msg = email.message_from_bytes(data2[0][1])
        sender  = decode_str(msg.get("From", ""))
        subject = decode_str(msg.get("Subject", ""))
        date    = msg.get("Date", "")

        if is_spam(sender):
            continue

        emoji, label = classify_email(subject, sender)

        if emoji:
            # Extrair corpo do email
            body = ""
            try:
                if msg.is_multipart():
                    for part in msg.walk():
                        ct = part.get_content_type()
                        cd = str(part.get("Content-Disposition", ""))
                        if ct == "text/plain" and "attachment" not in cd:
                            charset = part.get_content_charset() or "utf-8"
                            body = part.get_payload(decode=True).decode(charset, errors="replace")
                            break
                    if not body:  # fallback para text/html se não tiver plain
                        for part in msg.walk():
                            if part.get_content_type() == "text/html" and "attachment" not in str(part.get("Content-Disposition", "")):
                                charset = part.get_content_charset() or "utf-8"
                                raw = part.get_payload(decode=True).decode(charset, errors="replace")
                                import re
                                body = re.sub(r'<[^>]+>', ' ', raw)
                                body = re.sub(r'\s+', ' ', body).strip()
                                break
                else:
                    charset = msg.get_content_charset() or "utf-8"
                    raw = msg.get_payload(decode=True).decode(charset, errors="replace")
                    import re
                    if "<html" in raw.lower() or "<body" in raw.lower():
                        body = re.sub(r'<[^>]+>', ' ', raw)
                        body = re.sub(r'\s+', ' ', body).strip()
                    else:
                        body = raw
            except Exception:
                body = ""
            # Limpar e truncar — garantir que nunca manda HTML cru
            import re as _re
            body = body.strip()
            if body and ("<html" in body.lower() or "<head" in body.lower() or "<style" in body.lower()):
                body = _re.sub(r'<[^>]+>', ' ', body)
                body = _re.sub(r'\s+', ' ', body).strip()
            body = body[:600] if body else ""

            alerts.append({
                "uid": uid,
                "emoji": emoji,
                "label": label,
                "subject": subject[:80],
                "sender": sender[:60],
                "date": date[:30],
                "body": body
            })
            state.setdefault("alerted_ids", []).append(uid)

        if mode == "briefing" and emoji:
            briefing_items.append(f"{emoji} *{label}*: {subject[:70]}")

    mail.logout()

    # Manter apenas últimos 500 IDs no estado
    state["alerted_ids"] = state.get("alerted_ids", [])[-500:]
    save_state(state)

    # ── Modo monitor: alerta imediato ─────────────────────────────────────────
    if mode == "monitor" and alerts:
        lines = [f"📬 *Alfred — Alerta de E-mail*\n"]
        for a in alerts[:5]:  # máx 5 por vez
            lines.append(f"{a['emoji']} *{a['label']}*")
            lines.append(f"De: {a['sender']}")
            lines.append(f"Assunto: {a['subject']}")
            if a.get("body"):
                lines.append(f"```\n{a['body'][:500]}\n```")
            lines.append("")
        send_telegram("\n".join(lines))

    # ── Modo briefing: resumo diário ─────────────────────────────────────────
    if mode == "briefing":
        hoje = datetime.now().strftime("%d/%m/%Y")
        if briefing_items:
            msg = f"📬 *Briefing de E-mail — {hoje}*\n\n"
            msg += "\n".join(briefing_items[:15])
            msg += "\n\n_Responda se quiser detalhes de algum._"
        else:
            msg = f"📬 *Briefing de E-mail — {hoje}*\n\nNada crítico na inbox. ✅"
        send_telegram(msg)

    print(f"[{datetime.now().strftime('%H:%M')}] {mode}: {len(alerts)} alertas encontrados.")

# ── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else "monitor"
    check_emails(mode)
