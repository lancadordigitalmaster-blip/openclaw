#!/bin/bash
# ============================================================
# DIAGNÓSTICO OPENCLAW — Scan completo da infraestrutura
# Uso: bash ~/.openclaw/workspace/scripts/diagnostico-openclaw.sh
# ============================================================

echo "=========================================="
echo "  DIAGNÓSTICO OPENCLAW — $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

# ── 1. GATEWAY STATUS ──────────────────────────────────────────
echo "== 1. GATEWAY STATUS =="
echo "Porta 18789:"
curl -s -o /dev/null -w "HTTP %{http_code} — %{time_total}s\n" http://127.0.0.1:18789/ 2>/dev/null || echo "NÃO RESPONDEU"
echo ""
echo "Processo OpenClaw:"
ps aux | grep -i openclaw | grep -v grep || echo "Nenhum processo encontrado"
echo ""
echo "Processos na porta 18789:"
lsof -i :18789 2>/dev/null || echo "Nada na porta 18789"
echo ""

# ── 2. CRONS ATIVOS (crontab) ─────────────────────────────────
echo "== 2. CRONTAB DO USUARIO =="
crontab -l 2>/dev/null || echo "Nenhum crontab configurado"
echo ""

# ── 3. OPENCLAW JOBS.JSON ──────────────────────────────────────
echo "== 3. JOBS.JSON DO OPENCLAW =="
JOBS_FILE="$HOME/.openclaw/cron/jobs.json"
if [ -f "$JOBS_FILE" ]; then
  echo "Arquivo: $JOBS_FILE"
  cat "$JOBS_FILE"
else
  echo "jobs.json não encontrado em $JOBS_FILE"
fi
echo ""

# ── 4. LAUNCHAGENTS (macOS) ───────────────────────────────────
echo "== 4. LAUNCHAGENTS WOLF/OPENCLAW =="
ls -la ~/Library/LaunchAgents/ 2>/dev/null | grep -iE "wolf|openclaw|alfred|gabi|heartbeat" || echo "Nenhum LaunchAgent relacionado"
echo ""
echo "LaunchAgents carregados:"
launchctl list 2>/dev/null | grep -iE "wolf|openclaw|alfred" || echo "Nenhum carregado"
echo ""

# ── 5. ESTRUTURA DO WORKSPACE ─────────────────────────────────
echo "== 5. WORKSPACE OPENCLAW =="
WORKSPACE="$HOME/.openclaw/workspace"
if [ -d "$WORKSPACE" ]; then
  echo "Workspace: $WORKSPACE"
  echo ""
  echo "Estrutura (2 níveis):"
  find "$WORKSPACE" -maxdepth 2 -type d | sort
  echo ""
  echo "Arquivos .md na raiz do workspace:"
  ls -la "$WORKSPACE"/*.md 2>/dev/null || echo "Nenhum .md na raiz"
  echo ""
  echo "Conteúdo de SOUL.md (primeiras 30 linhas):"
  head -30 "$WORKSPACE/SOUL.md" 2>/dev/null || echo "SOUL.md não encontrado"
  echo ""
  echo "Conteúdo de AGENTS.md (primeiras 30 linhas):"
  head -30 "$WORKSPACE/AGENTS.md" 2>/dev/null || echo "AGENTS.md não encontrado"
else
  echo "Workspace não encontrado em $WORKSPACE"
fi
echo ""

# ── 6. SCRIPTS EXISTENTES ─────────────────────────────────────
echo "== 6. SCRIPTS (bash/python) =="
echo "Em workspace/scripts/:"
ls -la "$WORKSPACE/scripts/" 2>/dev/null || echo "Pasta scripts não encontrada"
echo ""
echo "Em workspace/cron/:"
ls -la "$WORKSPACE/cron/" 2>/dev/null || echo "Pasta cron não encontrada"
echo ""
echo "Scripts .sh no workspace (recursivo):"
find "$WORKSPACE" -name "*.sh" -type f 2>/dev/null | sort
echo ""
echo "Scripts .py no workspace (recursivo):"
find "$WORKSPACE" -name "*.py" -type f 2>/dev/null | sort
echo ""

# ── 7. OPENCLAW-BRAIN (pacote TypeScript) ─────────────────────
echo "== 7. OPENCLAW-BRAIN =="
if [ -d ~/openclaw-brain ]; then
  echo "ENCONTRADO em ~/openclaw-brain"
  ls -la ~/openclaw-brain/
  echo ""
  echo "package.json:"
  head -20 ~/openclaw-brain/package.json 2>/dev/null
  echo ""
  echo "Processo rodando?"
  ps aux | grep "openclaw-brain" | grep -v grep || echo "Não está rodando"
else
  echo "NÃO ENCONTRADO em ~/openclaw-brain"
fi
find ~ -maxdepth 3 -name "openclaw-brain" -type d 2>/dev/null | head -5
echo ""

# ── 8. AGENTS CONFIGURADOS ────────────────────────────────────
echo "== 8. AGENTS =="
echo "Diretórios em workspace/agents/:"
ls -la "$WORKSPACE/agents/" 2>/dev/null || echo "Pasta agents não encontrada"
echo ""
echo "Skills (diretórios em workspace/skills/):"
SKILL_COUNT=$(ls -d "$WORKSPACE/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
echo "$SKILL_COUNT diretórios de skills"
ls -d "$WORKSPACE/skills/"*/ 2>/dev/null | head -20
echo "... (primeiros 20)"
echo ""

# ── 9. MEMORY ─────────────────────────────────────────────────
echo "== 9. MEMORY =="
echo "Arquivos em memory/:"
MEMDIR="$WORKSPACE/memory"
if [ ! -d "$MEMDIR" ]; then
  MEMDIR="$WORKSPACE/shared/memory"
fi
ls -la "$MEMDIR/" 2>/dev/null || echo "Pasta memory não encontrada"
echo ""
echo "Daily notes recentes (últimos 7 dias):"
find "$MEMDIR" -name "202*.md" -mtime -7 2>/dev/null | sort
echo ""

# ── 10. LOGS RECENTES ─────────────────────────────────────────
echo "== 10. LOGS =="
LOGDIR="$HOME/.openclaw/logs"
if [ -d "$LOGDIR" ]; then
  echo "Diretório: $LOGDIR"
  echo "Arquivos de log:"
  ls -lhS "$LOGDIR/" 2>/dev/null | head -20
  echo ""
  echo "Último log modificado:"
  ls -lt "$LOGDIR/" 2>/dev/null | head -3
  echo ""
  echo "Últimas 20 linhas do log mais recente:"
  LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    echo "Arquivo: $LATEST"
    tail -20 "$LATEST"
  fi
else
  echo "Diretório de logs não encontrado em $LOGDIR"
fi
echo ""

# ── 11. OPENCLAW CONFIG ───────────────────────────────────────
echo "== 11. OPENCLAW CONFIG =="
echo "openclaw.json:"
cat ~/.openclaw/openclaw.json 2>/dev/null || echo "Não encontrado"
echo ""
echo "Versão do OpenClaw:"
openclaw --version 2>/dev/null || echo "Comando openclaw não encontrado no PATH"
npm list -g openclaw 2>/dev/null | grep openclaw || echo ""
echo ""

# ── 12. SAÚDE DO SISTEMA ──────────────────────────────────────
echo "== 12. SAÚDE GERAL =="
echo "Disco:"
df -h / 2>/dev/null
echo ""
echo "RAM:"
vm_stat 2>/dev/null | head -5 || free -h 2>/dev/null
echo ""
echo "Uptime:"
uptime
echo ""

echo "=========================================="
echo "  FIM DO DIAGNÓSTICO"
echo "=========================================="
