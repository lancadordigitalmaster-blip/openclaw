#!/bin/bash
# social-media-weekly-plan.sh — Sugestao de pauta semanal
# Roda toda segunda 07h30 — Luna sugere posts para a semana
# Crontab: 30 7 * * 1 bash ~/.openclaw/workspace/scripts/social-media-weekly-plan.sh

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
SM_DIR="$WORKSPACE/memory/social-media"
WEEK_NUM=$(date '+%V')
YEAR=$(date '+%Y')
DATE_DISPLAY=$(date '+%d/%m/%Y')

wolf_log "social-plan" "Gerando sugestao de pauta semanal"

# Ler config
CONFIG="$SM_DIR/config.md"
if [ ! -f "$CONFIG" ]; then
    wolf_log "social-plan" "ERRO: config.md nao encontrado"
    exit 1
fi

# Ler ultimo report (se existir)
LAST_REPORT=""
LAST_REPORT_FILE=$(find "$SM_DIR/reports/" -name "*-report.md" -type f 2>/dev/null | sort -r | head -1 || true)
[ -n "$LAST_REPORT_FILE" ] && [ -f "$LAST_REPORT_FILE" ] && LAST_REPORT=$(cat "$LAST_REPORT_FILE")

# Gerar sugestoes baseadas nos pilares
cat > /tmp/social-plan-$$.py << 'PYEOF'
import os, sys, json
from datetime import datetime, timedelta

week_num = sys.argv[1]
date_display = sys.argv[2]

now = datetime.now()
dias = []
for i in range(5):  # seg a sex
    d = now + timedelta(days=i)
    dia_nome = ["Seg", "Ter", "Qua", "Qui", "Sex"][d.weekday()] if d.weekday() < 5 else "?"
    dias.append(f"{dia_nome} {d.strftime('%d/%m')}")

# Templates de conteudo por tipo
formatos = ["Carrossel", "Reels", "Stories", "Post Estatico", "Video Curto"]
temas_agencia = [
    "Bastidores: como a IA ajuda a Wolf a entregar resultados",
    "Case de resultado: metricas reais de um cliente (com permissao)",
    "Dica rapida: 1 hack de trafego pago em 60 segundos",
    "Trend da semana: ferramenta ou estrategia em alta",
    "Depoimento ou prova social de cliente",
]
temas_auto = [
    "Oferta da semana: destaque do estoque",
    "Novidade: modelo recem-chegado",
    "Dica de financiamento ou manutencao",
    "Depoimento de cliente satisfeito",
    "Bastidores da concessionaria",
]

msg = f"""📋 Sugestao de Pauta — Semana {week_num} ({date_display})

🐺 WOLF AGENCY (@wolfagency_)
"""
for i, dia in enumerate(dias[:3]):
    fmt = formatos[i % len(formatos)]
    tema = temas_agencia[i % len(temas_agencia)]
    prio = "🔥" if i == 0 else "📊"
    msg += f"\n{i+1}. {dia} — {fmt} — {tema} — {prio}"

msg += f"""

🚗 GR VEICULOS (@grveiculos)
"""
for i, dia in enumerate(dias):
    fmt = formatos[(i+2) % len(formatos)]
    tema = temas_auto[i % len(temas_auto)]
    prio = "🔥" if i < 2 else "📊"
    msg += f"\n{i+1}. {dia} — {fmt} — {tema} — {prio}"

msg += """

⚡ Quick wins (producao <30min):
- Repost de stories de clientes (UGC)
- Print de metrica boa com texto overlay
- Enquete nos stories (engajamento facil)

📌 Mirelli: valide e ajuste. Duvidas? Me chama!"""

print(msg)
PYEOF

PLAN=$(python3 /tmp/social-plan-$$.py "$WEEK_NUM" "$DATE_DISPLAY" 2>&1)
rm -f /tmp/social-plan-$$.py

wolf_notify_role "mirelli" "$PLAN"

# Salvar
echo "$PLAN" > "$SM_DIR/reports/${YEAR}-W${WEEK_NUM}-plan.md"

wolf_log "social-plan" "Pauta semanal W${WEEK_NUM} enviada"
echo "OK: social-media-weekly-plan completed at $(date '+%Y-%m-%d %H:%M:%S')"
