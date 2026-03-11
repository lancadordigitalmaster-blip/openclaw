#!/bin/bash
# gateway-healthcheck.sh — Wolf Agency OpenClaw
# Roda a cada 2 min via cron
# Detecta gateway morto e faz bootstrap se necessário

WATCHDOG_LOG="$HOME/.openclaw/logs/watchdog.log"
PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) $1" >> "$WATCHDOG_LOG"; }

# Checa se o processo existe
if ! pgrep -f "openclaw" > /dev/null 2>&1; then
    log "[HEALTHCHECK] Gateway morto — nenhum processo openclaw"

    # Verifica se está no launchd
    IS_BOOTSTRAPPED=$(launchctl list 2>/dev/null | grep -c "ai.openclaw.gateway" || true)

    if [ "$IS_BOOTSTRAPPED" -eq 0 ]; then
        log "[HEALTHCHECK] Serviço não está no launchd — executando bootstrap"
        launchctl bootstrap gui/$(id -u) "$PLIST" 2>/dev/null
        sleep 5
    else
        log "[HEALTHCHECK] Serviço no launchd mas processo morto — kickstart"
        launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
        sleep 5
    fi

    # Verifica resultado
    NEW_PID=$(pgrep -f "openclaw" 2>/dev/null | head -1)
    if [ -n "$NEW_PID" ]; then
        log "[HEALTHCHECK] Gateway recuperado (PID $NEW_PID)"
    else
        log "[HEALTHCHECK] FALHA ao recuperar gateway — tente manualmente: bash ~/.openclaw/scripts/alfred-emergency-reset.sh"
    fi
fi

exit 0
