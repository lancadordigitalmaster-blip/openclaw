#!/bin/bash
# ============================================================
# WOLF HEARTBEAT — Heartbeat deterministico (a cada 30 min)
# Monta contexto REAL antes de chamar o LLM
# ============================================================
set -euo pipefail

LOG="/tmp/wolf-heartbeat.log"
GATEWAY_LOG="$HOME/.openclaw/logs/gateway.log"
DETAILED_LOG="/tmp/openclaw/openclaw-$(date '+%Y-%m-%d').log"
JOBS="$HOME/.openclaw/cron/jobs.json"
AGENDA="$HOME/.openclaw/workspace/memory/agenda-alfred.md"
BOOT_CONTEXT="$HOME/.openclaw/workspace/memory/boot-context.md"
ANOMALIAS="$HOME/.openclaw/workspace/memory/anomalias.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
GATEWAY_TOKEN="b52639408a26e05b9170423402be3068db69ae001d4b0610"

# ============================================================
# PASSO 1 — Extrair erros dos logs (ultimas 2h, regex, sem LLM)
# ============================================================
ERRORS=""
ERROR_COUNT=0

if [[ -f "$DETAILED_LOG" ]]; then
  ERRORS=$(grep -i '"logLevelName":"ERROR"' "$DETAILED_LOG" 2>/dev/null \
    | grep -o '"1":"[^"]*"' \
    | sed 's/"1":"//;s/"$//' \
    | tail -10 || true)
  ERROR_COUNT=$(echo "$ERRORS" | grep -c . 2>/dev/null || echo "0")
  # Filter out empty lines
  if [[ -z "$ERRORS" ]]; then
    ERROR_COUNT=0
  fi
fi

# ============================================================
# PASSO 2 — Verificar crons falhados (sem LLM)
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

# ============================================================
# PASSO 3 — Verificar tarefas executaveis no agenda-alfred.md
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
# PASSO 4 — Verificar saude do gateway
# ============================================================
GW_STATUS="OK"
GW_PID=""
if lsof -i :18789 >/dev/null 2>&1; then
  GW_PID=$(lsof -ti :18789 2>/dev/null | head -1 || true)
  GW_STATUS="OK (PID $GW_PID)"
else
  GW_STATUS="DOWN"
fi

# ============================================================
# PASSO 5 — Montar contexto completo (com agenda + errors.md)
# ============================================================
AGENDA_CONTENT=""
if [[ -f "$AGENDA" ]]; then
  AGENDA_CONTENT=$(head -30 "$AGENDA" 2>/dev/null || true)
fi

ERRORS_LOG=""
ERRORS_LOG_FILE="$HOME/.openclaw/workspace/memory/errors.md"
if [[ -f "$ERRORS_LOG_FILE" ]]; then
  ERRORS_LOG=$(tail -5 "$ERRORS_LOG_FILE" 2>/dev/null || true)
fi

CONTEXT="HEARTBEAT $TIMESTAMP
GATEWAY: $GW_STATUS
ERROS (ultimas 2h): $ERROR_COUNT
$CRON_REPORT
TAREFAS PENDENTES: $TASK_COUNT

AGENDA ALFRED (memory/agenda-alfred.md):
$AGENDA_CONTENT

ULTIMOS ERROS REGISTRADOS (memory/errors.md):
$ERRORS_LOG"

if [[ "$TASK_COUNT" -gt 0 ]]; then
  CONTEXT="$CONTEXT

TAREFAS EXECUTAVEIS:
$TASKS"
fi

# Log always
echo "[$TIMESTAMP] gateway=$GW_STATUS erros=$ERROR_COUNT tarefas=$TASK_COUNT" >> "$LOG"

# Self-heal gateway if down (deterministic, no LLM)
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
  fi
  CONTEXT="$CONTEXT
SELF-HEAL: gateway was down -> $GW_STATUS"
fi

# ============================================================
# PASSO 5.2 — Self-Reflection check (Kaizen)
# ============================================================
SELF_REFLECTION_BIN="$HOME/.openclaw/workspace/skills/self-reflection/bin/self-reflection"
REFLECTION_STATUS=""
if [[ -x "$SELF_REFLECTION_BIN" ]]; then
  REFLECTION_STATUS=$("$SELF_REFLECTION_BIN" check --quiet 2>/dev/null || true)
  if [[ "$REFLECTION_STATUS" == "ALERT" ]]; then
    CONTEXT="$CONTEXT
KAIZEN: Self-reflection pendente — analise erros recentes (memory/errors.md) e registre reflexao com: self-reflection log <tag> <miss> <fix>"
    echo "[$TIMESTAMP] KAIZEN: self-reflection due" >> "$LOG"
  fi
fi

# ============================================================
# PASSO 5.3 — Detectar crons "fantasma" (ok sem acao real)
# ============================================================
# O gateway marca sessao como "ok" se o LLM respondeu texto,
# mesmo sem executar nenhuma tool. Com kimi-k2.5 via Ollama Cloud
# isso acontece 100% das vezes (0 tool_calls em 298+ sessoes).
# Detectamos comparando: crons habilitados com agentTurn vs
# crons que realmente precisavam de tools (payload menciona acao).
GHOST_SESSIONS=$(python3 << 'PYEOF'
import json, os, time

jobs_path = os.path.expanduser("~/.openclaw/cron/jobs.json")
with open(jobs_path) as f:
    data = json.load(f)

now = time.time() * 1000
ghost_count = 0
ghost_names = []

# Palavras que indicam que o cron PRECISA executar tools
action_words = ["enviar", "telegram", "envie", "execute", "buscar",
                "fetch", "consultar", "clickup", "youtube", "whatsapp",
                "web_fetch", "send", "post"]

for j in data.get("jobs", []):
    if not j.get("enabled", False):
        continue
    payload = j.get("payload", {})
    if payload.get("kind") != "agentTurn":
        continue
    state = j.get("state", {})
    status = state.get("lastRunStatus", "never")
    last_run = state.get("lastRunAtMs", 0)

    # So checa crons que rodaram nas ultimas 24h
    if status != "ok" or (now - last_run) > 86400000:
        continue

    # Checa se o payload esperava acao
    msg = payload.get("message", "").lower()
    needs_action = any(w in msg for w in action_words)

    if needs_action:
        ghost_count += 1
        ghost_names.append(j.get("name", "?"))

if ghost_count > 0:
    print(f"GHOST:{ghost_count}:" + "|".join(ghost_names[:5]))
else:
    print("GHOST:0")
PYEOF
)

GHOST_COUNT=$(echo "$GHOST_SESSIONS" | grep -o "GHOST:[0-9]*" | cut -d: -f2)
if [[ "${GHOST_COUNT:-0}" -gt 0 ]]; then
  GHOST_NAMES=$(echo "$GHOST_SESSIONS" | cut -d: -f3-)
  CONTEXT="$CONTEXT
ALERTA GHOST: $GHOST_COUNT crons marcaram 'ok' mas provavelmente nao executaram tools ($GHOST_NAMES)"
  echo "[$TIMESTAMP] GHOST: $GHOST_COUNT crons sem acao real: $GHOST_NAMES" >> "$LOG"
  NEEDS_LLM=true
fi

# ============================================================
# PASSO 5.5 — Decidir se chama LLM (logica invertida)
# ============================================================
# Contador de execucoes para forcar chamada a cada 3 runs (90min)
HEARTBEAT_COUNT_FILE="$HOME/.openclaw/heartbeat-count"
COUNT=$(cat "$HEARTBEAT_COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo $COUNT > "$HEARTBEAT_COUNT_FILE"

# Padrao: chama LLM
NEEDS_LLM=true

# So NAO chama se TUDO estiver OK e nao for a 3a execucao
if [[ "$ERROR_COUNT" -eq 0 ]] && \
   [[ "$TASK_COUNT" -eq 0 ]] && \
   [[ "$GW_STATUS" == "OK"* ]] && \
   ! echo "$CRON_REPORT" | grep -q "CRONS COM ERRO: [1-9]"; then
  # Tudo OK — so chama a cada 3 execucoes (90min)
  if [[ $((COUNT % 3)) -ne 0 ]]; then
    NEEDS_LLM=false
  fi
fi

if [[ "$NEEDS_LLM" == "true" ]]; then
  PAYLOAD="Heartbeat automatico — contexto real montado por script (NAO inventar dados):

$CONTEXT

Com base APENAS nos dados acima:
1. Se houver erros: diagnostica causa provavel em 1 linha
2. Se houver crons falhados: sugere correcao especifica
3. Se houver tarefas pendentes: executa a mais prioritaria
4. Se gateway estava down: confirma status atual
5. Se tudo OK mas ha itens na AGENDA com autonomia total:
   executa o primeiro item pendente e registra em memory/agenda-alfred.md
6. Se tudo OK e sem agenda pendente: nao responda nada
7. Se KAIZEN self-reflection pendente: analise memory/errors.md, identifique 1 erro recente, registre reflexao

Envie resumo via Telegram para Netto (chat 789352357) APENAS se ha acao necessaria."

  # Send to Alfred via gateway API
  ESCAPED_PAYLOAD=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$PAYLOAD")
  curl -s -X POST http://127.0.0.1:18789/api/agent/message \
    -H "Authorization: Bearer $GATEWAY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"message\": $ESCAPED_PAYLOAD}" \
    --max-time 90 >/dev/null 2>&1 || true

  echo "[$TIMESTAMP] LLM called (count=$COUNT erros=$ERROR_COUNT tarefas=$TASK_COUNT gw=$GW_STATUS)" >> "$LOG"
else
  echo "[$TIMESTAMP] All clear (count=$COUNT) — no LLM needed" >> "$LOG"
fi

# ============================================================
# PASSO 6 — Atualizar boot-context.md
# ============================================================
cat > "$BOOT_CONTEXT" << EOFBOOT
# Boot Context — Auto-gerado pelo heartbeat
# Ultima atualizacao: $TIMESTAMP

## Estado
- Gateway: $GW_STATUS
- Erros (2h): $ERROR_COUNT
- Crons: ver abaixo

## Crons
$CRON_REPORT

## Tarefas pendentes
$(if [[ -n "$TASKS" ]]; then echo "$TASKS"; else echo "Nenhuma"; fi)

## Alertas ativos
$(grep "^- " "$ANOMALIAS" 2>/dev/null | tail -5 || echo "Nenhum")
EOFBOOT

# ============================================================
# PASSO EXTRA — Tool Fallback (auto-correcao)
# ============================================================
FALLBACK_SCRIPT="$HOME/.openclaw/workspace/scripts/wolf-tool-fallback.sh"
if [[ -x "$FALLBACK_SCRIPT" ]]; then
  bash "$FALLBACK_SCRIPT" 2>/dev/null || true
fi

# Trim log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 500 ]]; then
  tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
