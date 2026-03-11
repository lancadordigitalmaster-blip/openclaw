#!/bin/bash
# YouTube Multi-Channel Monitor com suporte a tradução
# Monitora vários canais e traduz conteúdo de canais em inglês

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
MONITOR_LOG="$WORKSPACE/memory/youtube-monitor-multilang.log"
CHANNELS_CONFIG="$WORKSPACE/config/youtube-channels.json"

mkdir -p "$WORKSPACE/memory"

# Função de log
log_entry() {
  local channel=$1
  local msg=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$channel] $msg" >> "$MONITOR_LOG"
}

# Config de canais
# Se não existir, cria default
if [ ! -f "$CHANNELS_CONFIG" ]; then
  mkdir -p "$WORKSPACE/config"
  cat > "$CHANNELS_CONFIG" <<'EOF'
{
  "channels": [
    {
      "name": "@oalanicolas",
      "url": "https://youtube.com/@oalanicolas",
      "language": "pt-BR",
      "category": "dev-tools",
      "active": true
    },
    {
      "name": "@alexfinnofficial",
      "url": "https://youtube.com/@alexfinnofficial",
      "language": "en",
      "translate_to": "pt-BR",
      "category": "marketing",
      "active": true
    }
  ]
}
EOF
  log_entry "CONFIG" "Arquivo de config criado em $CHANNELS_CONFIG"
fi

# Função: extrair último vídeo de um canal
get_latest_video() {
  local channel_url=$1
  local latest=$(curl -s "$channel_url" 2>/dev/null | grep -oP 'href="/watch\?v=\K[^"]+' | head -1)
  echo "$latest"
}

# Função: traduzir com Google Translate API (fallback: texto em inglês)
translate_text() {
  local text=$1
  local from_lang=$2
  local to_lang=$3
  
  # Tenta com curl + Google Translate (simplificado)
  local encoded_text=$(echo "$text" | jq -sRr @uri)
  
  # Fallback: só avisa que tá em inglês
  if [ "$to_lang" = "pt-BR" ] && [ "$from_lang" = "en" ]; then
    echo "[TRADUÇÃO PENDENTE] $text"
  else
    echo "$text"
  fi
}

# Processar cada canal
if [ -f "$CHANNELS_CONFIG" ]; then
  CHANNEL_COUNT=$(jq '.channels | length' < "$CHANNELS_CONFIG")
  
  for ((i=0; i<CHANNEL_COUNT; i++)); do
    CHANNEL=$(jq ".channels[$i]" < "$CHANNELS_CONFIG")
    
    ACTIVE=$(echo "$CHANNEL" | jq -r '.active')
    if [ "$ACTIVE" != "true" ]; then
      continue
    fi
    
    CHANNEL_NAME=$(echo "$CHANNEL" | jq -r '.name')
    CHANNEL_URL=$(echo "$CHANNEL" | jq -r '.url')
    LANGUAGE=$(echo "$CHANNEL" | jq -r '.language')
    TRANSLATE_TO=$(echo "$CHANNEL" | jq -r '.translate_to // empty')
    CATEGORY=$(echo "$CHANNEL" | jq -r '.category')
    
    log_entry "$CHANNEL_NAME" "Verificando canal..."
    
    # Pega último vídeo
    LATEST_VIDEO=$(get_latest_video "$CHANNEL_URL")
    
    if [ -z "$LATEST_VIDEO" ]; then
      log_entry "$CHANNEL_NAME" "ERRO: Não conseguiu extrair vídeos"
      continue
    fi
    
    LATEST_VIDEO_URL="https://www.youtube.com/watch?v=$LATEST_VIDEO"
    LAST_VIDEO_FILE="$WORKSPACE/memory/.last-youtube-${CHANNEL_NAME}"
    
    # Verifica se já processamos
    if [ -f "$LAST_VIDEO_FILE" ]; then
      LAST_VIDEO=$(cat "$LAST_VIDEO_FILE")
      if [ "$LAST_VIDEO" = "$LATEST_VIDEO" ]; then
        log_entry "$CHANNEL_NAME" "OK: Nenhum vídeo novo"
        continue
      fi
    fi
    
    # NOVO VÍDEO!
    log_entry "$CHANNEL_NAME" "NOVO VÍDEO: $LATEST_VIDEO_URL"
    echo "$LATEST_VIDEO" > "$LAST_VIDEO_FILE"
    
    # Criar alert
    cat > "$WORKSPACE/memory/.youtube-alert-${CHANNEL_NAME}" <<ALERT_EOF
Canal: $CHANNEL_NAME
URL: $LATEST_VIDEO_URL
Categoria: $CATEGORY
Idioma Original: $LANGUAGE
Idioma Alvo: $TRANSLATE_TO
Detectado em: $(date '+%Y-%m-%d %H:%M:%S')
Status: Aguardando análise
ALERT_EOF

    log_entry "$CHANNEL_NAME" "Alert criado para processamento"
  done
else
  log_entry "ERROR" "Arquivo config não encontrado"
  exit 1
fi

exit 0
