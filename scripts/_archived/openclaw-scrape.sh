#!/bin/bash
# openclaw-scrape.sh — Wrapper CLI for Scout (autonomous scraping agent)
# Usage:
#   bash openclaw-scrape.sh --url "https://example.com" --objective "Extract pricing"
#   bash openclaw-scrape.sh --url "https://example.com" --objective "..." --session my_audit --notify
#   bash openclaw-scrape.sh --url "https://example.com" --objective "..." --visible --no-stealth

set -euo pipefail

SCRIPT_DIR="$HOME/.openclaw/scraping"
ENV_FILE="$HOME/.openclaw/.env"

# Load environment
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

export PATH="/opt/homebrew/bin:/opt/homebrew/opt/python@3.14/bin:$PATH"

exec python3 "$SCRIPT_DIR/scout.py" "$@"
