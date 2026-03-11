#!/bin/bash
# video-analyze-deep.sh — Análise profunda de vídeo de referência
# Uso: video analyze-deep [arquivo]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VIDEO_FILE="$1"

if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    echo -e "${RED}❌ Uso: video analyze-deep [arquivo-de-video]${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 ANÁLISE PROFUNDA DE VÍDEO${NC}"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Arquivo: $(basename "$VIDEO_FILE")"
echo ""

# Informações básicas
echo -e "${BLUE}📊 INFORMAÇÕES TÉCNICAS${NC}"
echo "────────────────────────────────────────────────────"

DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'.' -f1 | tr -d ',')
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | tr -d ',')
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | tr -d ',')
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'/' -f1 | tr -d ',')
BITRATE=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | tr -d ',')
CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | tr -d ',')

DURATION=${DURATION:-0}
WIDTH=${WIDTH:-0}
HEIGHT=${HEIGHT:-0}
FPS=${FPS:-0}
BITRATE=${BITRATE:-0}
CODEC=${CODEC:-"unknown"}

echo "• Resolução: ${WIDTH}x${HEIGHT}"
echo "• Duração: ${DURATION} segundos"
echo "• Frame rate: ${FPS} fps"
echo "• Codec: $CODEC"

if [ "$BITRATE" -gt 0 ]; then
    BITRATE_MBPS=$((BITRATE / 1000000))
    echo "• Bitrate: ${BITRATE_MBPS} Mbps"
fi

# Detectar proporção
if [ "$WIDTH" -eq "$HEIGHT" ]; then
    echo "• Proporção: 1:1 (Quadrado)"
    FORMATO_SUGERIDO="feed"
elif [ "$WIDTH" -eq 1920 ] && [ "$HEIGHT" -eq 1080 ]; then
    echo "• Proporção: 16:9 (Horizontal — YouTube/Ads)"
    FORMATO_SUGERIDO="youtube"
elif [ "$WIDTH" -eq 1080 ] && [ "$HEIGHT" -eq 1920 ]; then
    echo "• Proporção: 9:16 (Vertical — Reels/Stories)"
    FORMATO_SUGERIDO="short"
elif [ "$WIDTH" -eq 1080 ] && [ "$HEIGHT" -eq 1350 ]; then
    echo "• Proporção: 4:5 (Feed Instagram)"
    FORMATO_SUGERIDO="feed"
else
    echo "• Proporção: Custom (${WIDTH}:${HEIGHT})"
    FORMATO_SUGERIDO="custom"
fi

echo ""

# Análise de cenas (extrair frames-chave)
echo -e "${BLUE}🎬 ANÁLISE DE ESTRUTURA${NC}"
echo "────────────────────────────────────────────────────"

if [ "$DURATION" -gt 0 ]; then
    # Extrair 5 frames-chave
    INTERVAL=$((DURATION / 5))
    
    echo "Frames-chave extraídos:"
    for i in 0 1 2 3 4; do
        TIME=$((i * INTERVAL))
        if [ "$TIME" -lt "$DURATION" ]; then
            printf "  • %02d:%02d — " $((TIME/60)) $((TIME%60))
            
            # Detectar mudanças significativas
            if [ "$i" -eq 0 ]; then
                echo "Hook/Abertura"
            elif [ "$i" -eq 4 ]; then
                echo "CTA/Final"
            else
                echo "Cena $i"
            fi
        fi
    done
fi

echo ""

# Sugestões de recriação
echo -e "${BLUE}💡 SUGESTÕES PARA RECRIAR NO REMOTION${NC}"
echo "────────────────────────────────────────────────────"

echo ""
echo "1. ESPECIFICAÇÃO TÉCNICA:"
echo "   • Duração: ${DURATION}s"
echo "   • Resolução: ${WIDTH}x${HEIGHT}"
echo "   • FPS: ${FPS}"
echo ""

echo "2. PROMPT PARA RECRIAR:"
echo "   Crie um vídeo de ${DURATION}s no formato ${FORMATO_SUGERIDO}."
echo "   Resolução: ${WIDTH}x${HEIGHT}."
echo "   Analisar o vídeo de referência e extrair:"
echo "   • Paleta de cores dominantes"
echo "   • Tipo de motion (suave/energético/cinemático)"
echo "   • Estrutura de cenas"
echo "   • Timing de transições"
echo "   • Estilo de texto/legendas"
echo ""

echo "3. COMANDO PARA EXTRAIR FRAMES:"
echo "   ffmpeg -i $(basename "$VIDEO_FILE") -vf fps=1/5 frame_%03d.jpg"
echo ""

# Extrair paleta de cores (simplificado)
echo -e "${BLUE}🎨 ANÁLISE DE CORES (Estimativa)${NC}"
echo "────────────────────────────────────────────────────"
echo "Para extrair paleta exata:"
echo "  ffmpeg -i $(basename "$VIDEO_FILE") -vf 'fps=1,scale=100:-1' frames.jpg"
echo "  # Depois usar ferramenta de extração de cor"
echo ""

# Verificar áudio
echo -e "${BLUE}🔊 INFORMAÇÕES DE ÁUDIO${NC}"
echo "────────────────────────────────────────────────────"

AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$VIDEO_FILE" 2>/dev/null)
AUDIO_BITRATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of csv=p=0 "$VIDEO_FILE" 2>/dev/null)

if [ ! -z "$AUDIO_CODEC" ]; then
    echo "• Codec de áudio: $AUDIO_CODEC"
    if [ ! -z "$AUDIO_BITRATE" ]; then
        AUDIO_KBPS=$((AUDIO_BITRATE / 1000))
        echo "• Bitrate de áudio: ${AUDIO_KBPS} kbps"
    fi
else
    echo "• Sem áudio detectado"
fi

echo ""
echo -e "${GREEN}✅ Análise completa!${NC}"
echo ""
echo -e "${YELLOW}💡 Próximo passo: Use 'video spec ${FORMATO_SUGERIDO} [objetivo]'${NC}"
echo "   para criar especificação baseada nesta referência."
