#!/bin/bash
# lembrete-agua.sh — Lembrete de agua via Telegram (8x/dia)
# Cron: 0 8,10,12,14,16,18,20,22 * * * (BRT)
# Zero LLM — texto fixo direto pro Telegram

set -euo pipefail

ENV_FILE="$HOME/.openclaw/.env"
if [ -f "$ENV_FILE" ]; then set -a; source "$ENV_FILE"; set +a; fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

[ -z "$BOT_TOKEN" ] && { echo "[lembrete-agua] BOT_TOKEN vazio"; exit 1; }

HORA=$(date +"%H")

case "$HORA" in
    08) MSG="Bom dia, Netto. Lembra de tomar agua antes de comecar o dia.";;
    10) MSG="Netto, pausa rapida — bebe um copo de agua.";;
    12) MSG="Meio-dia, Netto. Agua antes do almoco.";;
    14) MSG="Boa tarde. Ja tomou agua depois do almoco?";;
    16) MSG="Netto, hidratacao da tarde. Bebe agua.";;
    18) MSG="Fim do expediente chegando. Bebe agua.";;
    20) MSG="Noite, Netto. Mais um copo de agua.";;
    22) MSG="Ultimo lembrete do dia — bebe agua antes de dormir.";;
    *)  MSG="Netto, bebe agua.";;
esac

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"$CHAT_ID\", \"text\": \"$MSG\"}" \
    > /dev/null 2>&1

echo "[lembrete-agua] Enviado: $MSG"
