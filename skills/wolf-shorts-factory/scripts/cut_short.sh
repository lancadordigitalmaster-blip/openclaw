#!/bin/bash
# Wolf Shorts Factory — Script de Corte e Edição
# Uso: ./cut_short.sh <video_url_ou_path> <inicio> <fim> [nome_saida]
# Ex:  ./cut_short.sh "https://youtu.be/xxx" "00:02:30" "00:05:00" "short_01"

set -e

VIDEO_INPUT="$1"
START="$2"
END="$3"
OUTPUT_NAME="${4:-short_$(date +%H%M%S)}"
OUTPUT_DIR="${HOME}/Desktop/wolf-shorts"
WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/tmp"

echo "🐺 Wolf Shorts Factory iniciando..."
echo "📥 Input: $VIDEO_INPUT"
echo "⏱️  Corte: $START → $END"
echo "📁 Output: $OUTPUT_DIR/$OUTPUT_NAME"

# --- FASE 1: DOWNLOAD (se for URL) ---
if [[ "$VIDEO_INPUT" == http* ]]; then
  echo ""
  echo "⬇️  Baixando vídeo..."
  yt-dlp -o "$OUTPUT_DIR/tmp/source.%(ext)s" \
    --merge-output-format mp4 \
    "$VIDEO_INPUT"
  SOURCE_FILE=$(ls "$OUTPUT_DIR/tmp/source."* 2>/dev/null | head -1)
else
  SOURCE_FILE="$VIDEO_INPUT"
fi

echo "✅ Fonte: $SOURCE_FILE"

# --- FASE 2: CORTE ---
echo ""
echo "✂️  Cortando clipe $START → $END..."
CLIP_FILE="$OUTPUT_DIR/tmp/${OUTPUT_NAME}_raw.mp4"

ffmpeg -y -ss "$START" -to "$END" -i "$SOURCE_FILE" \
  -c:v libx264 -c:a aac -preset fast \
  "$CLIP_FILE" 2>/dev/null

echo "✅ Clipe cortado: $(du -sh "$CLIP_FILE" | cut -f1)"

# --- FASE 3: CONVERTER PARA 9:16 (1080x1920) ---
echo ""
echo "📐 Convertendo para 9:16 vertical (1080x1920)..."
VERTICAL_FILE="$OUTPUT_DIR/tmp/${OUTPUT_NAME}_vertical.mp4"

# Detecta resolução original
ORIG_W=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$CLIP_FILE")
ORIG_H=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$CLIP_FILE")

echo "   Resolução original: ${ORIG_W}x${ORIG_H}"

# Se já for vertical, não converte
if [ "$ORIG_H" -gt "$ORIG_W" ]; then
  echo "   Já é vertical, apenas redimensionando..."
  ffmpeg -y -i "$CLIP_FILE" \
    -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
    -c:v libx264 -c:a aac -preset fast \
    "$VERTICAL_FILE" 2>/dev/null
else
  echo "   Convertendo horizontal → vertical (crop central)..."
  ffmpeg -y -i "$CLIP_FILE" \
    -vf "crop=ih*9/16:ih,scale=1080:1920" \
    -c:v libx264 -c:a aac -preset fast \
    "$VERTICAL_FILE" 2>/dev/null
fi

echo "✅ Vertical pronto"

# --- FASE 4: LEGENDAS ---
echo ""
echo "💬 Gerando transcrição e legendas..."
SRT_FILE="$OUTPUT_DIR/tmp/${OUTPUT_NAME}.srt"

whisper "$VERTICAL_FILE" \
  --model base \
  --language Portuguese \
  --word_timestamps True \
  --max_words_per_line 4 \
  --output_format srt \
  --output_dir "$OUTPUT_DIR/tmp/" 2>/dev/null

# Renomear SRT gerado
GENERATED_SRT=$(ls "$OUTPUT_DIR/tmp/"*vertical*.srt 2>/dev/null | head -1)
if [ -f "$GENERATED_SRT" ]; then
  mv "$GENERATED_SRT" "$SRT_FILE"
  echo "✅ Legendas geradas: $SRT_FILE"
fi

# --- FASE 5: QUEIMAR LEGENDAS NO VÍDEO ---
echo ""
echo "🔥 Queimando legendas estilo CapCut..."
FINAL_FILE="$OUTPUT_DIR/${OUTPUT_NAME}_final.mp4"

if [ -f "$SRT_FILE" ]; then
  ffmpeg -y -i "$VERTICAL_FILE" \
    -vf "subtitles=${SRT_FILE}:force_style='FontName=Arial Black,FontSize=16,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=3,Shadow=2,Alignment=2,MarginV=120'" \
    -c:v libx264 -c:a aac -preset fast \
    "$FINAL_FILE" 2>/dev/null
else
  echo "⚠️  Sem legendas, exportando sem elas..."
  cp "$VERTICAL_FILE" "$FINAL_FILE"
fi

# --- FASE 6: FADE IN/OUT ---
echo ""
echo "✨ Adicionando fade in/out..."
FADE_FILE="$OUTPUT_DIR/${OUTPUT_NAME}_with_fade.mp4"
DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$FINAL_FILE" | cut -d. -f1)
FADE_START=$((DURATION - 1))

ffmpeg -y -i "$FINAL_FILE" \
  -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=${FADE_START}:d=1" \
  -af "afade=t=in:st=0:d=0.5,afade=t=out:st=${FADE_START}:d=1" \
  -c:v libx264 -c:a aac -preset fast \
  "$FADE_FILE" 2>/dev/null

# Substituir arquivo final
mv "$FADE_FILE" "$FINAL_FILE"

# --- RESULTADO ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SHORT PRONTO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Arquivo: $FINAL_FILE"
echo "📊 Tamanho: $(du -sh "$FINAL_FILE" | cut -f1)"
echo "⏱️  Duração: ${DURATION}s"
echo "📐 Formato: 1080x1920 (9:16)"
echo ""
if [ -f "$SRT_FILE" ]; then
  echo "📝 Legendas: $SRT_FILE"
fi
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -rf "$OUTPUT_DIR/tmp"
echo "✅ Pronto para publicar!"
