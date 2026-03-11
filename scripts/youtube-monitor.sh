#!/bin/bash
# YouTube Channel Monitor — Detecta novos vídeos e notifica
# Canal: @oalanicolas

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
CHANNEL_URL="https://youtube.com/@oalanicolas"
MONITOR_LOG="$WORKSPACE/memory/youtube-monitor.log"
LAST_VIDEO_FILE="$WORKSPACE/memory/.last-youtube-video"

mkdir -p "$WORKSPACE/memory"

# Função de log
log_entry() {
  local msg=$1
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $msg" >> "$MONITOR_LOG"
}

# Tenta pegar os últimos vídeos via RSS (mais rápido que web scraping)
# YouTube RSS: https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID
# Mas já que tem o @alias, a gente tenta com summarize CLI

log_entry "Verificando canal $CHANNEL_URL"

# Tenta pegar info do canal (fallback: verifica via curl + grep)
LATEST_VIDEO=$(curl -s "$CHANNEL_URL" 2>/dev/null | grep -oP 'href="/watch\?v=\K[^"]+' | head -1)

if [ -z "$LATEST_VIDEO" ]; then
  log_entry "ERRO: Não conseguiu pegar vídeos do canal"
  exit 1
fi

LATEST_VIDEO_URL="https://www.youtube.com/watch?v=$LATEST_VIDEO"

# Verifica se já processamos esse vídeo
if [ -f "$LAST_VIDEO_FILE" ]; then
  LAST_VIDEO=$(cat "$LAST_VIDEO_FILE")
  if [ "$LAST_VIDEO" = "$LATEST_VIDEO" ]; then
    log_entry "OK: Nenhum vídeo novo"
    exit 0
  fi
fi

# Novo vídeo encontrado!
log_entry "NOVO VÍDEO: $LATEST_VIDEO_URL"
echo "$LATEST_VIDEO" > "$LAST_VIDEO_FILE"

# Criar arquivo de notificação
cat > "$WORKSPACE/memory/.youtube-alert" <<EOF
Canal: @oalanicolas
Vídeo: $LATEST_VIDEO_URL
Detectado em: $(date '+%Y-%m-%d %H:%M:%S')
Status: Aguardando processamento
EOF

exit 0
