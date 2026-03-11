#!/bin/bash
# video-qc.sh — Checklist de Qualidade Pré-Entrega (simplificado)
# Uso: video qc [arquivo] [--formato=short|vsl|youtube]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VIDEO_FILE="$1"
FORMATO="${2:-auto}"

# Verificar arquivo
if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    echo -e "${RED}❌ Uso: video qc [arquivo-de-video] [formato]${NC}"
    echo ""
    echo "Exemplos:"
    echo "  video qc meu-video.mp4"
    echo "  video qc meu-video.mp4 short"
    echo "  video qc meu-video.mp4 vsl"
    exit 1
fi

# Detectar formato pelo nome se não especificado
if [ "$FORMATO" == "auto" ]; then
    filename=$(basename "$VIDEO_FILE" | tr '[:upper:]' '[:lower:]')
    if echo "$filename" | grep -qE "(reels|stories|short|vertical|9x16)"; then
        FORMATO="short"
    elif echo "$filename" | grep -qE "(vsl|sales|lp|landing)"; then
        FORMATO="vsl"
    elif echo "$filename" | grep -qE "(youtube|yt|16x9|horizontal)"; then
        FORMATO="youtube"
    else
        FORMATO="short"
    fi
fi

echo -e "${BLUE}🔍 VIDEO QC — Checklist de Qualidade Pré-Entrega${NC}"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Arquivo: $(basename "$VIDEO_FILE")"
echo "Formato: $(echo "$FORMATO" | tr '[:lower:]' '[:upper:]')"
echo "Data: $(date '+%d/%m/%Y %H:%M')"
echo ""

# Pontuação
TOTAL_CHECKS=0
PASSED_CHECKS=0
CRITICAL_FAILS=0
WARNING_COUNT=0

# Função: Verificar critério
check_item() {
    local desc="$1"
    local status="$2"
    local critical="${3:-false}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case "$status" in
        PASS)
            echo -e "${GREEN}✅${NC} $desc"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        FAIL)
            if [ "$critical" == "true" ]; then
                echo -e "${RED}❌ CRÍTICO:${NC} $desc"
                CRITICAL_FAILS=$((CRITICAL_FAILS + 1))
            else
                echo -e "${YELLOW}⚠️${NC} $desc"
                WARNING_COUNT=$((WARNING_COUNT + 1))
            fi
            ;;
        *)
            echo -e "${CYAN}⏸️${NC} $desc (verificar manualmente)"
            ;;
    esac
}

# Obter informações do vídeo
echo -e "${BLUE}📊 ANÁLISE TÉCNICA${NC}"
echo "────────────────────────────────────────────────────"
echo ""

# Usar ffprobe para extrair informações
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'.' -f1)
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'x' -f1)
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'x' -f2)
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d'/' -f1)
CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$VIDEO_FILE" 2>/dev/null)
BITRATE=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$VIDEO_FILE" 2>/dev/null)

# Valores padrão se vazios
DURATION=${DURATION:-0}
WIDTH=${WIDTH:-0}
HEIGHT=${HEIGHT:-0}
FPS=${FPS:-0}
CODEC=${CODEC:-"unknown"}
BITRATE=${BITRATE:-0}

# Mostrar informações detectadas
echo "Informações detectadas:"
echo "  • Resolução: ${WIDTH}x${HEIGHT}"
echo "  • Duração: ${DURATION}s"
echo "  • Frame rate: ${FPS}fps"
echo "  • Codec: $CODEC"
echo ""

# Verificações por formato
case "$FORMATO" in
    short|reels|stories)
        # Resolução 1080x1920
        if [ "$WIDTH" -eq 1080 ] && [ "$HEIGHT" -eq 1920 ]; then
            check_item "Resolução 1080x1920 (9:16)" "PASS"
        else
            check_item "Resolução 1080x1920 — Atual: ${WIDTH}x${HEIGHT}" "FAIL" "true"
        fi
        
        # Duração 15-90s
        if [ "$DURATION" -ge 15 ] && [ "$DURATION" -le 90 ]; then
            check_item "Duração ideal (${DURATION}s)" "PASS"
        elif [ "$DURATION" -gt 90 ]; then
            check_item "Duração ${DURATION}s — Recomendado: até 90s" "FAIL"
        else
            check_item "Duração ${DURATION}s — Muito curto (min: 15s)" "FAIL"
        fi
        ;;
        
    vsl)
        # VSL: 1920x1080 ou 1080x1920
        if [ "$WIDTH" -eq 1920 ] && [ "$HEIGHT" -eq 1080 ]; then
            check_item "Resolução 1920x1080 (16:9)" "PASS"
        elif [ "$WIDTH" -eq 1080 ] && [ "$HEIGHT" -eq 1920 ]; then
            check_item "Resolução 1080x1920 (9:16)" "PASS"
        else
            check_item "Resolução padrão — Atual: ${WIDTH}x${HEIGHT}" "FAIL"
        fi
        
        # Duração VSL: 2-10 minutos
        if [ "$DURATION" -ge 120 ] && [ "$DURATION" -le 600 ]; then
            check_item "Duração VSL (${DURATION}s)" "PASS"
        elif [ "$DURATION" -lt 60 ]; then
            check_item "Duração ${DURATION}s — Muito curto para VSL" "FAIL"
        fi
        ;;
        
    youtube)
        if [ "$WIDTH" -ge 1920 ] && [ "$HEIGHT" -ge 1080 ]; then
            check_item "Resolução mínima 1920x1080" "PASS"
        else
            check_item "Resolução ${WIDTH}x${HEIGHT} — Baixa para YouTube" "FAIL"
        fi
        ;;
esac

# Frame rate
if [ "$FPS" -ge 24 ] && [ "$FPS" -le 60 ]; then
    check_item "Frame rate ${FPS}fps" "PASS"
else
    check_item "Frame rate ${FPS}fps — Fora do padrão (24-60fps)" "FAIL"
fi

# Codec
if echo "$CODEC" | grep -qi "h264"; then
    check_item "Codec H.264 (compatível web)" "PASS"
else
    check_item "Codec $CODEC — Recomendado: H.264" "FAIL"
fi

# Bitrate
if [ "$BITRATE" -gt 0 ]; then
    BITRATE_MBPS=$((BITRATE / 1000000))
    if [ "$BITRATE_MBPS" -ge 5 ]; then
        check_item "Bitrate ${BITRATE_MBPS} Mbps" "PASS"
    else
        check_item "Bitrate ${BITRATE_MBPS} Mbps — Baixo (min: 5Mbps)" "FAIL"
    fi
fi

echo ""

# Checklist de conteúdo
echo -e "${BLUE}🎬 CHECKLIST DE CONTEÚDO${NC}"
echo "────────────────────────────────────────────────────"
echo ""

case "$FORMATO" in
    short|reels|stories)
        echo "SHORT-FORM (Reels/Stories):"
        check_item "Hook nos primeiros 2 segundos" "MANUAL" "true"
        check_item "Legendas em todo o vídeo" "MANUAL" "true"
        check_item "Safe areas respeitadas" "MANUAL" "true"
        check_item "Áudio limpo (sem ruído)" "MANUAL" "true"
        check_item "CTA claro no final" "MANUAL"
        check_item "Primeiro frame atrativo" "MANUAL"
        check_item "Música royalty-free" "MANUAL"
        ;;
        
    vsl)
        echo "VSL (Video Sales Letter):"
        check_item "Hook forte (0-30s)" "MANUAL" "true"
        check_item "Prova inserida após claims" "MANUAL"
        check_item "Reset atencional a cada 30s" "MANUAL"
        check_item "Áudio profissional" "MANUAL" "true"
        check_item "CTA claro e urgente" "MANUAL" "true"
        check_item "Sem dead zones" "MANUAL"
        check_item "Legendas sincronizadas" "MANUAL" "true"
        check_item "Color grading consistente" "MANUAL"
        ;;
        
    youtube)
        echo "YOUTUBE:"
        check_item "Thumbnail sugerida" "MANUAL"
        check_item "Intro curta (<5s)" "MANUAL"
        check_item "Áudio limpo" "MANUAL" "true"
        check_item "Cards/links no final" "MANUAL"
        ;;
esac

echo ""

# Resultado final
echo -e "${BLUE}📋 RESULTADO DA QUALIDADE${NC}"
echo "═══════════════════════════════════════════════════"
echo ""

if [ $TOTAL_CHECKS -gt 0 ]; then
    SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    SCORE=0
fi

echo "Verificações técnicas: $PASSED_CHECKS/$TOTAL_CHECKS"
echo "Score: ${SCORE}%"
echo ""

# Veredicto
if [ $CRITICAL_FAILS -gt 0 ]; then
    echo -e "${RED}🚫 REPROVADO — Corrigir falhas críticas${NC}"
    echo ""
    echo "Falhas críticas: $CRITICAL_FAILS"
    echo "Revise os itens ❌ CRÍTICO"
    EXIT_CODE=1
elif [ $SCORE -ge 90 ]; then
    echo -e "${GREEN}✅ APROVADO — Pronto para entrega${NC}"
    EXIT_CODE=0
elif [ $SCORE -ge 75 ]; then
    echo -e "${YELLOW}⚠️ APROVADO COM RESSALVAS${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}❌ REPROVADO — Melhorias necessárias${NC}"
    EXIT_CODE=1
fi

if [ $WARNING_COUNT -gt 0 ]; then
    echo ""
    echo "Avisos: $WARNING_COUNT"
fi

echo ""
echo -e "${CYAN}💡 Dica: Use 'video scorecard $FORMATO' para avaliação detalhada${NC}"

exit $EXIT_CODE
