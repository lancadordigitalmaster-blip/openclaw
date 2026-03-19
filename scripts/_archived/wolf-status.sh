#!/bin/bash
# wolf-status.sh — CLI unificada para consultar estado do sistema Wolf
# Uso: bash wolf-status.sh [comando]
# Comandos: clients | agents | crons | infra | memory | all | validate
#
# Exemplos:
#   bash wolf-status.sh clients      → lista clientes com status
#   bash wolf-status.sh agents       → lista agentes com ultimo heartbeat
#   bash wolf-status.sh crons        → lista crons com status
#   bash wolf-status.sh infra        → gateway, bridge, disco, sessions
#   bash wolf-status.sh memory       → tamanho memoria, lessons, errors
#   bash wolf-status.sh validate     → valida integridade dos dados
#   bash wolf-status.sh all          → tudo junto
#   bash wolf-status.sh              → resumo rapido

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
ENV_FILE="$HOME/.openclaw/.env"
CMD="${1:-summary}"

set -a; source "$ENV_FILE" 2>/dev/null; set +a

# ── Cores ──
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${RESET}"; }
ok() { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }

# ═══════════════════════════════════════════════════════════════
# CLIENTS
# ═══════════════════════════════════════════════════════════════
status_clients() {
    header "CLIENTES"
    local CLIENTS_FILE="$WORKSPACE/shared/memory/clients.yaml"
    if [ ! -f "$CLIENTS_FILE" ]; then
        warn "clients.yaml nao encontrado"
        return
    fi
    local COUNT=0
    local CURRENT_SLUG=""
    local CURRENT_NOME=""
    local CURRENT_STATUS=""
    local CURRENT_SEG=""
    while IFS= read -r line; do
        # Detect client slug (top-level key under clientes)
        if echo "$line" | grep -qE '^  [a-z].*:$'; then
            # Print previous client
            if [ -n "$CURRENT_SLUG" ]; then
                local ICON="⚪"
                [ "$CURRENT_STATUS" = "ativo" ] && ICON="🟢"
                [ "$CURRENT_STATUS" = "pausado" ] && ICON="🟡"
                echo "  $ICON ${CURRENT_NOME:-$CURRENT_SLUG} ($CURRENT_SLUG) — ${CURRENT_SEG:-?}"
                COUNT=$((COUNT + 1))
            fi
            CURRENT_SLUG=$(echo "$line" | sed 's/^ *//;s/:$//')
            CURRENT_NOME="" ; CURRENT_STATUS="" ; CURRENT_SEG=""
        fi
        echo "$line" | grep -q '^\s*nome:' && CURRENT_NOME=$(echo "$line" | sed 's/.*nome: *//' | tr -d '"')
        echo "$line" | grep -q '^\s*status:' && CURRENT_STATUS=$(echo "$line" | sed 's/.*status: *//' | tr -d '"')
        echo "$line" | grep -q '^\s*segmento:' && CURRENT_SEG=$(echo "$line" | sed 's/.*segmento: *//' | tr -d '"')
    done < "$CLIENTS_FILE"
    # Last client
    if [ -n "$CURRENT_SLUG" ]; then
        local ICON="⚪"
        [ "$CURRENT_STATUS" = "ativo" ] && ICON="🟢"
        [ "$CURRENT_STATUS" = "pausado" ] && ICON="🟡"
        echo "  $ICON ${CURRENT_NOME:-$CURRENT_SLUG} ($CURRENT_SLUG) — ${CURRENT_SEG:-?}"
        COUNT=$((COUNT + 1))
    fi
    echo -e "\n  Total: $COUNT clientes"
}

# ═══════════════════════════════════════════════════════════════
# AGENTS
# ═══════════════════════════════════════════════════════════════
status_agents() {
    header "AGENTES"

    # Marketing squad
    echo -e "  ${BOLD}Marketing Squad${RESET}"
    for agent in gabi social seo strategy cfo-wolf natiely video-editor-pro; do
        SKILL="$WORKSPACE/agents/$agent/SKILL.md"
        if [ -f "$SKILL" ]; then
            ok "$agent (SKILL.md ✓)"
        else
            warn "$agent (sem SKILL.md)"
        fi
    done

    # Dev squad with heartbeat status
    echo -e "\n  ${BOLD}Dev Squad (heartbeats)${RESET}"
    for agent in shield bridge flux turbo craft quill ops atlas forge echo titan iris vega pixel; do
        HB_LOG="$WORKSPACE/memory/logs/heartbeat-${agent}.log"
        if [ -f "$HB_LOG" ] && [ -s "$HB_LOG" ]; then
            LAST=$(tail -1 "$HB_LOG" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)
            [ -n "$LAST" ] && ok "$agent (ultimo: $LAST)" || ok "$agent (log existe)"
        elif [ -f "$HB_LOG" ]; then
            warn "$agent (log vazio)"
        else
            warn "$agent (sem log de heartbeat)"
        fi
    done

    # Count
    MARKETING=$(find "$WORKSPACE/agents" -maxdepth 1 -name "*.md" -path "*/SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "\n  Total: 8 marketing + 14 dev = 22 agentes ativos"
}

# ═══════════════════════════════════════════════════════════════
# CRONS
# ═══════════════════════════════════════════════════════════════
status_crons() {
    header "CRONS"

    echo -e "  ${BOLD}LLM Crons (jobs.json)${RESET}"
    python3 << 'PYEOF'
import json, os
f = os.path.expanduser("~/.openclaw/cron/jobs.json")
if os.path.exists(f):
    data = json.load(open(f))
    enabled = [j for j in data.get("jobs", []) if j.get("enabled", True)]
    disabled = [j for j in data.get("jobs", []) if not j.get("enabled", True)]
    for j in enabled:
        name = j.get("name", "?")
        sched = j.get("schedule", {}).get("expr", "?")
        last = j.get("state", {}).get("lastRunStatus", "?")
        icon = "🟢" if last == "ok" else "🔴" if last == "error" else "⚪"
        print(f"  {icon} {name} [{sched}] — {last}")
    print(f"\n  Ativos: {len(enabled)} | Desativados: {len(disabled)}")
PYEOF

    echo ""
    echo -e "  ${BOLD}Crontab scripts${RESET}"
    CRON_TOTAL=$(crontab -l 2>/dev/null | grep -v "^$" | wc -l | tr -d ' ')
    echo "  Total: $CRON_TOTAL entradas ativas"
}

# ═══════════════════════════════════════════════════════════════
# INFRA
# ═══════════════════════════════════════════════════════════════
status_infra() {
    header "INFRAESTRUTURA"

    # Gateway
    GW=$(curl -s --max-time 2 http://localhost:18789/health 2>/dev/null)
    if echo "$GW" | grep -q "ok\|live"; then
        ok "Gateway (18789): UP"
    else
        fail "Gateway (18789): DOWN"
    fi

    # Bridge
    BR=$(curl -s --max-time 2 http://localhost:3002/health 2>/dev/null)
    if echo "$BR" | grep -q "ok"; then
        TOOLS=$(echo "$BR" | python3 -c "import json,sys; print(json.load(sys.stdin).get('features',{}).get('tools',0))" 2>/dev/null || echo "?")
        ok "Bridge (3002): UP ($TOOLS tools)"
    else
        fail "Bridge (3002): DOWN"
    fi

    # Disco
    DISCO=$(df -h / | awk 'NR==2{print $5}')
    ok "Disco: $DISCO usado"

    # Sessions
    SESS_COUNT=$(find ~/.openclaw/agents/main/sessions/ -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    SESS_SIZE=$(du -sh ~/.openclaw/agents/main/sessions/ 2>/dev/null | awk '{print $1}')
    if [ "$SESS_COUNT" -gt 300 ]; then
        warn "Sessions: $SESS_COUNT arquivos ($SESS_SIZE) — considerar cleanup"
    else
        ok "Sessions: $SESS_COUNT arquivos ($SESS_SIZE)"
    fi

    # OpenClaw size
    OC_SIZE=$(du -sh ~/.openclaw/ 2>/dev/null | awk '{print $1}')
    ok "~/.openclaw total: $OC_SIZE"
}

# ═══════════════════════════════════════════════════════════════
# MEMORY
# ═══════════════════════════════════════════════════════════════
status_memory() {
    header "MEMORIA"

    MEM_SIZE=$(du -sh "$WORKSPACE/memory/" 2>/dev/null | awk '{print $1}')
    MEM_FILES=$(find "$WORKSPACE/memory/" -type f 2>/dev/null | wc -l | tr -d ' ')
    ok "memory/: $MEM_SIZE ($MEM_FILES arquivos)"

    # Lessons
    LESSONS=$(grep -c "^###" "$WORKSPACE/memory/lessons.md" 2>/dev/null || echo 0)
    LESSONS_APPS=$(grep -i 'Aplicacoes:' "$WORKSPACE/memory/lessons.md" 2>/dev/null | sed 's/.*Aplicacoes:[* ]*//' | awk '{s+=$1}END{print s+0}')
    ok "lessons.md: $LESSONS licoes ($LESSONS_APPS aplicacoes total)"

    # Errors
    ERRORS=$(grep -c "^###" "$WORKSPACE/memory/errors.md" 2>/dev/null || echo 0)
    ok "errors.md: $ERRORS erros"

    # Corrections
    CORRECTIONS=$(grep -c "^### COR-" "$WORKSPACE/memory/corrections.md" 2>/dev/null || echo 0)
    CORR_APPS=$(grep -i 'Aplicacoes:' "$WORKSPACE/memory/corrections.md" 2>/dev/null | sed 's/.*Aplicacoes:[* ]*//' | awk '{s+=$1}END{print s+0}')
    ok "corrections.md: $CORRECTIONS correcoes ($CORR_APPS aplicacoes total)"

    # Patterns
    PATTERNS=$(grep -c "^###" "$WORKSPACE/memory/patterns.md" 2>/dev/null || echo 0)
    ok "patterns.md: $PATTERNS padroes"

    # Daily logs
    DAILIES=$(find "$WORKSPACE/memory/" -maxdepth 1 -name "202*.md" 2>/dev/null | wc -l | tr -d ' ')
    ok "Daily logs: $DAILIES dias"

    # Weekly digests
    WEEKLIES=$(find "$WORKSPACE/memory/weekly/" -name "*digest*" 2>/dev/null | wc -l | tr -d ' ')
    ok "Weekly digests: $WEEKLIES"
}

# ═══════════════════════════════════════════════════════════════
# VALIDATE — integridade dos dados
# ═══════════════════════════════════════════════════════════════
status_validate() {
    header "VALIDACAO"
    ISSUES=0

    # 1. Clients — campos obrigatorios
    echo -e "  ${BOLD}Clientes${RESET}"
    local CLI_FILE="$WORKSPACE/shared/memory/clients.yaml"
    if [ -f "$CLI_FILE" ]; then
        local CLI_ISSUES=0
        local CLI_SLUG=""
        local HAS_NOME=0 HAS_SEG=0 HAS_STATUS=0
        while IFS= read -r line; do
            if echo "$line" | grep -qE '^  [a-z].*:$'; then
                # Check previous slug
                if [ -n "$CLI_SLUG" ]; then
                    [ "$HAS_NOME" -eq 0 ] && { fail "$CLI_SLUG: campo 'nome' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
                    [ "$HAS_SEG" -eq 0 ] && { fail "$CLI_SLUG: campo 'segmento' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
                    [ "$HAS_STATUS" -eq 0 ] && { fail "$CLI_SLUG: campo 'status' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
                fi
                CLI_SLUG=$(echo "$line" | sed 's/^ *//;s/:$//')
                HAS_NOME=0; HAS_SEG=0; HAS_STATUS=0
            fi
            echo "$line" | grep -q '^\s*nome:' && HAS_NOME=1
            echo "$line" | grep -q '^\s*segmento:' && HAS_SEG=1
            echo "$line" | grep -q '^\s*status:' && HAS_STATUS=1
        done < "$CLI_FILE"
        # Last slug
        if [ -n "$CLI_SLUG" ]; then
            [ "$HAS_NOME" -eq 0 ] && { fail "$CLI_SLUG: campo 'nome' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
            [ "$HAS_SEG" -eq 0 ] && { fail "$CLI_SLUG: campo 'segmento' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
            [ "$HAS_STATUS" -eq 0 ] && { fail "$CLI_SLUG: campo 'status' ausente"; CLI_ISSUES=$((CLI_ISSUES+1)); }
        fi
        [ "$CLI_ISSUES" -eq 0 ] && ok "Todos os clientes validos"
        echo "  Issues: $CLI_ISSUES"
    else
        warn "clients.yaml nao encontrado"
    fi

    # 2. Team — campos basicos
    echo -e "\n  ${BOLD}Equipe${RESET}"
    local TEAM_FILE="$WORKSPACE/shared/memory/team.yaml"
    if [ -f "$TEAM_FILE" ]; then
        local DESIGNERS=$(grep -c '^\s*- nome:' "$TEAM_FILE" 2>/dev/null || echo 0)
        ok "Equipe: $DESIGNERS membros encontrados em team.yaml"
    else
        warn "team.yaml nao encontrado"
    fi

    # 3. Tokens — verificar se existem no .env
    echo -e "\n  ${BOLD}Tokens & Credenciais${RESET}"
    REQUIRED_TOKENS="ANTHROPIC_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID META_ADS_ACCESS_TOKEN SUPABASE_URL SUPABASE_ANON_KEY"
    for token in $REQUIRED_TOKENS; do
        VAL=$(grep "^${token}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
        if [ -n "$VAL" ] && [ "$VAL" != '""' ] && [ "$VAL" != "''" ]; then
            ok "$token: definido"
        else
            fail "$token: AUSENTE"
            ISSUES=$((ISSUES + 1))
        fi
    done

    # 4. Token Meta por cliente
    echo -e "\n  ${BOLD}Tokens Meta por Cliente${RESET}"
    CLIENT_TOKENS="META_TOKEN_GR_VEICULOS META_ADS_TOKEN_TICOMIA META_ADS_TOKEN_FORLAN"
    for token in $CLIENT_TOKENS; do
        VAL=$(grep "^${token}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
        if [ -n "$VAL" ] && [ ${#VAL} -gt 20 ]; then
            ok "$token: definido (${#VAL} chars)"
        else
            warn "$token: ausente ou curto"
        fi
    done

    # 5. SOUL.md size
    echo -e "\n  ${BOLD}Documentos Criticos${RESET}"
    SOUL_SIZE=$(wc -c < "$WORKSPACE/SOUL.md" 2>/dev/null || echo 0)
    if [ "$SOUL_SIZE" -gt 20000 ]; then
        fail "SOUL.md: ${SOUL_SIZE} chars (ACIMA do limite 20K!)"
    elif [ "$SOUL_SIZE" -gt 18000 ]; then
        warn "SOUL.md: ${SOUL_SIZE} chars (proximo do limite 20K)"
    else
        ok "SOUL.md: ${SOUL_SIZE} chars (limite 20K)"
    fi

    # 6. Crons com erro
    echo -e "\n  ${BOLD}Crons com Erro${RESET}"
    python3 << 'PYEOF'
import json, os
f = os.path.expanduser("~/.openclaw/cron/jobs.json")
issues = 0
if os.path.exists(f):
    data = json.load(open(f))
    for j in data.get("jobs", []):
        if not j.get("enabled", True):
            continue
        errs = j.get("state", {}).get("consecutiveErrors", 0)
        if errs >= 3:
            print(f"  ✗ {j['name']}: {errs} erros consecutivos")
            issues += 1
if issues == 0:
    print("  ✓ Nenhum cron com erros consecutivos")
PYEOF

    # 7. Scripts sem +x
    echo -e "\n  ${BOLD}Scripts sem permissao de execucao${RESET}"
    NOEXEC=$(find "$WORKSPACE/scripts/" -name "*.sh" ! -perm +111 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NOEXEC" -gt 0 ]; then
        warn "$NOEXEC scripts .sh sem +x"
        find "$WORKSPACE/scripts/" -name "*.sh" ! -perm +111 2>/dev/null | head -5 | sed 's/^/    /'
    else
        ok "Todos os scripts .sh tem +x"
    fi
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY — visao rapida
# ═══════════════════════════════════════════════════════════════
status_summary() {
    echo -e "${BOLD}🐺 Wolf System Status — $(date '+%d/%m/%Y %H:%M')${RESET}"

    # Gateway
    GW=$(curl -s --max-time 2 http://localhost:18789/health 2>/dev/null)
    echo "$GW" | grep -q "ok\|live" && ok "Gateway: UP" || fail "Gateway: DOWN"

    # Bridge
    BR=$(curl -s --max-time 2 http://localhost:3002/health 2>/dev/null)
    echo "$BR" | grep -q "ok" && ok "Bridge: UP" || fail "Bridge: DOWN"

    # Clients
    CLIENTS=$(grep -c 'status: ativo' "$WORKSPACE/shared/memory/clients.yaml" 2>/dev/null || echo "0")
    ok "Clientes ativos: $CLIENTS"

    # Crons
    LLM_CRONS=$(python3 -c "import json; print(len([j for j in json.load(open('$HOME/.openclaw/cron/jobs.json')).get('jobs',[]) if j.get('enabled',True)]))" 2>/dev/null || echo "?")
    SCRIPT_CRONS=$(crontab -l 2>/dev/null | grep -v "^$" | wc -l | tr -d ' ')
    ok "Crons: $LLM_CRONS LLM + $SCRIPT_CRONS scripts"

    # Memory
    LESSONS=$(grep -c "^###" "$WORKSPACE/memory/lessons.md" 2>/dev/null || echo 0)
    CORRECTIONS=$(grep -c "^### COR-" "$WORKSPACE/memory/corrections.md" 2>/dev/null || echo 0)
    ok "Aprendizado: $LESSONS licoes, $CORRECTIONS correcoes"

    # Disco
    DISCO=$(df -h / | awk 'NR==2{print $5}')
    ok "Disco: $DISCO"
}

# ═══════════════════════════════════════════════════════════════
# ROUTER
# ═══════════════════════════════════════════════════════════════
case "$CMD" in
    clients)   status_clients ;;
    agents)    status_agents ;;
    crons)     status_crons ;;
    infra)     status_infra ;;
    memory)    status_memory ;;
    validate)  status_validate ;;
    all)
        status_summary
        status_clients
        status_agents
        status_crons
        status_infra
        status_memory
        status_validate
        ;;
    summary|*)
        status_summary
        ;;
esac
