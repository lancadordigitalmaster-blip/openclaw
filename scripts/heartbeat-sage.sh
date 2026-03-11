#!/bin/bash
# heartbeat-sage.sh — Sage (SEO) heartbeat semanal (terca 09h)
# Verifica: skills de SEO, dados de pesquisa, ferramentas
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="ca48acd3-ad6d-45b6-88aa-5e123dae95ef"
AGENT="Sage"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de SEO"

MID=$(wolf_mission_create "Sage — Status de ferramentas SEO" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando ferramentas de SEO." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Skills de SEO
SEO_SKILLS=0
for skill in google-trends content-creator competitor-analysis-report; do
    if [ -f "$WOLF_WORKSPACE/skills/$skill/SKILL.md" ]; then
        SEO_SKILLS=$((SEO_SKILLS + 1))
    fi
done
METRICS="Skills SEO: $SEO_SKILLS/3"

# 2. Research index
RESEARCH_IDX="$WOLF_WORKSPACE/shared/memory/research/INDEX.md"
if [ -f "$RESEARCH_IDX" ]; then
    RES_LINES=$(wc -l < "$RESEARCH_IDX" | tr -d ' ')
    METRICS="$METRICS | Research INDEX: $RES_LINES linhas"
else
    WARNINGS+=("Research INDEX.md nao encontrado")
fi

# 3. SKILL.md do Sage
SAGE_SKILL="$WOLF_WORKSPACE/agents/seo/SKILL.md"
if [ -f "$SAGE_SKILL" ]; then
    LINES=$(wc -l < "$SAGE_SKILL" | tr -d ' ')
    METRICS="$METRICS | Sage SKILL.md: $LINES linhas"
else
    ISSUES+=("SKILL.md do Sage nao encontrado")
fi

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

wolf_mission_move "$MID" "done" "$DESCRIPTION"
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, SEO verificado. $SEO_SKILLS skills ativas." "signal"

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: sage heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
