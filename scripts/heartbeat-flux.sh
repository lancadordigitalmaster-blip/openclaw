#!/bin/bash
# heartbeat-flux.sh — Flux (AI/LLM) heartbeat diario 06h30
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="b9db11f2-cae1-40f6-bc4f-703d7bf1bf69"  # Flux UUID
AGENT="Flux"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
CHECKS_OK=0

wolf_log "$AGENT" "Iniciando heartbeat de LLMs"

# ── ETAPA 1: Missao nasce (inbox) ──
MID=$(wolf_mission_create "Flux — Health check de LLMs" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando health check de todas as LLMs." "signal"

# ── ETAPA 2: Flux pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Flux comeca a testar (in_progress) ──
wolf_mission_move "$MID" "in_progress"

# 1a. Testar Anthropic Sonnet 4.6 (primario para Telegram)
SONNET_RESP=$(curl -s --max-time 15 "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: ${ANTHROPIC_API_KEY:-}" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-sonnet-4-6","max_tokens":5,"messages":[{"role":"user","content":"Responda apenas: OK"}]}' 2>/dev/null)

SONNET_CONTENT=$(echo "$SONNET_RESP" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    c=d.get('content',[{}])[0].get('text','')
    print('OK' if c else 'EMPTY')
except: print('ERROR')" 2>/dev/null)

if [ "$SONNET_CONTENT" = "OK" ]; then CHECKS_OK=$((CHECKS_OK + 1))
elif [ "$SONNET_CONTENT" = "EMPTY" ]; then ISSUES+=("Anthropic Sonnet 4.6: resposta vazia")
else
    SONNET_ERR=$(echo "$SONNET_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null)
    ISSUES+=("CRITICO: Anthropic Sonnet 4.6 falhou: $SONNET_ERR — Alfred no Telegram esta em fallback!")
fi

# 1b. Testar Anthropic Haiku 4.5 (primario para crons/heartbeat)
ANTH_RESP=$(curl -s --max-time 10 "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: ${ANTHROPIC_API_KEY:-}" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-haiku-4-5-20251001","max_tokens":5,"messages":[{"role":"user","content":"Responda apenas: OK"}]}' 2>/dev/null)

ANTH_CONTENT=$(echo "$ANTH_RESP" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    c=d.get('content',[{}])[0].get('text','')
    print('OK' if c else 'EMPTY')
except: print('ERROR')" 2>/dev/null)

if [ "$ANTH_CONTENT" = "OK" ]; then CHECKS_OK=$((CHECKS_OK + 1))
elif [ "$ANTH_CONTENT" = "EMPTY" ]; then ISSUES+=("Anthropic Haiku 4.5: resposta vazia")
else
    ANTH_ERR=$(echo "$ANTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null)
    ISSUES+=("Anthropic Haiku 4.5: $ANTH_ERR")
fi

# 2. Testar OpenRouter Haiku 4.5 (fallback)
OR_RESP=$(curl -s --max-time 10 "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY:-}" \
    -H "Content-Type: application/json" \
    -d '{"model":"anthropic/claude-haiku-4-5","messages":[{"role":"user","content":"Responda apenas: OK"}],"max_tokens":5}' 2>/dev/null)

OR_CONTENT=$(echo "$OR_RESP" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    c=d.get('choices',[{}])[0].get('message',{}).get('content','')
    print('OK' if c else 'EMPTY')
except: print('ERROR')" 2>/dev/null)

if [ "$OR_CONTENT" = "OK" ]; then CHECKS_OK=$((CHECKS_OK + 1))
elif [ "$OR_CONTENT" = "EMPTY" ]; then ISSUES+=("OpenRouter Haiku 4.5: resposta vazia")
else
    OR_ERR=$(echo "$OR_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message','unknown'))" 2>/dev/null)
    ISSUES+=("OpenRouter Haiku 4.5: $OR_ERR")
fi

# 3. Verificar crons LLM com erro
CRON_FILE="$HOME/.openclaw/cron/jobs.json"
if [ -f "$CRON_FILE" ]; then
    FAILED_CRONS=$(python3 -c "
import json
data = json.load(open('$CRON_FILE'))
failed = []
for j in data.get('jobs', []):
    if not j.get('enabled'): continue
    state = j.get('state', {})
    ce = state.get('consecutiveErrors', 0)
    if ce >= 2:
        failed.append(f\"{j['name']} ({ce}x)\")
    elif state.get('lastRunStatus') == 'error':
        failed.append(f\"{j['name']} (ultimo falhou)\")
print('|'.join(failed) if failed else '')
" 2>/dev/null)

    if [ -n "$FAILED_CRONS" ]; then
        IFS='|' read -ra CRON_LIST <<< "$FAILED_CRONS"
        for c in "${CRON_LIST[@]}"; do WARNINGS+=("Cron com erro: $c"); done
    else
        CHECKS_OK=$((CHECKS_OK + 1))
    fi
fi

# 4. Custo acumulado hoje
TELEMETRY="$HOME/.openclaw/logs/token-telemetry.jsonl"
COST_EST="0"
if [ -f "$TELEMETRY" ]; then
    TODAY=$(date +"%Y-%m-%d")
    TODAY_TOKENS=$(grep "$TODAY" "$TELEMETRY" 2>/dev/null | tail -1 | python3 -c "
import sys,json
try:
    line = sys.stdin.read().strip()
    if line:
        d = json.loads(line)
        sessions = d.get('sessions', d.get('data',{}).get('sessions',[]))
        total = sum(s.get('totalTokens', s.get('total_tokens', 0)) for s in sessions)
        print(total)
    else: print(0)
except: print(0)" 2>/dev/null)

    COST_EST=$(python3 -c "print(f'{int(${TODAY_TOKENS:-0}) * 0.00000015:.4f}')" 2>/dev/null)

    if python3 -c "exit(0 if float('${COST_EST:-0}') < 1.0 else 1)" 2>/dev/null; then
        CHECKS_OK=$((CHECKS_OK + 1))
    else
        WARNINGS+=("Custo hoje: \$$COST_EST (acima de \$1)")
    fi
fi

# ── ETAPA 4: Resultado ──
TOTAL_CHECKS=$((CHECKS_OK + ${#ISSUES[@]} + ${#WARNINGS[@]}))
DESCRIPTION="LLMs verificadas: $CHECKS_OK/$TOTAL_CHECKS OK | Custo hoje: \$${COST_EST:-?}"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Flux detectou ${#ISSUES[@]} LLM(s) com problema:"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    MSG="$MSG

Custo hoje: \$${COST_EST:-?}"
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, ${#ISSUES[@]} LLM(s) com problema. Custo hoje: \$${COST_EST:-?}" "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, LLMs OK com ${#WARNINGS[@]} aviso(s). Custo: \$${COST_EST:-?}" "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, todas LLMs saudaveis. Custo hoje: \$${COST_EST:-?}" "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — OK:$CHECKS_OK issues:${#ISSUES[@]} warnings:${#WARNINGS[@]} custo:\$${COST_EST:-?}"
echo "OK: flux heartbeat — checks=$CHECKS_OK issues=${#ISSUES[@]} warnings=${#WARNINGS[@]} cost=\$${COST_EST:-?}"
