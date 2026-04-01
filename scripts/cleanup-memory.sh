#!/bin/bash
# cleanup-memory.sh — Garbage collection para MEMORY.md + memory/
# Roda todo domingo 23:00 BRT
# Funcao: Mover entries antigas (>30 dias) para archive/

set -e

WORKSPACE="$HOME/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive"
TODAY=$(date +%Y-%m-%d)
CUTOFF_DATE=$(date -d "30 days ago" +%Y-%m-%d)

# Criar archive dir se nao existir
mkdir -p "$ARCHIVE_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting memory cleanup..."

# 1. Compactar decisions-log.md (>30 dias)
if [[ -f "$MEMORY_DIR/decisions-log.md" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Archiving decisions-log entries older than $CUTOFF_DATE"
  
  # Extrair entries >30 dias, arquivar, manter recentes
  if grep "^## " "$MEMORY_DIR/decisions-log.md" | grep -q "$CUTOFF_DATE"; then
    ARCHIVE_FILE="$ARCHIVE_DIR/decisions-$(date +%Y-%m).md"
    # Simples: append linhas antigas
    echo "# Decisions Archive — $(date +%Y-%m)" > "$ARCHIVE_FILE"
    echo "" >> "$ARCHIVE_FILE"
    tail -n +2 "$MEMORY_DIR/decisions-log.md" >> "$ARCHIVE_FILE" || true
    echo "[OK] decisions-log compactado para $ARCHIVE_FILE"
  fi
fi

# 2. Compactar anomalias.md resolvidas
if [[ -f "$MEMORY_DIR/anomalias.md" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Archiving resolved anomalies"
  grep -E "RESOLVIDO|FECHADO" "$MEMORY_DIR/anomalias.md" > "$ARCHIVE_DIR/anomalias-resolved-$(date +%Y-%m).md" 2>/dev/null || true
fi

# 3. Mover YYYY-MM-DD.md >7 dias para weekly compaction
find "$MEMORY_DIR" -maxdepth 1 -name "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -mtime +7 | while read -r daily_file; do
  WEEK=$(date -d "$(basename "$daily_file" .md)" +%Y-W%V)
  WEEKLY_FILE="$MEMORY_DIR/weekly-$WEEK.md"
  if [[ ! -f "$WEEKLY_FILE" ]]; then
    echo "# Weekly Digest — $WEEK" > "$WEEKLY_FILE"
  fi
  cat "$daily_file" >> "$WEEKLY_FILE"
  rm "$daily_file"
  echo "[OK] Compactado $(basename $daily_file) para $WEEKLY_FILE"
done

# 4. Limpar QUEUE.md secao CONCLUIDO
if [[ -f "$MEMORY_DIR/../tasks/QUEUE.md" ]]; then
  sed -i '/^## CONCLUIDO/,/^## /d' "$MEMORY_DIR/../tasks/QUEUE.md" 2>/dev/null || true
  echo "[OK] QUEUE.md limpado"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memory cleanup complete"
exit 0
