#!/bin/bash
# instagram-screenshot.sh — Captura screenshot de qualquer URL via Chrome CDP
# Uso: ./instagram-screenshot.sh "https://www.instagram.com/reel/..."
# Output: /tmp/instagram_screenshot.jpg

URL="${1:-https://www.instagram.com}"
OUTPUT="${2:-/tmp/instagram_screenshot.jpg}"
WORKSPACE="$HOME/.openclaw/workspace"

# 1. Matar Chrome existente e reiniciar com remote debugging
pkill -f "Google Chrome" 2>/dev/null
sleep 1

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="/tmp/chrome-alfred-session" \
  --no-first-run \
  --no-default-browser-check \
  "$URL" \
  &>/tmp/chrome-cdp.log &

# 2. Aguardar Chrome inicializar
sleep 6

# 3. Capturar screenshot via CDP (Node.js + ws)
cd /tmp && node -e "
const WebSocket = require('./node_modules/ws');
const fs = require('fs');
const http = require('http');

// Buscar aba do alvo
const req = http.get('http://127.0.0.1:9222/json/list', (res) => {
  let data = '';
  res.on('data', d => data += d);
  res.on('end', () => {
    const tabs = JSON.parse(data);
    const target = tabs.find(t => t.url && !t.url.startsWith('chrome-extension')) || tabs[0];
    if (!target) { console.log('No tab found'); process.exit(1); }

    const ws = new WebSocket('ws://127.0.0.1:9222/devtools/page/' + target.id);
    ws.on('open', () => {
      setTimeout(() => {
        ws.send(JSON.stringify({id:1, method:'Page.captureScreenshot', params:{format:'jpeg',quality:80}}));
      }, 3000); // aguarda página carregar
    });
    ws.on('message', (msg) => {
      const d = JSON.parse(msg);
      if (d.id === 1 && d.result) {
        fs.writeFileSync('$OUTPUT', Buffer.from(d.result.data, 'base64'));
        console.log('Screenshot saved: $OUTPUT');
        ws.close();
        process.exit(0);
      }
    });
    ws.on('error', e => { console.log('Error:', e.message); process.exit(1); });
    setTimeout(() => { console.log('Timeout'); process.exit(1); }, 15000);
  });
});
req.on('error', e => { console.log('Chrome not ready:', e.message); process.exit(1); });
" 2>&1

# 4. Copiar para workspace se diferente
if [ "$OUTPUT" != "$WORKSPACE/instagram_screenshot.jpg" ]; then
  cp "$OUTPUT" "$WORKSPACE/instagram_screenshot.jpg" 2>/dev/null
fi

echo "Done: $OUTPUT"
