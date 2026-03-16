#!/usr/bin/env python3
"""wolf-reminders.py — Sistema unificado de lembretes via WhatsApp (zero LLM)

Uso:
    python3 wolf-reminders.py                  # envia lembrete da hora atual
    python3 wolf-reminders.py --type agua      # força tipo específico
    python3 wolf-reminders.py --type approvals # checa pendências
    python3 wolf-reminders.py --list           # lista todos os lembretes configurados

Crontab:
    0 8,10,12,14,16,18,20,22 * * * python3 scripts/wolf-reminders.py --type agua
    0 15 * * * python3 scripts/wolf-reminders.py --type approvals
"""

import json
import os
import sys
import random
import urllib.request
import urllib.parse
from datetime import datetime
from pathlib import Path

# ── Config ──
ENV_FILE = Path.home() / ".openclaw" / ".env"
WORKSPACE = Path.home() / ".openclaw" / "workspace"
LOG_DIR = WORKSPACE / "memory" / "logs"
WHATSAPP_BRIDGE = "http://127.0.0.1:3002/send"
NETTO_WHATSAPP = os.environ.get("NETTO_WHATSAPP", "557391484716")

def load_env():
    """Carrega variáveis do .env"""
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, val = line.partition("=")
                val = val.strip().strip("'\"")
                env[key.strip()] = val
                os.environ.setdefault(key.strip(), val)
    return env

def send_whatsapp(text, to=None):
    """Envia mensagem via WhatsApp Bridge API (porta 3002)"""
    to = to or os.environ.get("NETTO_WHATSAPP", NETTO_WHATSAPP)
    payload = json.dumps({"to": to, "text": text}).encode()
    req = urllib.request.Request(WHATSAPP_BRIDGE, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except Exception as e:
        print(f"[wolf-reminders] Erro WhatsApp Bridge: {e}")
        return False

def notify(text):
    """Envia via WhatsApp (sem fallback Telegram)"""
    return send_whatsapp(text)

# ── Lembretes de Água ──
AGUA_MSGS = {
    8:  [
        "Bom dia, Netto. Começa o dia com um copo de água.",
        "Bom dia! Hidrata antes de abrir o notebook.",
        "Manhã começando — bebe água antes de tudo.",
    ],
    10: [
        "Pausa rápida — bebe um copo de água.",
        "Meio da manhã, hora de hidratar.",
        "Netto, 10h. Já bebeu água hoje?",
    ],
    12: [
        "Meio-dia. Água antes do almoço.",
        "12h — hidrata antes de comer.",
        "Pausa pro almoço. Começa com água.",
    ],
    14: [
        "Boa tarde. Já tomou água depois do almoço?",
        "14h — aquela água pós-almoço.",
        "Tarde começando. Bebe água.",
    ],
    16: [
        "Hidratação da tarde. Bebe água.",
        "16h — mais um copo de água.",
        "Reta final do dia. Hidrata.",
    ],
    18: [
        "Fim do expediente chegando. Bebe água.",
        "18h — pausa pra hidratar.",
        "Encerramento do dia de trabalho. Água!",
    ],
    20: [
        "Noite, Netto. Mais um copo de água.",
        "20h — hidrata antes do jantar.",
        "Lembrete noturno de água.",
    ],
    22: [
        "Último lembrete do dia — bebe água antes de dormir.",
        "22h — último copo do dia. Boa noite!",
        "Antes de descansar: água.",
    ],
}

def lembrete_agua():
    """Envia lembrete de água com mensagem aleatória por horário"""
    hora = datetime.now().hour
    msgs = AGUA_MSGS.get(hora, ["Netto, bebe água."])
    msg = random.choice(msgs)
    if notify(msg):
        print(f"[agua] Enviado ({hora}h): {msg}")
    return True

# ── Aprovações Pendentes ──
def lembrete_approvals():
    """Checa pending-approvals.json e notifica se houver pendências"""
    pending_file = WORKSPACE / "memory" / "pending-approvals.json"

    if not pending_file.exists():
        print("[approvals] Nenhum arquivo de pendências")
        return True

    try:
        data = json.loads(pending_file.read_text())
        pending = [p for p in data if p.get("status") == "pending"]
    except (json.JSONDecodeError, KeyError):
        print("[approvals] Arquivo inválido")
        return True

    if not pending:
        print("[approvals] Nenhuma pendência")
        return True

    names = "\n".join(f"- {p.get('actionName', p.get('name', 'sem nome'))}" for p in pending)
    msg = f"Netto, tem {len(pending)} proposta(s) esperando tua resposta:\n\n{names}\n\nResponde SIM ou NÃO pra cada uma no Telegram."

    if notify(msg):
        print(f"[approvals] {len(pending)} pendência(s) notificadas")
    return True

# ── Registry ──
REMINDERS = {
    "agua": {"fn": lembrete_agua, "desc": "Lembrete de água (8x/dia)", "cron": "0 8,10,12,14,16,18,20,22 * * *"},
    "approvals": {"fn": lembrete_approvals, "desc": "Propostas pendentes (15h)", "cron": "0 15 * * *"},
}

def list_reminders():
    print("Lembretes configurados:\n")
    for key, r in REMINDERS.items():
        print(f"  {key:12s} — {r['desc']}")
        print(f"  {'':12s}   cron: {r['cron']}\n")

def main():
    load_env()

    if "--list" in sys.argv:
        list_reminders()
        return

    reminder_type = None
    if "--type" in sys.argv:
        idx = sys.argv.index("--type")
        if idx + 1 < len(sys.argv):
            reminder_type = sys.argv[idx + 1]

    if reminder_type:
        if reminder_type not in REMINDERS:
            print(f"Tipo desconhecido: {reminder_type}. Use: {', '.join(REMINDERS.keys())}")
            sys.exit(1)
        REMINDERS[reminder_type]["fn"]()
    else:
        # Auto-detect pela hora
        lembrete_agua()

if __name__ == "__main__":
    main()
