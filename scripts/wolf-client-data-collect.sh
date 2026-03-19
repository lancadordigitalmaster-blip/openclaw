#!/bin/bash
# wolf-client-data-collect.sh — Envia formulário para Netto via Telegram
# pedindo dados faltantes dos clientes
# Execução única (não é cron)

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

MSG="📋 *Alfred — Dados de Clientes*

Netto, preciso completar a ficha dos clientes para os relatórios automatizados funcionarem com metas. Responda quando puder:

*1️⃣ GR Veículos*
- WhatsApp do contato principal?
- Meta de ROAS mínimo? (ex: 3.0)
- Budget mensal Meta Ads? (ex: R\$3.000)
- Tom de voz da marca? (ex: profissional, popular, premium)
- Canais ativos? (Instagram, Facebook, Google Ads?)

*2️⃣ Ticomia*
- WhatsApp do contato principal?
- Meta de ROAS mínimo?
- Budget mensal Meta Ads?
- Tom de voz da marca?
- Canais ativos?

*3️⃣ William Forlan*
- WhatsApp do contato principal?
- Meta de ROAS mínimo?
- Budget mensal Meta Ads?
- Tom de voz da marca?
- Canais ativos?

*4️⃣ Wolf Pack* (interno)
- Budget mensal Meta Ads? (R\$140/dia = ~R\$4.200?)
- Meta de ROAS mínimo?

_Pode responder parcialmente — vou atualizando conforme receber._"

wolf_telegram "$MSG"
echo "Formulário enviado via Telegram"
