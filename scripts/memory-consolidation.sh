#!/bin/bash
# memory-consolidation.sh — Consolidacao semanal de memoria
# Roda todo domingo 23h — resume semana, extrai padroes, limpa acumulo
# Crontab: 0 23 * * 0 bash ~/.openclaw/workspace/scripts/memory-consolidation.sh

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
MEMORY="$WORKSPACE/memory"
WEEKLY="$MEMORY/weekly"
WEEK_NUM=$(date '+%V')
YEAR=$(date '+%Y')
TODAY=$(date '+%Y-%m-%d')
LOG="$MEMORY/logs/memory-consolidation.log"

mkdir -p "$WEEKLY" "$(dirname "$LOG")"

wolf_log "consolidation" "Iniciando consolidacao semanal W${WEEK_NUM}"

# ── 1. Coletar daily logs da semana ──
DAILY_FILES=""
DAILY_COUNT=0
for i in $(seq 0 6); do
    DAY=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "-${i} days" '+%Y-%m-%d')
    FILE="$MEMORY/${DAY}.md"
    if [ -f "$FILE" ]; then
        DAILY_FILES="$DAILY_FILES $FILE"
        DAILY_COUNT=$((DAILY_COUNT + 1))
    fi
done

# ── 2. Gerar resumo semanal ──
TMP_DIGEST=$(mktemp /tmp/wolf-digest-XXXXXX.py)

cat > "$TMP_DIGEST" << 'PYEOF'
import os, sys, json, glob
from datetime import datetime, timedelta
from collections import Counter

memory = os.path.expanduser("~/.openclaw/workspace/memory")
week_num = sys.argv[1]
year = sys.argv[2]
today = sys.argv[3]

# Read daily files from this week
daily_content = []
now = datetime.now()
for i in range(7):
    day = (now - timedelta(days=i)).strftime("%Y-%m-%d")
    path = os.path.join(memory, f"{day}.md")
    if os.path.exists(path):
        with open(path) as f:
            content = f.read()
            daily_content.append({"date": day, "content": content, "lines": len(content.splitlines())})

# Count sessions from this week
sessions_dir = os.path.expanduser("~/.openclaw/agents/main/sessions/")
session_count = 0
for f in glob.glob(sessions_dir + "*.jsonl"):
    try:
        mtime = os.path.getmtime(f)
        if (now.timestamp() - mtime) < 7 * 86400:
            session_count += 1
    except:
        pass

# Read errors and lessons
errors_count = 0
errors_file = os.path.join(memory, "errors.md")
if os.path.exists(errors_file):
    with open(errors_file) as f:
        errors_count = f.read().count("###")

lessons_count = 0
lessons_file = os.path.join(memory, "lessons.md")
if os.path.exists(lessons_file):
    with open(lessons_file) as f:
        lessons_count = f.read().count("###")

# Read alerts log
alerts_count = 0
alerts_file = os.path.join(memory, "gabi", "alerts-log.md")
if os.path.exists(alerts_file):
    with open(alerts_file) as f:
        for line in f:
            if line.startswith("|") and today[:7] in line:
                alerts_count += 1

# Read reports
report_files = glob.glob(os.path.join(memory, "reports", f"*{today[:7]}*.txt"))
reports_count = len(report_files)

# Generate digest
digest = f"""# Digest Semanal — Semana {week_num}/{year}
> Gerado automaticamente em {today}

## Resumo
- Daily logs da semana: {len(daily_content)}
- Sessoes ativas: {session_count}
- Erros registrados: {errors_count}
- Licoes totais: {lessons_count}
- Alertas disparados: {alerts_count}
- Reports gerados: {reports_count}

## Atividade por Dia
"""
for d in sorted(daily_content, key=lambda x: x["date"]):
    digest += f"- {d['date']}: {d['lines']} linhas\n"

digest += """
## Destaque da Semana
[Revisar manualmente — qual foi a atividade mais impactante?]

## Proxima Semana
[O que precisa de atencao? Tokens expirando? Clientes pendentes?]
"""

print(digest)
PYEOF

DIGEST=$(python3 "$TMP_DIGEST" "$WEEK_NUM" "$YEAR" "$TODAY" 2>&1)
rm -f "$TMP_DIGEST"

# Salvar digest
DIGEST_FILE="$WEEKLY/${YEAR}-W${WEEK_NUM}-digest.md"
echo "$DIGEST" > "$DIGEST_FILE"

wolf_log "consolidation" "Digest salvo em $DIGEST_FILE"

# ── 3. Arquivar sessions antigas (>30 dias) ──
SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
ARCHIVE_DIR="$SESSIONS_DIR/_archive"
mkdir -p "$ARCHIVE_DIR"

ARCHIVED=0
if [ -d "$SESSIONS_DIR" ]; then
    while IFS= read -r -d '' f; do
        mv "$f" "$ARCHIVE_DIR/" 2>/dev/null && ARCHIVED=$((ARCHIVED + 1))
    done < <(find "$SESSIONS_DIR" -maxdepth 1 -name "*.jsonl" -mtime +30 -print0 2>/dev/null)
fi

wolf_log "consolidation" "Sessions arquivadas: $ARCHIVED"

# ── 4. Enviar resumo ──
SUMMARY="📚 Consolidacao Semanal W${WEEK_NUM}

Daily logs: ${DAILY_COUNT}
Sessions arquivadas: ${ARCHIVED}
Digest salvo em: weekly/${YEAR}-W${WEEK_NUM}-digest.md"

wolf_notify_info "$SUMMARY"

wolf_log "consolidation" "Consolidacao concluida — ${DAILY_COUNT} dailies, ${ARCHIVED} sessions arquivadas"
echo "OK: memory-consolidation W${WEEK_NUM} completed at $(date '+%Y-%m-%d %H:%M:%S')"
