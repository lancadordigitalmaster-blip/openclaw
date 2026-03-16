#!/bin/bash
# backup-offsite.sh — Backup offsite diario (rsync incremental)
# Crontab: 0 4 * * * /Users/thomasgirotto/.openclaw/workspace/scripts/backup-offsite.sh
set -euo pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

DATE=$(date +%Y-%m-%d)
BACKUP_BASE="$HOME/.openclaw/backups/offsite"
BACKUP_DIR="$BACKUP_BASE/$DATE"
LOG="$HOME/.openclaw/backups/offsite/backup-offsite.log"
ENV_FILE="$HOME/.openclaw/.env"

mkdir -p "$BACKUP_DIR/launchagents" "$BACKUP_DIR/whatsapp-bridge"

# Load Telegram for failure alerts
source "$ENV_FILE" 2>/dev/null || true
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-789352357}"

notify_fail() {
  echo "[$(date '+%H:%M:%S')] FALHA: $1" >> "$LOG"
  [[ -n "$BOT_TOKEN" ]] && curl -s -o /dev/null \
    wolf_notify "[Backup Offsite] FALHA: $1"
}

trap 'notify_fail "erro inesperado linha $LINENO"' ERR

echo "[$DATE $(date '+%H:%M:%S')] Backup offsite iniciado" >> "$LOG"

# 1. Workspace (rsync, incremental)
rsync -a --delete \
  --exclude='node_modules' --exclude='__pycache__' --exclude='.venv' \
  --exclude='Wolf-Videos' --exclude='wolf-video-templates' --exclude='temp' \
  --exclude='.netlify' --exclude='.DS_Store' --exclude='backups' \
  "$HOME/.openclaw/workspace/" "$BACKUP_DIR/workspace/"

# 2. Config files
cp "$HOME/.openclaw/.env" "$BACKUP_DIR/dot-env" 2>/dev/null || true
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/cron/jobs.json" "$BACKUP_DIR/" 2>/dev/null || true

# 3. WhatsApp bridge (exclude auth_state + node_modules)
rsync -a --delete \
  --exclude='node_modules' --exclude='auth_state' --exclude='.DS_Store' \
  "$HOME/openclaw/whatsapp-bridge/" "$BACKUP_DIR/whatsapp-bridge/" 2>/dev/null || true

# 4. LaunchAgents
cp "$HOME/Library/LaunchAgents/ai.openclaw."*.plist "$BACKUP_DIR/launchagents/" 2>/dev/null || true

# 5. Log size
SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "[$DATE $(date '+%H:%M:%S')] Backup concluido: $SIZE" >> "$LOG"

# 6. Rotation: keep last 7 days
ls -1d "$BACKUP_BASE"/????-??-?? 2>/dev/null | sort -r | tail -n +8 | while read OLD; do
  rm -rf "$OLD"
  echo "[$DATE $(date '+%H:%M:%S')] Removido: $(basename "$OLD")" >> "$LOG"
done

# --- Future: sync to Google Drive with rclone ---
# rclone sync "$BACKUP_DIR" gdrive:wolf-backups/$DATE --transfers=4 --checkers=8
# Setup: brew install rclone && rclone config (choose Google Drive)
