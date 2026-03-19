#!/bin/bash
# heartbeat-digest.sh — Resumo diario dos heartbeats (10h BRT)
# Le TODOS os logs de heartbeat das ultimas 24h e envia 1 mensagem consolidada
# Crontab: 0 10 * * * bash ~/.openclaw/workspace/scripts/heartbeat-digest.sh >> ~/.openclaw/logs/heartbeat-digest.log 2>&1

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

DATE=$(date '+%d/%m/%Y')
TODAY=$(date '+%Y-%m-%d')
YESTERDAY=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d 'yesterday' '+%Y-%m-%d')
LOG_DIR="$HOME/.openclaw/workspace/memory/logs"

wolf_log "hb-digest" "Iniciando Heartbeat Digest"

# Agentes com heartbeat (nome:schedule)
AGENTS="shield:02h bridge:05h forge:04h30 echo:05h30 flux:06h30 iris:07h30 titan:07h atlas:04h vega:08h gabi:09h ops:03h luna:seg-09h sage:ter-09h nova:seg-10h quill:sex-16h turbo:dom-05h craft:sab-06h pixel:qua-06h"

TOTAL=0
RAN=0
ISSUES=0
WARNINGS=0
ISSUE_LIST=""
OK_LIST=""

for entry in $AGENTS; do
    NAME="${entry%%:*}"
    SCHEDULE="${entry#*:}"
    LOGFILE="$LOG_DIR/heartbeat-${NAME}.log"
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$LOGFILE" ]; then
        ISSUE_LIST="${ISSUE_LIST}\n  - ${NAME} (${SCHEDULE}): sem log"
        ISSUES=$((ISSUES + 1))
        continue
    fi

    # Check if ran in last 24h (today or yesterday)
    LAST_LINE=$(tail -1 "$LOGFILE" 2>/dev/null)
    if echo "$LAST_LINE" | grep -qE "$TODAY|$YESTERDAY"; then
        RAN=$((RAN + 1))

        # Check for issues in the last run
        HAS_ISSUE=$(grep -cE "$TODAY.*\(CRITICO\|ISSUE\|PROBLEMA\)" "$LOGFILE" 2>/dev/null || echo 0)
        HAS_WARN=$(grep -cE "$TODAY.*\(AVISO\|WARNING\)" "$LOGFILE" 2>/dev/null || echo 0)

        if [ "$HAS_ISSUE" -gt 0 ]; then
            ISSUES=$((ISSUES + 1))
            DETAIL=$(grep -E "$TODAY.*\(CRITICO\|ISSUE\|PROBLEMA\)" "$LOGFILE" 2>/dev/null | tail -1 | sed "s/.*$TODAY [0-9:]* //" | cut -c1-60)
            ISSUE_LIST="${ISSUE_LIST}\n  - ${NAME}: ${DETAIL}"
        elif [ "$HAS_WARN" -gt 0 ]; then
            WARNINGS=$((WARNINGS + 1))
        else
            OK_LIST="${OK_LIST} ${NAME}"
        fi
    else
        # Didn't run — check if it was supposed to (daily vs weekly)
        case "$SCHEDULE" in
            *seg*|*ter*|*qua*|*qui*|*sex*|*sab*|*dom*)
                # Weekly — only flag if it's the right day and didn't run
                OK_LIST="${OK_LIST} ${NAME}(semanal)"
                RAN=$((RAN + 1))  # count as "not expected today"
                ;;
            *)
                # Daily — should have run
                ISSUE_LIST="${ISSUE_LIST}\n  - ${NAME} (${SCHEDULE}): nao rodou"
                ISSUES=$((ISSUES + 1))
                ;;
        esac
    fi
done

# Build message
if [ "$ISSUES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    # All good — silent (no notification)
    wolf_log "hb-digest" "Todos heartbeats OK — ${RAN}/${TOTAL} rodaram. Sem notificacao."
    echo "OK: heartbeat-digest — all clear, no notification sent"
    exit 0
fi

# Only notify if there are issues or warnings
MSG="*Heartbeat Digest — ${DATE}*

Status: ${RAN}/${TOTAL} rodaram | ${ISSUES} problema(s) | ${WARNINGS} aviso(s)"

if [ -n "$ISSUE_LIST" ]; then
    MSG="${MSG}

*Problemas:*$(echo -e "$ISSUE_LIST")"
fi

if [ -n "$OK_LIST" ]; then
    MSG="${MSG}

OK:${OK_LIST}"
fi

wolf_notify "$MSG"
wolf_log "hb-digest" "Digest enviado — ran=$RAN/$TOTAL issues=$ISSUES warnings=$WARNINGS"
