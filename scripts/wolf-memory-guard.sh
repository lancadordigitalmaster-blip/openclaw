#!/bin/bash
# ============================================================
# WOLF MEMORY GUARD — Garante que arquivos de memoria existem
# Roda 1x/dia as 00:05 via LaunchAgent
# ============================================================
set -euo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

WORKSPACE="$HOME/.openclaw/workspace"
TODAY=$(date '+%Y-%m-%d')
LOG="/tmp/wolf-memory-guard.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

CREATED=0

create_if_missing() {
  local filepath="$1"
  local content="$2"
  if [[ ! -f "$filepath" ]]; then
    mkdir -p "$(dirname "$filepath")"
    echo -e "$content" > "$filepath"
    CREATED=$((CREATED + 1))
    echo "[$TIMESTAMP] CREATED: $filepath" >> "$LOG"
  fi
}

create_if_missing "$WORKSPACE/memory/alfred-core.md" \
"# Alfred Core — Estado Operacional
# Criado automaticamente em $TODAY

## Projetos Ativos
Nenhum registrado.

## Decisoes Recentes
Nenhuma.

## Grupos Telegram
Nenhum registrado."

create_if_missing "$WORKSPACE/memory/agenda-alfred.md" \
"# Agenda Alfred
# Criado automaticamente em $TODAY

## Objetivos da Semana
Nenhum definido.

## Tarefas Autonomas Diarias
- verificar logs a cada heartbeat
- atualizar memory/YYYY-MM-DD.md"

create_if_missing "$WORKSPACE/memory/decisions-log.md" \
"# Decisions Log
# Criado automaticamente em $TODAY

| Data | Decisao | Impacto |
|------|---------|---------|"

create_if_missing "$WORKSPACE/memory/clients.md" \
"# Clientes Ativos
# Criado automaticamente em $TODAY

Nenhum cliente registrado. Preencher com dados reais."

create_if_missing "$WORKSPACE/memory/${TODAY}.md" \
"# Nota Diaria — $TODAY
# Criado automaticamente pelo memory-guard

## Sessoes
Nenhuma registrada.

## Decisoes
Nenhuma."

create_if_missing "$WORKSPACE/memory/boot-context.md" \
"# Boot Context
# Ultima atualizacao: $TIMESTAMP

## Estado
- Gateway: verificar
- Erros: verificar

## Tarefas
Nenhuma pendente."

create_if_missing "$WORKSPACE/memory/anomalias.md" \
"# Anomalias Detectadas
# Criado automaticamente em $TODAY

Nenhuma anomalia registrada."

create_if_missing "$WORKSPACE/memory/lessons.md" \
"# Licoes Aprendidas
# Criado automaticamente em $TODAY

Nenhuma licao registrada."

create_if_missing "$WORKSPACE/memory/projects.md" \
"# Projetos
# Criado automaticamente em $TODAY

Nenhum projeto registrado."

create_if_missing "$WORKSPACE/memory/pending.md" \
"# Pendencias
# Criado automaticamente em $TODAY

Nenhuma pendencia registrada."

if [[ "$CREATED" -gt 0 ]]; then
  echo "[$TIMESTAMP] Created $CREATED missing memory files" >> "$LOG"
else
  echo "[$TIMESTAMP] All memory files present" >> "$LOG"
fi

# ============================================================
# ROTACAO DE LOGS
# ============================================================

# Gateway log — manter ultimas 5000 linhas, comprimir o resto
GATEWAY_LOG="$HOME/.openclaw/logs/gateway.log"
MAX_LINES=5000
if [[ -f "$GATEWAY_LOG" ]]; then
  CURRENT_LINES=$(wc -l < "$GATEWAY_LOG" 2>/dev/null || echo 0)
  if [[ "$CURRENT_LINES" -gt "$MAX_LINES" ]]; then
    ARCHIVE="$HOME/.openclaw/logs/gateway-$(date +%Y%m%d).log.gz"
    gzip -c "$GATEWAY_LOG" > "$ARCHIVE"
    tail -n $MAX_LINES "$GATEWAY_LOG" > /tmp/gateway-new.log
    mv /tmp/gateway-new.log "$GATEWAY_LOG"
    echo "[$TIMESTAMP] gateway.log rotacionado ($CURRENT_LINES -> $MAX_LINES linhas). Arquivo: $ARCHIVE" >> "$LOG"
  fi
fi

# Token telemetry — mesmo tratamento
TOKEN_LOG="$HOME/.openclaw/logs/token-telemetry.jsonl"
if [[ -f "$TOKEN_LOG" ]]; then
  TK_LINES=$(wc -l < "$TOKEN_LOG" 2>/dev/null || echo 0)
  if [[ "$TK_LINES" -gt 2000 ]]; then
    ARCHIVE="$HOME/.openclaw/logs/token-telemetry-$(date +%Y%m%d).jsonl.gz"
    gzip -c "$TOKEN_LOG" > "$ARCHIVE"
    tail -n 1000 "$TOKEN_LOG" > /tmp/token-new.jsonl
    mv /tmp/token-new.jsonl "$TOKEN_LOG"
    echo "[$TIMESTAMP] token-telemetry.jsonl rotacionado ($TK_LINES linhas)" >> "$LOG"
  fi
fi

# Gateway error log
GW_ERR="$HOME/.openclaw/logs/gateway.err.log"
if [[ -f "$GW_ERR" ]]; then
  ERR_SIZE=$(wc -c < "$GW_ERR" 2>/dev/null || echo 0)
  if [[ "$ERR_SIZE" -gt 500000 ]]; then
    tail -n 500 "$GW_ERR" > /tmp/gw-err-new.log
    mv /tmp/gw-err-new.log "$GW_ERR"
    echo "[$TIMESTAMP] gateway.err.log truncado" >> "$LOG"
  fi
fi

# Limpa logs comprimidos com mais de 30 dias
find "$HOME/.openclaw/logs/" -name "*.gz" -mtime +30 -delete 2>/dev/null || true

# Limpa /tmp/openclaw — logs diarios com mais de 7 dias
find /tmp/openclaw/ -type f -mtime +7 -delete 2>/dev/null || true

# Trim memory-guard log
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 200 ]]; then
  tail -100 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# ============================================================
# SESSION LEAK DETECTION
# ============================================================

SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
if [[ -f "$SESSIONS_FILE" ]]; then
  # Load Telegram creds for alerts
  _ENV="$HOME/.openclaw/.env"
  _TG_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$_ENV" 2>/dev/null | cut -d= -f2)
  _TG_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$_ENV" 2>/dev/null | cut -d= -f2)
  _send_tg() {
    [[ -z "${_TG_TOKEN:-}" || -z "${_TG_CHAT:-}" ]] && return
    wolf_notify "$1"
  }

  # Count sessions
  SESSION_COUNT=$(python3 -c "import json; d=json.load(open('$SESSIONS_FILE')); print(len(d))" 2>/dev/null || echo 0)
  if [[ "$SESSION_COUNT" -gt 15 ]]; then
    _send_tg "⚠️ $SESSION_COUNT sessões acumuladas — considere limpar sessions.json"
    echo "[$TIMESTAMP] WARN: $SESSION_COUNT sessions accumulated" >> "$LOG"
  fi

  # Check file size
  SESS_SIZE=$(wc -c < "$SESSIONS_FILE" 2>/dev/null || echo 0)
  if [[ "$SESS_SIZE" -gt 512000 ]]; then
    SESS_HUMAN=$(du -h "$SESSIONS_FILE" | cut -f1)
    _send_tg "⚠️ sessions.json com $SESS_HUMAN — risco de travamento"
    echo "[$TIMESTAMP] WARN: sessions.json size $SESS_HUMAN" >> "$LOG"
  fi

  # Check if file not modified in 24h (may indicate stale sessions)
  SESS_AGE=$(( $(date +%s) - $(stat -f %m "$SESSIONS_FILE" 2>/dev/null || echo 0) ))
  if [[ "$SESS_AGE" -gt 86400 ]] && [[ "$SESSION_COUNT" -gt 0 ]]; then
    _send_tg "⚠️ sessions.json não atualizado há $(( SESS_AGE / 3600 ))h com $SESSION_COUNT sessões — pode ter sessões antigas"
    echo "[$TIMESTAMP] WARN: sessions.json stale (${SESS_AGE}s)" >> "$LOG"
  fi
fi
