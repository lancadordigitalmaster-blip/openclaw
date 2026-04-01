#!/bin/bash
# wolf-cron-autoheal.sh — Auto-heal para crons com falhas consecutivas
# Logica: se cron falha 3x seguidas → pausa automatica + alerta via wolf_notify
# Roda via crontab ou LaunchAgent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

JOBS_FILE="$HOME/.openclaw/cron/jobs.json"
LOG_FILE="$HOME/.openclaw/logs/cron-autoheal.log"
THRESHOLD=3

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Cron autoheal check iniciado ==="

# Verificar se jobs.json existe
if [ ! -f "$JOBS_FILE" ]; then
    log "ERRO: $JOBS_FILE nao encontrado"
    exit 1
fi

# Usar python3 para ler jobs.json, verificar consecutiveErrors e desabilitar se necessario
python3 << 'PYEOF' - "$JOBS_FILE" "$THRESHOLD" "$LOG_FILE"
import json
import sys
import os
from datetime import datetime

jobs_file = sys.argv[1]
threshold = int(sys.argv[2])
log_file = sys.argv[3]

def log(msg):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, 'a') as f:
        f.write(f"[{timestamp}] {msg}\n")

try:
    with open(jobs_file, 'r') as f:
        data = json.load(f)
except Exception as e:
    log(f"ERRO: Falha ao ler jobs.json: {e}")
    sys.exit(1)

# jobs.json can be a list or dict with "jobs" key
jobs = data if isinstance(data, list) else data.get('jobs', data.get('crons', []))
if isinstance(jobs, dict):
    # Some formats use numbered keys
    jobs_list = list(jobs.values()) if all(isinstance(v, dict) for v in jobs.values()) else []
else:
    jobs_list = jobs

modified = False
disabled_crons = []

for i, job in enumerate(jobs_list):
    if not isinstance(job, dict):
        continue

    enabled = job.get('enabled', True)
    if not enabled:
        continue

    name = job.get('name', job.get('title', f'cron#{i}'))

    # Check state.consecutiveErrors
    state = job.get('state', {})
    if not isinstance(state, dict):
        continue

    errors = state.get('consecutiveErrors', 0)

    if errors >= threshold:
        log(f"AUTOHEAL: Cron '{name}' com {errors} erros consecutivos (>= {threshold}) — DESABILITANDO")
        job['enabled'] = False
        modified = True
        disabled_crons.append((name, errors))
    elif errors > 0:
        log(f"CHECK: Cron '{name}' com {errors} erros consecutivos (< {threshold}) — monitorando")
    else:
        log(f"CHECK: Cron '{name}' — OK (0 erros)")

if modified:
    # Write back
    if isinstance(data, list):
        output = jobs_list
    else:
        key = 'jobs' if 'jobs' in data else ('crons' if 'crons' in data else None)
        if key:
            data[key] = jobs_list
            output = data
        else:
            output = jobs_list

    try:
        with open(jobs_file, 'w') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        log(f"SAVE: jobs.json atualizado — {len(disabled_crons)} cron(s) desabilitado(s)")
    except Exception as e:
        log(f"ERRO: Falha ao salvar jobs.json: {e}")
        sys.exit(1)

    # Output disabled crons for bash to notify
    for name, errors in disabled_crons:
        print(f"{name}|{errors}")
else:
    log("OK: Nenhum cron precisou ser desabilitado")

PYEOF

# Capturar output do python (crons desabilitados)
DISABLED=$(python3 << 'PYEOF2' - "$JOBS_FILE" "$THRESHOLD"
import json, sys
jobs_file = sys.argv[1]
threshold = int(sys.argv[2])
with open(jobs_file, 'r') as f:
    data = json.load(f)
jobs = data if isinstance(data, list) else data.get('jobs', data.get('crons', []))
if isinstance(jobs, dict):
    jobs = list(jobs.values())
for job in jobs:
    if not isinstance(job, dict): continue
    if job.get('enabled', True): continue
    state = job.get('state', {})
    if not isinstance(state, dict): continue
    errors = state.get('consecutiveErrors', 0)
    if errors >= threshold:
        name = job.get('name', job.get('title', '?'))
        print(f"{name}|{errors}")
PYEOF2
)

# Enviar alertas para cada cron desabilitado
if [ -n "$DISABLED" ]; then
    while IFS='|' read -r cron_name error_count; do
        [ -z "$cron_name" ] && continue
        wolf_notify "⚠️ *Cron Auto-Heal*: '$cron_name' desabilitado automaticamente ($error_count erros consecutivos). Verifique e reative manualmente."
        log "NOTIFY: Alerta enviado para cron '$cron_name'"
    done <<< "$DISABLED"
fi

log "=== Cron autoheal check finalizado ==="
