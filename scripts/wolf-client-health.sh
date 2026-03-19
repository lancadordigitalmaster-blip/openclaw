#!/bin/bash
# wolf-client-health.sh — Client Health Monitor
# Roda diariamente às 07h00 — calcula health score por cliente
# Integra dados do gabi-proactive-alerts (não duplica coleta)
# Bash puro — sem LLM

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

CLIENTS_DIR="$WOLF_WORKSPACE/memory/clients"
TODAY=$(date +%Y-%m-%d)
LOG="$WOLF_WORKSPACE/memory/logs/client-health.log"
mkdir -p "$(dirname "$LOG")"

wolf_log "client-health" "Verificando saúde dos clientes"

# Ler clientes do clients.yaml
YAML_FILE="$HOME/.openclaw/workspace/shared/memory/clients.yaml"

# Para cada cliente com health.yaml
ALERTS=""
SUMMARY=""
CLIENT_COUNT=0

for health_file in "$CLIENTS_DIR"/*/health.yaml; do
  [ -f "$health_file" ] || continue
  CLIENT_DIR=$(dirname "$health_file")
  CLIENT_NAME=$(basename "$CLIENT_DIR")
  CLIENT_COUNT=$((CLIENT_COUNT + 1))

  # Ler token Meta Ads do cliente
  TOKEN_VAR=$(grep "meta_token_var" "$health_file" 2>/dev/null | awk -F'"' '{print $2}')
  AD_ACCOUNT=$(grep "meta_ad_account_id" "$health_file" 2>/dev/null | awk -F'"' '{print $2}')

  SCORE=70  # Score padrão (saudável)
  TREND="stable"
  ISSUES=""

  if [ -n "$TOKEN_VAR" ] && [ -n "$AD_ACCOUNT" ] && [ "$AD_ACCOUNT" != "null" ]; then
    TOKEN="${!TOKEN_VAR}"

    if [ -n "$TOKEN" ]; then
      # Puxar métricas dos últimos 3 dias
      INSIGHTS=$(curl -s --max-time 15 \
        "https://graph.facebook.com/v21.0/act_${AD_ACCOUNT}/insights?fields=spend,impressions,clicks,ctr,actions&date_preset=last_3d&access_token=$TOKEN" 2>/dev/null || echo "{}")

      # Salvar snapshot
      echo "$INSIGHTS" > "$CLIENT_DIR/snapshot-$TODAY.json"

      # Parsear com Python
      METRICS=$(echo "$INSIGHTS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin).get('data', [])
    if not data:
        print('NO_DATA')
        sys.exit(0)
    spend = sum(float(d.get('spend', 0)) for d in data)
    impressions = sum(int(d.get('impressions', 0)) for d in data)
    clicks = sum(int(d.get('clicks', 0)) for d in data)
    ctr = (clicks / impressions * 100) if impressions > 0 else 0
    convs = 0
    for d in data:
        for a in (d.get('actions') or []):
            if 'conversation' in a.get('action_type','') or 'lead' in a.get('action_type',''):
                convs += int(a.get('value', 0))
    cpa = spend / convs if convs > 0 else 0
    print(f'{spend:.2f}|{impressions}|{clicks}|{ctr:.2f}|{convs}|{cpa:.2f}')
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null)

      if [ "$METRICS" = "NO_DATA" ]; then
        SCORE=50
        ISSUES="sem dados nos ultimos 3 dias"
      elif echo "$METRICS" | grep -q "^ERROR"; then
        SCORE=60
        ISSUES="erro ao processar metricas"
      else
        # Parsear métricas
        SPEND=$(echo "$METRICS" | cut -d'|' -f1)
        IMPR=$(echo "$METRICS" | cut -d'|' -f2)
        CLICKS=$(echo "$METRICS" | cut -d'|' -f3)
        CTR=$(echo "$METRICS" | cut -d'|' -f4)
        CONVS=$(echo "$METRICS" | cut -d'|' -f5)
        CPA=$(echo "$METRICS" | cut -d'|' -f6)

        # Calcular spend diário médio (3 dias)
        AVG_SPEND=$(python3 -c "print(f'{float(\"$SPEND\")/3:.2f}')" 2>/dev/null || echo "0")

        # Salvar métricas no health.yaml
        sed -i '' "s/  avg_cpa_7d: .*/  avg_cpa_7d: $CPA/" "$health_file" 2>/dev/null
        sed -i '' "s/  avg_ctr_7d: .*/  avg_ctr_7d: $CTR/" "$health_file" 2>/dev/null
        sed -i '' "s/  avg_spend_daily: .*/  avg_spend_daily: $AVG_SPEND/" "$health_file" 2>/dev/null

        # Calcular score baseado nas métricas
        # Impressões > 0 = +10, Conversões > 0 = +15, CTR > 1% = +5
        SCORE=60
        [ "$IMPR" -gt 0 ] 2>/dev/null && SCORE=$((SCORE + 10))
        [ "$CONVS" -gt 0 ] 2>/dev/null && SCORE=$((SCORE + 15))
        python3 -c "exit(0 if float('$CTR') > 1.0 else 1)" 2>/dev/null && SCORE=$((SCORE + 5))
        python3 -c "exit(0 if float('$CPA') > 0 and float('$CPA') < 10 else 1)" 2>/dev/null && SCORE=$((SCORE + 10))

        [ $SCORE -gt 100 ] && SCORE=100
      fi
    else
      SCORE=40
      ISSUES="token nao configurado ($TOKEN_VAR)"
    fi
  fi

  # Verificar alertas Gabi recentes para este cliente
  GABI_ALERTS=$(grep -c "$CLIENT_NAME" "$WOLF_WORKSPACE/memory/gabi/alerts-log.md" 2>/dev/null || echo "0")
  GABI_ALERTS=$(echo "$GABI_ALERTS" | tr -d '[:space:]')
  [ "$GABI_ALERTS" -gt 2 ] 2>/dev/null && SCORE=$((SCORE - 10))

  # Determinar trend (comparar com score anterior)
  PREV_SCORE=$(grep "score:" "$health_file" | head -1 | awk '{print $2}')
  if [ -n "$PREV_SCORE" ] && [ "$PREV_SCORE" != "null" ]; then
    DIFF=$((SCORE - PREV_SCORE))
    if [ $DIFF -gt 5 ]; then TREND="improving"
    elif [ $DIFF -lt -5 ]; then TREND="declining"
    else TREND="stable"; fi
  fi

  # Atualizar health.yaml com sed
  sed -i '' "s/  score: .*/  score: $SCORE/" "$health_file" 2>/dev/null
  sed -i '' "s/  trend: .*/  trend: $TREND/" "$health_file" 2>/dev/null
  sed -i '' "s/  last_check: .*/  last_check: \"$TODAY\"/" "$health_file" 2>/dev/null

  # Adicionar ao histórico (JSON simples ao lado do health.yaml)
  HISTORY_FILE="$CLIENT_DIR/history.jsonl"
  echo "{\"date\":\"$TODAY\",\"score\":$SCORE,\"trend\":\"$TREND\"}" >> "$HISTORY_FILE"
  # Manter apenas últimos 30 dias
  if [ -f "$HISTORY_FILE" ]; then
    tail -30 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
  fi

  # Build summary
  EMOJI="🟢"
  [ $SCORE -lt 70 ] && EMOJI="🟡"
  [ $SCORE -lt 50 ] && EMOJI="🔴"

  DISPLAY_NAME=$(grep "client:" "$health_file" 2>/dev/null | awk -F'"' '{print $2}')
  [ -z "$DISPLAY_NAME" ] && DISPLAY_NAME="$CLIENT_NAME"

  SUMMARY="${SUMMARY}${EMOJI} ${DISPLAY_NAME}: ${SCORE}/100 (${TREND})"
  [ -n "$ISSUES" ] && SUMMARY="${SUMMARY} — ${ISSUES}"
  SUMMARY="${SUMMARY}\n"

  # Alertas urgentes
  if [ $SCORE -lt 50 ]; then
    ALERTS="${ALERTS}🔴 ${DISPLAY_NAME}: score ${SCORE}/100 — ${ISSUES:-atencao necessaria}\n"
  fi

  wolf_log "client-health" "$DISPLAY_NAME: score=$SCORE trend=$TREND"
done

# Enviar alertas urgentes
if [ -n "$ALERTS" ]; then
  wolf_notify_urgent "🏥 *Client Health — $TODAY*\n\n$ALERTS\nAção requerida para clientes em risco."
fi

# Log resumo (não envia se tudo OK — silêncio = saudável)
wolf_log "client-health" "Verificados: $CLIENT_COUNT clientes"

echo "OK: wolf-client-health completed ($CLIENT_COUNT clients) at $(date '+%Y-%m-%d %H:%M:%S')"
