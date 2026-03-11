#!/usr/bin/env bash
# session-cleanup.sh — Wolf Agency
# Limpa sessões de cron ociosas do OpenClaw
# Zero LLM. Roda via cron a cada 30min (08h-22h).
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG="/tmp/session-cleanup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
IDLE_MINUTES=60

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG"
}

log "=== Session Cleanup iniciado ==="

if ! command -v openclaw &>/dev/null; then
    log "ERRO: openclaw CLI não encontrado"
    exit 1
fi

# Verifica sessões ociosas (informativo)
openclaw sessions --json > /tmp/sess_check.json 2>/dev/null

python3 - <<PYEOF
import json

with open('/tmp/sess_check.json') as f:
    data = json.load(f)

sessions = data.get('sessions', [])
idle_ms = ${IDLE_MINUTES} * 60 * 1000
old = [s for s in sessions if ':run:' in s.get('key','') and s.get('ageMs', 0) > idle_ms]

if old:
    print(f"Sessoes ociosas detectadas: {len(old)}")
    for s in old:
        print(f"  - {s['key'][:70]} | {s.get('ageMs',0)/60000:.0f}min")
else:
    print("Nenhuma sessao ociosa. Sistema limpo.")
PYEOF

# Executa limpeza nativa do OpenClaw
openclaw sessions cleanup >> "$LOG" 2>&1

log "=== Cleanup concluído ==="
