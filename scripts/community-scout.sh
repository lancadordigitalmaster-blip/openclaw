#!/bin/bash
# community-scout.sh — Pesquisa diaria em comunidades OpenClaw (20h BRT)
# PRECISA DE LLM (web_search) — roda via cron OpenClaw, nao standalone.
# Pesquisa GitHub, ClawHub, forums por novidades, skills, cases de uso.
# Salva em memory/COMMUNITY_INTEL.md e envia resumo no Telegram.

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
INTEL_FILE="$WORKSPACE/memory/COMMUNITY_INTEL.md"
TODAY=$(date +"%Y-%m-%d")

# Este script e um TEMPLATE — o payload real do cron e o que importa.
# O Alfred vai usar web_search pra buscar e depois escrever o resultado.

echo "[community-scout] Pesquisa de comunidade para $TODAY"
echo "Este script e executado pelo Alfred via cron com web_search habilitado."
echo "Ver payload do cron para o prompt completo."
