#!/bin/bash
# heartbeat-titan.sh — Titan (Dev Lead) heartbeat diario 07h
# Verifica: estrutura do codigo, CLAUDE.md sync, git status, scripts com erro de sintaxe
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="10c5e66f-d2c2-4bef-a3ff-c604c1070882"
AGENT="Titan"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de lideranca dev"

MID=$(wolf_mission_create "Titan — Revisao de codigo e estrutura" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, iniciando revisao da estrutura de codigo." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. Scripts com erro de sintaxe
SYNTAX_ERRORS=0
for script in "$WOLF_WORKSPACE"/scripts/*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        ISSUES+=("Erro de sintaxe: $(basename "$script")")
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done
TOTAL_SCRIPTS=$(find "$WOLF_WORKSPACE/scripts" -maxdepth 1 -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
METRICS="Scripts: $TOTAL_SCRIPTS total, $SYNTAX_ERRORS com erro"

# 2. Git status (arquivos nao rastreados)
cd "$WOLF_WORKSPACE"
UNTRACKED=$(git status --porcelain 2>/dev/null | grep -c '^??' || echo "0")
MODIFIED=$(git status --porcelain 2>/dev/null | grep -c '^ M\|^M ' || echo "0")
METRICS="$METRICS | Git: $UNTRACKED untracked, $MODIFIED modified"
[ "$UNTRACKED" -gt 50 ] && WARNINGS+=("$UNTRACKED arquivos untracked no git")

# 3. CLAUDE.md existe e tem conteudo
CLAUDE="$WOLF_WORKSPACE/CLAUDE.md"
if [ -f "$CLAUDE" ]; then
    CL_LINES=$(wc -l < "$CLAUDE" | tr -d ' ')
    METRICS="$METRICS | CLAUDE.md: $CL_LINES linhas"
    [ "$CL_LINES" -lt 20 ] && WARNINGS+=("CLAUDE.md muito curto ($CL_LINES linhas)")
else
    ISSUES+=("CLAUDE.md ausente")
fi

# 4. SOUL.md dentro do limite
SOUL="$WOLF_WORKSPACE/SOUL.md"
if [ -f "$SOUL" ]; then
    SOUL_CHARS=$(wc -c < "$SOUL" | tr -d ' ')
    METRICS="$METRICS | SOUL.md: $SOUL_CHARS chars"
    [ "$SOUL_CHARS" -gt 18000 ] && WARNINGS+=("SOUL.md proximo do limite: $SOUL_CHARS/20000")
fi

# 5. Agents SKILL.md — quantos tem conteudo real (>50 linhas)
STRONG=0
WEAK=0
while IFS= read -r f; do
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    if [ "${lines:-0}" -ge 50 ]; then STRONG=$((STRONG + 1))
    else WEAK=$((WEAK + 1)); fi
done < <(find "$WOLF_WORKSPACE/agents" -maxdepth 3 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null)
METRICS="$METRICS | Agents: $STRONG fortes, $WEAK fracos"
[ "$WEAK" -gt 5 ] && WARNINGS+=("$WEAK agents com SKILL.md fraco (<50 linhas)")

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, encontrei ${#ISSUES[@]} problema(s) de codigo. Intervencao necessaria." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, codigo revisado — ${#WARNINGS[@]} ponto(s) de atencao. $TOTAL_SCRIPTS scripts OK." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, estrutura de codigo limpa. $TOTAL_SCRIPTS scripts, $STRONG agents fortes." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: titan heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
