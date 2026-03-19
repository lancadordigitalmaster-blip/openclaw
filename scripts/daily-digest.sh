#!/bin/bash
# Wolf Daily Digest — 23h50 BRT (UNICO relatorio noturno)
# Consolida TUDO do dia em UMA unica mensagem WhatsApp
# Absorve: daily_progress_report + wolf-daily-ops-report + nota_diaria
# Crontab: 50 23 * * * bash ~/.openclaw/workspace/scripts/daily-digest.sh >> ~/.openclaw/logs/daily-digest.log 2>&1

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.openclaw/workspace/scripts/lib-wolf.sh"

DATE=$(date '+%d/%m/%Y')
TODAY=$(date '+%Y-%m-%d')
LOGS="$HOME/.openclaw/logs"
WORKSPACE="$HOME/.openclaw/workspace"
QUEUE="$WORKSPACE/tasks/QUEUE.md"
SESSIONS="$HOME/.openclaw/agents/main/sessions/sessions.json"
DAILY="$WORKSPACE/memory/daily"

mkdir -p "$DAILY"

wolf_log "digest" "Iniciando Daily Digest consolidado"

# ============================================================
# SECAO 1 — TASKS (absorvido de daily_progress_report)
# ============================================================
DONE="$(grep -icE '^\- \[x\]' "$QUEUE" 2>/dev/null || true)"
DONE="${DONE%%$'\n'*}"; DONE="${DONE:-0}"
OPEN="$(grep -c '^\- \[ \]' "$QUEUE" 2>/dev/null || true)"
OPEN="${OPEN%%$'\n'*}"; OPEN="${OPEN:-0}"
URGENT="$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep -c '^\- \[ \]' 2>/dev/null || true)"
URGENT="${URGENT%%$'\n'*}"; URGENT="${URGENT:-0}"

# Salvar nota diaria (absorvido de daily_progress_report)
DONE_LIST=$(grep "^- \[x\]\|^- \[X\]" "$QUEUE" 2>/dev/null || echo "_Nenhuma_")
URGENT_LIST=$(awk '/## URGENT/,/## THIS WEEK/' "$QUEUE" 2>/dev/null | grep "^- \[ \]" || echo "_Nenhuma_")

cat > "$DAILY/${TODAY}.md" << EOF
# Nota Diaria — $DATE
- Tasks concluidas: $DONE
- Tasks em aberto: $OPEN
- Tasks urgentes pendentes: $URGENT

## Concluidas hoje
$DONE_LIST

## Urgentes abertas
$URGENT_LIST

_Gerado automaticamente — 23:50_
EOF

# Mover concluidas para DONE.md (absorvido de daily_progress_report)
DONE_FILE="$WORKSPACE/memory/DONE.md"
[ ! -f "$DONE_FILE" ] && echo "# DONE.md — Tasks Concluidas" > "$DONE_FILE"
if [ "$DONE" -gt 0 ]; then
  EXISTING="$(grep -cF "## $DATE" "$DONE_FILE" 2>/dev/null || true)"
  EXISTING="${EXISTING%%$'\n'*}"; EXISTING="${EXISTING:-0}"
  if [ "$EXISTING" -eq 0 ]; then
    echo "" >> "$DONE_FILE"
    echo "## $DATE" >> "$DONE_FILE"
    grep "^- \[x\]\|^- \[X\]" "$QUEUE" 2>/dev/null >> "$DONE_FILE" || true
  fi
fi

# ============================================================
# SECAO 2 — SISTEMA
# ============================================================
GW_PID=$(pgrep -f "openclaw" | head -1)
GW_STATUS="DOWN"; [ -n "$GW_PID" ] && GW_STATUS="UP"
DISCO=$(df -h / | awk 'NR==2{print $5}')

SESS_COUNT=0
[ -f "$SESSIONS" ] && SESS_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS')); print(len(d))" 2>/dev/null || echo 0)

BACKUP="nao"; [ -f "$LOGS/backup-offsite.log" ] && grep -q "$TODAY" "$LOGS/backup-offsite.log" 2>/dev/null && BACKUP="ok"

# ============================================================
# SECAO 3 — ERROS
# ============================================================
GW_ERRS=0
[ -f "$LOGS/gateway.log" ] && GW_ERRS=$(grep -c "$TODAY.*\(error\|ERROR\)" "$LOGS/gateway.log" 2>/dev/null || echo 0)
BR_ERRS=0
[ -f "$LOGS/whatsapp-bridge.log" ] && BR_ERRS=$(grep -c "$TODAY.*\(error\|ERROR\)" "$LOGS/whatsapp-bridge.log" 2>/dev/null || echo 0)

# ============================================================
# SECAO 4 — CUSTO DO DIA (absorvido de wolf-daily-ops-report)
# ============================================================
COST_INFO=$(python3 << 'PYEOF'
import json, os
from collections import defaultdict

today = os.popen("date '+%Y-%m-%d'").read().strip()
telemetry = os.path.expanduser("~/.openclaw/logs/token-telemetry.jsonl")

PRICES = {
    "claude-sonnet-4-6": {"input": 3e-6, "output": 15e-6},
    "claude-haiku-4-5-20251001": {"input": 8e-7, "output": 4e-6},
    "anthropic/claude-haiku-4-5": {"input": 8e-7, "output": 4e-6},
}

session_seen = {}
if os.path.exists(telemetry):
    with open(telemetry) as f:
        for line in f:
            try:
                d = json.loads(line.strip())
                if today not in d.get("ts", ""):
                    continue
                for s in d.get("sessions", []):
                    key = s.get("key", "")
                    total = s.get("totalTokens", 0)
                    prev = session_seen.get(key, {})
                    if total >= prev.get("total", 0):
                        session_seen[key] = {
                            "model": s.get("model", "?"),
                            "input": s.get("inputTokens", 0),
                            "output": s.get("outputTokens", 0),
                            "total": total
                        }
            except:
                pass

total_cost = 0.0
for info in session_seen.values():
    prices = PRICES.get(info["model"], {"input": 3e-6, "output": 15e-6})
    total_cost += info["input"] * prices["input"] + info["output"] * prices["output"]

print(f"${total_cost:.2f} ({len(session_seen)} sessoes LLM)")
PYEOF
)
COST_INFO="${COST_INFO:-$? (erro)}"

# ============================================================
# SECAO 5 — GIT (absorvido de wolf-daily-ops-report)
# ============================================================
GIT_COMMITS=0
GIT_LIST=""
if cd "$WORKSPACE" 2>/dev/null; then
    GIT_COMMITS=$(git log --oneline --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GIT_COMMITS" -gt 0 ]; then
        GIT_LIST=$(git log --oneline --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" 2>/dev/null | head -3 | sed 's/^/  /')
    fi
fi

# ============================================================
# SECAO 6 — HEARTBEATS (resumo)
# ============================================================
HB_COUNT=$(find "$WORKSPACE/memory/logs" -name "heartbeat-*.log" -mtime 0 2>/dev/null | wc -l | tr -d ' ')
HB_ISSUES=0
for hblog in "$WORKSPACE"/memory/logs/heartbeat-*.log; do
    [ -f "$hblog" ] || continue
    HB_ISSUES=$((HB_ISSUES + $(grep -c "$TODAY.*\(CRITICO\|ISSUE\|PROBLEMA\)" "$hblog" 2>/dev/null || echo 0)))
done

# ============================================================
# SECAO 7 — AUDITORIA
# ============================================================
AUDIT="nao rodou"
if [ -f "$LOGS/audit-diario.log" ] && grep -q "$TODAY" "$LOGS/audit-diario.log" 2>/dev/null; then
  A_PROB=$(grep -c "$TODAY.*PROBLEMA" "$LOGS/audit-diario.log" 2>/dev/null || echo 0)
  A_AVIS=$(grep -c "$TODAY.*AVISO" "$LOGS/audit-diario.log" 2>/dev/null || echo 0)
  AUDIT="${A_PROB} problemas, ${A_AVIS} avisos"
fi

# ============================================================
# SECAO 8 — ALERTAS DO DIA
# ============================================================
ALERTAS=""
for logf in "$LOGS"/wolf-monitor.log "$LOGS"/watchdog.log "$LOGS"/kanban-guardian.log "$LOGS"/cost-tracker.log; do
  [ -f "$logf" ] || continue
  ALERT_LINE=$(grep "$TODAY.*\(ALERTA\|WARN\|CRITICAL\|PROBLEMA\)" "$logf" 2>/dev/null | tail -1)
  if [ -n "$ALERT_LINE" ]; then
    NOME=$(basename "$logf" .log)
    ALERTAS="${ALERTAS}
  - ${NOME}: $(echo "$ALERT_LINE" | sed "s/.*$TODAY [0-9:]*//" | cut -c1-80)"
  fi
done

# ============================================================
# SECAO 9 — SUPABASE MISSIONS (absorvido de wolf-daily-ops-report)
# ============================================================
WMC_DATA=""
if [ -n "$WOLF_SVC_KEY" ] && [ -n "$WOLF_SUPABASE_URL" ]; then
    WMC_RESP=$(curl -s --max-time 10 \
        "${WOLF_SUPABASE_URL}/rest/v1/missions?created_at=gte.${TODAY}T00:00:00&select=id,status" \
        -H "apikey: ${WOLF_ANON_KEY}" \
        -H "Authorization: Bearer ${WOLF_SVC_KEY}" 2>/dev/null || echo "[]")
    WMC_DATA=$(echo "$WMC_RESP" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and data:
        total = len(data)
        by_status = {}
        for m in data:
            s = m.get('status', '?')
            by_status[s] = by_status.get(s, 0) + 1
        parts = [f'{v} {k}' for k, v in sorted(by_status.items(), key=lambda x: -x[1])]
        print(f'{total} missoes: ' + ', '.join(parts))
    else:
        print('')
except:
    print('')
" 2>/dev/null)
fi

# ============================================================
# PREPARAR CONTEXTO MATINAL
# ============================================================
cat > "$WORKSPACE/memory/morning_context.md" << EOFCTX
# Contexto Matinal — encerramento de $DATE
## Tasks em aberto: $OPEN
$(grep "^- \[ \]" "$QUEUE" 2>/dev/null | head -5 || echo "_Fila vazia_")
## Concluidas hoje: $DONE
## Ultima atualizacao: $(date '+%Y-%m-%d %H:%M:%S')
EOFCTX

# ============================================================
# MONTAR MENSAGEM UNICA
# ============================================================
MSG="*Fechamento do dia — ${DATE}*

*Tasks:* ${DONE} concluida(s) | ${OPEN} abertas"
[ "$URGENT" -gt 0 ] && MSG="${MSG} | ${URGENT} urgentes"

MSG="${MSG}

*Sistema:* GW ${GW_STATUS} | Disco ${DISCO} | ${SESS_COUNT} sessoes | Backup ${BACKUP}
*Erros:* GW ${GW_ERRS} | Bridge ${BR_ERRS} | Heartbeats ${HB_COUNT} ok"
[ "$HB_ISSUES" -gt 0 ] && MSG="${MSG}, ${HB_ISSUES} com problema"
MSG="${MSG}
*Custo:* ${COST_INFO}
*Auditoria:* ${AUDIT}"

# Git (so mostra se teve commits)
if [ "$GIT_COMMITS" -gt 0 ]; then
    MSG="${MSG}

*Git:* ${GIT_COMMITS} commit(s)
${GIT_LIST}"
fi

# Mission Control (so mostra se teve missoes)
[ -n "$WMC_DATA" ] && MSG="${MSG}
*Missoes:* ${WMC_DATA}"

# Alertas
if [ -n "$ALERTAS" ]; then
    MSG="${MSG}

*Alertas:*${ALERTAS}"
fi

MSG="${MSG}

Contexto de amanha preparado. Boa noite."

wolf_notify "$MSG"

# Marker
touch /tmp/.wolf-digest-mark

wolf_log "digest" "Digest enviado — done=$DONE open=$OPEN errs=$GW_ERRS/$BR_ERRS cost=$COST_INFO"
