#!/bin/bash
# Self-Heal Watchdog — Zero-Cost System Recovery
# Roda a cada 5-10min via cron
# Se encontra problema: tenta corrigir automaticamente
# Se conseguir: silêncio. Se não conseguir: notifica Netto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
LOG_FILE="$WORKSPACE/memory/self-heal.log"
MEMORY_DIR="$WORKSPACE/memory"
GATEWAY_LOCK="/tmp/openclaw-gateway.lock"
TIMEOUT_SECS=5

# ─────────────────────────────────────────────────────────────
# UTIL: Log entry
# ─────────────────────────────────────────────────────────────
log_entry() {
  local level=$1
  local msg=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# CHECK 1: Gateway — delegado para wolf-monitor.sh (30min, porta 18789)
# Removido daqui para evitar redundancia e porta errada (3535 vs 18789)

# ─────────────────────────────────────────────────────────────
# CHECK 2: Memória não explodir?
# ─────────────────────────────────────────────────────────────
check_memory() {
  local mem_used=$(ps aux | grep openclaw | grep -v grep | awk '{sum+=$6} END {print sum}')
  local mem_mb=$((mem_used / 1024))
  
  # Alertar só se ultrapassar 1GB (mais realista para produção)
  if [ "$mem_mb" -gt 1000 ]; then
    log_entry "WARN" "Memória CRÍTICA: ${mem_mb}MB — considera restart"
    return 1
  elif [ "$mem_mb" -gt 700 ]; then
    log_entry "NOTICE" "Memória elevada: ${mem_mb}MB"
    return 0
  else
    log_entry "CHECK" "Memória OK: ${mem_mb}MB"
    return 0
  fi
}

# ─────────────────────────────────────────────────────────────
# CHECK 3: Logs de erro recentes?
# ─────────────────────────────────────────────────────────────
check_errors() {
  if [ ! -f "$MEMORY_DIR/errors.md" ]; then
    return 0
  fi
  
  # Conta erros das últimas 4 horas (macOS compatible)
  local four_hours_ago=$(date -u -v-4H +%Y-%m-%d)
  local recent_errors=$(grep "$four_hours_ago" "$MEMORY_DIR/errors.md" 2>/dev/null | wc -l)
  
  if [ "$recent_errors" -gt 3 ]; then
    log_entry "WARN" "Múltiplos erros detectados ($recent_errors nas últimas 4h)"
    return 1
  else
    log_entry "CHECK" "Erros recentes: $recent_errors (OK)"
    return 0
  fi
}

# ─────────────────────────────────────────────────────────────
# CHECK 4: Crons falhando?
# ─────────────────────────────────────────────────────────────
check_crons() {
  # Verifica se há cron jobs que não rodaram nas últimas 2h
  # (simplificado — em produção seria mais sofisticado)
  log_entry "CHECK" "Crons — verificação manual via 'openclaw cron list' recomendada"
  return 0
}

# ─────────────────────────────────────────────────────────────
# CHECK 5: WhatsApp Bridge rodando?
# ─────────────────────────────────────────────────────────────
check_whatsapp_bridge() {
  local bridge_ok=false

  # Tenta health endpoint primeiro
  if curl -s --max-time 5 http://127.0.0.1:3002/health > /dev/null 2>&1; then
    bridge_ok=true
  elif pgrep -f "bridge.js" > /dev/null 2>&1; then
    bridge_ok=true
  fi

  if [ "$bridge_ok" = true ]; then
    log_entry "CHECK" "WhatsApp Bridge OK"
    return 0
  fi

  log_entry "ALERT" "WhatsApp Bridge DOWN — tentando restart via launchctl..."
  launchctl kickstart -k "gui/$(id -u)/ai.openclaw.whatsapp-bridge" 2>/dev/null || true
  sleep 5

  # Verificar se voltou
  if curl -s --max-time 5 http://127.0.0.1:3002/health > /dev/null 2>&1 || pgrep -f "bridge.js" > /dev/null 2>&1; then
    log_entry "FIXED" "WhatsApp Bridge reiniciado com sucesso"
    wolf_notify "🔧 *Self-Heal*: WhatsApp Bridge estava DOWN — reiniciado automaticamente."
    return 0
  else
    log_entry "ERROR" "WhatsApp Bridge nao voltou apos restart — escalando"
    wolf_notify "🚨 *Self-Heal CRITICO*: WhatsApp Bridge DOWN e nao consegui reiniciar. Verificar manualmente."
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────
# CHECK 6: Espaco em disco
# ─────────────────────────────────────────────────────────────
check_disk_space() {
  local disk_usage
  disk_usage=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

  if [ -z "$disk_usage" ]; then
    log_entry "WARN" "Disco: nao foi possivel obter uso"
    return 0
  fi

  local result=0

  # Verificar tamanho do diretorio de sessoes (sempre, independente do disco)
  local sessions_dir="$HOME/.openclaw/agents/main/sessions"
  if [ -d "$sessions_dir" ]; then
    local sessions_size_kb
    sessions_size_kb=$(du -sk "$sessions_dir" 2>/dev/null | awk '{print $1}')
    local sessions_size_mb=$((sessions_size_kb / 1024))

    if [ "$sessions_size_mb" -gt 50 ]; then
      log_entry "ALERT" "Sessions dir ${sessions_size_mb}MB (>50MB) — limpando .jsonl.bak"
      find "$sessions_dir" -name "*.jsonl.bak" -delete 2>/dev/null || true
      wolf_notify "🧹 *Self-Heal*: Sessions dir estava em ${sessions_size_mb}MB — arquivos .bak limpos."
    fi
  fi

  if [ "$disk_usage" -gt 95 ]; then
    log_entry "ALERT" "Disco CRITICO: ${disk_usage}% — limpando logs antigos e arquivos temporarios"
    wolf_notify "🚨 *Self-Heal*: Disco em ${disk_usage}%! Limpando logs antigos automaticamente."

    # Limpar logs com mais de 3 dias (truncar, nao deletar)
    find "$HOME/.openclaw/logs" -name "*.log" -mtime +3 -exec truncate -s 0 {} \; 2>/dev/null || true

    # Limpar arquivos .jsonl.bak antigos
    find "$HOME/.openclaw" -name "*.jsonl.bak" -mtime +1 -delete 2>/dev/null || true

    log_entry "ACTION" "Logs >3 dias truncados, .jsonl.bak antigos removidos"
    result=1

  elif [ "$disk_usage" -gt 90 ]; then
    log_entry "WARN" "Disco ALTO: ${disk_usage}% — monitorando"
    wolf_notify "⚠️ *Self-Heal*: Disco em ${disk_usage}%. Considere liberar espaco."
  else
    log_entry "CHECK" "Disco OK: ${disk_usage}%"
  fi

  return $result
}

# ─────────────────────────────────────────────────────────────
# MAIN EXECUTION
# ─────────────────────────────────────────────────────────────
mkdir -p "$MEMORY_DIR"

FAILED_CHECKS=0

# check_gateway removido — wolf-monitor.sh cuida (porta 18789 correta)
check_memory || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_errors || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_crons
check_whatsapp_bridge || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_disk_space || FAILED_CHECKS=$((FAILED_CHECKS + 1))

# ─────────────────────────────────────────────────────────────
# REPORT: Notifica Netto APENAS se há problema não-resolvido
# ─────────────────────────────────────────────────────────────
if [ "$FAILED_CHECKS" -gt 0 ]; then
  log_entry "CRITICAL" "Self-heal detectou $FAILED_CHECKS problema(s) não resolvido(s)"
  
  # Salva estado para Alfred notificar
  echo "SELF_HEAL_FAILED=true" > "$MEMORY_DIR/.self-heal-alert"
  echo "FAILED_CHECKS=$FAILED_CHECKS" >> "$MEMORY_DIR/.self-heal-alert"
else
  log_entry "SUCCESS" "Tudo OK — sistema saudável"
  rm -f "$MEMORY_DIR/.self-heal-alert"
fi

# Rotação de logs (manter últimos 7 dias)
if [ -f "$LOG_FILE" ]; then
  find "$MEMORY_DIR" -name "self-heal.log*" -mtime +7 -delete 2>/dev/null || true
fi

exit $FAILED_CHECKS
