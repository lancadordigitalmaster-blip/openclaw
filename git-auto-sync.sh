#!/bin/bash
# Wolf Agency — Git Auto-Sync (Mac Mini)
# Roda a cada 30min via cron
#
# REGRAS DE OURO:
#   • MacBook é dono do código — Mac Mini sempre puxa, nunca sobrescreve código do MacBook
#   • Mac Mini tem autoridade sobre: shared/memory/ (estado cognitivo Alfred)
#   • EXCEÇÃO: skills/agents criados diretamente no Mac Mini via SSH são commitados antes do pull
#
# FLUXO:
#   1. Commita mudanças locais (skills/agents criados via SSH) ANTES de puxar
#   2. git pull --rebase → pega código novo do MacBook
#   3. Propaga repo → workspace (Alfred usa versão atualizada)
#   4. Reinicia OpenClaw se houve mudança de código
#   5. Commita e empurra shared/memory/ → GitHub

REPO="/Users/thomasgirotto/openclaw-repo"
WS="/Users/thomasgirotto/.openclaw/workspace"
BRIDGE="/Users/thomasgirotto/openclaw/whatsapp-bridge"
LOG="/Users/thomasgirotto/.openclaw/logs/git-sync.log"
OPENCLAW_CLI="/opt/homebrew/opt/node/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/index.js"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Git Auto-Sync (Mac Mini) ==="

cd "$REPO" || { echo "ERRO: repo nao encontrado"; exit 1; }

git config user.email "lancadordigitalmaster@gmail.com" 2>/dev/null
git config user.name "Wilson Girotto" 2>/dev/null

# ── PASSO 1: Commita mudanças locais antes de puxar ───────────
# Garante que skills/agents instalados via SSH não sejam perdidos no pull
LOCAL_CHANGES=$(git status --porcelain -- skills/ agents/ whatsapp-bridge/ orchestrator/ 2>/dev/null | grep -v "shared/memory" | wc -l | tr -d ' ')

if [ "$LOCAL_CHANGES" -gt 0 ]; then
  echo "[$(date '+%H:%M:%S')] $LOCAL_CHANGES mudança(s) local(is) detectada(s) — commitando antes do pull..."
  SUMMARY=$(git status --porcelain -- skills/ agents/ 2>/dev/null | head -3 | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')
  git add skills/ agents/ whatsapp-bridge/ orchestrator/ 2>/dev/null
  git commit -m "macmini: $SUMMARY" 2>&1
  git push origin main 2>&1 && \
    echo "[$(date '+%H:%M:%S')] ✓ Mudanças locais enviadas" || \
    echo "[WARN] Push de mudanças locais falhou"
fi

# ── PASSO 2: Pull do GitHub (pega código novo do MacBook) ──────
BEFORE=$(git rev-parse HEAD 2>/dev/null)
git pull --rebase origin main 2>&1 || {
  echo "[WARN] git pull --rebase falhou, tentando merge..."
  git rebase --abort 2>/dev/null
  git pull origin main 2>&1 || echo "[ERRO] Pull falhou"
}
AFTER=$(git rev-parse HEAD 2>/dev/null)

CODE_CHANGED=false
[ "$BEFORE" != "$AFTER" ] && CODE_CHANGED=true

# ── PASSO 3: Propaga repo → workspace do Alfred ────────────────
if [ "$CODE_CHANGED" = true ]; then
  echo "[$(date '+%H:%M:%S')] Código novo detectado — atualizando workspace..."

  rsync -a --exclude='*.log' --exclude='.DS_Store' \
    "$REPO/skills/"       "$WS/skills/"
  rsync -a --exclude='.DS_Store' \
    "$REPO/agents/"       "$WS/agents/"
  rsync -a --exclude='.DS_Store' \
    "$REPO/orchestrator/" "$WS/orchestrator/"
  rsync -a --exclude='.DS_Store' \
    "$REPO/shared/"       "$WS/shared/"
  rsync -a --exclude='.DS_Store' --exclude='node_modules' \
    "$REPO/scripts/"      "$WS/scripts/"
  rsync -a --exclude='.DS_Store' \
    "$REPO/config/"       "$WS/config/"

  for f in SOUL.md TOOLS.md CLAUDE.md IDENTITY.md AGENTS.md USER.md; do
    [ -f "$REPO/$f" ] && cp "$REPO/$f" "$WS/$f"
  done

  # Propaga whatsapp-bridge (apenas arquivos de código, não dados)
  if [ -d "$REPO/whatsapp-bridge" ] && [ -d "$BRIDGE" ]; then
    for f in bridge.js package.json sales-report.sh resync-history.sh design-production-report.py design-morning-audit.py run-report.sh; do
      [ -f "$REPO/whatsapp-bridge/$f" ] && cp "$REPO/whatsapp-bridge/$f" "$BRIDGE/$f"
    done
  fi

  # ── PASSO 4: Reinicia OpenClaw ─────────────────────────────
  echo "[$(date '+%H:%M:%S')] Reiniciando OpenClaw..."
  launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" 2>&1 && \
    echo "[$(date '+%H:%M:%S')] ✓ OpenClaw reiniciado" || \
    echo "[WARN] Restart falhou"
else
  echo "[$(date '+%H:%M:%S')] Sem código novo"
fi

# ── PASSO 5: Commita e empurra shared/memory/ ──────────────────
# Mac Mini tem autoridade sobre o estado cognitivo do Alfred
if [ -d "$WS/shared/memory" ]; then
  rsync -a --exclude='.DS_Store' "$WS/shared/memory/" "$REPO/shared/memory/"
fi

MEMORY_CHANGES=$(git status --porcelain -- shared/memory/ 2>/dev/null | wc -l | tr -d ' ')

if [ "$MEMORY_CHANGES" -gt 0 ]; then
  echo "[$(date '+%H:%M:%S')] $MEMORY_CHANGES memória(s) atualizada(s)"
  git add shared/memory/
  SUMMARY=$(git diff --cached --name-only | head -3 | tr '\n' ', ' | sed 's/,$//')
  git commit -m "alfred-memory: $SUMMARY" 2>&1
  git push origin main 2>&1 && \
    echo "[$(date '+%H:%M:%S')] ✓ Memórias enviadas" || \
    echo "[WARN] Push de memórias falhou"
else
  echo "[$(date '+%H:%M:%S')] Nenhuma memória nova"
fi

# ── PASSO 6: Auto-instala crons novos do repo ──────────────────
# Qualquer script em scripts/cron-install/ é registrado automaticamente no crontab
CRON_INSTALL_DIR="$WS/scripts/cron-install"
if [ -d "$CRON_INSTALL_DIR" ]; then
  CURRENT_CRONTAB=$(crontab -l 2>/dev/null)
  CRONTAB_CHANGED=false

  for entry_file in "$CRON_INSTALL_DIR"/*.cron; do
    [ -f "$entry_file" ] || continue
    CRON_LINE=$(cat "$entry_file" | tr -d '\n')
    [ -z "$CRON_LINE" ] && continue

    # Extrai identificador único (comentário após #ID:)
    CRON_ID=$(echo "$CRON_LINE" | grep -o '#ID:[^ ]*' | head -1)
    [ -z "$CRON_ID" ] && continue

    # Só adiciona se ainda não existe
    if ! echo "$CURRENT_CRONTAB" | grep -qF "$CRON_ID"; then
      CURRENT_CRONTAB="$CURRENT_CRONTAB"$'\n'"$CRON_LINE"
      CRONTAB_CHANGED=true
      echo "[$(date '+%H:%M:%S')] ✓ Cron instalado: $CRON_ID"
    fi
  done

  if [ "$CRONTAB_CHANGED" = true ]; then
    echo "$CURRENT_CRONTAB" | crontab -
    echo "[$(date '+%H:%M:%S')] Crontab atualizado"
  fi
fi

echo "[$(date '+%H:%M:%S')] === Sync concluido ==="
