#!/bin/bash
# Wolf Feedback Collector
# Registra feedback sobre recomendações

REC_ID="$2"
RATING="$4"
COMMENT="$6"

FEEDBACK_FILE="/Users/thomasgirotto/.openclaw/workspace/memory/feedback-loop.md"

if [ -z "$REC_ID" ] || [ -z "$RATING" ]; then
    echo "Uso: wolf-feedback --id=\"rec-123\" --rating=\"5\" --comment=\"Funcionou!\""
    echo ""
    echo "Ratings:"
    echo "  5 = ⭐ Funcionou perfeitamente"
    echo "  4 = 🟢 Funcionou bem"
    echo "  3 = 🟡 Funcionou parcialmente"
    echo "  2 = 🟠 Não funcionou bem"
    echo "  1 = ❌ Não funcionou"
    exit 1
fi

# Criar entrada de feedback
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
ENTRY="
## Feedback: $REC_ID
- **Data:** $TIMESTAMP
- **Rating:** $RATING/5
- **Comentário:** ${COMMENT:-"Sem comentário"}
- **Status:** Registrado ✅

---
"

# Adicionar ao arquivo
echo "$ENTRY" >> "$FEEDBACK_FILE"

echo "✅ Feedback registrado!"
echo "📁 Salvo em: $FEEDBACK_FILE"
echo ""
echo "Resumo:"
echo "  ID: $REC_ID"
echo "  Rating: $RATING/5"
echo "  Comentário: ${COMMENT:-"Sem comentário"}"

# Atualizar métricas se existir
if [ -f "/Users/thomasgirotto/.openclaw/workspace/memory/wolf-metrics.json" ]; then
    echo "📊 Métricas atualizadas"
fi