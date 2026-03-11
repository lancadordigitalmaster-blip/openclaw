#!/bin/bash
# heartbeat-luna.sh — Luna (Social) heartbeat semanal (segunda 09h)
# Verifica: skills de social, assets, ferramentas disponiveis
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="62013484-3fae-4c0f-b767-50862aace334"
AGENT="Luna"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de social media"

MID=$(wolf_mission_create "Luna — Status de ferramentas social" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando ferramentas de social media." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Skills de social disponiveis
SOCIAL_SKILLS=0
for skill in wolf-caption-gen blogburst social-data sovereign-brand-voice-writer content-creator humanizer; do
    if [ -f "$WOLF_WORKSPACE/skills/$skill/SKILL.md" ]; then
        SOCIAL_SKILLS=$((SOCIAL_SKILLS + 1))
    fi
done
METRICS="Skills social: $SOCIAL_SKILLS/6"
[ "$SOCIAL_SKILLS" -lt 4 ] && WARNINGS+=("Apenas $SOCIAL_SKILLS/6 skills de social disponiveis")

# 2. SKILL.md da Luna
LUNA_SKILL="$WOLF_WORKSPACE/agents/social/SKILL.md"
if [ -f "$LUNA_SKILL" ]; then
    LINES=$(wc -l < "$LUNA_SKILL" | tr -d ' ')
    METRICS="$METRICS | Luna SKILL.md: $LINES linhas"
    [ "$LINES" -lt 30 ] && WARNINGS+=("SKILL.md da Luna fraco ($LINES linhas)")
else
    ISSUES+=("SKILL.md da Luna nao encontrado")
fi

# 3. Knowledge de conteudo
KB_COUNT=$(find "$WOLF_WORKSPACE/memory/content-analysis" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
KD_COUNT=$(find "$WOLF_WORKSPACE/memory/knowledge-digest" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
METRICS="$METRICS | Knowledge: $KB_COUNT analises, $KD_COUNT digests"

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, social com ${#ISSUES[@]} problema(s)." "alert"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, ferramentas social OK. $SOCIAL_SKILLS skills ativas, $KB_COUNT conteudos analisados." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: luna heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
