#!/bin/bash
# heartbeat-quill.sh — Quill (Documentacao) heartbeat semanal (sexta 16h)
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="f04b67f0-6761-4cf6-a4a7-7695626a7b0d"  # Quill UUID
AGENT="Quill"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de documentacao"

# ── ETAPA 1: Missao nasce (inbox) ──
MID=$(wolf_mission_create "Quill — Auditoria de documentacao" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando auditoria de documentacao do workspace." "signal"

# ── ETAPA 2: Quill pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Quill comeca a verificar (in_progress) ──
wolf_mission_move "$MID" "in_progress"

NOW_EPOCH=$(date +%s)
TWO_WEEKS=1209600

# 1. Documentos principais
STALE_DOCS=0
MISSING_DOCS=0
TOTAL_CRITICAL=4
for doc_entry in \
    "SOUL.md:$WOLF_WORKSPACE/SOUL.md" \
    "CLAUDE.md:$WOLF_WORKSPACE/CLAUDE.md" \
    "TOOLS.md:$WOLF_WORKSPACE/TOOLS.md" \
    "ORCHESTRATOR.md:$WOLF_WORKSPACE/orchestrator/ORCHESTRATOR.md"; do

    doc_name="${doc_entry%%:*}"
    doc_path="${doc_entry#*:}"

    if [ ! -f "$doc_path" ]; then
        ISSUES+=("Documento critico ausente: $doc_name")
        MISSING_DOCS=$((MISSING_DOCS + 1))
    else
        doc_mod=$(stat -f%m "$doc_path" 2>/dev/null || echo "0")
        doc_age=$((NOW_EPOCH - doc_mod))
        if [ "$doc_age" -gt "$TWO_WEEKS" ] 2>/dev/null; then
            days_old=$((doc_age / 86400))
            WARNINGS+=("$doc_name desatualizado (${days_old} dias sem edicao)")
            STALE_DOCS=$((STALE_DOCS + 1))
        fi
    fi
done
METRICS="Docs criticos: $((TOTAL_CRITICAL - MISSING_DOCS))/$TOTAL_CRITICAL presentes | Stale: $STALE_DOCS"

# 2. SOUL.md tamanho
SOUL_FILE="$WOLF_WORKSPACE/SOUL.md"
if [ -f "$SOUL_FILE" ]; then
    SOUL_CHARS=$(wc -c < "$SOUL_FILE" | tr -d ' ')
    SOUL_LINES=$(wc -l < "$SOUL_FILE" | tr -d ' ')
    METRICS="$METRICS | SOUL.md: ${SOUL_LINES} linhas, ${SOUL_CHARS} chars"
    [ "$SOUL_CHARS" -gt 18000 ] 2>/dev/null && WARNINGS+=("SOUL.md proximo do limite: ${SOUL_CHARS}/20000 chars")
fi

# 3. Agents SKILL.md
EXPECTED_AGENTS="titan pixel forge vega shield atlas bridge craft echo flux iris ops quill turbo"
MISSING_SKILLS=""
for agent in $EXPECTED_AGENTS; do
    skill="$WOLF_WORKSPACE/agents/dev/$agent/SKILL.md"
    [ ! -f "$skill" ] && MISSING_SKILLS="$MISSING_SKILLS $agent"
done
MARKETING_AGENTS="gabi social seo strategy"
for agent in $MARKETING_AGENTS; do
    skill="$WOLF_WORKSPACE/agents/$agent/SKILL.md"
    [ ! -f "$skill" ] && MISSING_SKILLS="$MISSING_SKILLS $agent"
done
[ -n "$MISSING_SKILLS" ] && ISSUES+=("SKILL.md ausente:$MISSING_SKILLS")

# 4. CLAUDE.md consistencia
CLAUDE_FILE="$WOLF_WORKSPACE/CLAUDE.md"
if [ -f "$CLAUDE_FILE" ]; then
    grep -q "anthropic" "$CLAUDE_FILE" 2>/dev/null || WARNINGS+=("CLAUDE.md nao menciona anthropic")
    grep -q "moonshot\|xai\|minimax" "$CLAUDE_FILE" 2>/dev/null && WARNINGS+=("CLAUDE.md menciona modelos removidos")
fi

# 5. Memory files
for mem_file in decisions-log.md errors.md lessons.md; do
    [ ! -f "$WOLF_WORKSPACE/memory/$mem_file" ] && WARNINGS+=("Arquivo de memoria ausente: $mem_file")
done

# 6. Documentacao total
TOTAL_MD=$(find "$WOLF_WORKSPACE" -name "*.md" -not -path "*/_archive/*" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_LINES=$(find "$WOLF_WORKSPACE" -name "*.md" -not -path "*/_archive/*" -not -path "*/node_modules/*" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
METRICS="$METRICS | Total docs: $TOTAL_MD arquivos ($TOTAL_LINES linhas)"

# ── ETAPA 4: Resultado ──
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Quill detectou ${#ISSUES[@]} problema(s) de documentacao:"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, documentacao com ${#ISSUES[@]} problema(s). $TOTAL_MD docs no workspace." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, docs com ${#WARNINGS[@]} aviso(s). $TOTAL_MD arquivos .md no workspace." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, documentacao em dia. $TOTAL_MD docs ($TOTAL_LINES linhas) — tudo atualizado." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: quill heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
