#!/bin/bash
# Wolf Knowledge Base Viewer
# Mostra padrões e frameworks armazenados

TOPIC="$2"

KB_DIR="/Users/thomasgirotto/.openclaw/workspace/memory/wolf-knowledge-base"

if [ ! -d "$KB_DIR" ]; then
    echo "📚 Knowledge Base ainda vazia"
    echo ""
    echo "Para popular:"
    echo "1. Analise conteúdo: wolf-analyze --client=\"X\" --folder=\"...\""
    echo "2. Use o sistema e dê feedbacks"
    echo "3. A Knowledge Base cresce automaticamente"
    exit 0
fi

if [ -z "$TOPIC" ]; then
    echo "🧠 Wolf Knowledge Base"
    echo "======================"
    echo ""
    echo "Tópicos disponíveis:"
    echo ""
    
    if [ -d "$KB_DIR/frameworks" ]; then
        echo "📐 Frameworks:"
        ls -1 "$KB_DIR/frameworks/" 2>/dev/null | sed 's/^/  - /'
        echo ""
    fi
    
    if [ -d "$KB_DIR/niches" ]; then
        echo "🎯 Nichos:"
        ls -1 "$KB_DIR/niches/" 2>/dev/null | sed 's/^/  - /'
        echo ""
    fi
    
    if [ -d "$KB_DIR/patterns" ]; then
        echo "🔍 Padrões:"
        ls -1 "$KB_DIR/patterns/" 2>/dev/null | sed 's/^/  - /'
        echo ""
    fi
    
    echo "Uso: wolf-knowledge --topic=\"hooks\""
    
else
    echo "🔍 Buscando: $TOPIC"
    echo ""
    
    # Procurar em todos os diretórios
    FOUND=$(find "$KB_DIR" -type f -name "*$TOPIC*" 2>/dev/null)
    
    if [ -n "$FOUND" ]; then
        echo "Resultados encontrados:"
        echo "$FOUND" | while read -r file; do
            echo ""
            echo "📄 $file:"
            cat "$file" | head -30
            echo "..."
        done
    else
        echo "❌ Nenhum resultado para: $TOPIC"
        echo ""
        echo "A Knowledge Base está aprendendo..."
        echo "Continue usando o sistema e dando feedbacks!"
    fi
fi