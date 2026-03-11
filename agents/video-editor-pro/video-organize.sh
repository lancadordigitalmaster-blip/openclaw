#!/bin/bash
# video-organize.sh — Organizador automático de footage (compatível macOS)
# Uso: video organize [pasta] [--by-date|--by-type|--by-scene]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SOURCE_DIR="${1:-.}"
ORG_MODE="${2:-by-type}"

# Verificar se diretório existe
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Diretório não encontrado: $SOURCE_DIR${NC}"
    exit 1
fi

# Função: Detectar tipo de arquivo
detect_type() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        mov|mp4|avi|mkv|m4v|mts|m2ts)
            if echo "$file" | grep -qiE "(entrevista|interview|depoimento|testimonial|apresentador|host)"; then
                echo "a-roll"
            elif echo "$file" | grep -qiE "(produto|product|b-roll|detalhe|detail)"; then
                echo "b-roll"
            elif echo "$file" | grep -qiE "(screen|tela|gravacao|recording|zoom)"; then
                echo "screen"
            else
                echo "video"
            fi
            ;;
        wav|mp3|aac|m4a|flac)
            if echo "$file" | grep -qiE "(voz|voice|entrevista|interview|fala|speech)"; then
                echo "voice"
            elif echo "$file" | grep -qiE "(musica|music|trilha|track|bgm)"; then
                echo "music"
            elif echo "$file" | grep -qiE "(sfx|effect|efeito|som|sound)"; then
                echo "sfx"
            else
                echo "audio"
            fi
            ;;
        jpg|jpeg|png|tiff|tif|raw|cr2|nef)
            if echo "$file" | grep -qiE "(logo|marca|brand|identidade)"; then
                echo "logo"
            elif echo "$file" | grep -qiE "(produto|product|item)"; then
                echo "product"
            else
                echo "photo"
            fi
            ;;
        pdf|doc|docx|txt|md)
            echo "document"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Função: Extrair data do nome do arquivo
extract_date() {
    local file="$1"
    local date_str=""
    
    # Padrões comuns
    if echo "$file" | grep -qE "[0-9]{4}[-_]?[0-9]{2}[-_]?[0-9]{2}"; then
        date_str=$(echo "$file" | grep -oE "[0-9]{4}[-_]?[0-9]{2}" | head -1 | sed 's/\(....\)\(..\)/\1-\2/')
    elif echo "$file" | grep -qE "20[0-9]{2}[0-9]{2}[0-9]{2}"; then
        date_str=$(echo "$file" | grep -oE "20[0-9]{2}[0-9]{2}" | head -1 | sed 's/\(....\)\(..\)/\1-\2/')
    else
        date_str=$(stat -f "%Sm" -t "%Y-%m" "$file" 2>/dev/null)
    fi
    
    echo "$date_str"
}

# Menu principal
echo -e "${BLUE}🎬 VIDEO ORGANIZE — Organizador de Footage${NC}"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Diretório: $SOURCE_DIR"
echo "Modo: $ORG_MODE"
echo ""

# Listar arquivos encontrados
echo "Arquivos encontrados:"
find "$SOURCE_DIR" -maxdepth 1 -type f | head -10 | while read f; do
    echo "  • $(basename "$f")"
done
total_files=$(find "$SOURCE_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$total_files" -gt 10 ]; then
    echo "  ... e mais $((total_files - 10)) arquivos"
fi
echo ""

# Criar estrutura de pastas
echo -e "${BLUE}📁 Criando estrutura...${NC}"
mkdir -p "$SOURCE_DIR/ORGANIZADO/01_A_ROLL"
mkdir -p "$SOURCE_DIR/ORGANIZADO/02_B_ROLL"
mkdir -p "$SOURCE_DIR/ORGANIZADO/03_SCREEN"
mkdir -p "$SOURCE_DIR/ORGANIZADO/04_AUDIO/VOICE"
mkdir -p "$SOURCE_DIR/ORGANIZADO/04_AUDIO/MUSIC"
mkdir -p "$SOURCE_DIR/ORGANIZADO/04_AUDIO/SFX"
mkdir -p "$SOURCE_DIR/ORGANIZADO/05_PHOTOS/LOGOS"
mkdir -p "$SOURCE_DIR/ORGANIZADO/05_PHOTOS/PRODUCTS"
mkdir -p "$SOURCE_DIR/ORGANIZADO/06_DOCUMENTS"
mkdir -p "$SOURCE_DIR/ORGANIZADO/99_OTHER"

# Contadores
COUNT_A_ROLL=0
COUNT_B_ROLL=0
COUNT_SCREEN=0
COUNT_VOICE=0
COUNT_MUSIC=0
COUNT_SFX=0
COUNT_PHOTO=0
COUNT_LOGO=0
COUNT_PRODUCT=0
COUNT_DOC=0
COUNT_OTHER=0

# Organizar arquivos
echo ""
echo -e "${BLUE}📂 Organizando arquivos...${NC}"
echo ""

find "$SOURCE_DIR" -maxdepth 1 -type f | while read file; do
    filename=$(basename "$file")
    filetype=$(detect_type "$filename")
    
    target_folder=""
    case "$filetype" in
        a-roll) 
            target_folder="01_A_ROLL"
            COUNT_A_ROLL=$((COUNT_A_ROLL + 1))
            ;;
        b-roll) 
            target_folder="02_B_ROLL"
            COUNT_B_ROLL=$((COUNT_B_ROLL + 1))
            ;;
        screen) 
            target_folder="03_SCREEN"
            COUNT_SCREEN=$((COUNT_SCREEN + 1))
            ;;
        voice) 
            target_folder="04_AUDIO/VOICE"
            COUNT_VOICE=$((COUNT_VOICE + 1))
            ;;
        music) 
            target_folder="04_AUDIO/MUSIC"
            COUNT_MUSIC=$((COUNT_MUSIC + 1))
            ;;
        sfx) 
            target_folder="04_AUDIO/SFX"
            COUNT_SFX=$((COUNT_SFX + 1))
            ;;
        audio) 
            target_folder="04_AUDIO"
            ;;
        logo) 
            target_folder="05_PHOTOS/LOGOS"
            COUNT_LOGO=$((COUNT_LOGO + 1))
            ;;
        product) 
            target_folder="05_PHOTOS/PRODUCTS"
            COUNT_PRODUCT=$((COUNT_PRODUCT + 1))
            ;;
        photo) 
            target_folder="05_PHOTOS"
            COUNT_PHOTO=$((COUNT_PHOTO + 1))
            ;;
        document) 
            target_folder="06_DOCUMENTS"
            COUNT_DOC=$((COUNT_DOC + 1))
            ;;
        *) 
            target_folder="99_OTHER"
            COUNT_OTHER=$((COUNT_OTHER + 1))
            ;;
    esac
    
    if [ ! -z "$target_folder" ]; then
        mv "$file" "$SOURCE_DIR/ORGANIZADO/$target_folder/"
        echo -e "${CYAN}→${NC} $filename → ${GREEN}$target_folder${NC}"
    fi
done

# Relatório
echo ""
echo -e "${BLUE}📊 RELATÓRIO DE ORGANIZAÇÃO${NC}"
echo "═══════════════════════════════════════════════════"
echo ""
echo "📁 ARQUIVOS ORGANIZADOS:"
echo "────────────────────────────────────────────────────"

# Contar arquivos em cada pasta
for folder in 01_A_ROLL 02_B_ROLL 03_SCREEN 04_AUDIO 04_AUDIO/VOICE 04_AUDIO/MUSIC 04_AUDIO/SFX 05_PHOTOS 05_PHOTOS/LOGOS 05_PHOTOS/PRODUCTS 06_DOCUMENTS 99_OTHER; do
    count=$(find "$SOURCE_DIR/ORGANIZADO/$folder" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "• $folder: $count arquivo(s)"
    fi
done

echo ""
total_organized=$(find "$SOURCE_DIR/ORGANIZADO" -type f | wc -l | tr -d ' ')
echo "Total organizado: $total_organized arquivo(s)"

# Tamanho total
if [ -d "$SOURCE_DIR/ORGANIZADO" ]; then
    total_size=$(du -sh "$SOURCE_DIR/ORGANIZADO" 2>/dev/null | cut -f1)
    echo "Tamanho total: $total_size"
fi

echo ""
echo -e "${GREEN}✅ Organização concluída!${NC}"
echo ""
echo -e "${YELLOW}💡 Próximos passos:${NC}"
echo "  1. Revise a pasta ORGANIZADO/"
echo "  2. Use 'video tools analyze [arquivo]' para análise técnica"
echo "  3. Use 'video spec [formato] [objetivo]' para criar especificação"
