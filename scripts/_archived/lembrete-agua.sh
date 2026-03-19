#!/bin/bash
# lembrete-agua.sh — Lembrete de agua via WhatsApp (8x/dia)
# Cron: 0 8,10,12,14,16,18,20,22 * * * (BRT)
# Zero LLM — texto fixo direto pro WhatsApp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh" 2>/dev/null || true

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

wolf_notify "$MSG"

echo "[lembrete-agua] Enviado: $MSG"
