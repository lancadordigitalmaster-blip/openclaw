#!/bin/bash
# ============================================================================
# APPLY-WRAPPER — Aplica cron-wrapper.sh em todas as entradas do crontab
#
# O que faz:
#   1. Lê o crontab atual
#   2. Para cada linha ativa (não comentário), insere o wrapper antes do comando
#   3. Extrai o nome do script como identificador
#   4. Mostra o DIFF antes de aplicar — não muda nada sem aprovação
#
# USO:
#   bash apply-wrapper.sh          → mostra o diff (dry-run)
#   bash apply-wrapper.sh --apply  → aplica de verdade
#
# SEGURANÇA:
#   - Faz backup do crontab antes de qualquer mudança
#   - Não toca em linhas comentadas ou variáveis de ambiente
#   - Se a linha já tem cron-wrapper.sh, pula
# ============================================================================

WRAPPER="bash ~/.openclaw/workspace/scripts/cron-wrapper.sh"
BACKUP_DIR="${HOME}/.openclaw/backups"
mkdir -p "$BACKUP_DIR"

MODE="dry-run"
if [ "$1" = "--apply" ]; then
  MODE="apply"
fi

# Backup
BACKUP_FILE="${BACKUP_DIR}/crontab-backup-$(date +%Y%m%d-%H%M%S).txt"
crontab -l > "$BACKUP_FILE" 2>/dev/null
echo "Backup salvo em: $BACKUP_FILE"
echo ""

# Processa
ORIGINAL=$(crontab -l 2>/dev/null)
MODIFIED=""
CHANGED=0
SKIPPED=0

while IFS= read -r line; do
  # Pula comentários, linhas vazias, e variáveis de ambiente
  if [[ "$line" =~ ^# ]] || [[ -z "$line" ]] || [[ "$line" =~ ^[A-Z_]+= ]]; then
    MODIFIED="${MODIFIED}${line}\n"
    continue
  fi

  # Pula se já tem wrapper
  if [[ "$line" == *"cron-wrapper.sh"* ]]; then
    MODIFIED="${MODIFIED}${line}\n"
    ((SKIPPED++))
    continue
  fi

  # Pula comandos complexos que não funcionam com $COMMAND (cd&&, bash -c, find -exec)
  COMMAND_PART=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}')
  if [[ "$COMMAND_PART" == cd\ * ]] || [[ "$COMMAND_PART" == *"bash -c"* ]] || [[ "$COMMAND_PART" == find\ * ]]; then
    MODIFIED="${MODIFIED}${line}\n"
    ((SKIPPED++))
    continue
  fi

  # Extrai: schedule (5 campos) + comando
  SCHEDULE=$(echo "$line" | awk '{print $1, $2, $3, $4, $5}')
  COMMAND=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

  # Extrai nome do script como identificador
  SCRIPT_NAME=$(echo "$COMMAND" | grep -oE '[^ /]+\.(sh|py)' | head -1 | sed 's/\.\(sh\|py\)$//')
  if [ -z "$SCRIPT_NAME" ]; then
    SCRIPT_NAME="unknown-$(echo "$COMMAND" | md5 -q 2>/dev/null || echo "$RANDOM")"
  fi

  # Nova linha com wrapper
  NEW_LINE="${SCHEDULE} ${WRAPPER} \"${SCRIPT_NAME}\" ${COMMAND}"
  MODIFIED="${MODIFIED}${NEW_LINE}\n"
  ((CHANGED++))

done <<< "$ORIGINAL"

echo "Resultado: ${CHANGED} linhas modificadas, ${SKIPPED} já tinham wrapper"
echo ""

if [ "$MODE" = "dry-run" ]; then
  echo "=== DIFF (dry-run — nada foi alterado) ==="
  diff <(echo "$ORIGINAL") <(echo -e "$MODIFIED") || echo "(sem diferenças)"
  echo ""
  echo "Para aplicar de verdade:"
  echo "  bash apply-wrapper.sh --apply"
  echo ""
  echo "Para reverter depois:"
  echo "  crontab $BACKUP_FILE"
else
  echo -e "$MODIFIED" | crontab -
  echo "Crontab atualizado com wrapper em ${CHANGED} entradas."
  echo ""
  echo "Para reverter:"
  echo "  crontab $BACKUP_FILE"
fi
