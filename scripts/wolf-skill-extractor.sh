#!/bin/bash
# wolf-skill-extractor.sh — Detecta licoes recorrentes e propoe extracao de skills
# Roda junto com o Kaizen (sexta 18h) ou sob demanda
# Crontab: 15 18 * * 5 bash ~/.openclaw/workspace/scripts/wolf-skill-extractor.sh

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
LESSONS="$WORKSPACE/memory/lessons.md"
CORRECTIONS="$WORKSPACE/memory/corrections.md"
PATTERNS="$WORKSPACE/memory/patterns.md"
PROPOSALS_LOG="$WORKSPACE/memory/upgrades/skill-proposals.md"

mkdir -p "$(dirname "$PROPOSALS_LOG")"

wolf_log "skill-extractor" "Analisando licoes para extracao de skills"

# Initialize proposals log if needed
if [ ! -f "$PROPOSALS_LOG" ]; then
    cat > "$PROPOSALS_LOG" << 'HEADER'
# Propostas de Extracao de Skills
> Gerado automaticamente pelo wolf-skill-extractor.sh
> Licoes recorrentes que podem virar scripts/skills reutilizaveis

| Data | Licao | Recorrencia | Proposta | Status |
|------|-------|-------------|----------|--------|
HEADER
fi

TMP_PY=$(mktemp /tmp/wolf-extract-XXXXXX.py)

cat > "$TMP_PY" << 'PYEOF'
import os, sys, re, json
from collections import Counter, defaultdict
from datetime import datetime

workspace = os.path.expanduser("~/.openclaw/workspace")

# Read lessons
lessons = []
lessons_file = os.path.join(workspace, "memory/lessons.md")
if os.path.exists(lessons_file):
    with open(lessons_file) as f:
        content = f.read()
    # Parse entries by ### headers
    current = None
    for line in content.splitlines():
        if line.startswith("### "):
            if current:
                lessons.append(current)
            # Extract category
            title = line[4:].strip()
            cat_match = re.match(r'\[(\w+)\]', title)
            category = cat_match.group(1) if cat_match else "GERAL"
            current = {"title": title, "category": category, "lines": [], "has_fix": False}
        elif current:
            current["lines"].append(line)
            if "fix" in line.lower() or "corri" in line.lower() or "soluc" in line.lower() or "acao tomada" in line.lower():
                current["has_fix"] = True
    if current:
        lessons.append(current)

# Read corrections
corrections = []
corrections_file = os.path.join(workspace, "memory/corrections.md")
if os.path.exists(corrections_file):
    with open(corrections_file) as f:
        content = f.read()
    current = None
    for line in content.splitlines():
        if line.startswith("### COR-"):
            if current:
                corrections.append(current)
            current = {"title": line[4:].strip(), "lines": [], "recurrence": 0}
        elif current:
            current["lines"].append(line)
            rec_match = re.match(r'.*Recorrencia:\*\*\s*(\d+)', line)
            if rec_match:
                current["recurrence"] = int(rec_match.group(1))
    if current:
        corrections.append(current)

# Read patterns
patterns = []
patterns_file = os.path.join(workspace, "memory/patterns.md")
if os.path.exists(patterns_file):
    with open(patterns_file) as f:
        content = f.read()
    current = None
    for line in content.splitlines():
        if line.startswith("### "):
            if current:
                patterns.append(current)
            current = {"title": line[4:].strip(), "lines": [], "occurrences": 0}
        elif current:
            current["lines"].append(line)
            occ_match = re.match(r'.*Ocorr.ncias:\*\*\s*(\d+)', line)
            if occ_match:
                current["occurrences"] = int(occ_match.group(1))
    if current:
        patterns.append(current)

# Detect candidates for skill extraction
proposals = []

# 1. Lessons with same category appearing 2+ times
category_count = Counter(l["category"] for l in lessons)
for cat, count in category_count.items():
    if count >= 2:
        cat_lessons = [l for l in lessons if l["category"] == cat and l["has_fix"]]
        if len(cat_lessons) >= 2:
            titles = [l["title"] for l in cat_lessons[:3]]
            proposals.append({
                "source": "lessons",
                "category": cat,
                "count": count,
                "titles": titles,
                "suggestion": f"Consolidar {count} licoes [{cat}] em checklist/script de prevencao"
            })

# 2. Corrections with recurrence >= 2
for c in corrections:
    if c["recurrence"] >= 2:
        proposals.append({
            "source": "corrections",
            "category": "CORRECAO",
            "count": c["recurrence"],
            "titles": [c["title"]],
            "suggestion": f"Correcao recorrente ({c['recurrence']}x) — automatizar validacao"
        })

# 3. Patterns with 2+ occurrences that have known solutions
for p in patterns:
    body = "\n".join(p["lines"])
    if p["occurrences"] >= 2 and ("solucao" in body.lower() or "resolvido" in body.lower()):
        proposals.append({
            "source": "patterns",
            "category": "PADRAO",
            "count": p["occurrences"],
            "titles": [p["title"]],
            "suggestion": f"Padrao recorrente ({p['occurrences']}x) com solucao conhecida — criar script de deteccao automatica"
        })

# Output
if proposals:
    print("HAS_PROPOSALS=true")
    msg = "🧠 Skill Extraction — " + str(len(proposals)) + " proposta(s)\n"
    for i, p in enumerate(proposals, 1):
        msg += f"\n{i}. [{p['category']}] {p['suggestion']}"
        msg += f"\n   Fonte: {', '.join(p['titles'][:2])}"
        msg += f"\n   Recorrencia: {p['count']}x"
    print(f"MSG={msg}")

    # Log proposals
    today = datetime.now().strftime("%Y-%m-%d")
    log_lines = []
    for p in proposals:
        title = p["titles"][0][:40]
        log_lines.append(f"| {today} | {title} | {p['count']}x | {p['suggestion'][:50]} | Pendente |")
    print(f"LOG={'|'.join(log_lines)}")
else:
    print("HAS_PROPOSALS=false")
    print("MSG=Nenhuma licao com recorrencia suficiente para extracao")
PYEOF

RESULT=$(python3 "$TMP_PY" 2>&1)
rm -f "$TMP_PY"

HAS=$(echo "$RESULT" | grep "^HAS_PROPOSALS=" | cut -d= -f2)
MSG=$(echo "$RESULT" | grep "^MSG=" | cut -d= -f2-)

if [ "$HAS" = "true" ]; then
    wolf_notify_info "$MSG"

    # Append to proposals log
    LOG_DATA=$(echo "$RESULT" | grep "^LOG=" | cut -d= -f2-)
    echo "$LOG_DATA" | tr '|' '\n' | grep -v "^$" | while read -r line; do
        echo "$line" >> "$PROPOSALS_LOG"
    done

    wolf_log "skill-extractor" "Enviou propostas de extracao"
else
    wolf_log "skill-extractor" "Nenhuma proposta — licoes sem recorrencia suficiente"
fi

echo "OK: wolf-skill-extractor completed at $(date '+%Y-%m-%d %H:%M:%S')"
