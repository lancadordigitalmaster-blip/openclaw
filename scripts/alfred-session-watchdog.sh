#!/bin/bash
# alfred-session-watchdog.sh — Wolf Agency
# Detecta sessão travada do Alfred e auto-corrige
# Roda a cada 3min via cron
#
# Padrões de sessão travada:
#   1. "typing TTL reached" nos últimos 5min (Alfred ficou digitando sem responder)
#   2. "live session model switch" 3+ vezes nos últimos 5min (loop de fallback)
#   3. Nenhum "sendMessage ok" nos últimos 5min (Alfred parou de responder)

GATEWAY_LOG="$HOME/.openclaw/logs/gateway.log"
WATCHDOG_LOG="$HOME/.openclaw/logs/session-watchdog.log"
SESSIONS="$HOME/.openclaw/agents/main/sessions/sessions.json"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) $1" | tee -a "$WATCHDOG_LOG"; }

mkdir -p "$(dirname "$WATCHDOG_LOG")"

# Pega últimas 5 minutos do log
RECENT=$(tail -200 "$GATEWAY_LOG" 2>/dev/null | \
  awk -v cutoff="$(date -v-5M '+%Y-%m-%dT%H:%M')" '$0 >= cutoff')

[ -z "$RECENT" ] && exit 0

# ── Detectores de sessão travada ──────────────────────────────

# Sinal 1: typing TTL (Alfred ficou "digitando" sem responder)
TYPING_TTL=$(echo "$RECENT" | grep -c "typing TTL reached" || true)

# Sinal 2: loop de model switch (fallback repetindo)
MODEL_SWITCH=$(echo "$RECENT" | grep -c "live session model switch" || true)

# Sinal 3: tempo desde última resposta bem-sucedida
LAST_SEND=$(echo "$RECENT" | grep "sendMessage ok" | tail -1)

# ── Decisão ───────────────────────────────────────────────────

STUCK=false
REASON=""

if [ "$TYPING_TTL" -gt 0 ]; then
  STUCK=true
  REASON="typing TTL reached ($TYPING_TTL vez(es))"
fi

if [ "$MODEL_SWITCH" -ge 3 ] && [ -z "$LAST_SEND" ]; then
  STUCK=true
  REASON="$REASON | model switch loop ($MODEL_SWITCH vezes) sem resposta"
fi

if [ "$STUCK" = false ]; then
  exit 0
fi

# ── Auto-heal ─────────────────────────────────────────────────

log "[WATCHDOG] Sessão travada detectada: $REASON"
log "[WATCHDOG] Iniciando auto-heal..."

# Limpa sessão travada
if [ -f "$SESSIONS" ]; then
  cp "$SESSIONS" "${SESSIONS}.bak.$(date '+%Y%m%d%H%M%S')" 2>/dev/null
  rm -f "$SESSIONS"
  log "[WATCHDOG] sessions.json removido"
fi

# Reinicia gateway
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null
sleep 5

# Verifica se voltou
NEW_PID=$(pgrep -f "openclaw" 2>/dev/null | head -1)
if [ -n "$NEW_PID" ]; then
  log "[WATCHDOG] ✓ Alfred recuperado (PID $NEW_PID)"
else
  log "[WATCHDOG] FALHA ao recuperar — intervenção manual necessária"
fi
