#!/bin/bash
# upgrade-proposer.sh — Propoe max 3 upgrades por dia (21h BRT)
# Le SYSTEM_HEALTH.md, COMMUNITY_INTEL.md, logs do dia.
# Gera propostas formatadas. PRECISA DE LLM (sintetizar).

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
TODAY=$(date +"%Y-%m-%d")

echo "[upgrade-proposer] Analisando oportunidades de upgrade para $TODAY"
echo "Este script e executado pelo Alfred via cron."
echo "Ver payload do cron para o prompt completo."
