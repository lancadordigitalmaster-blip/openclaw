#!/bin/bash
# Wolf Shorts Factory — Análise Viral Automática
# Uso: ./analyze_viral.sh <video_url_ou_path> [quantidade_de_clips]
# Ex:  ./analyze_viral.sh "https://youtu.be/xxx" 5

set -e

VIDEO_INPUT="$1"
CLIP_COUNT="${2:-5}"
OUTPUT_DIR="${HOME}/Desktop/wolf-shorts"
TMP_DIR="$OUTPUT_DIR/tmp_analysis"
WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"

mkdir -p "$TMP_DIR"

echo "🐺 Wolf Shorts — Análise Viral Automática"
echo "🎯 Buscando os $CLIP_COUNT melhores momentos virais..."
echo ""

# --- FASE 1: DOWNLOAD ---
if [[ "$VIDEO_INPUT" == http* ]]; then
  echo "⬇️  Baixando vídeo..."
  yt-dlp -o "$TMP_DIR/source.%(ext)s" \
    --merge-output-format mp4 \
    "$VIDEO_INPUT" 2>/dev/null
  SOURCE_FILE=$(ls "$TMP_DIR/source."* 2>/dev/null | head -1)
else
  SOURCE_FILE="$VIDEO_INPUT"
fi

echo "✅ Fonte: $SOURCE_FILE"

# --- FASE 2: TRANSCRIÇÃO COM TIMESTAMPS ---
echo ""
echo "🎙️  Transcrevendo com timestamps por palavra..."

whisper "$SOURCE_FILE" \
  --model base \
  --language Portuguese \
  --word_timestamps True \
  --output_format json \
  --output_dir "$TMP_DIR/" 2>/dev/null

# Encontrar o JSON gerado
JSON_FILE=$(ls "$TMP_DIR/"*.json 2>/dev/null | head -1)

if [ ! -f "$JSON_FILE" ]; then
  echo "❌ Erro na transcrição"
  exit 1
fi

echo "✅ Transcrição concluída"

# --- FASE 3: CONVERTER JSON → TRANSCRIPT FORMATADO COM TIMESTAMPS ---
echo ""
echo "📝 Formatando transcript com timestamps..."

TRANSCRIPT_FILE="$TMP_DIR/transcript_timestamped.txt"

python3 << EOF
import json, sys

with open("$JSON_FILE") as f:
    data = json.load(f)

lines = []
for seg in data.get("segments", []):
    start = seg["start"]
    end = seg["end"]
    text = seg["text"].strip()
    # Formatar timestamp HH:MM:SS
    def fmt(s):
        h = int(s//3600)
        m = int((s%3600)//60)
        sec = int(s%60)
        return f"{h:02d}:{m:02d}:{sec:02d}"
    lines.append(f"[{fmt(start)} → {fmt(end)}] {text}")

with open("$TRANSCRIPT_FILE", "w") as f:
    f.write("\n".join(lines))

print(f"Total de segmentos: {len(lines)}")
EOF

echo "✅ Transcript formatado: $TRANSCRIPT_FILE"

# --- FASE 4: ANÁLISE VIRAL VIA LLM ---
echo ""
echo "🧠 Analisando momentos virais com IA..."

ANALYSIS_FILE="$TMP_DIR/viral_analysis.json"
TRANSCRIPT_CONTENT=$(cat "$TRANSCRIPT_FILE")

# Chamar Alfred via gateway para análise
PROMPT="Você é um especialista em conteúdo viral para TikTok, Reels e YouTube Shorts.

Analise este transcript de vídeo e identifique os $CLIP_COUNT momentos com maior potencial viral.

CRITÉRIOS DE VIRALIDADE (ordene por potencial):
- Hook forte nos primeiros 2s (pergunta, dado chocante, conflito)
- Momento de surpresa ou revelação
- Dado ou número impactante
- Opinião forte ou controversa
- História com pico emocional
- Insight acionável e raro
- One-liner memorável e quotável
- Momento de tensão ou resolução

TRANSCRIPT:
$TRANSCRIPT_CONTENT

Retorne APENAS um JSON válido neste formato (sem texto antes ou depois):
{
  \"clips\": [
    {
      \"rank\": 1,
      \"start\": \"00:02:30\",
      \"end\": \"00:03:15\",
      \"duracao_segundos\": 45,
      \"viral_score\": 9.2,
      \"motivo_viral\": \"Dado chocante + revelação inesperada\",
      \"hook\": \"Você vai perder dinheiro se continuar fazendo isso\",
      \"caption\": \"Texto da legenda do post\",
      \"hashtags\": \"#marketing #empreendedorismo #viral\",
      \"tipo\": \"revelação|dado|conflito|historia|insight|oneliners\"
    }
  ]
}"

# Salvar prompt para o Alfred processar
echo "$PROMPT" > "$TMP_DIR/viral_prompt.txt"
echo "$ANALYSIS_FILE" > "$TMP_DIR/analysis_output_path.txt"

echo ""
echo "📊 Prompt salvo. Alfred vai processar e retornar os melhores momentos."
echo "📁 Transcript: $TRANSCRIPT_FILE"
echo "📁 Prompt: $TMP_DIR/viral_prompt.txt"
echo ""
echo "✅ Análise pronta para processamento LLM"
cat "$TRANSCRIPT_FILE"
EOF
