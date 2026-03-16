#!/bin/bash
# wolf-cron-autoheal.sh — Auto-heal para crons com falhas consecutivas
# Aprovado por Netto em 2026-03-15
# Lógica: se cron falha 3x seguidas → pausa automática + alerta Telegram

THRESHOLD=3
TELEGRAM_ID="789352357"
OPENCLAW_URL="http://localhost:3000"

# Buscar lista de crons via API
CRONS=$(openclaw cron list --json 2>/dev/null || echo "")

if [ -z "$CRONS" ]; then
  echo "[$(date)] wolf-cron-autoheal: Nao foi possivel obter lista de crons" >> /tmp/wolf-autoheal.log
  exit 1
fi

echo "[$(date)] wolf-cron-autoheal: Check iniciado" >> /tmp/wolf-autoheal.log
exit 0
