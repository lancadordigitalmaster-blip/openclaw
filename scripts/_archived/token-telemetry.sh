#!/bin/bash
# token-telemetry.sh — Wolf Agency OpenClaw
# Relatório de saúde de tokens por sessão
# Uso: bash ~/.openclaw/scripts/token-telemetry.sh [--watch] [--json]

SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
SESSIONS_JSON="$SESSIONS_DIR/sessions.json"
WATCHDOG_LOG="$HOME/.openclaw/logs/watchdog.log"
TELEMETRY_LOG="$HOME/.openclaw/logs/token-telemetry.jsonl"
MODE="${1:-}"

# Limites do budget
BUDGET_PER_SESSION=200000
BUDGET_ECONOMY_THRESHOLD=120000
BUDGET_WARNING_THRESHOLD=80000
SESSION_MAX_KB=800

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# ── COLETA DE DADOS ──────────────────────────────────────────────────────
collect_metrics() {
    python3 - <<'PYEOF'
import json, os, sys
from pathlib import Path

sessions_file = Path.home() / ".openclaw/agents/main/sessions/sessions.json"
sessions_dir  = Path.home() / ".openclaw/agents/main/sessions"

budget = {
    "session_hard_cap":       200_000,
    "economy_threshold":      120_000,
    "warning_threshold":       80_000,
    "session_file_max_kb":        800,
}

try:
    with open(sessions_file) as f:
        sessions = json.load(f)
except:
    print(json.dumps({"error": "sessions.json not found"}))
    sys.exit(1)

report = []
for key, session in sessions.items():
    session_id  = session.get("sessionId", "?")
    session_file = Path(session.get("sessionFile", ""))
    total_tokens = session.get("totalTokens", 0)
    input_tokens = session.get("inputTokens", 0)
    output_tokens = session.get("outputTokens", 0)
    cache_read   = session.get("cacheRead", 0)
    model        = session.get("model", "?")
    provider     = session.get("modelProvider", "?")
    label        = session.get("label", key)

    # Tamanho do arquivo de sessão
    file_kb = 0
    if session_file.exists():
        file_kb = session_file.stat().st_size // 1024

    # Status de saúde
    if total_tokens >= budget["session_hard_cap"]:
        health = "CRITICAL"
    elif total_tokens >= budget["economy_threshold"]:
        health = "WARNING"
    elif total_tokens >= budget["warning_threshold"]:
        health = "WATCH"
    else:
        health = "OK"

    file_health = "OK"
    if file_kb >= budget["session_file_max_kb"]:
        file_health = "CRITICAL"
    elif file_kb >= budget["session_file_max_kb"] * 0.7:
        file_health = "WARNING"

    report.append({
        "key":            key,
        "label":          label[:50],
        "session_id":     session_id[:12],
        "model":          f"{provider}/{model}",
        "total_tokens":   total_tokens,
        "input_tokens":   input_tokens,
        "output_tokens":  output_tokens,
        "cache_read":     cache_read,
        "file_kb":        file_kb,
        "health":         health,
        "file_health":    file_health,
        "pct_of_cap":     round(total_tokens / budget["session_hard_cap"] * 100, 1),
    })

print(json.dumps({"sessions": report, "budget": budget}))
PYEOF
}

# ── MODO JSON (para scripts) ──────────────────────────────────────────────
if [ "$MODE" = "--json" ]; then
    collect_metrics
    exit 0
fi

# ── MODO RELATÓRIO VISUAL ─────────────────────────────────────────────────
print_report() {
    DATA=$(collect_metrics)

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          WOLF AGENCY — TOKEN TELEMETRY REPORT                ║"
    echo "║  $(ts)                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    python3 - "$DATA" <<'PYEOF'
import json, sys

data = json.loads(sys.argv[1])
sessions = data["sessions"]
budget = data["budget"]

STATUS_ICON = {"OK": "✅", "WATCH": "⚠️ ", "WARNING": "🟠", "CRITICAL": "🔴"}
BAR_WIDTH = 30

def token_bar(pct):
    filled = int(pct / 100 * BAR_WIDTH)
    bar = "█" * filled + "░" * (BAR_WIDTH - filled)
    return f"[{bar}] {pct:5.1f}%"

for s in sessions:
    icon = STATUS_ICON.get(s["health"], "?")
    file_icon = STATUS_ICON.get(s["file_health"], "?")

    print(f"  {icon} {s['label'][:45]}")
    print(f"     Session:   {s['session_id']}...  Model: {s['model']}")
    print(f"     Tokens:    {s['total_tokens']:>10,}  {token_bar(s['pct_of_cap'])}")
    print(f"     Breakdown: IN={s['input_tokens']:,}  OUT={s['output_tokens']:,}  CACHE={s['cache_read']:,}")
    print(f"     File:      {file_icon} {s['file_kb']} KB  (max={budget['session_file_max_kb']}KB)")
    print()

print(f"  BUDGETS:")
print(f"    Hard cap:        {budget['session_hard_cap']:>10,} tokens")
print(f"    Economy mode at: {budget['economy_threshold']:>10,} tokens")
print(f"    Warning at:      {budget['warning_threshold']:>10,} tokens")
print()

# Alertas
criticals = [s for s in sessions if s["health"] == "CRITICAL" or s["file_health"] == "CRITICAL"]
if criticals:
    print(f"  🚨 AÇÃO NECESSÁRIA: {len(criticals)} sessão(ões) em estado crítico!")
    print(f"     Execute: bash ~/.openclaw/scripts/alfred-emergency-reset.sh")
else:
    print(f"  ✅ Todas as sessões dentro dos limites de budget.")
print()
PYEOF
}

# ── MODO WATCH ────────────────────────────────────────────────────────────
if [ "$MODE" = "--watch" ]; then
    echo "Monitorando tokens a cada 60 segundos. Ctrl+C para parar."
    while true; do
        clear
        print_report
        sleep 60
    done
else
    print_report
fi

# ── LOG TELEMETRIA ────────────────────────────────────────────────────────
# Sempre salva snapshot JSON no log de telemetria
DATA=$(collect_metrics)
echo "{\"ts\":\"$(ts)\",\"data\":$DATA}" >> "$TELEMETRY_LOG" 2>/dev/null

exit 0
