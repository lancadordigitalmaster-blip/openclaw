#!/bin/bash
# video-tools.sh — Ferramentas gratuitas de vídeo (FFmpeg)
# Uso: source video-tools.sh ou ./video-tools.sh [comando]

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função: Analisar vídeo com FFmpeg
analyze_video() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Arquivo não encontrado: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🎬 ANÁLISE TÉCNICA — $(basename "$file")${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    # Informações básicas
    echo "📊 INFORMAÇÕES GERAIS:"
    echo "────────────────────────────────────────────────────"
    ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate -of default=noprint_wrappers=1 "$file" 2>/dev/null | while read line; do
        case "$line" in
            *duration=*) echo "• Duração: $(echo "$line" | cut -d= -f2 | awk '{printf "%.2f segundos", $1}')" ;;
            *size=*) echo "• Tamanho: $(echo "$line" | cut -d= -f2 | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "$(echo "$line" | cut -d= -f2) bytes")" ;;
            *bit_rate=*) echo "• Bitrate: $(echo "$line" | cut -d= -f2 | awk '{printf "%.0f kbps", $1/1000}')" ;;
            *width=*) width=$(echo "$line" | cut -d= -f2) ;;
            *height=*) height=$(echo "$line" | cut -d= -f2) ;;
            *codec_name=*) echo "• Codec: $(echo "$line" | cut -d= -f2)" ;;
            *r_frame_rate=*) 
                fps=$(echo "$line" | cut -d= -f2)
                if [[ "$fps" == *"/"* ]]; then
                    num=$(echo "$fps" | cut -d/ -f1)
                    den=$(echo "$fps" | cut -d/ -f2)
                    fps=$(echo "scale=2; $num/$den" | bc 2>/dev/null || echo "$fps")
                fi
                echo "• Frame rate: ${fps} fps"
                ;;
        esac
    done
    
    # Resolução
    if [ ! -z "$width" ] && [ ! -z "$height" ]; then
        echo "• Resolução: ${width}x${height}"
        
        # Detectar proporção
        if [ "$width" -eq "$height" ]; then
            aspect="1:1 (Quadrado)"
        elif [ "$((width * 16))" -eq "$((height * 9))" ]; then
            aspect="16:9 (Horizontal)"
        elif [ "$((width * 9))" -eq "$((height * 16))" ]; then
            aspect="9:16 (Vertical)"
        elif [ "$((width * 4))" -eq "$((height * 5))" ]; then
            aspect="4:5 (Feed)"
        else
            aspect="Custom"
        fi
        echo "• Proporção: $aspect"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Análise completa!${NC}"
}

# Função: Extrair thumbnail
extract_thumbnail() {
    local file="$1"
    local time="${2:-00:00:01}"
    local output="${3:-thumbnail.jpg}"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Arquivo não encontrado: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🖼️  Extraindo thumbnail...${NC}"
    ffmpeg -i "$file" -ss "$time" -vframes 1 -q:v 2 "$output" -y 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Thumbnail salvo: $output${NC}"
    else
        echo -e "${RED}❌ Erro ao extrair thumbnail${NC}"
    fi
}

# Função: Converter para formato
convert_video() {
    local input="$1"
    local format="${2:-mp4}"
    local output="${input%.*}_converted.$format"
    
    if [ ! -f "$input" ]; then
        echo -e "${RED}❌ Arquivo não encontrado: $input${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Convertendo para $format...${NC}"
    
    case "$format" in
        mp4)
            ffmpeg -i "$input" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k "$output" -y 2>/dev/null
            ;;
        webm)
            ffmpeg -i "$input" -c:v libvpx-vp9 -crf 30 -b:v 0 -c:a libopus "$output" -y 2>/dev/null
            ;;
        gif)
            ffmpeg -i "$input" -vf "fps=30,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" "$output" -y 2>/dev/null
            ;;
        *)
            ffmpeg -i "$input" "$output" -y 2>/dev/null
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Convertido: $output${NC}"
    else
        echo -e "${RED}❌ Erro na conversão${NC}"
    fi
}

# Função: Otimizar para web
optimize_web() {
    local input="$1"
    local output="${input%.*}_web.mp4"
    
    if [ ! -f "$input" ]; then
        echo -e "${RED}❌ Arquivo não encontrado: $input${NC}"
        return 1
    fi
    
    echo -e "${BLUE}⚡ Otimizando para web...${NC}"
    echo "   (H.264, 1080p, bitrate adaptativo)"
    
    ffmpeg -i "$input" \
        -c:v libx264 \
        -preset slow \
        -crf 23 \
        -maxrate 5M \
        -bufsize 10M \
        -vf "scale=-2:1080" \
        -c:a aac \
        -b:a 128k \
        -movflags +faststart \
        "$output" -y 2>/dev/null
    
    if [ $? -eq 0 ]; then
        original_size=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input" 2>/dev/null)
        new_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
        
        echo -e "${GREEN}✅ Otimizado: $output${NC}"
        echo "   Original: $(echo "$original_size" | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "${original_size} bytes")"
        echo "   Novo: $(echo "$new_size" | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "${new_size} bytes")"
    else
        echo -e "${RED}❌ Erro na otimização${NC}"
    fi
}

# Função: Cortar vídeo
trim_video() {
    local input="$1"
    local start="$2"
    local duration="$3"
    local output="${input%.*}_trimmed.mp4"
    
    if [ ! -f "$input" ]; then
        echo -e "${RED}❌ Arquivo não encontrado: $input${NC}"
        return 1
    fi
    
    echo -e "${BLUE}✂️  Cortando vídeo...${NC}"
    echo "   Início: $start | Duração: $duration"
    
    ffmpeg -i "$input" -ss "$start" -t "$duration" -c copy "$output" -y 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Cortado: $output${NC}"
    else
        echo -e "${RED}❌ Erro no corte${NC}"
    fi
}

# Menu principal
show_menu() {
    echo -e "${BLUE}🎬 VIDEO TOOLS — Ferramentas FFmpeg (Gratuitas)${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Comandos:"
    echo ""
    echo "  analyze [arquivo]              Análise técnica completa"
    echo "  thumbnail [arquivo] [tempo]    Extrair thumbnail"
    echo "  convert [arquivo] [formato]    Converter formato"
    echo "  optimize [arquivo]             Otimizar para web"
    echo "  trim [arquivo] [início] [dur]  Cortar vídeo"
    echo "  help                           Mostrar ajuda"
    echo ""
    echo "Exemplos:"
    echo "  video-tools analyze meu-video.mp4"
    echo "  video-tools thumbnail video.mp4 00:00:05"
    echo "  video-tools convert video.mov mp4"
    echo "  video-tools optimize video.mp4"
    echo "  video-tools trim video.mp4 00:00:10 00:00:30"
    echo ""
}

# Execução principal
case "${1:-help}" in
    analyze)
        analyze_video "$2"
        ;;
    thumbnail)
        extract_thumbnail "$2" "$3" "$4"
        ;;
    convert)
        convert_video "$2" "$3"
        ;;
    optimize)
        optimize_web "$2"
        ;;
    trim)
        trim_video "$2" "$3" "$4"
        ;;
    help|*)
        show_menu
        ;;
esac
