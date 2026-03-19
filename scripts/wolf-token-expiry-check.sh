#!/bin/bash
# wolf-token-expiry-check.sh — Wolf Agency
# Verifica dias restantes até expiração dos tokens Meta Ads
# Alerta via WhatsApp em 30, 14, 7, 3, 1 dia antes
# Zero LLM. Roda via cron diário às 09h.

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"
source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

LOG="/tmp/wolf-token-expiry.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Data de expiração dos tokens Meta Ads (atualizar quando renovar)
META_TOKEN_EXPIRY="2026-05-12"

# Calcular dias restantes
EXPIRY_EPOCH=$(date -j -f "%Y-%m-%d" "$META_TOKEN_EXPIRY" "+%s" 2>/dev/null)
TODAY_EPOCH=$(date "+%s")
DAYS_LEFT=$(( (EXPIRY_EPOCH - TODAY_EPOCH) / 86400 ))

echo "[$TIMESTAMP] Meta Ads tokens: $DAYS_LEFT dias restantes (expira $META_TOKEN_EXPIRY)" >> "$LOG"

# Alertar em marcos específicos
ALERT_DAYS="30 14 7 3 1"

for D in $ALERT_DAYS; do
    if [ "$DAYS_LEFT" -eq "$D" ]; then
        if [ "$DAYS_LEFT" -le 3 ]; then
            EMOJI="🔴"
            URGENCY="URGENTE"
        elif [ "$DAYS_LEFT" -le 7 ]; then
            EMOJI="🟡"
            URGENCY="ATENÇÃO"
        else
            EMOJI="🟢"
            URGENCY="LEMBRETE"
        fi

        MSG="$EMOJI *$URGENCY — Meta Ads Tokens*

Os tokens Meta Ads expiram em *$DAYS_LEFT dia(s)* ($META_TOKEN_EXPIRY).

Clientes afetados:
• GR Veículos (act_1221676633470141)
• Ticomia (act_1336968033454787)
• William Forlan (act_702342462816996)
• Wolf Pack (act_1583430182930723)

👉 Renovar em: business.facebook.com > System Users > Generate Token

_Após renovar, atualizar .env e .env.facebook_"

        if [ "$DAYS_LEFT" -le 3 ]; then
            wolf_notify_urgent "$MSG"
        else
            wolf_notify "$MSG"
        fi

        echo "[$TIMESTAMP] ALERTA ENVIADO: $DAYS_LEFT dias restantes" >> "$LOG"
        break
    fi
done

# Alerta crítico: token já expirou
if [ "$DAYS_LEFT" -lt 0 ]; then
    MSG="🔴 *CRÍTICO — Meta Ads Tokens EXPIRADOS*

Tokens expiraram há $(( DAYS_LEFT * -1 )) dia(s)!
Campanhas de TODOS os clientes estão paradas.

👉 Renovar AGORA em: business.facebook.com"

    wolf_notify_urgent "$MSG"
    echo "[$TIMESTAMP] CRITICO: Tokens expirados há $(( DAYS_LEFT * -1 )) dias" >> "$LOG"
fi

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 100 ]]; then
    tail -50 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
