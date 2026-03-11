#!/bin/bash
# heartbeat-craft.sh — Craft (Qualidade) heartbeat semanal (sabado 06h)
# Lifecycle real: inbox → assigned → in_progress → done/blocked
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="77c808ac-8c12-4df0-812a-0ad2e7103c6d"  # Craft UUID
AGENT="Craft"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de qualidade"

# ── ETAPA 1: Missao nasce (inbox) ──
MID=$(wolf_mission_create "Craft — Auditoria de qualidade" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando auditoria de qualidade do workspace." "signal"

# ── ETAPA 2: Craft pega a missao (assigned) ──
wolf_mission_move "$MID" "assigned"

# ── ETAPA 3: Craft comeca a auditar (in_progress) ──
wolf_mission_move "$MID" "in_progress"

# 1. Scripts sem permissao
SCRIPTS_DIR="$WOLF_WORKSPACE/scripts"
NON_EXEC=$(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" ! -perm +111 2>/dev/null | wc -l | tr -d ' ')
if [ "${NON_EXEC:-0}" -gt 0 ] 2>/dev/null; then
    WARNINGS+=("$NON_EXEC script(s) sem permissao de execucao")
    find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" ! -perm +111 -exec chmod +x {} \; 2>/dev/null
    METRICS="$METRICS | Auto-fix: chmod +x em $NON_EXEC scripts"
fi

# 2. Scripts no crontab que nao existem
MISSING_SCRIPTS=0
while IFS= read -r line; do
    script_path=$(echo "$line" | grep -oE '/[^ ]+\.sh' | head -1)
    if [ -n "$script_path" ] && [ ! -f "$script_path" ]; then
        ISSUES+=("Script no crontab nao existe: $(basename "$script_path")")
        MISSING_SCRIPTS=$((MISSING_SCRIPTS + 1))
    fi
done < <(crontab -l 2>/dev/null | grep -v '^#' | grep '\.sh')
METRICS="Scripts no crontab: $(crontab -l 2>/dev/null | grep -v '^#' | grep -c '\.sh' | tr -d ' ')"

# 3. Skills < 10 linhas
EMPTY_SKILLS=0
while IFS= read -r skill_file; do
    lines=$(wc -l < "$skill_file" 2>/dev/null | tr -d ' ')
    if [ "${lines:-0}" -lt 10 ] 2>/dev/null; then
        skill_name=$(basename "$(dirname "$skill_file")")
        WARNINGS+=("Skill '$skill_name' com apenas $lines linhas")
        EMPTY_SKILLS=$((EMPTY_SKILLS + 1))
    fi
done < <(find "$WOLF_WORKSPACE/skills" -maxdepth 2 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null)
METRICS="$METRICS | Skills < 10 linhas: $EMPTY_SKILLS"

# 4. Agents SKILL.md < 30 linhas
WEAK_AGENTS=0
while IFS= read -r agent_file; do
    lines=$(wc -l < "$agent_file" 2>/dev/null | tr -d ' ')
    if [ "${lines:-0}" -lt 30 ] 2>/dev/null; then
        agent_name=$(echo "$agent_file" | grep -oE 'agents/[^/]+' | head -1)
        WARNINGS+=("Agente '$agent_name' SKILL.md com apenas $lines linhas")
        WEAK_AGENTS=$((WEAK_AGENTS + 1))
    fi
done < <(find "$WOLF_WORKSPACE/agents" -maxdepth 3 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null)
METRICS="$METRICS | Agents < 30 linhas: $WEAK_AGENTS"

# 5. Arquivos orfaos
ORPHAN_FILES=$(find "$WOLF_WORKSPACE" -maxdepth 1 -type f \
    -not -name "*.md" -not -name "*.yaml" -not -name "*.yml" \
    -not -name "*.json" -not -name "*.html" -not -name "*.pdf" \
    -not -name "*.sh" -not -name ".gitignore" -not -name ".env*" \
    2>/dev/null | wc -l | tr -d ' ')
[ "${ORPHAN_FILES:-0}" -gt 3 ] 2>/dev/null && WARNINGS+=("$ORPHAN_FILES arquivo(s) orfao(s) na raiz")
METRICS="$METRICS | Arquivos orfaos: ${ORPHAN_FILES:-0}"

# 6. Contagem geral
TOTAL_SCRIPTS=$(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SKILLS=$(find "$WOLF_WORKSPACE/skills" -maxdepth 2 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_AGENTS=$(find "$WOLF_WORKSPACE/agents" -maxdepth 3 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null | wc -l | tr -d ' ')
METRICS="$METRICS | Total: $TOTAL_SCRIPTS scripts, $TOTAL_SKILLS skills, $TOTAL_AGENTS agents"

# ── ETAPA 4: Resultado ──
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    MSG="Craft detectou ${#ISSUES[@]} problema(s) de qualidade:"
    for i in "${ISSUES[@]}"; do MSG="$MSG
- $i"; done
    wolf_telegram "$MSG"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, qualidade: ${#ISSUES[@]} problema(s). $TOTAL_SCRIPTS scripts, $TOTAL_AGENTS agents verificados." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, qualidade OK com ${#WARNINGS[@]} aviso(s). $TOTAL_SCRIPTS scripts, $TOTAL_AGENTS agents." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, qualidade impecavel. $TOTAL_SCRIPTS scripts, $TOTAL_SKILLS skills, $TOTAL_AGENTS agents — tudo em ordem." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: craft heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
