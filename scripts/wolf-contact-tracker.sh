#!/bin/bash
# wolf-contact-tracker.sh — Rastreia último contato humano com cada cliente
# Roda diariamente às 07h15 (antes do Health Monitor às 07h00? Não — depois, pra atualizar health)
# Crontab: 15 7 * * * bash ~/.openclaw/workspace/scripts/wolf-contact-tracker.sh >> ~/.openclaw/workspace/memory/logs/contact-tracker.log 2>&1
#
# Fontes de dados:
# 1. WhatsApp Bridge logs (mensagens enviadas/recebidas por grupo)
# 2. Gateway sessions (menção ao cliente em conversas com Netto)
# 3. Health yaml (campo days_since_human_contact)

set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

CLIENTS_DIR="$WOLF_WORKSPACE/memory/clients"
SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
BRIDGE_GROUPS="$HOME/openclaw/whatsapp-bridge/groups"
TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date +%s)
ALERTS=""

wolf_log "contact-tracker" "Verificando ultimo contato com clientes"

for health_file in "$CLIENTS_DIR"/*/health.yaml; do
  [ -f "$health_file" ] || continue
  CLIENT_DIR=$(dirname "$health_file")
  CLIENT_SLUG=$(basename "$CLIENT_DIR")
  CLIENT_NAME=$(grep "client:" "$health_file" 2>/dev/null | awk -F'"' '{print $2}')
  [ -z "$CLIENT_NAME" ] && CLIENT_NAME="$CLIENT_SLUG"

  LAST_CONTACT=""

  # === FONTE 1: WhatsApp Bridge (buscar menção ao cliente nos grupos) ===
  # Buscar nos summaries diários dos grupos
  if [ -d "$BRIDGE_GROUPS" ]; then
    for summary in "$BRIDGE_GROUPS"/*/summaries/daily-*.json; do
      [ -f "$summary" ] || continue
      SUMMARY_DATE=$(basename "$summary" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
      [ -z "$SUMMARY_DATE" ] && continue

      # Verificar se o nome do cliente aparece no summary
      if grep -qi "$CLIENT_SLUG" "$summary" 2>/dev/null || grep -qi "$CLIENT_NAME" "$summary" 2>/dev/null; then
        if [ -z "$LAST_CONTACT" ] || [[ "$SUMMARY_DATE" > "$LAST_CONTACT" ]]; then
          LAST_CONTACT="$SUMMARY_DATE"
        fi
      fi
    done
  fi

  # === FONTE 2: Gateway sessions (menção ao cliente em conversas) ===
  if [ -d "$SESSIONS_DIR" ]; then
    # Verificar últimos 30 dias de sessões
    for session_file in "$SESSIONS_DIR"/*.jsonl; do
      [ -f "$session_file" ] || continue
      # Buscar menção do cliente nos últimos 30 dias
      MATCH_DATE=$(grep -i "$CLIENT_SLUG" "$session_file" 2>/dev/null | \
        grep -oE '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}' 2>/dev/null | \
        grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' 2>/dev/null | \
        sort -r | head -1 || true)

      if [ -n "$MATCH_DATE" ]; then
        if [ -z "$LAST_CONTACT" ] || [[ "$MATCH_DATE" > "$LAST_CONTACT" ]]; then
          LAST_CONTACT="$MATCH_DATE"
        fi
      fi
    done
  fi

  # === FONTE 3: Snapshots de health (se tem snapshot recente, houve interação) ===
  LATEST_SNAPSHOT=$(ls -1 "$CLIENT_DIR"/snapshot-*.json 2>/dev/null | sort -r | head -1)
  if [ -n "$LATEST_SNAPSHOT" ]; then
    SNAP_DATE=$(basename "$LATEST_SNAPSHOT" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
    if [ -n "$SNAP_DATE" ]; then
      if [ -z "$LAST_CONTACT" ] || [[ "$SNAP_DATE" > "$LAST_CONTACT" ]]; then
        LAST_CONTACT="$SNAP_DATE"
      fi
    fi
  fi

  # === CALCULAR DIAS SEM CONTATO ===
  DAYS_SINCE="null"
  if [ -n "$LAST_CONTACT" ]; then
    CONTACT_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_CONTACT" "+%s" 2>/dev/null || echo 0)
    if [ "$CONTACT_EPOCH" -gt 0 ]; then
      DAYS_SINCE=$(( (TODAY_EPOCH - CONTACT_EPOCH) / 86400 ))
    fi
  fi

  # === ATUALIZAR HEALTH.YAML ===
  if [ "$DAYS_SINCE" != "null" ]; then
    sed -i '' "s/  days_since_human_contact: .*/  days_since_human_contact: $DAYS_SINCE/" "$health_file" 2>/dev/null
  fi

  # === ALERTAS ===
  if [ "$DAYS_SINCE" != "null" ] && [ "$DAYS_SINCE" -ge 21 ] 2>/dev/null; then
    ALERTS="${ALERTS}🔴 ${CLIENT_NAME}: ${DAYS_SINCE} dias sem contato humano — URGENTE\n"
  elif [ "$DAYS_SINCE" != "null" ] && [ "$DAYS_SINCE" -ge 14 ] 2>/dev/null; then
    ALERTS="${ALERTS}🟡 ${CLIENT_NAME}: ${DAYS_SINCE} dias sem contato humano\n"
  fi

  wolf_log "contact-tracker" "$CLIENT_NAME: last_contact=$LAST_CONTACT days_since=$DAYS_SINCE"
done

# Enviar alertas se necessário
if [ -n "$ALERTS" ]; then
  wolf_notify_urgent "📞 *Contact Tracker — $TODAY*\n\n$ALERTS\nClientes precisam de atenção humana."
fi

echo "OK: wolf-contact-tracker completed at $(date '+%Y-%m-%d %H:%M:%S')"
