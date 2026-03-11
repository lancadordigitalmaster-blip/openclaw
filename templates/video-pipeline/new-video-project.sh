#!/bin/bash
# new-video-project.sh
# Cria estrutura de projeto de vídeo automaticamente

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
    echo "❌ Uso: ./new-video-project.sh [nome-do-projeto]"
    echo ""
    echo "Exemplo:"
    echo "  ./new-video-project.sh campanha-q1-2026"
    exit 1
fi

# Sanitiza nome (remove espaços e caracteres especiais)
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

TEMPLATE_DIR="/Users/thomasgirotto/.openclaw/workspace/templates/video-pipeline"
PROJECT_DIR="/Users/thomasgirotto/.openclaw/workspace/projects/$PROJECT_NAME"

# Verifica se já existe
if [ -d "$PROJECT_DIR" ]; then
    echo "❌ Projeto '$PROJECT_NAME' já existe!"
    echo "   $PROJECT_DIR"
    exit 1
fi

echo "🎬 Criando projeto: $PROJECT_NAME"
echo ""

# Cria estrutura de pastas
mkdir -p "$PROJECT_DIR"/{00-briefing,01-pre-producao,02-roteiro,03-storyboard,04-gravacao,05-edicao,06-revisao,07-final,08-entrega,_assets/{musicas,fontes,luts,imagens},_exports,_archive}

# Copia templates
cp "$TEMPLATE_DIR/README.md" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/NOMENCLATURA.md" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/00-briefing/BRIEFING-TEMPLATE.md" "$PROJECT_DIR/00-briefing/"
cp "$TEMPLATE_DIR/04-gravacao/CHECKLIST-GRAVACAO.md" "$PROJECT_DIR/04-gravacao/"

# Cria arquivo de configuração do projeto
cat > "$PROJECT_DIR/PROJECT.md" << EOF
# $PROJECT_NAME

**Criado:** $(date '+%Y-%m-%d %H:%M')  
**Status:** 🟡 Em briefing

---

## Links Importantes

- Briefing: \`00-briefing/BRIEFING-TEMPLATE.md\`
- Checklist gravação: \`04-gravacao/CHECKLIST-GRAVACAO.md\`
- Guia de nomenclatura: \`NOMENCLATURA.md\`

---

## Histórico de Versões

| Data | Versão | Etapa | Responsável | Descrição |
|------|--------|-------|-------------|-----------|
| $(date '+%Y-%m-%d') | v0.1 | 00-briefing | | Criação do projeto |

---

## Próximos Passos

- [ ] Preencher briefing em \`00-briefing/BRIEFING-TEMPLATE.md\`
- [ ] Obter aprovação do briefing
- [ ] Mover para 01-pre-producao/

---

*Gerado automaticamente pelo Wolf Video Pipeline*
EOF

echo "✅ Projeto criado com sucesso!"
echo ""
echo "📁 Local: $PROJECT_DIR"
echo ""
echo "Próximos passos:"
echo "  1. cd $PROJECT_DIR"
echo "  2. Edite 00-briefing/BRIEFING-TEMPLATE.md"
echo "  3. Siga o README.md para o fluxo completo"
echo ""
