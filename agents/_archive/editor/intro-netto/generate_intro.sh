#!/bin/bash

# Cria intro animada usando FFmpeg
# Estilo: tecnológico/futurista

OUTPUT="out/intro_netto_girotto.mp4"
DURATION=5
FPS=30
WIDTH=1920
HEIGHT=1080
TOTAL_FRAMES=$((DURATION * FPS))

mkdir -p frames

# Gera frames com texto animado
for i in $(seq 0 $((TOTAL_FRAMES - 1))); do
    FRAME_NUM=$(printf "%04d" $i)
    
    # Calcula progresso (0.0 a 1.0)
    PROGRESS=$(echo "scale=4; $i / $TOTAL_FRAMES" | bc -l)
    
    # Opacidade do texto (fade in nas primeiras 20 frames)
    if [ $i -lt 20 ]; then
        OPACITY=$(echo "scale=2; $i / 20" | bc -l)
    else
        OPACITY=1
    fi
    
    # Efeito de scan line
    SCAN_Y=$(echo "scale=0; 200 + ($i * 20) % 880" | bc)
    
    ffmpeg -y -f lavfi -i color=c=#0a0a0f:s=${WIDTH}x${HEIGHT}:d=1 \
        -vf "
        drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:
        text='NETTO GIROTTO':
        fontsize=80:
        fontcolor=white@$OPACITY:
        x=(w-text_w)/2:
        y=(h-text_h)/2:
        shadowcolor=#00d4ff@0.8:
        shadowx=3:shadowy=3,
        drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:
        text='MARKETING DIGITAL':
        fontsize=24:
        fontcolor=#00d4ff@$OPACITY:
        x=(w-text_w)/2:
        y=(h/2)+60:
        enable='gte(t,1)',
        drawbox=x=0:y=$SCAN_Y:w=iw:h=2:color=#00d4ff@0.5:t=fill:enable='lt(mod($i,30),5)'
        " \
        -frames:v 1 "frames/frame_$FRAME_NUM.png" 2>/dev/null
        
    echo -ne "\rFrame $i/$TOTAL_FRAMES"
done

echo ""
echo "Compilando vídeo..."

# Compila frames em vídeo
ffmpeg -y -framerate $FPS -i frames/frame_%04d.png \
    -c:v libx264 -pix_fmt yuv420p -crf 18 "$OUTPUT"

# Limpa frames temporários
rm -rf frames

echo "Vídeo criado: $OUTPUT"
