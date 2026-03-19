#!/bin/bash
# social-media-weekly-report.sh — Report semanal de social media
# Roda toda sexta 17h30 — compila status da semana
# Crontab: 30 17 * * 5 bash ~/.openclaw/workspace/scripts/social-media-weekly-report.sh

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

WORKSPACE="$HOME/.openclaw/workspace"
SM_DIR="$WORKSPACE/memory/social-media"
WEEK_NUM=$(date '+%V')
YEAR=$(date '+%Y')
DATE_DISPLAY=$(date '+%d/%m/%Y')

wolf_log "social-report" "Gerando report semanal social media"

# Nota: sem API do Instagram, o report e baseado em dados disponiveis
# Quando integrar Instagram API, substituir este bloco

REPORT="📱 Social Media — Report Semanal — Semana $WEEK_NUM ($DATE_DISPLAY)

🐺 WOLF AGENCY
Status: [Preencher metricas manualmente ou via Instagram API quando disponivel]
- Posts publicados esta semana: _
- Alcance total: _
- Engagement rate: _

🚗 GR VEICULOS
Status: [Preencher metricas]
- Posts publicados: _
- Alcance total: _
- Engagement rate: _

📊 Observacoes:
- Melhor post da semana: [identificar]
- Pior post: [identificar e analisar]
- Tendencia: [crescimento/estagnacao/queda]

💡 Sugestao proxima semana:
- Baseado nos resultados, focar em [formato/tema que performou melhor]
- Testar [novo formato ou horario]

📌 Mirelli: preencha os dados acima e envie pra Netto.
Quando tivermos Instagram API integrada, esse report sera 100% automatico.

---
Proxima integracao pendente: Instagram Graph API (requer Facebook Business Manager)"

wolf_notify_role "mirelli" "$REPORT"

echo "$REPORT" > "$SM_DIR/reports/${YEAR}-W${WEEK_NUM}-report.md"

wolf_log "social-report" "Report semanal W${WEEK_NUM} enviado"
echo "OK: social-media-weekly-report completed at $(date '+%Y-%m-%d %H:%M:%S')"
