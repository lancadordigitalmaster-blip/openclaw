#!/bin/bash
# Auto-Update Script for OpenClaw + Skills
# Created: 2026-03-05

set -e

LOG_FILE="$HOME/.openclaw/logs/auto-update.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Starting auto-update ==="

# Capture starting versions
OPENCLAW_VERSION_BEFORE=$(openclaw --version 2>/dev/null || echo "unknown")
log "OpenClaw before: $OPENCLAW_VERSION_BEFORE"

# Update OpenClaw
log "Updating OpenClaw..."
if command -v npm &> /dev/null && npm list -g openclaw &> /dev/null; then
  npm update -g openclaw@latest 2>&1 | tee -a "$LOG_FILE"
elif [ -d "$HOME/.openclaw/.git" ]; then
  cd "$HOME/.openclaw" && git pull 2>&1 | tee -a "$LOG_FILE" || true
else
  log "OpenClaw: using gateway update"
  openclaw update 2>&1 | tee -a "$LOG_FILE" || true
fi

# Note: DO NOT restart gateway here — it kills the cron process that's running this script
log "Skipping gateway restart (unsafe from within cron). Restart manually if needed."

# Capture new version
OPENCLAW_VERSION_AFTER=$(openclaw --version 2>/dev/null || echo "unknown")
log "OpenClaw after: $OPENCLAW_VERSION_AFTER"

# Update skills (if clawdhub exists)
log "Updating skills..."
if command -v clawdhub &> /dev/null; then
  SKILL_OUTPUT=$(clawdhub update --all 2>&1) || true
  echo "$SKILL_OUTPUT" >> "$LOG_FILE"
  log "$SKILL_OUTPUT"
else
  log "clawdhub not found, skipping skill update"
  SKILL_OUTPUT="clawdhub not available"
fi

log "=== Auto-update complete ==="

# Output summary
echo ""
echo "=== UPDATE SUMMARY ==="
echo "openclaw_before: $OPENCLAW_VERSION_BEFORE"
echo "openclaw_after: $OPENCLAW_VERSION_AFTER"
echo "skill_output: $SKILL_OUTPUT"
echo "======================"
