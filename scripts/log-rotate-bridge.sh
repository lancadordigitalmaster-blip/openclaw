#!/bin/bash
# log-rotate-bridge.sh — Rotação diária do whatsapp-bridge.log
# Mantém últimos 7 dias, comprime logs antigos

LOG="/Users/thomasgirotto/.openclaw/logs/whatsapp-bridge.log"
MAX_SIZE_MB=50

[ ! -f "$LOG" ] && exit 0

SIZE_MB=$(du -m "$LOG" 2>/dev/null | awk '{print $1}')
[ "$SIZE_MB" -lt "$MAX_SIZE_MB" ] && exit 0

# Rotacionar
DATE=$(date +%Y-%m-%d)
cp "$LOG" "${LOG}.${DATE}"
: > "$LOG"

# Comprimir
gzip -f "${LOG}.${DATE}" 2>/dev/null

# Limpar logs > 7 dias
find "$(dirname "$LOG")" -name "whatsapp-bridge.log.*.gz" -mtime +7 -delete 2>/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated: ${SIZE_MB}MB → compressed"
