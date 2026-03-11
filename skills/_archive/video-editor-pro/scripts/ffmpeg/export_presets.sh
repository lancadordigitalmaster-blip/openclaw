#!/bin/bash
# Export Presets — Video Editor Pro
# Wolf Agency
# Presets FFmpeg para diferentes plataformas

# Diretório de saída
OUTPUT_DIR="${OUTPUT_DIR:-./output}"
mkdir -p "$OUTPUT_DIR"

# ============================================
# PRESET: Reels/Stories (Instagram/TikTok)
# ============================================
preset_reels() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/reels_$(basename "$input")}"
    
    ffmpeg -y -i "$input" \
        -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -profile:v high -level 4.2 \
        -b:v 12M -maxrate 16M -bufsize 24M \
        -r 30 -pix_fmt yuv420p \
        -c:a aac -b:a 320k -ar 48000 \
        -movflags +faststart \
        "$output"
    
    echo "✅ Reels: $output"
}

# ============================================
# PRESET: YouTube/VSL (Full HD)
# ============================================
preset_youtube() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/youtube_$(basename "$input")}"
    
    ffmpeg -y -i "$input" \
        -c:v libx264 -profile:v high -level 4.2 \
        -b:v 20M -maxrate 25M -bufsize 35M \
        -r 30 -pix_fmt yuv420p \
        -c:a aac -b:a 320k -ar 48000 \
        -movflags +faststart \
        "$output"
    
    echo "✅ YouTube: $output"
}

# ============================================
# PRESET: Master (ProRes para arquivamento)
# ============================================
preset_master() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/master_$(basename "$input" .mp4).mov}"
    
    ffmpeg -y -i "$input" \
        -c:v prores_ks -profile:v 2 \
        -c:a pcm_s24le -ar 48000 \
        "$output"
    
    echo "✅ Master: $output"
}

# ============================================
# PRESET: Review (Compressão leve)
# ============================================
preset_review() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/review_$(basename "$input")}"
    
    ffmpeg -y -i "$input" \
        -c:v libx264 -profile:v main -level 3.1 \
        -b:v 4M -maxrate 5M -bufsize 8M \
        -r 30 -pix_fmt yuv420p \
        -vf "scale=-2:720" \
        -c:a aac -b:a 128k -ar 48000 \
        -movflags +faststart \
        "$output"
    
    echo "✅ Review: $output"
}

# ============================================
# PRESET: Thumbnail (1º frame)
# ============================================
preset_thumbnail() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/thumb_$(basename "$input" .mp4).jpg}"
    
    ffmpeg -y -i "$input" \
        -ss 00:00:01 \
        -vframes 1 \
        -q:v 2 \
        "$output"
    
    echo "✅ Thumbnail: $output"
}

# ============================================
# PRESET: GIF Preview
# ============================================
preset_gif() {
    local input="$1"
    local output="${2:-$OUTPUT_DIR/preview_$(basename "$input" .mp4).gif}"
    
    ffmpeg -y -i "$input" \
        -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=64[p];[s1][p]paletteuse=dither=bayer" \
        -loop 0 \
        "$output"
    
    echo "✅ GIF: $output"
}

# ============================================
# USO
# ============================================
usage() {
    echo "Uso: $0 <preset> <input> [output]"
    echo ""
    echo "Presets disponíveis:"
    echo "  reels     - Instagram Reels/Stories (1080x1920)"
    echo "  youtube   - YouTube/VSL (1920x1080)"
    echo "  master    - ProRes 422 (arquivamento)"
    echo "  review    - Compressão leve (review)"
    echo "  thumb     - Thumbnail JPG"
    echo "  gif       - GIF animado (preview)"
    echo "  all       - Gera todos os formatos"
    echo ""
    echo "Exemplo:"
    echo "  $0 reels meuvideo.mp4"
    echo "  $0 all meuvideo.mp4"
}

# ============================================
# MAIN
# ============================================
main() {
    if [ $# -lt 2 ]; then
        usage
        exit 1
    fi
    
    local preset="$1"
    local input="$2"
    local output="${3:-}"
    
    if [ ! -f "$input" ]; then
        echo "❌ Arquivo não encontrado: $input"
        exit 1
    fi
    
    case "$preset" in
        reels)
            preset_reels "$input" "$output"
            ;;
        youtube)
            preset_youtube "$input" "$output"
            ;;
        master)
            preset_master "$input" "$output"
            ;;
        review)
            preset_review "$input" "$output"
            ;;
        thumb)
            preset_thumbnail "$input" "$output"
            ;;
        gif)
            preset_gif "$input" "$output"
            ;;
        all)
            echo "Gerando todos os formatos..."
            preset_reels "$input"
            preset_youtube "$input"
            preset_review "$input"
            preset_thumbnail "$input"
            preset_gif "$input"
            echo "✅ Todos os formatos gerados em $OUTPUT_DIR"
            ;;
        *)
            echo "❌ Preset desconhecido: $preset"
            usage
            exit 1
            ;;
    esac
}

main "$@"
