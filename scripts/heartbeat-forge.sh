#!/bin/bash
# heartbeat-forge.sh — Forge (Backend) heartbeat diario 04h30
# Verifica: configs validas, .env completo, JSON syntax, dependencias
# Zero LLM — registra no Mission Control

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

AGENT_ID="c106b8d2-b0a5-47e9-ab06-baf2885ef423"
AGENT="Forge"
ALFRED_ID="a1abe880-f1e3-40aa-bb62-0f748f5ac2c2"
ISSUES=()
WARNINGS=()
METRICS=""

wolf_log "$AGENT" "Iniciando heartbeat de backend"

MID=$(wolf_mission_create "Forge — Verificacao de configs e backend" "$AGENT_ID" "low")
wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, verificando configuracoes de backend." "signal"
wolf_mission_move "$MID" "assigned"
wolf_mission_move "$MID" "in_progress"

# 1. JSON files validos
JSON_ERRORS=0
for jf in "$HOME/.openclaw/cron/jobs.json" "$HOME/.openclaw/openclaw.json"; do
    if [ -f "$jf" ]; then
        if ! python3 -c "import json; json.load(open('$jf'))" 2>/dev/null; then
            ISSUES+=("JSON invalido: $(basename "$jf")")
            JSON_ERRORS=$((JSON_ERRORS + 1))
        fi
    fi
done
METRICS="JSONs verificados: $((2 - JSON_ERRORS))/2 OK"

# 2. YAML files validos
YAML_ERRORS=0
for yf in "$WOLF_WORKSPACE/shared/memory/team.yaml" "$WOLF_WORKSPACE/shared/memory/clients.yaml" "$WOLF_WORKSPACE/shared/memory/alerts.yaml"; do
    if [ -f "$yf" ]; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$yf'))" 2>/dev/null; then
            WARNINGS+=("YAML invalido: $(basename "$yf")")
            YAML_ERRORS=$((YAML_ERRORS + 1))
        fi
    fi
done
METRICS="$METRICS | YAMLs: $((3 - YAML_ERRORS))/3 OK"

# 3. .env completude (keys essenciais)
MISSING_KEYS=0
for key in TELEGRAM_BOT_TOKEN SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY GROQ_API_KEY OPENROUTER_API_KEY; do
    val=$(grep "^${key}=" "$HOME/.openclaw/.env" 2>/dev/null | cut -d= -f2)
    if [ -z "$val" ]; then
        WARNINGS+=("Key ausente no .env: $key")
        MISSING_KEYS=$((MISSING_KEYS + 1))
    fi
done
TOTAL_KEYS=$(grep -c '^[A-Z]' "$HOME/.openclaw/.env" 2>/dev/null || echo "0")
METRICS="$METRICS | .env: $TOTAL_KEYS keys ($MISSING_KEYS ausentes)"

# 4. openclaw.json config
OC_JSON="$HOME/.openclaw/openclaw.json"
if [ -f "$OC_JSON" ]; then
    MODEL=$(python3 -c "import json; d=json.load(open('$OC_JSON')); print(d.get('model','?'))" 2>/dev/null)
    METRICS="$METRICS | Modelo gateway: $MODEL"
fi

# 5. Skills com SKILL.md valido
SKILL_COUNT=$(find "$WOLF_WORKSPACE/skills" -maxdepth 2 -name "SKILL.md" -not -path "*/_archive/*" 2>/dev/null | wc -l | tr -d ' ')
METRICS="$METRICS | Skills ativas: $SKILL_COUNT"

# Resultado
DESCRIPTION="$METRICS"
[ ${#ISSUES[@]} -gt 0 ] && for i in "${ISSUES[@]}"; do DESCRIPTION="$DESCRIPTION | CRITICO: $i"; done
[ ${#WARNINGS[@]} -gt 0 ] && for w in "${WARNINGS[@]}"; do DESCRIPTION="$DESCRIPTION | AVISO: $w"; done

if [ ${#ISSUES[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "in_progress" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, backend com ${#ISSUES[@]} problema(s). Configs invalidas." "alert"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, backend OK com ${#WARNINGS[@]} aviso(s). $SKILL_COUNT skills ativas." "signal"
else
    wolf_mission_move "$MID" "done" "$DESCRIPTION"
    wolf_handoff "$AGENT_ID" "$ALFRED_ID" "Alfred, backend solido. Configs, JSONs e YAMLs todos validos." "signal"
fi

wolf_log "$AGENT" "Heartbeat concluido — $METRICS"
echo "OK: forge heartbeat — issues=${#ISSUES[@]} warnings=${#WARNINGS[@]}"
