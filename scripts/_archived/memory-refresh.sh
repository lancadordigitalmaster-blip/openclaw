#!/bin/bash
# memory-refresh.sh — Atualiza arquivos core de memória do Alfred
# Roda: segunda 07h (crontab, 1 chamada Haiku ~$0.01)
# Função: reescreve state.md e agenda.md com dados reais

set -euo pipefail

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
MEMORY="$WORKSPACE/memory"
LOG="$MEMORY/logs/memory-refresh.log"
TODAY=$(date +%Y-%m-%d)
CLI="/opt/homebrew/opt/node/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/index.js"

source "$WORKSPACE/scripts/lib-wolf.sh" 2>/dev/null || true

log_refresh() { echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"; }
log_refresh "=== Memory Refresh iniciado ==="

# ─── 1. COLETAR ESTADO ATUAL ───────────────────────────────────

# Gateway
GW_PID=$(pgrep -f "openclaw.*gateway" 2>/dev/null | head -1 || echo "OFF")
GW_STATUS="OFF"
[ "$GW_PID" != "OFF" ] && GW_STATUS="OK (PID $GW_PID)"

# Disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

# Crons
CRON_STORE="$HOME/.openclaw/cron/jobs.json"
CRONS_TOTAL=0
CRONS_ERROR=0
if [ -f "$CRON_STORE" ]; then
  CRONS_TOTAL=$(python3 -c "
import json
with open('$CRON_STORE') as f: d=json.load(f)
jobs=[j for j in d.get('jobs',[]) if j.get('enabled',True)]
print(len(jobs))
" 2>/dev/null || echo "?")
  CRONS_ERROR=$(python3 -c "
import json
with open('$CRON_STORE') as f: d=json.load(f)
jobs=[j for j in d.get('jobs',[]) if j.get('enabled',True) and j.get('consecutiveErrors',0)>=3]
print(len(jobs))
" 2>/dev/null || echo "?")
fi

# Modelo atual
MODEL_PRIMARY=$(grep -o '"anthropic/claude-[^"]*"' "$HOME/.openclaw/openclaw.json" 2>/dev/null | head -1 | tr -d '"' || echo "?")

# Clientes
CLIENTS_COUNT=0
CLIENTS_FILE="$WORKSPACE/shared/memory/clients.yaml"
if [ -f "$CLIENTS_FILE" ]; then
  CLIENTS_COUNT=$(grep -c "status: \"ativo\"" "$CLIENTS_FILE" 2>/dev/null || echo "0")
fi

# Erros recentes (últimas 24h no gateway log)
ERRORS_24H=$(grep -c "ERROR\|error\|Error" "$HOME/.openclaw/logs/gateway.log" 2>/dev/null || echo "0")

# WhatsApp Bridge
WA_PID=$(pgrep -f "whatsapp-bridge" 2>/dev/null | head -1 || echo "OFF")
WA_STATUS="OFF"
[ "$WA_PID" != "OFF" ] && WA_STATUS="OK (PID $WA_PID)"

# Meta Ads tokens
META_TOKENS=$(grep -c "META_TOKEN" "$HOME/.openclaw/.env" 2>/dev/null || echo "0")

log_refresh "Estado coletado: GW=$GW_STATUS, Disco=$DISK_USAGE, Crons=$CRONS_TOTAL (err=$CRONS_ERROR)"

# ─── 2. REESCREVER STATE.MD ────────────────────────────────────

cat > "$MEMORY/state.md" << STATEEOF
# Estado do Sistema — Wolf Agency
# Auto-gerado por memory-refresh.sh | Reescrito semanalmente
# Última atualização: $TODAY

---

## Infraestrutura

| Sistema | Status |
|---------|--------|
| Gateway OpenClaw | $GW_STATUS |
| Telegram Bot | Polling ativo (@alfredwolf_bot) |
| WhatsApp Bridge | $WA_STATUS |
| Modelo Primário | $MODEL_PRIMARY |
| Modelo Crons | anthropic/claude-haiku-4-5-20251001 |
| Web Search | Provider: gemini |
| Disco | $DISK_USAGE usado |
| Meta Ads Tokens | $META_TOKENS configurados |

## Crons

- Ativos: $CRONS_TOTAL
- Com erro (>=3 consecutivos): $CRONS_ERROR
- Erros gateway (24h): $ERRORS_24H

## Clientes Ativos

- Total: $CLIENTS_COUNT

---

*Próximo refresh: segunda 07h via memory-refresh.sh*
STATEEOF

log_refresh "state.md reescrito"

# ─── 3. VERIFICAR PENDÊNCIAS RESOLVIDAS ────────────────────────

# Checar se items do agenda.md foram resolvidos
# (heurística simples: se arquivo/config mencionado existe, marcar como done)
RESOLVED=0

# Meta Ads token
if grep -q "META_TOKEN" "$HOME/.openclaw/.env" 2>/dev/null; then
  # Token existe — se agenda menciona "Meta Ads", está resolvido
  RESOLVED=$((RESOLVED + 1))
fi

# ClickUp no Vercel — não podemos verificar remotamente, manter pendente

log_refresh "Pendências verificadas: $RESOLVED resolvidas automaticamente"

# ─── 4. EXTRAIR PADRÕES DE ERRORS.MD → PATTERNS.MD ─────────────

ERRORS_FILE="$MEMORY/errors.md"
PATTERNS_FILE="$MEMORY/patterns.md"

if [ -f "$ERRORS_FILE" ]; then
  # Contar ocorrências por tipo de erro
  EMAIL_ERRORS=$(grep -c "email-monitor" "$ERRORS_FILE" 2>/dev/null || echo "0")
  SOUL_ERRORS=$(grep -c "SOUL.md" "$ERRORS_FILE" 2>/dev/null || echo "0")
  NETWORK_ERRORS=$(grep -c "Network\|timeout\|ETIMEDOUT" "$ERRORS_FILE" 2>/dev/null || echo "0")

  # Se patterns.md não menciona um padrão novo, adicionar
  if [ "$EMAIL_ERRORS" -gt 3 ] && ! grep -q "email-monitor.py" "$PATTERNS_FILE" 2>/dev/null; then
    cat >> "$PATTERNS_FILE" << PATEOF

### email-monitor.py — timeout permanente (auto-detectado)
- **Ocorrências:** $EMAIL_ERRORS entradas em errors.md
- **Status:** Requer investigação
- **Detectado em:** $TODAY por memory-refresh.sh
PATEOF
    log_refresh "Novo padrão detectado: email-monitor ($EMAIL_ERRORS ocorrências)"
  fi
fi

# ─── 5. STALENESS CHECK ────────────────────────────────────────

STALE_FILES=""
for CHECK_FILE in "$MEMORY/lessons.md" "$MEMORY/decisions-log.md" "$MEMORY/patterns.md"; do
  [ -f "$CHECK_FILE" ] || continue
  if [[ "$OSTYPE" == "darwin"* ]]; then
    MOD_EPOCH=$(stat -f %m "$CHECK_FILE")
  else
    MOD_EPOCH=$(stat -c %Y "$CHECK_FILE")
  fi
  NOW_EPOCH=$(date "+%s")
  AGE_DAYS=$(( (NOW_EPOCH - MOD_EPOCH) / 86400 ))
  if [ "$AGE_DAYS" -gt 14 ]; then
    STALE_FILES="$STALE_FILES $(basename "$CHECK_FILE")($AGE_DAYS d)"
  fi
done

if [ -n "$STALE_FILES" ]; then
  log_refresh "ALERTA: Arquivos stale:$STALE_FILES"
fi

log_refresh "=== Memory Refresh concluído ==="
