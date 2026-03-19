#!/bin/bash
# memory-hygiene.sh — Garbage collection da memória do Alfred
# Roda: domingo 23h (crontab, sem LLM)
# Função: compacta, deduplica, arquiva. Zero custo.

set -euo pipefail

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
MEMORY="$WORKSPACE/memory"
ARCHIVE="$MEMORY/archive"
WEEKLY="$MEMORY/weekly"
LOG="$MEMORY/logs/memory-hygiene.log"
TODAY=$(date +%Y-%m-%d)
WEEK_NUM=$(date +%V)
YEAR=$(date +%Y)

mkdir -p "$ARCHIVE" "$WEEKLY"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"; }
log "=== Memory Hygiene iniciado ==="

# ─── 1. COMPACTAR NOTAS DIÁRIAS >7 DIAS ────────────────────────
WEEKLY_FILE="$WEEKLY/W${WEEK_NUM}-${YEAR}.md"
COMPACTED=0

for NOTE in "$MEMORY"/2026-*.md; do
  [ -f "$NOTE" ] || continue
  BASENAME=$(basename "$NOTE" .md)
  NOTE_DATE="$BASENAME"

  # Calcular idade em dias
  if [[ "$OSTYPE" == "darwin"* ]]; then
    NOTE_EPOCH=$(date -j -f "%Y-%m-%d" "$NOTE_DATE" "+%s" 2>/dev/null || continue)
    NOW_EPOCH=$(date "+%s")
  else
    NOTE_EPOCH=$(date -d "$NOTE_DATE" "+%s" 2>/dev/null || continue)
    NOW_EPOCH=$(date "+%s")
  fi

  AGE_DAYS=$(( (NOW_EPOCH - NOTE_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -gt 7 ]; then
    SIZE=$(wc -c < "$NOTE" | tr -d ' ')
    # Só compacta se tem conteúdo real (>150 bytes = mais que template)
    if [ "$SIZE" -gt 150 ]; then
      echo "" >> "$WEEKLY_FILE"
      echo "## $NOTE_DATE" >> "$WEEKLY_FILE"
      # Extrair conteúdo sem header
      tail -n +3 "$NOTE" >> "$WEEKLY_FILE"
      log "Compactado: $NOTE_DATE ($SIZE bytes) → W${WEEK_NUM}"
    fi
    mv "$NOTE" "$ARCHIVE/${BASENAME}.md"
    COMPACTED=$((COMPACTED + 1))
  fi
done

log "Notas compactadas: $COMPACTED"

# ─── 2. DEDUPLICA ERRORS.MD ────────────────────────────────────
ERRORS="$MEMORY/errors.md"
if [ -f "$ERRORS" ]; then
  BEFORE=$(wc -l < "$ERRORS" | tr -d ' ')

  # Manter header (linhas 1-5) + deduplicar entradas
  HEAD_LINES=5
  head -n $HEAD_LINES "$ERRORS" > "${ERRORS}.tmp"

  # Extrair entradas únicas (baseado nos primeiros 80 chars de cada linha ## )
  tail -n +$((HEAD_LINES + 1)) "$ERRORS" | awk '
    /^## / {
      key = substr($0, 1, 80)
      if (seen[key]++) {
        count[key]++
        next
      }
    }
    { print }
    END {
      for (k in count) {
        if (count[k] > 0)
          print "## [DEDUP] " count[k] " entradas repetidas removidas para: " k
      }
    }
  ' >> "${ERRORS}.tmp"

  mv "${ERRORS}.tmp" "$ERRORS"
  AFTER=$(wc -l < "$ERRORS" | tr -d ' ')
  log "errors.md: $BEFORE → $AFTER linhas"
fi

# ─── 3. LIMPA DONE.MD (remove duplicatas) ──────────────────────
DONE="$MEMORY/DONE.md"
if [ -f "$DONE" ]; then
  BEFORE=$(wc -l < "$DONE" | tr -d ' ')

  # Remove linhas duplicadas consecutivas, mantém estrutura
  awk '!seen[$0]++ || /^##/ || /^$/' "$DONE" > "${DONE}.tmp"
  mv "${DONE}.tmp" "$DONE"

  AFTER=$(wc -l < "$DONE" | tr -d ' ')
  REMOVED=$((BEFORE - AFTER))
  [ "$REMOVED" -gt 0 ] && log "DONE.md: removidas $REMOVED linhas duplicadas"
fi

# ─── 4. ARQUIVA DECISIONS >30 DIAS ─────────────────────────────
DECISIONS="$MEMORY/decisions-log.md"
if [ -f "$DECISIONS" ]; then
  SIZE=$(wc -l < "$DECISIONS" | tr -d ' ')
  if [ "$SIZE" -gt 100 ]; then
    MONTH=$(date +%Y-%m)
    cp "$DECISIONS" "$ARCHIVE/decisions-${MONTH}.md"
    # Manter apenas últimas 50 linhas + header
    head -n 4 "$DECISIONS" > "${DECISIONS}.tmp"
    tail -n 50 "$DECISIONS" >> "${DECISIONS}.tmp"
    mv "${DECISIONS}.tmp" "$DECISIONS"
    log "decisions-log.md: arquivado e truncado (mantidas últimas 50 linhas)"
  fi
fi

# ─── 5. LIMPA LOGS >7 DIAS ─────────────────────────────────────
# (já feito pelo overnight_work.sh, mas garante)
LOGS_CLEANED=0
for LOGFILE in "$MEMORY"/logs/*.log; do
  [ -f "$LOGFILE" ] || continue
  LOGNAME=$(basename "$LOGFILE")
  # Não limpar archive
  [ "$LOGNAME" = "archive" ] && continue

  if [[ "$OSTYPE" == "darwin"* ]]; then
    MOD_EPOCH=$(stat -f %m "$LOGFILE")
  else
    MOD_EPOCH=$(stat -c %Y "$LOGFILE")
  fi
  NOW_EPOCH=$(date "+%s")
  AGE_DAYS=$(( (NOW_EPOCH - MOD_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -gt 14 ]; then
    mv "$LOGFILE" "$MEMORY/logs/archive/"
    LOGS_CLEANED=$((LOGS_CLEANED + 1))
  fi
done
[ "$LOGS_CLEANED" -gt 0 ] && log "Logs arquivados: $LOGS_CLEANED"

# ─── 6. LIMPA QUEUE.MD CONCLUÍDO ───────────────────────────────
QUEUE="$WORKSPACE/tasks/QUEUE.md"
if [ -f "$QUEUE" ]; then
  # Remove seção CONCLUÍDO (tudo após "## CONCLUÍDO" ou "## Concluído")
  sed -i.bak '/^## [Cc][Oo][Nn][Cc][Ll][Uu]/,$ { /^## [Cc][Oo][Nn][Cc][Ll][Uu]/!d; }' "$QUEUE" 2>/dev/null
  rm -f "${QUEUE}.bak"
fi

# ─── 7. STALENESS DEMOTION — entradas sem referência >60 dias ──
# Move entradas stale de lessons.md e patterns.md para archive/
# Se padrão reaparecer, Kaizen re-promove automaticamente
DEMOTED=0

demote_stale_entries() {
  local FILE="$1"
  local BASENAME=$(basename "$FILE" .md)
  local ARCHIVE_FILE="$ARCHIVE/${BASENAME}-demoted.md"
  local TEMP_KEEP=$(mktemp /tmp/hygiene-keep-XXXXXX)
  local TEMP_DEMOTE=$(mktemp /tmp/hygiene-demote-XXXXXX)
  local NOW_EPOCH=$(date "+%s")
  local THRESHOLD_DAYS=60
  local IN_ENTRY=0
  local ENTRY_BUF=""
  local ENTRY_REF=""
  local HEADER_DONE=0

  while IFS= read -r line; do
    # Detect entry start (### header)
    if echo "$line" | grep -qE '^### '; then
      # Flush previous entry
      if [ "$IN_ENTRY" -eq 1 ] && [ -n "$ENTRY_BUF" ]; then
        _flush_entry "$ENTRY_REF" "$ENTRY_BUF" "$TEMP_KEEP" "$TEMP_DEMOTE" "$NOW_EPOCH" "$THRESHOLD_DAYS"
      fi
      IN_ENTRY=1
      ENTRY_BUF="$line"
      ENTRY_REF=""
    elif [ "$IN_ENTRY" -eq 1 ]; then
      ENTRY_BUF="$ENTRY_BUF
$line"
      # Extract ultima referencia date
      if echo "$line" | grep -qi 'ultima referencia:'; then
        ENTRY_REF=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
      fi
    else
      # Header lines before first entry
      echo "$line" >> "$TEMP_KEEP"
    fi
  done < "$FILE"

  # Flush last entry
  if [ "$IN_ENTRY" -eq 1 ] && [ -n "$ENTRY_BUF" ]; then
    _flush_entry "$ENTRY_REF" "$ENTRY_BUF" "$TEMP_KEEP" "$TEMP_DEMOTE" "$NOW_EPOCH" "$THRESHOLD_DAYS"
  fi

  # Apply changes only if we demoted something
  if [ -s "$TEMP_DEMOTE" ]; then
    local DEMOTED_COUNT=$(grep -c '^### ' "$TEMP_DEMOTE" || echo 0)
    DEMOTED=$((DEMOTED + DEMOTED_COUNT))

    # Append demoted entries to archive
    echo "" >> "$ARCHIVE_FILE"
    echo "## Demoted $(date '+%Y-%m-%d') — $DEMOTED_COUNT entradas stale (>$THRESHOLD_DAYS dias)" >> "$ARCHIVE_FILE"
    cat "$TEMP_DEMOTE" >> "$ARCHIVE_FILE"

    # Replace original with kept entries
    mv "$TEMP_KEEP" "$FILE"
    log "$BASENAME: $DEMOTED_COUNT entradas demovidas para archive (>$THRESHOLD_DAYS dias sem referencia)"
  fi

  rm -f "$TEMP_KEEP" "$TEMP_DEMOTE"
}

_flush_entry() {
  local REF_DATE="$1"
  local BUF="$2"
  local KEEP="$3"
  local DEMOTE="$4"
  local NOW_EPOCH="$5"
  local THRESHOLD="$6"

  if [ -z "$REF_DATE" ]; then
    # No reference date = keep (conservative)
    echo "$BUF" >> "$KEEP"
    return
  fi

  local REF_EPOCH
  if [[ "$OSTYPE" == "darwin"* ]]; then
    REF_EPOCH=$(date -j -f "%Y-%m-%d" "$REF_DATE" "+%s" 2>/dev/null || echo 0)
  else
    REF_EPOCH=$(date -d "$REF_DATE" "+%s" 2>/dev/null || echo 0)
  fi

  local AGE_DAYS=$(( (NOW_EPOCH - REF_EPOCH) / 86400 ))

  if [ "$AGE_DAYS" -gt "$THRESHOLD" ]; then
    echo "$BUF" >> "$DEMOTE"
  else
    echo "$BUF" >> "$KEEP"
  fi
}

# Apply to lessons and patterns
demote_stale_entries "$MEMORY/lessons.md"
demote_stale_entries "$MEMORY/patterns.md"

[ "$DEMOTED" -gt 0 ] && log "Total entradas demovidas: $DEMOTED"

# ─── 8. MOVER ARQUIVOS GRANDES PARA ARCHIVE ─────────────────────
# Imagens e arquivos >100KB não pertencem ao diretório de memória ativa
LARGE_MOVED=0
for BIGFILE in $(find "$MEMORY" -maxdepth 2 \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.gif" \) -size +50k 2>/dev/null); do
    DEST="$ARCHIVE/media/$(basename "$BIGFILE")"
    mkdir -p "$ARCHIVE/media"
    mv "$BIGFILE" "$DEST" 2>/dev/null && LARGE_MOVED=$((LARGE_MOVED + 1))
done

# Transcripts e arquivos texto >100KB
for BIGTEXT in $(find "$MEMORY" -maxdepth 1 -name "transcript_*" -o -name "*.txt" | while read f; do [ "$(wc -c < "$f" 2>/dev/null | tr -d ' ')" -gt 102400 ] && echo "$f"; done 2>/dev/null); do
    mv "$BIGTEXT" "$ARCHIVE/" 2>/dev/null && LARGE_MOVED=$((LARGE_MOVED + 1))
done

[ "$LARGE_MOVED" -gt 0 ] && log "Arquivos grandes movidos para archive: $LARGE_MOVED"

# ─── 9. LIMPAR REPORTS >30 DIAS ─────────────────────────────────
REPORTS_CLEANED=0
if [ -d "$MEMORY/reports" ]; then
    for REPORT in "$MEMORY"/reports/*.txt; do
        [ -f "$REPORT" ] || continue
        if [[ "$OSTYPE" == "darwin"* ]]; then
            MOD_EPOCH=$(stat -f %m "$REPORT")
        else
            MOD_EPOCH=$(stat -c %Y "$REPORT")
        fi
        AGE_DAYS=$(( ($(date "+%s") - MOD_EPOCH) / 86400 ))
        if [ "$AGE_DAYS" -gt 30 ]; then
            rm -f "$REPORT"
            REPORTS_CLEANED=$((REPORTS_CLEANED + 1))
        fi
    done
fi
[ "$REPORTS_CLEANED" -gt 0 ] && log "Reports antigos removidos: $REPORTS_CLEANED"

# ─── RESUMO ─────────────────────────────────────────────────────
log "=== Memory Hygiene concluído ==="
log "Notas compactadas: $COMPACTED | Logs arquivados: $LOGS_CLEANED | Demovidos: $DEMOTED | Grandes: $LARGE_MOVED | Reports: $REPORTS_CLEANED"
