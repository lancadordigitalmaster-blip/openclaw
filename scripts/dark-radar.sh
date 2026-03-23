#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Dark Radar — Wrapper bash (padrao OpenClaw)
# Inteligencia de mercado dark channels
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$HOME/.openclaw/workspace"
ENGINE="$SCRIPT_DIR/radar-engine.py"
SERVER="$SCRIPT_DIR/radar-server.py"

[[ -f "$WORKSPACE/scripts/lib-wolf.sh" ]] && source "$WORKSPACE/scripts/lib-wolf.sh"
if [[ -f "$HOME/.openclaw/.env" ]]; then set -a; source "$HOME/.openclaw/.env"; set +a; fi

notify() {
    if type wolf_notify &>/dev/null; then wolf_notify "Dark Radar" "$1"
    else echo "[NOTIFY] $1"; fi
}

check_deps() {
    command -v python3 &>/dev/null || { echo "ERRO: python3"; exit 1; }
    command -v yt-dlp &>/dev/null || { echo "Instalando yt-dlp..."; pip3 install yt-dlp --break-system-packages -q; }
    python3 -c "import requests" 2>/dev/null || pip3 install requests --break-system-packages -q
}

case "${1:-help}" in
    add)
        check_deps
        shift; python3 "$ENGINE" add "$@"
        ;;
    list)
        check_deps
        python3 "$ENGINE" list
        ;;
    remove)
        check_deps
        shift; python3 "$ENGINE" remove "$@"
        ;;
    collect)
        check_deps
        echo "[$(date '+%H:%M')] Coleta iniciada"
        python3 "$ENGINE" collect
        notify "Coleta concluida"
        ;;
    analyze)
        check_deps
        echo "[$(date '+%H:%M')] Analise iniciada"
        python3 "$ENGINE" analyze
        notify "Analise concluida"
        ;;
    cycle)
        check_deps
        echo "[$(date '+%H:%M')] Ciclo completo"
        python3 "$ENGINE" cycle
        notify "Ciclo completo concluido"
        ;;
    insights)
        check_deps
        python3 "$ENGINE" insights
        ;;
    discovery)
        check_deps
        python3 "$ENGINE" discovery
        ;;
    strategy)
        check_deps
        shift; python3 "$ENGINE" strategy "$@"
        ;;
    score)
        check_deps
        shift; python3 "$ENGINE" score "$@"
        ;;
    server)
        check_deps
        python3 "$SERVER"
        ;;
    server-start)
        check_deps
        echo "Iniciando radar server em background (porta ${RADAR_PORT:-8898})..."
        nohup python3 "$SERVER" > "$WORKSPACE/memory/logs/dark-radar-server.log" 2>&1 &
        echo "PID: $!"
        echo $! > /tmp/dark-radar-server.pid
        ;;
    server-stop)
        if [[ -f /tmp/dark-radar-server.pid ]]; then
            kill "$(cat /tmp/dark-radar-server.pid)" 2>/dev/null && echo "Servidor parado" || echo "Servidor nao estava rodando"
            rm -f /tmp/dark-radar-server.pid
        else
            echo "PID file nao encontrado"
        fi
        ;;
    health)
        check_deps
        python3 "$ENGINE" health
        echo ""
        # Checa server
        if curl -s --max-time 3 "http://localhost:${RADAR_PORT:-8898}/api/radar/health" > /dev/null 2>&1; then
            echo "  [OK] Radar server online (porta ${RADAR_PORT:-8898})"
        else
            echo "  [--] Radar server offline"
        fi
        ;;
    help|*)
        cat <<EOF
Dark Radar — Inteligencia de mercado dark channels

Canais:
  $(basename "$0") add <url> [--type principal|concorrente|referencia|tendencia] [--nicho X]
  $(basename "$0") list
  $(basename "$0") remove <handle>
  $(basename "$0") score <handle>

Coleta e analise:
  $(basename "$0") collect              Coleta dados de todos os canais
  $(basename "$0") analyze              Roda analise IA
  $(basename "$0") cycle                Ciclo completo (coleta + analise + discovery)
  $(basename "$0") insights             Gera insights de mercado
  $(basename "$0") discovery            Descobre canais novos
  $(basename "$0") strategy [--topic X] Gera estrategia

Servidor API:
  $(basename "$0") server               Inicia servidor (foreground)
  $(basename "$0") server-start         Inicia em background
  $(basename "$0") server-stop          Para servidor
  $(basename "$0") health               Health check

Exemplos:
  $(basename "$0") add "https://www.youtube.com/@marcosdecastro91" --type principal --nicho historia
  $(basename "$0") add "https://www.youtube.com/@historiadark" --type concorrente --nicho historia
  $(basename "$0") cycle
  $(basename "$0") server-start
EOF
        ;;
esac
