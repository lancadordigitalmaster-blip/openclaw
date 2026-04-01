#!/bin/bash
# Self-Heal Watchdog — Zero-Cost System Recovery
# Roda a cada 5-10min via cron
# Se encontra problema: tenta corrigir automaticamente
# Se conseguir: silêncio. Se não conseguir: notifica Netto

set -e

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

# ─────────────────────────────────────────────────────────────
# CHECK 1: Gateway respondendo?
# ─────────────────────────────────────────────────────────────
check_gateway() {
  local status="OK"
  
  # Tenta fazer um simples ping na API local
  if ! timeout $TIMEOUT_SECS curl -s http://localhost:3535/status > /dev/null 2>&1; then
    status="FAIL"
    log_entry "ALERT" "Gateway não respondendo. Tentando restart via openclaw CLI..."
    
    # Tenta restart via CLI (não via launchctl que varia por OS)
    if (cd /opt/homebrew/lib/node_modules/openclaw && npm run gateway:restart 2>/dev/null) || openclaw gateway restart 2>/dev/null; then
      log_entry "ACTION" "Gateway restart solicitado"
      sleep 4
      
      # Verifica se voltou
      if timeout $TIMEOUT_SECS curl -s http://localhost:3535/status > /dev/null 2>&1; then
        log_entry "FIXED" "Gateway respondendo novamente após restart"
        return 0
      else
        log_entry "ERROR" "Gateway ainda não responde após restart — escalando para Netto"
        return 1
      fi
    else
      log_entry "ERROR" "Falha ao executar restart — openclaw CLI ou npm não encontrados"
      return 1
    fi
  else
    log_entry "CHECK" "Gateway OK"
    return 0
  fi
}

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
# MAIN EXECUTION
# ─────────────────────────────────────────────────────────────
mkdir -p "$MEMORY_DIR"

FAILED_CHECKS=0

check_gateway || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_memory || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_errors || FAILED_CHECKS=$((FAILED_CHECKS + 1))
check_crons

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
