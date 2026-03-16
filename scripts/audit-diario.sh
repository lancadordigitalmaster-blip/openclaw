#!/bin/bash
# =============================================================================
# WOLF — Auditoria Técnica Diária
# Roda: 06h00 diário (antes de todos os outros scripts)
# Cobre: gaps não cobertos por security-scan, watchdog ou heartbeat
# Notifica: Telegram só se encontrar problemas
# Autor: Wolf Agency / Claude — Março 2026
# =============================================================================

set -uo pipefail

# --- Configuração ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y-%m-%d')
LOG="$HOME/.openclaw/logs/audit-diario.log"
ENV_FILE="$HOME/.openclaw/.env"
GATEWAY_LOG="$HOME/.openclaw/logs/gateway.log"
WA_LOG="$HOME/.openclaw/logs/whatsapp-bridge.log"
TOKEN_LOG="$HOME/.openclaw/logs/token-telemetry.jsonl"
OPENCLAW_DIR="$HOME/.openclaw"

SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true
GATEWAY_TOKEN=$(grep '^GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

# --- Estado ---
PROBLEMAS=()
AVISOS=()
OK_COUNT=0

log() {
  echo "[$TIMESTAMP] $1" >> "$LOG"
}

alerta() {
  PROBLEMAS+=("$1")
  log "PROBLEMA: $1"
}

aviso() {
  AVISOS+=("$1")
  log "AVISO: $1"
}

ok() {
  OK_COUNT=$((OK_COUNT + 1))
  log "OK: $1"
}


log "=== Iniciando Auditoria Técnica Diária ==="

# =============================================================================
# CHECK 1 — Update do OpenClaw disponível
# O gateway.log mostra "update available" mas nenhum script processa isso
# =============================================================================
if [[ -f "$GATEWAY_LOG" ]]; then
  UPDATE_LINE=$(grep "update available" "$GATEWAY_LOG" | tail -1)
  if [[ -n "$UPDATE_LINE" ]]; then
    # Extrair versões
    CURRENT=$(echo "$UPDATE_LINE" | grep -oE 'current v[0-9.]+' | grep -oE '[0-9.]+')
    AVAILABLE=$(echo "$UPDATE_LINE" | grep -oE 'v[0-9.]+' | head -1 | tr -d 'v')
    if [[ -n "$AVAILABLE" && "$AVAILABLE" != "$CURRENT" ]]; then
      alerta "🔄 OpenClaw desatualizado: atual v${CURRENT} → disponível v${AVAILABLE}. Execute: \`openclaw update\`"
    fi
  else
    ok "OpenClaw na versão mais recente"
  fi
fi

# =============================================================================
# CHECK 2 — npm audit (vulnerabilidades nas dependências Node.js)
# Nenhum script existente faz isso
# =============================================================================
# WhatsApp Bridge
WA_DIR="$HOME/openclaw/whatsapp-bridge"
if [[ -d "$WA_DIR" && -f "$WA_DIR/package.json" ]]; then
  NPM_AUDIT=$(cd "$WA_DIR" && npm audit --json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vuln = d.get('metadata', {}).get('vulnerabilities', {})
    critical = vuln.get('critical', 0)
    high = vuln.get('high', 0)
    moderate = vuln.get('moderate', 0)
    total = sum(vuln.values())
    if critical > 0 or high > 0:
        print(f'CRITICAL:{critical} HIGH:{high} MODERATE:{moderate} TOTAL:{total}')
    elif total > 0:
        print(f'OK_MODERATE:{moderate} TOTAL:{total}')
    else:
        print('CLEAN')
except:
    print('SKIP')
" 2>/dev/null)

  case "$NPM_AUDIT" in
    CRITICAL:*|*HIGH:*)
      CRITICAL_N=$(echo "$NPM_AUDIT" | grep -oE 'CRITICAL:[0-9]+' | cut -d: -f2)
      HIGH_N=$(echo "$NPM_AUDIT" | grep -oE 'HIGH:[0-9]+' | cut -d: -f2)
      alerta "🚨 npm audit: ${CRITICAL_N:-0} críticas, ${HIGH_N:-0} altas no WhatsApp Bridge. Execute: \`cd $WA_DIR && npm audit fix\`"
      ;;
    OK_MODERATE:*)
      MOD_N=$(echo "$NPM_AUDIT" | grep -oE 'OK_MODERATE:[0-9]+' | cut -d: -f2)
      aviso "⚠️ npm audit: ${MOD_N:-0} vulnerabilidades moderadas no Bridge (não crítico)"
      ;;
    CLEAN)
      ok "npm audit limpo"
      ;;
  esac
fi

# =============================================================================
# CHECK 3 — pip outdated (dependências Python obsoletas)
# Verifica scripts Python do workspace
# =============================================================================
VENV_PIP="$HOME/.openclaw/workspace/scripts/.venv/bin/pip"
if [[ -f "$VENV_PIP" ]]; then
  OUTDATED_COUNT=$("$VENV_PIP" list --outdated 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')
  if [[ "$OUTDATED_COUNT" -gt 10 ]]; then
    alerta "📦 Python: $OUTDATED_COUNT dependências obsoletas no venv dos scripts"
  elif [[ "$OUTDATED_COUNT" -gt 0 ]]; then
    aviso "📦 Python: $OUTDATED_COUNT dependências desatualizadas (não crítico)"
  else
    ok "pip: dependências atualizadas"
  fi
fi

# =============================================================================
# CHECK 4 — Token Meta Ads expirado
# Detecta se scripts falharam por auth nos últimos logs
# =============================================================================
# Buscar erros de auth em logs recentes (últimas 24h)
META_ERRORS=$(find "$HOME/.openclaw/logs" -name "*.log" -mtime -1 2>/dev/null | \
  xargs grep -iE "meta.*error|facebook.*auth|ads.*token|OAuthException|invalid_token" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$META_ERRORS" -gt 0 ]]; then
  alerta "🔑 Meta Ads: $META_ERRORS erros de autenticação nas últimas 24h. Token provavelmente expirado — renovar em business.facebook.com"
else
  ok "Meta Ads: sem erros de auth detectados"
fi

# =============================================================================
# CHECK 5 — Portas expostas fora do localhost
# Verifica se 3002 (Bridge), 18789 (Gateway), 8765 (Mission Control) estão
# acessíveis na rede local (risco de exposição)
# =============================================================================
check_porta_exposta() {
  local porta="$1"
  local nome="$2"

  # lsof mostra em qual endereço a porta está bindada
  BIND=$(lsof -iTCP:"$porta" -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {print $9}' | head -1)

  if [[ -z "$BIND" ]]; then
    # Porta não está em uso
    return
  fi

  # Se bind for 0.0.0.0 ou * ou vazio sem 127, está exposta
  if echo "$BIND" | grep -qE '^\*:|^0\.0\.0\.0:'; then
    alerta "🌐 Porta $porta ($nome) exposta em 0.0.0.0 — acessível na rede local. Considere bindá-la em 127.0.0.1"
  else
    ok "Porta $porta ($nome) bindada em localhost"
  fi
}

check_porta_exposta 3002  "WhatsApp Bridge"
check_porta_exposta 18789 "OpenClaw Gateway"
check_porta_exposta 8765  "Mission Control"

# =============================================================================
# CHECK 6 — Crescimento de logs fora de controle
# whatsapp-bridge.log e token-telemetry.jsonl estão grandes (2M+ cada)
# =============================================================================
check_log_size() {
  local arquivo="$1"
  local nome="$2"
  local limite_mb="$3"

  if [[ -f "$arquivo" ]]; then
    SIZE_MB=$(du -m "$arquivo" 2>/dev/null | cut -f1)
    if [[ "$SIZE_MB" -ge "$limite_mb" ]]; then
      alerta "📁 Log crescendo sem controle: $nome tem ${SIZE_MB}MB (limite: ${limite_mb}MB). Rotação necessária."
    elif [[ "$SIZE_MB" -ge $((limite_mb / 2)) ]]; then
      aviso "📁 $nome com ${SIZE_MB}MB — acompanhar crescimento"
    else
      ok "$nome: ${SIZE_MB}MB (normal)"
    fi
  fi
}

check_log_size "$WA_LOG"    "whatsapp-bridge.log" 50
check_log_size "$TOKEN_LOG" "token-telemetry.jsonl" 50
check_log_size "$HOME/.openclaw/logs/gateway.err.log" "gateway.err.log" 10

# =============================================================================
# CHECK 7 — LaunchAgents críticos desabilitados sem justificativa
# =============================================================================
DISABLED_CRITICOS=()
CRITICOS=(
  "ai.openclaw.clickup-check.plist.disabled"
  "ai.openclaw.gateway-monitor.plist.disabled"
  "com.netto.openclaw-brain.plist.disabled"
)

for plist in "${CRITICOS[@]}"; do
  if [[ -f "$HOME/Library/LaunchAgents/$plist" ]]; then
    DISABLED_CRITICOS+=("$plist")
  fi
done

if [[ ${#DISABLED_CRITICOS[@]} -gt 0 ]]; then
  LISTA=$(printf '%s\n' "${DISABLED_CRITICOS[@]}" | sed 's/\.plist\.disabled//' | tr '\n' ', ' | sed 's/,$//')
  aviso "⚙️ LaunchAgents desabilitados: $LISTA — intencional ou esquecido?"
else
  ok "LaunchAgents críticos todos ativos"
fi

# =============================================================================
# RESULTADO — Notificar apenas se houver problemas
# =============================================================================
log "Resultado: ${#PROBLEMAS[@]} problemas, ${#AVISOS[@]} avisos, $OK_COUNT OK"

if [[ ${#PROBLEMAS[@]} -eq 0 && ${#AVISOS[@]} -eq 0 ]]; then
  log "Sistema limpo — sem notificação Telegram"
  exit 0
fi

# Montar mensagem
MSG="🔍 *Auditoria Técnica Diária — $DATE*"
MSG+="\n"

if [[ ${#PROBLEMAS[@]} -gt 0 ]]; then
  MSG+="\n*🔴 Problemas (${#PROBLEMAS[@]}):*"
  for p in "${PROBLEMAS[@]}"; do
    MSG+="\n• $p"
  done
fi

if [[ ${#AVISOS[@]} -gt 0 ]]; then
  MSG+="\n\n*🟡 Avisos (${#AVISOS[@]}):*"
  for a in "${AVISOS[@]}"; do
    MSG+="\n• $a"
  done
fi

MSG+="\n\n✅ $OK_COUNT checks passaram sem problema"
MSG+="\n_Wolf Audit System · 06h00 diário_"

wolf_notify "$MSG"
log "Notificação enviada ao Telegram"

exit 0
