#!/bin/bash
# YouTube Content Processor
# Transcreve, traduz (se necessário) e extrai conhecimento

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
PROCESSOR_LOG="$WORKSPACE/memory/youtube-processor.log"
CONTENT_DIR="$WORKSPACE/memory/content-analysis"

mkdir -p "$CONTENT_DIR"

log_entry() {
  local msg=$1
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $msg" >> "$PROCESSOR_LOG"
}

# Função: transcrever vídeo
transcribe_video() {
  local video_url=$1
  local video_id=$(echo "$video_url" | grep -oP 'v=\K[^&]+')
  
  log_entry "Transcrevendo: $video_id"
  
  # Usa summarize CLI pra extrair transcrição
  summarize "$video_url" --youtube auto --extract-only 2>/dev/null
}

# Função: traduzir usando LLM (Gemini Flash gratuito)
translate_with_llm() {
  local text=$1
  local from_lang=$2
  local to_lang=$3
  
  # Usa API do Gemini via OpenClaw
  # (simplificado - em produção usaria função própria)
  echo "[TRADUÇÃO] Converte $from_lang → $to_lang"
  echo "$text"
}

# Função: extrair insights com LLM
extract_insights() {
  local transcript=$1
  local channel=$2
  
  log_entry "Extraindo insights de $channel"
  
  # Prompt pra LLM extrair conhecimento
  cat > "$CONTENT_DIR/$channel-prompt.txt" <<PROMPT_EOF
Analise esta transcrição e extraia:
1. Tema principal
2. 5 conceitos-chave
3. Ferramentas/tecnologias mencionadas
4. Relevância para Wolf Agency
5. Ações recomendadas

Transcrição:
$transcript
PROMPT_EOF

  log_entry "Prompt criado em $CONTENT_DIR/$channel-prompt.txt"
}

# MAIN FLOW
# ─────────────────────────────────────────────────────────

# Verificar alerts pendentes
PENDING_ALERTS=$(ls "$WORKSPACE/memory/.youtube-alert-"* 2>/dev/null | wc -l)

if [ "$PENDING_ALERTS" -eq 0 ]; then
  log_entry "Nenhum vídeo novo pra processar"
  exit 0
fi

log_entry "Processando $PENDING_ALERTS vídeo(s)..."

# Processar cada alert
for alert_file in "$WORKSPACE/memory/.youtube-alert-"*; do
  [ ! -f "$alert_file" ] && continue
  
  CHANNEL=$(basename "$alert_file" | sed 's/\.youtube-alert-//')
  VIDEO_URL=$(grep "URL:" "$alert_file" | cut -d' ' -f2)
  LANGUAGE=$(grep "Idioma Original:" "$alert_file" | cut -d' ' -f3)
  TRANSLATE_TO=$(grep "Idioma Alvo:" "$alert_file" | cut -d' ' -f3)
  
  log_entry "Processando: $CHANNEL"
  
  # 1. TRANSCREVER
  TRANSCRIPT=$(transcribe_video "$VIDEO_URL")
  
  if [ -z "$TRANSCRIPT" ]; then
    log_entry "ERRO: Não conseguiu transcrever $CHANNEL"
    continue
  fi
  
  # 2. TRADUZIR (se necessário)
  if [ ! -z "$TRANSLATE_TO" ] && [ "$LANGUAGE" != "$TRANSLATE_TO" ]; then
    log_entry "Traduzindo $LANGUAGE → $TRANSLATE_TO"
    TRANSCRIPT=$(translate_with_llm "$TRANSCRIPT" "$LANGUAGE" "$TRANSLATE_TO")
  fi
  
  # 3. EXTRAIR INSIGHTS
  extract_insights "$TRANSCRIPT" "$CHANNEL"
  
  # 4. SALVAR TRANSCRIÇÃO
  TRANSCRIPT_FILE="$CONTENT_DIR/${CHANNEL}-$(date +%Y%m%d-%H%M%S).md"
  cat > "$TRANSCRIPT_FILE" <<EOF
# Análise: $CHANNEL
**Data:** $(date '+%Y-%m-%d %H:%M:%S')  
**URL:** $VIDEO_URL  
**Idioma:** $LANGUAGE → $TRANSLATE_TO

## Transcrição

$TRANSCRIPT

---
Status: Aguardando validação por Netto
EOF

  log_entry "Salvo em: $TRANSCRIPT_FILE"
  
  # 5. LIMPAR ALERT
  rm "$alert_file"
  log_entry "Alert processado e removido"
done

log_entry "Processamento completo"
exit 0
