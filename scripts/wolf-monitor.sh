#!/bin/bash
# ============================================================
# WOLF MONITOR — Monitoramento de infra (bash puro, zero LLM)
# Roda a cada 30 min via LaunchAgent
# Absorve: gateway, crons, erros, RAM, disco, self-heal
# ============================================================
set -euo pipefail

LOG="/tmp/wolf-monitor.log"
DETAILED_LOG="/tmp/openclaw/openclaw-$(date '+%Y-%m-%d').log"
JOBS="$HOME/.openclaw/cron/jobs.json"
AGENDA="$HOME/.openclaw/workspace/memory/agenda-alfred.md"
BOOT_CONTEXT="$HOME/.openclaw/workspace/memory/boot-context.md"
ANOMALIAS="$HOME/.openclaw/workspace/memory/anomalias.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh" 2>/dev/null || true

ALERTS=()

# ============================================================
# 1 — Extrair erros dos logs (ultimas 2h)
# ============================================================
ERRORS=""
ERROR_COUNT=0

if [[ -f "$DETAILED_LOG" ]]; then
  # Filtrar erros reais (ignorar lane task errors que sao inofensivos)
  ERRORS=$(grep -i '"logLevelName":"ERROR"' "$DETAILED_LOG" 2>/dev/null \
    | grep -v "lane task error" \
    | grep -o '"1":"[^"]*"' \
    | sed 's/"1":"//;s/"$//' \
    | tail -10 || true)
  ERROR_COUNT=$(echo "$ERRORS" | grep -c . 2>/dev/null || echo "0")
  if [[ -z "$ERRORS" ]]; then
    ERROR_COUNT=0
  fi
fi

# Só alerta se tiver 5+ erros (ruído abaixo disso é normal)
if [[ "$ERROR_COUNT" -ge 5 ]]; then
  ALERTS+=("$ERROR_COUNT erros nos logs (ultimas 2h)")
fi

# ============================================================
# 2 — Verificar crons falhados
# ============================================================
CRON_REPORT=$(python3 << 'PYEOF'
import json, os, time

jobs_path = os.path.expanduser('~/.openclaw/cron/jobs.json')

with open(jobs_path) as f:
    data = json.load(f)

now = time.time() * 1000
failed = []
never_ran = []
ok_count = 0

for j in data.get('jobs', []):
    if not j.get('enabled', False):
        continue
    name = j.get('name', '?')
    state = j.get('state', {})
    status = state.get('lastRunStatus', 'never')
    last_run = state.get('lastRunAtMs', 0)

    if status == 'error':
        ago = int((now - last_run) / 60000) if last_run else 0
        failed.append(f"{name} (erro ha {ago}min)")
    elif status == 'never' and last_run == 0:
        never_ran.append(name)
    elif status == 'ok':
        ok_count += 1

if failed:
    print(f"CRONS COM ERRO: {len(failed)}")
    for f in failed:
        print(f"  - {f}")
else:
    print("CRONS COM ERRO: 0")

print(f"CRONS OK: {ok_count}")

if never_ran:
    print(f"CRONS NUNCA RODARAM: {len(never_ran)}")
    for n in never_ran[:5]:
        print(f"  - {n}")
PYEOF
)

CRON_ERRORS=$(echo "$CRON_REPORT" | grep -o "CRONS COM ERRO: [0-9]*" | grep -o "[0-9]*")
if [[ "${CRON_ERRORS:-0}" -gt 0 ]]; then
  ALERTS+=("$CRON_ERRORS crons com erro")
fi

# ============================================================
# 3 — Verificar saude do gateway
# ============================================================
GW_STATUS="OK"
GW_PID=""
if lsof -i :18789 >/dev/null 2>&1; then
  GW_PID=$(lsof -ti :18789 2>/dev/null | head -1 || true)
  GW_STATUS="OK (PID $GW_PID)"
else
  GW_STATUS="DOWN"
fi

# Self-heal gateway if down
if [[ "$GW_STATUS" == "DOWN" ]]; then
  echo "[$TIMESTAMP] SELF-HEAL: gateway down, restarting" >> "$LOG"
  launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway 2>/dev/null || true
  sleep 10
  if lsof -i :18789 >/dev/null 2>&1; then
    GW_STATUS="RECOVERED"
    echo "[$TIMESTAMP] SELF-HEAL: gateway recovered" >> "$LOG"
  else
    GW_STATUS="STILL DOWN"
    echo "[$TIMESTAMP] SELF-HEAL: gateway still down after restart" >> "$LOG"
    ALERTS+=("Gateway DOWN — self-heal falhou")
  fi
fi

# ============================================================
# 4 — Verificar RAM e disco
# ============================================================
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
if [[ "${DISK_USAGE:-0}" -gt 90 ]]; then
  ALERTS+=("Disco em ${DISK_USAGE}%")
fi

MEM_PRESSURE=$(memory_pressure 2>/dev/null | grep "System-wide" | head -1 || true)
if echo "$MEM_PRESSURE" | grep -qi "critical\|warning"; then
  ALERTS+=("Pressao de memoria: $MEM_PRESSURE")
fi

# (detector de crons fantasma removido — era necessario com kimi-k2.5
#  que nao executava tools; Anthropic Haiku 4.5 funciona corretamente)

# ============================================================
# 5 — Verificar tarefas na agenda
# ============================================================
TASKS=""
TASK_COUNT=0
if [[ -f "$AGENDA" ]]; then
  TASKS=$(grep -B1 "status: pendente" "$AGENDA" 2>/dev/null \
    | grep "descricao:" \
    | sed 's/.*descricao: *"//;s/"$//' || true)
  if [[ -n "$TASKS" ]]; then
    TASK_COUNT=$(echo "$TASKS" | wc -l | tr -d ' ')
  fi
fi

# ============================================================
# 7 — Verificar QUEUE.md para itens urgentes
# ============================================================
QUEUE_FILE="$HOME/.openclaw/workspace/tasks/QUEUE.md"
QUEUE_URGENT=0
QUEUE_TOTAL=0
if [[ -f "$QUEUE_FILE" ]]; then
  QUEUE_TOTAL=$(grep -c "^\- \[ \]" "$QUEUE_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)
  # Contar items na secao URGENT (entre "## URGENT" e proximo "##")
  QUEUE_URGENT=$(sed -n '/^## URGENT/,/^## /p' "$QUEUE_FILE" 2>/dev/null | grep -c "^\- \[ \]" 2>/dev/null | tr -d '[:space:]' || echo 0)
fi

if [[ "$QUEUE_URGENT" -gt 0 ]]; then
  ALERTS+=("$QUEUE_URGENT tarefas URGENTES na fila")
fi

# ============================================================
# 8 — Log e notificacao
# ============================================================
echo "[$TIMESTAMP] gw=$GW_STATUS erros=$ERROR_COUNT crons_err=${CRON_ERRORS:-0} disco=${DISK_USAGE}% queue=$QUEUE_TOTAL tarefas=$TASK_COUNT alerts=${#ALERTS[@]}" >> "$LOG"

# Se ha alertas criticos, notifica via Telegram (sem LLM)
if [[ ${#ALERTS[@]} -gt 0 ]]; then
  MSG="Monitor detectou ${#ALERTS[@]} alerta(s):"
  for a in "${ALERTS[@]}"; do
    MSG="$MSG
- $a"
  done

  # Dedup: só envia se o alerta mudou OU se passou 2h desde o último envio
  LAST_ALERT_FILE="/tmp/wolf-monitor-last-alert.txt"
  MSG_HASH=$(echo "$MSG" | md5)
  NOW_EPOCH=$(date +%s)
  SHOULD_SEND=1

  if [[ -f "$LAST_ALERT_FILE" ]]; then
    LAST_HASH=$(sed -n '1p' "$LAST_ALERT_FILE" 2>/dev/null || echo "")
    LAST_TIME=$(sed -n '2p' "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
    ELAPSED=$(( NOW_EPOCH - LAST_TIME ))
    if [[ "$MSG_HASH" == "$LAST_HASH" && "$ELAPSED" -lt 7200 ]]; then
      SHOULD_SEND=0
      echo "[$TIMESTAMP] Alerta suprimido (mesmo alerta, $ELAPSED s atrás)" >> "$LOG"
    fi
  fi

  if [[ "$SHOULD_SEND" -eq 1 ]]; then
    # Notificar via lib-wolf se disponivel, senao via curl direto
    if type wolf_telegram &>/dev/null; then
      wolf_telegram "$MSG"
    else
      source "$HOME/.openclaw/.env" 2>/dev/null || true
      if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=789352357" \
          -d "text=$MSG" \
          --max-time 10 >/dev/null 2>&1 || true
      fi
    fi
    echo "$MSG_HASH" > "$LAST_ALERT_FILE"
    echo "$NOW_EPOCH" >> "$LAST_ALERT_FILE"
    echo "[$TIMESTAMP] ALERTAS ENVIADOS: ${#ALERTS[@]}" >> "$LOG"
  fi
fi

# ============================================================
# 9 — Atualizar boot-context.md
# ============================================================
cat > "$BOOT_CONTEXT" << EOFBOOT
# Boot Context — Auto-gerado pelo wolf-monitor
# Ultima atualizacao: $TIMESTAMP

## Estado
- Gateway: $GW_STATUS
- Erros (2h): $ERROR_COUNT
- Disco: ${DISK_USAGE}%
- Crons: ver abaixo

## Crons
$CRON_REPORT

## Fila de trabalho
- Total: $QUEUE_TOTAL | Urgente: $QUEUE_URGENT

## Tarefas agenda
$(if [[ -n "$TASKS" ]]; then echo "$TASKS"; else echo "Nenhuma"; fi)

## Alertas ativos
$(grep "^- " "$ANOMALIAS" 2>/dev/null | tail -5 || echo "Nenhum")
EOFBOOT

# ============================================================
# 10 — Tool Fallback (auto-correcao)
# ============================================================
FALLBACK_SCRIPT="$HOME/.openclaw/workspace/scripts/wolf-tool-fallback.sh"
if [[ -x "$FALLBACK_SCRIPT" ]]; then
  bash "$FALLBACK_SCRIPT" 2>/dev/null || true
fi

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 500 ]]; then
  tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

echo "OK: wolf-monitor — alerts=${#ALERTS[@]} gw=$GW_STATUS erros=$ERROR_COUNT"
