#!/bin/bash
# openclaw-tunnel.sh — Cloudflare tunnel for OpenClaw gateway
# Starts a quick tunnel and saves the URL to Supabase system_config
# LaunchAgent: ai.openclaw.tunnel

# Carregar credenciais do .env central
ENV_FILE="$HOME/.openclaw/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL not set in .env}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY not set in .env}"
LOG="/tmp/openclaw-tunnel.log"
GATEWAY_PORT=18789

echo "[$(date)] Starting OpenClaw tunnel..." > "$LOG"

# Kill any existing tunnel
pkill -f "cloudflared tunnel --url http://127.0.0.1:${GATEWAY_PORT}" 2>/dev/null
sleep 1

# Start tunnel and capture URL
TUNNEL_LOG="/tmp/cloudflared-openclaw.log"
/opt/homebrew/bin/cloudflared tunnel --url "http://127.0.0.1:${GATEWAY_PORT}" --no-autoupdate 2>"$TUNNEL_LOG" &
TUNNEL_PID=$!

echo "[$(date)] cloudflared PID: $TUNNEL_PID" >> "$LOG"

# Wait for tunnel URL (max 30s)
for i in $(seq 1 30); do
  sleep 1
  TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
  if [ -n "$TUNNEL_URL" ]; then
    echo "[$(date)] Tunnel URL: $TUNNEL_URL" >> "$LOG"
    break
  fi
done

if [ -z "$TUNNEL_URL" ]; then
  echo "[$(date)] ERROR: Failed to get tunnel URL after 30s" >> "$LOG"
  exit 1
fi

# Save URL to Supabase system_config (upsert)
RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${SUPABASE_URL}/rest/v1/system_config" \
  -X POST \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{\"key\": \"openclaw_tunnel_url\", \"value\": \"\\\"${TUNNEL_URL}\\\"\", \"description\": \"Cloudflare tunnel URL for OpenClaw gateway\"}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
echo "[$(date)] Supabase upsert response: HTTP $HTTP_CODE" >> "$LOG"

# Also save the gateway auth token
curl -s \
  "${SUPABASE_URL}/rest/v1/system_config" \
  -X POST \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{\"key\": \"openclaw_gateway_token\", \"value\": \"\\\"${GATEWAY_TOKEN}\\\"\", \"description\": \"OpenClaw gateway auth token\"}" > /dev/null 2>&1

echo "[$(date)] Tunnel running. Waiting for cloudflared to exit..." >> "$LOG"

# Keep running — LaunchAgent will restart if cloudflared dies
wait $TUNNEL_PID
echo "[$(date)] cloudflared exited" >> "$LOG"
