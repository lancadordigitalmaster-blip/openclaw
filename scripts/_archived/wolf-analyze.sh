#!/bin/bash
# Wolf Content Analyzer
# Analisa conteúdo histórico e extrai padrões

CLIENT="$2"
FOLDER="$4"

if [ -z "$CLIENT" ] || [ -z "$FOLDER" ]; then
    echo "Uso: wolf-analyze --client=\"Nome\" --folder=\"/caminho/\""
    exit 1
fi

OUTPUT_DIR="/Users/thomasgirotto/.openclaw/workspace/memory/clients/$CLIENT"
mkdir -p "$OUTPUT_DIR"

echo "🧠 Analisando conteúdo de: $CLIENT"
echo "📁 Pasta: $FOLDER"
echo ""

# Contar arquivos
FILE_COUNT=$(find "$FOLDER" -type f \( -name "*.txt" -o -name "*.md" -o -name "*.json" \) | wc -l)
echo "📊 Arquivos encontrados: $FILE_COUNT"

# Criar estrutura de análise
cat > "$OUTPUT_DIR/analysis-prompt.txt" << EOF
Analise o conteúdo de $CLIENT e extraia:

1. TOM DE VOZ
   - Formalidade (1-10)
   - Emoção predominante
   - Gírias/linguagem específica
   - Forma de se comunicar

2. ESTRUTURA DE COPY
   - Padrão de hooks (primeiras palavras)
   - Estrutura de legendas
   - Uso de emojis
   - Chamadas para ação (CTA)

3. PADRÕES VISUAIS (se aplicável)
   - Cores predominantes
   - Tipografia
   - Estilo de imagem

4. TEMAS RECORRENTES
   - Assuntos mais abordados
   - Ângulos de comunicação
   - Provas sociais usadas

5. FRAMEWORKS IDENTIFICADOS
   - Fórmulas de copy usadas
   - Sequências de conteúdo
   - Estratégias de engajamento

Gere 3 arquivos:
- style-guide.md (guia completo)
- patterns.json (padrões estruturados)
- tone-of-voice.md (tom de voz detalhado)
EOF

echo "✅ Estrutura criada em: $OUTPUT_DIR"
echo ""
echo "Próximo passo:"
echo "1. Coloque os arquivos de conteúdo em: $FOLDER"
echo "2. Me chame para analisar: 'Alfred, analisa o conteúdo de $CLIENT'"
echo ""
echo "📄 Prompt de análise salvo em: $OUTPUT_DIR/analysis-prompt.txt"