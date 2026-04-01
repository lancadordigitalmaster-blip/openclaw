#!/bin/bash
# llm-research.sh — Pesquisa semanal de novas LLMs (domingo 19h BRT)
# PRECISA DE LLM (web_search) — pesquisa novos modelos, avalia custo/beneficio.

set -euo pipefail

TODAY=$(date +"%Y-%m-%d")

echo "[llm-research] Pesquisa semanal de LLMs para $TODAY"
echo "Este script e executado pelo Alfred via cron com web_search habilitado."
echo "Ver payload do cron para o prompt completo."
