#!/bin/bash
# Wolf Agency — Git Auto-Sync (a cada 30min via LaunchAgent)

REPO="/Users/thomasgirotto/openclaw-repo"
WS="/Users/thomasgirotto/.openclaw/workspace"
BRIDGE="/Users/thomasgirotto/openclaw/whatsapp-bridge"
VERCEL="/tmp/wolf-vercel-app"
LOG="/Users/thomasgirotto/.openclaw/logs/git-sync.log"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Git Auto-Sync ==="

cd "$REPO" || { echo "ERRO: repo nao encontrado"; exit 1; }

# Sync workspace
rsync -a --delete --exclude='node_modules' --exclude='.venv' --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='.DS_Store' --exclude='backups' --exclude='*.bak' --exclude='*.log' "$WS/skills/" "$REPO/skills/"
rsync -a --delete --exclude='.DS_Store' "$WS/agents/" "$REPO/agents/"
rsync -a --delete --exclude='.DS_Store' "$WS/orchestrator/" "$REPO/orchestrator/"
rsync -a --delete --exclude='.DS_Store' "$WS/shared/" "$REPO/shared/"
rsync -a --delete --exclude='.DS_Store' --exclude='node_modules' --exclude='.venv' --exclude='venv' --exclude='git-auto-sync.sh' "$WS/scripts/" "$REPO/scripts/"
rsync -a --delete --exclude='.DS_Store' "$WS/config/" "$REPO/config/"
rsync -a --delete --exclude='.DS_Store' "$WS/wolf-mission-control/" "$REPO/wolf-mission-control/"

for f in SOUL.md TOOLS.md CLAUDE.md IDENTITY.md AGENTS.md USER.md wolf-comercial.html; do
  [ -f "$WS/$f" ] && cp "$WS/$f" "$REPO/$f"
done

if [ -d "$BRIDGE" ]; then
  mkdir -p "$REPO/whatsapp-bridge"
  for f in bridge.js package.json sales-report.sh resync-history.sh; do
    [ -f "$BRIDGE/$f" ] && cp "$BRIDGE/$f" "$REPO/whatsapp-bridge/$f"
  done
fi

if [ -d "$VERCEL" ]; then
  rsync -a --exclude='node_modules' --exclude='.vercel' --exclude='.DS_Store' "$VERCEL/api/" "$REPO/api/"
  rsync -a --exclude='.DS_Store' "$VERCEL/_lib/" "$REPO/_lib/"
  rsync -a --exclude='.DS_Store' "$VERCEL/public/" "$REPO/public/"
  [ -f "$VERCEL/vercel.json" ] && cp "$VERCEL/vercel.json" "$REPO/vercel.json"
  [ -f "$VERCEL/package.json" ] && cp "$VERCEL/package.json" "$REPO/package.json"
fi

# Sanitize secrets before commit
sed -i '' "s/sb_secret_[A-Za-z0-9_-]*/SET_YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE/g" "$REPO/wolf-mission-control/migrations/001_mission_control.sql" 2>/dev/null

cd "$REPO"
CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

if [ "$CHANGES" -eq 0 ]; then
  echo "[$(date '+%H:%M:%S')] Nenhuma mudanca"
  exit 0
fi

echo "[$(date '+%H:%M:%S')] $CHANGES arquivo(s) modificado(s)"
git add -A
SUMMARY=$(git diff --cached --stat | tail -1)
git commit -m "auto-sync: $SUMMARY" 2>&1
git push origin main 2>&1

echo "[$(date '+%H:%M:%S')] === Sync concluido ==="
