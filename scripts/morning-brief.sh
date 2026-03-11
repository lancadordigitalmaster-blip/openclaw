#!/bin/bash
# morning-brief.sh — Morning Brief do Netto
# Roda 08:30 todo dia — 3 mensagens separadas em sequência
# Bloco 1: Tasks | Bloco 2: Emails | Bloco 3: Financeiro

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG="$WORKSPACE/memory/logs/morning-brief.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$TIMESTAMP] $1" | tee -a "$LOG"; }

log "Morning Brief iniciado"

# ── Bloco 1: Task Queue ────────────────────────────────────────────────────
log "Bloco 1: Task Queue"
bash "$WORKSPACE/scripts/morning_kickoff.sh" >> "$LOG" 2>&1 && log "Tasks OK" || log "WARN: Tasks falhou"

sleep 3

# ── Bloco 2: Email Briefing ───────────────────────────────────────────────
log "Bloco 2: Email Briefing"
cd "$WORKSPACE" && scripts/.venv/bin/python3 scripts/email-monitor.py briefing >> "$LOG" 2>&1 && log "Email OK" || log "WARN: Email falhou"

# ── Bloco 3: Financeiro — SUSPENSO (migrar para WhatsApp)
# log "Bloco 3: Financeiro"
# scripts/.venv/bin/python3 scripts/financeiro-morning.py >> "$LOG" 2>&1

log "Morning Brief concluído"
