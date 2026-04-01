#!/bin/bash
# session-start.sh — Wolf Agency Session Start Hook
# Adaptado do ECC everything-claude-code para arquitetura OpenClaw
# Roda no início de cada sessão via cron ou auto-heal
# Carrega contexto da sessão anterior se recente (<15min)

export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
SESSIONS_DIR="$MEMORY_DIR/sessions"

mkdir -p "$SESSIONS_DIR"

# 1. Verificar se existe last-context.md recente
LAST_CONTEXT="$MEMORY_DIR/last-context.md"
if [ -f "$LAST_CONTEXT" ]; then
  MODIFIED=$(stat -f "%m" "$LAST_CONTEXT" 2>/dev/null || stat -c "%Y" "$LAST_CONTEXT" 2>/dev/null)
  NOW=$(date +%s)
  AGE=$(( NOW - MODIFIED ))
  
  if [ "$AGE" -lt 900 ]; then
    echo "[SessionStart] last-context.md encontrado (${AGE}s atrás). Retomando contexto."
  else
    echo "[SessionStart] last-context.md existe mas é antigo (${AGE}s). Renomeando sem retomar."
    mv "$LAST_CONTEXT" "$MEMORY_DIR/last-context-EXPIRADO-$(date +%Y%m%d-%H%M).md"
  fi
fi

# 2. Verificar sessões recentes salvas (últimas 7 dias)
RECENT_SESSIONS=$(find "$SESSIONS_DIR" -name "*-session.md" -mtime -7 2>/dev/null | sort -r | head -5)

if [ -n "$RECENT_SESSIONS" ]; then
  LATEST=$(echo "$RECENT_SESSIONS" | head -1)
  COUNT=$(echo "$RECENT_SESSIONS" | wc -l | tr -d ' ')
  echo "[SessionStart] $COUNT sessão(ões) recente(s) encontrada(s). Mais recente: $(basename $LATEST)"
else
  echo "[SessionStart] Nenhuma sessão recente encontrada. Sessão nova."
fi

# 3. Reportar skills carregadas
SKILLS_COUNT=$(ls "$WORKSPACE/skills/" 2>/dev/null | wc -l | tr -d ' ')
echo "[SessionStart] $SKILLS_COUNT skills disponíveis em skills/"

# 4. Verificar estado do sistema
GATEWAY_PID=$(pgrep -f "openclaw" | head -1)
if [ -n "$GATEWAY_PID" ]; then
  echo "[SessionStart] Gateway OK (PID: $GATEWAY_PID)"
else
  echo "[SessionStart] ⚠️ Gateway não detectado"
fi

# 5. Log em boot-context.md
echo "[SessionStart] $(date '+%Y-%m-%d %H:%M:%S') — Sessão iniciada" >> "$MEMORY_DIR/session-history.log"

exit 0
