#!/bin/bash
# heartbeat-turbo.sh — Turbo (Performance) heartbeat semanal (domingo 05h)
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="4043d898-d25b-40f6-849a-c4aa33231282"  # Turbo UUID
AGENT="Turbo"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de performance"

# ── ETAPA 1: Missao nasce (inbox) ──
MID=$(wolf_mission_create "Turbo — Analise de performance" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando analise de performance do sistema." "signal"

# ── ETAPA 2: Turbo pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Turbo comeca a medir (in_progress) ──
wolf_mission_move "$MID" "in_progress"

# 1. Workspace size
WS_SIZE=$(du -sh "$WOLF_WORKSPACE" 2>/dev/null | awk '{print $1}')
WS_BYTES=$(du -s "$WOLF_WORKSPACE" 2>/dev/null | awk '{print $1}')
METRICS="Workspace: $WS_SIZE"
[ "${WS_BYTES:-0}" -gt 512000 ] 2>/dev/null && WARNINGS+=("Workspace cresceu para $WS_SIZE (limite: 500MB)")

# 2. Logs acumulados
LOG_DIR="$WOLF_WORKSPACE/memory/logs"
if [ -d "$LOG_DIR" ]; then
    LOG_SIZE=$(du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}')
    LOG_COUNT=$(find "$LOG_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    METRICS="$METRICS | Logs: $LOG_SIZE ($LOG_COUNT arquivos)"
    OLD_LOGS=$(find "$LOG_DIR" -type f -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    if [ "${OLD_LOGS:-0}" -gt 0 ] 2>/dev/null; then
        find "$LOG_DIR" -type f -mtime +7 -delete 2>/dev/null
        METRICS="$METRICS | Limpei $OLD_LOGS logs antigos (>7d)"
    fi
fi

# 3. Gateway logs
GW_LOG="$HOME/.openclaw/logs/gateway.log"
if [ -f "$GW_LOG" ]; then
    GW_SIZE=$(du -sh "$GW_LOG" 2>/dev/null | awk '{print $1}')
    METRICS="$METRICS | Gateway log: $GW_SIZE"
    GW_BYTES=$(du -s "$GW_LOG" 2>/dev/null | awk '{print $1}')
    [ "${GW_BYTES:-0}" -gt 51200 ] 2>/dev/null && WARNINGS+=("Gateway log grande: $GW_SIZE")
fi

# 4. Sessions acumuladas
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [ -f "$SESSIONS_FILE" ]; then
    SESSION_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS_FILE')); print(len(d) if isinstance(d,dict) else 0)" 2>/dev/null || echo "0")
    SESSION_SIZE=$(du -sh "$SESSIONS_FILE" 2>/dev/null | awk '{print $1}')
    METRICS="$METRICS | Sessions: $SESSION_COUNT ($SESSION_SIZE)"
    [ "$SESSION_COUNT" -gt 10 ] 2>/dev/null && WARNINGS+=("$SESSION_COUNT sessoes acumuladas")
fi

# 5. Disco
DISK_PCT=$(df "$WOLF_WORKSPACE" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
DISK_FREE=$(df -h "$WOLF_WORKSPACE" 2>/dev/null | awk 'NR==2 {print $4}')
METRICS="$METRICS | Disco: ${DISK_PCT}% usado ($DISK_FREE livre)"
[ "$DISK_PCT" -gt 85 ] 2>/dev/null && ISSUES+=("Disco critico: ${DISK_PCT}%")
[ "$DISK_PCT" -gt 70 ] && [ "$DISK_PCT" -le 85 ] 2>/dev/null && WARNINGS+=("Disco alto: ${DISK_PCT}%")

# 6. Gateway latencia
GW_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 5 "http://127.0.0.1:18789/" 2>/dev/null || echo "timeout")
METRICS="$METRICS | Gateway latencia: ${GW_TIME}s"
python3 -c "exit(0 if float('$GW_TIME') > 2.0 else 1)" 2>/dev/null && WARNINGS+=("Gateway lento: ${GW_TIME}s")

# 7. Telemetria
TELEMETRY="$HOME/.openclaw/logs/token-telemetry.jsonl"
if [ -f "$TELEMETRY" ]; then
    TEL_LINES=$(wc -l < "$TELEMETRY" | tr -d ' ')
    TEL_SIZE=$(du -sh "$TELEMETRY" 2>/dev/null | awk '{print $1}')
    METRICS="$METRICS | Telemetria: $TEL_LINES entries ($TEL_SIZE)"
fi

# ── ETAPA 4: Resultado ──
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Turbo detectou ${#ISSUES[@]} problema(s) de performance:
$METRICS"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, performance critica — ${#ISSUES[@]} problema(s). ${WS_SIZE} workspace, disco ${DISK_PCT}%." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, performance com ${#WARNINGS[@]} aviso(s). Workspace: ${WS_SIZE}." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, performance OK. Workspace: ${WS_SIZE}, disco ${DISK_PCT}% usado." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: turbo heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
