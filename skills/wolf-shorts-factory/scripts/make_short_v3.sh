#!/bin/bash
# Wolf Shorts Factory v3 — Pipeline completo
# Blur BG + Legendas + SFX + Fade
# Uso: ./make_short_v3.sh <source.mp4> <start_sec> <end_sec> <output_name> <sfx_type>

set -e
FFMPEG=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
FFPROBE=/opt/homebrew/opt/ffmpeg-full/bin/ffprobe
SOURCE="$1"; START="$2"; END="$3"; NAME="$4"; SFX_TYPE="${5:-impact}"
OUT=~/Desktop/wolf-shorts
TMP=$(mktemp -d)
SFX_DIR=~/Desktop/wolf-shorts/sfx

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 Wolf Shorts v3 — $NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. CORTAR
echo "✂️  [1/5] Cortando ${START}s → ${END}s..."
$FFMPEG -y -ss "$START" -to "$END" -i "$SOURCE" \
  -c:v libx264 -c:a aac -preset fast "$TMP/raw.mp4" 2>/dev/null

W=$($FFPROBE -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "$TMP/raw.mp4")
H=$($FFPROBE -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "$TMP/raw.mp4")
DUR=$($FFPROBE -v quiet -show_entries format=duration -of csv=p=0 "$TMP/raw.mp4" | cut -d. -f1)
FADE_OUT=$((DUR - 1))
SCALE_H=$((H * 1080 / W))
OV_Y=$(( (1920 - SCALE_H) / 2 ))

# 2. BLUR BACKGROUND + 9:16
echo "📐 [2/5] Convertendo 9:16 com fundo desfocado..."
$FFMPEG -y -i "$TMP/raw.mp4" -filter_complex \
  "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=25:5[bg];
   [0:v]scale=1080:${SCALE_H}[fg];
   [bg][fg]overlay=0:${OV_Y}[v];
   [0:a]acopy[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -c:a aac -preset fast "$TMP/blurred.mp4" 2>/dev/null
echo "   ✅ Blur OK (${W}x${H} → 1080x1920)"

# 3. LEGENDAS com libass (ffmpeg-full)
echo "💬 [3/5] Transcrevendo e gerando legendas..."
whisper "$TMP/raw.mp4" --model base --language Portuguese \
  --word_timestamps True --max_words_per_line 4 \
  --output_format srt --output_dir "$TMP/" 2>/dev/null

SRT=$(ls "$TMP/"*.srt 2>/dev/null | head -1)
if [ -f "$SRT" ]; then
  # Criar ASS estilizado
  python3 - <<PYEOF
import re
with open("$SRT") as f:
    content = f.read()
header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial Black,62,&H00FFFFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,4,2,2,40,40,160,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
def ts(t):
    t = t.replace(',','.')
    return t
events = []
for block in re.split(r'\n\n+', content.strip()):
    lines = block.strip().split('\n')
    if len(lines) < 3: continue
    m = re.match(r'(\S+) --> (\S+)', lines[1])
    if m:
        text = ' '.join(lines[2:])
        text = re.sub(r'<[^>]+>', '', text).strip()
        text = text.replace('{','[').replace('}',']')
        events.append(f"Dialogue: 0,{ts(m.group(1))},{ts(m.group(2))},Default,,0,0,0,,{text}")
with open("$TMP/subs.ass", 'w') as f:
    f.write(header + '\n'.join(events))
print(f"  ASS: {len(events)} legendas geradas")
PYEOF

  echo "🔥 Queimando legendas..."
  $FFMPEG -y -i "$TMP/blurred.mp4" \
    -vf "ass=$TMP/subs.ass" \
    -c:v libx264 -c:a aac -preset fast "$TMP/with_subs.mp4" 2>/dev/null
  echo "   ✅ Legendas OK"
  VIDEO_IN="$TMP/with_subs.mp4"
else
  echo "   ⚠️ Sem legendas — continuando"
  VIDEO_IN="$TMP/blurred.mp4"
fi

# 4. SFX + FADE
echo "🔊 [4/5] Adicionando SFX ($SFX_TYPE) + fade..."
SFX_FILE="$SFX_DIR/${SFX_TYPE}.wav"
if [ -f "$SFX_FILE" ]; then
  # Adicionar SFX no segundo 1 (início do conteúdo)
  $FFMPEG -y -i "$VIDEO_IN" -i "$SFX_FILE" -filter_complex \
    "[1:a]adelay=800|800,volume=0.35[sfx];
     [0:a][sfx]amix=inputs=2:duration=first:dropout_transition=0[aout];
     [0:v]fade=t=in:st=0:d=0.4,fade=t=out:st=${FADE_OUT}:d=0.8[vout];
     [aout]afade=t=in:st=0:d=0.4,afade=t=out:st=${FADE_OUT}:d=0.8[afout]" \
    -map "[vout]" -map "[afout]" \
    -c:v libx264 -c:a aac -preset fast "$OUT/${NAME}.mp4" 2>/dev/null
else
  $FFMPEG -y -i "$VIDEO_IN" \
    -vf "fade=t=in:st=0:d=0.4,fade=t=out:st=${FADE_OUT}:d=0.8" \
    -af "afade=t=in:st=0:d=0.4,afade=t=out:st=${FADE_OUT}:d=0.8" \
    -c:v libx264 -c:a aac -preset fast "$OUT/${NAME}.mp4" 2>/dev/null
fi

# 5. RESULTADO
SIZE=$(du -sh "$OUT/${NAME}.mp4" | cut -f1)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PRONTO: $NAME.mp4"
echo "   Tamanho: $SIZE | Duração: ${DUR}s | Formato: 1080x1920"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rm -rf "$TMP"
