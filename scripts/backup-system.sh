#!/bin/bash
# ============================================================
# WOLF BACKUP SYSTEM — Backup completo diario
# Roda via LaunchAgent as 03:00
# Destino: ~/.openclaw/backups/YYYY-MM-DD/
# ============================================================
set -euo pipefail

DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$HOME/.openclaw/backups/$DATE"
BACKUP_TAR="$HOME/.openclaw/backups/backup-${DATE}.tar.gz"
LOG="/tmp/openclaw/backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$BACKUP_DIR" /tmp/openclaw

echo "[$TIMESTAMP] Backup iniciado" >> "$LOG"

# Se ja existe backup de hoje, pula
if [[ -f "$BACKUP_TAR" ]]; then
  echo "[$TIMESTAMP] Backup de hoje ja existe: $BACKUP_TAR" >> "$LOG"
  exit 0
fi

# ============================================================
# Arquivos a incluir
# ============================================================

# 1. Credenciais
cp "$HOME/.openclaw/.env" "$BACKUP_DIR/" 2>/dev/null || true

# 2. Config principal
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_DIR/" 2>/dev/null || true

# 3. Definicoes de crons
cp "$HOME/.openclaw/cron/jobs.json" "$BACKUP_DIR/" 2>/dev/null || true

# 4. Workspace (memory, agents, scripts, shared, orchestrator, skills)
for DIR in memory agents scripts shared orchestrator skills; do
  if [[ -d "$HOME/.openclaw/workspace/$DIR" ]]; then
    cp -r "$HOME/.openclaw/workspace/$DIR" "$BACKUP_DIR/" 2>/dev/null || true
  fi
done

# 5. Arquivos .md na raiz do workspace (SOUL.md, AGENTS.md, etc)
cp "$HOME/.openclaw/workspace/"*.md "$BACKUP_DIR/" 2>/dev/null || true

# 6. LaunchAgents do OpenClaw
mkdir -p "$BACKUP_DIR/launchagents"
cp "$HOME/Library/LaunchAgents/ai.openclaw."*.plist "$BACKUP_DIR/launchagents/" 2>/dev/null || true

# 7. Auth profiles (sem tokens no nome do arquivo)
cp "$HOME/.openclaw/auth-profiles.json" "$BACKUP_DIR/" 2>/dev/null || true

# ============================================================
# Comprimir
# ============================================================
cd "$HOME/.openclaw/backups"
tar -czf "backup-${DATE}.tar.gz" "$DATE/" 2>/dev/null

# Remover pasta intermediaria (manter so o .tar.gz)
rm -rf "$BACKUP_DIR"

# Tamanho do backup
SIZE=$(du -sh "$BACKUP_TAR" | cut -f1)
echo "[$TIMESTAMP] Backup criado: $BACKUP_TAR ($SIZE)" >> "$LOG"

# ============================================================
# Rotacao: manter apenas ultimos 7 dias
# ============================================================
find "$HOME/.openclaw/backups/" -name "backup-*.tar.gz" -mtime +7 -delete 2>/dev/null || true
DELETED=$(find "$HOME/.openclaw/backups/" -name "backup-*.tar.gz" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
if [[ "$DELETED" -gt 0 ]]; then
  echo "[$TIMESTAMP] Rotacao: $DELETED backups antigos removidos" >> "$LOG"
fi

echo "[$TIMESTAMP] Backup concluido com sucesso" >> "$LOG"
