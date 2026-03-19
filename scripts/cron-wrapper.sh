#!/bin/bash
# ============================================================================
# CRON WRAPPER — Action Logger Universal
# Envolve qualquer cron e registra execução em actions.jsonl
#
# USO NO CRONTAB:
#   ANTES:  */15 * * * * bash ~/.openclaw/workspace/scripts/meu-script.sh >> ~/.openclaw/logs/meu.log 2>&1
#   DEPOIS: */15 * * * * bash ~/.openclaw/workspace/scripts/cron-wrapper.sh "meu-script" bash ~/.openclaw/workspace/scripts/meu-script.sh >> ~/.openclaw/logs/meu.log 2>&1
#
# O wrapper NÃO interfere no output — tudo que o script original mandaria
# pro log continua indo. O wrapper só adiciona uma linha no actions.jsonl.
#
# INSTALAÇÃO:
#   cp cron-wrapper.sh ~/.openclaw/workspace/scripts/cron-wrapper.sh
#   chmod +x ~/.openclaw/workspace/scripts/cron-wrapper.sh
#   mkdir -p ~/.openclaw/logs
# ============================================================================

CRON_NAME="$1"
shift
COMMAND="$@"

# Arquivo central de registro
ACTIONS_LOG="${HOME}/.openclaw/logs/actions.jsonl"

# Garante que o diretório existe
mkdir -p "$(dirname "$ACTIONS_LOG")"

# Timestamp de início
START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_EPOCH=$(date +%s)

# Executa o comando original, captura stderr separado
STDERR_TMP=$(mktemp)
$COMMAND 2>"$STDERR_TMP"
EXIT_CODE=$?

# Calcula duração
END_EPOCH=$(date +%s)
DURATION_MS=$(( (END_EPOCH - START_EPOCH) * 1000 ))

# Captura preview do erro (se houver)
ERROR_PREVIEW=""
if [ $EXIT_CODE -ne 0 ] && [ -s "$STDERR_TMP" ]; then
  ERROR_PREVIEW=$(head -c 200 "$STDERR_TMP" | tr '\n' ' ' | tr '"' "'")
fi

# Reemite stderr pro output original (pra não quebrar os logs existentes)
cat "$STDERR_TMP" >&2
rm -f "$STDERR_TMP"

# Status legível
if [ $EXIT_CODE -eq 0 ]; then
  STATUS="ok"
else
  STATUS="error"
fi

# Grava no actions.jsonl (append-only, uma linha por execução)
echo "{\"ts\":\"${START_TS}\",\"cron\":\"${CRON_NAME}\",\"status\":\"${STATUS}\",\"exit_code\":${EXIT_CODE},\"duration_ms\":${DURATION_MS},\"error\":\"${ERROR_PREVIEW}\"}" >> "$ACTIONS_LOG"

# Sai com o mesmo código do script original
exit $EXIT_CODE
