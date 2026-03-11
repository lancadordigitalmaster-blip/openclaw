#!/bin/bash
# video-editor-pro.sh — Executor do agente Video Editor Pro
# Uso: ./video-editor-pro.sh [comando] [args]

COMMAND=${1:-help}
WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
AGENT_DIR="$WORKSPACE/agents/video-editor-pro"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case $COMMAND in
  analyze|analisar)
    VIDEO_FILE=$2
    if [ -z "$VIDEO_FILE" ]; then
      echo -e "${RED}❌ Uso: video-editor-pro analyze [arquivo-de-video]${NC}"
      exit 1
    fi
    
    echo -e "${BLUE}🎬 VIDEO EDITOR PRO — Análise de Vídeo${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    if [ ! -f "$VIDEO_FILE" ]; then
      echo -e "${YELLOW}⚠️  Arquivo não encontrado: $VIDEO_FILE${NC}"
      echo ""
      echo "Modo simulação — estrutura de análise:"
    else
      echo -e "${GREEN}✅ Arquivo encontrado${NC}"
      echo ""
    fi
    
    echo "📊 ANÁLISE TÉCNICA:"
    echo "────────────────────────────────────────────────────"
    echo "• Formato: [detectar do arquivo]"
    echo "• Resolução: [detectar do arquivo]"
    echo "• Duração: [detectar do arquivo]"
    echo "• Frame rate: [detectar do arquivo]"
    echo "• Codec: [detectar do arquivo]"
    echo ""
    
    echo "🎯 ANÁLISE DE CONTEÚDO:"
    echo "────────────────────────────────────────────────────"
    echo "• Hook: [analisar primeiros 2-5s]"
    echo "• Clareza da mensagem: [avaliar]"
    echo "• Ritmo/Pacing: [analisar cortes]"
    echo "• Prova/Evidência: [identificar]"
    echo "• CTA: [avaliar chamada]"
    echo ""
    
    echo "📋 RECOMENDAÇÕES:"
    echo "────────────────────────────────────────────────────"
    echo "• [Recomendação 1 baseada na análise]"
    echo "• [Recomendação 2 baseada na análise]"
    echo "• [Recomendação 3 baseada na análise]"
    echo ""
    
    echo -e "${YELLOW}💡 Para análise completa, forneça o arquivo de vídeo${NC}"
    ;;
    
  scorecard|score)
    TYPE=${2:-short}
    
    echo -e "${BLUE}🎯 VIDEO EDITOR PRO — Scorecard de Revisão${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    if [ "$TYPE" == "vsl" ]; then
      echo "📋 SCORECARD VSL (0–10 por item):"
      echo "────────────────────────────────────────────────────"
      echo ""
      echo "1. Hook:          [ ] /10  — Captura atenção inicial"
      echo "2. Promessa:      [ ] /10  — Proposta de valor clara"
      echo "3. Progressão:    [ ] /10  — Construção de crença"
      echo "4. Prova:         [ ] /10  — Evidências convincentes"
      echo "5. Mecanismo:     [ ] /10  — Explicação do 'como'"
      echo "6. Objeções:      [ ] /10  — Respostas antecipadas"
      echo "7. CTA:           [ ] /10  — Chamada clara"
      echo "8. Ritmo:         [ ] /10  — Sem dead zones"
      echo "9. Áudio:         [ ] /10  — Qualidade profissional"
      echo "10. Inserts:      [ ] /10  — Funcionais, não decorativos"
      echo ""
      echo "TOTAL:    [  ] /100"
      echo ""
      echo "INTERPRETAÇÃO:"
      echo "• 90–100: PRONTO para publicar"
      echo "• 75–89:  AJUSTES necessários"
      echo "• <75:    REEDIÇÃO estrutural"
      
    else
      echo "📋 SCORECARD SHORT-FORM (0–10 por item):"
      echo "────────────────────────────────────────────────────"
      echo ""
      echo "1. Hook:          [ ] /10  — Captura em 0–2s"
      echo "2. Clareza:       [ ] /10  — Mensagem no 1º watch"
      echo "3. Ritmo:         [ ] /10  — Pacing adequado"
      echo "4. Legenda:       [ ] /10  — Legível, posicionada"
      echo "5. Prova:         [ ] /10  — Evidência presente"
      echo "6. CTA:           [ ] /10  — Chamada clara"
      echo "7. Áudio:         [ ] /10  — Limpo, balanceado"
      echo "8. Visual:        [ ] /10  — Safe areas respeitadas"
      echo "9. Marca:         [ ] /10  — Identidade presente"
      echo "10. Loopability:  [ ] /10  — Transição fluida"
      echo ""
      echo "TOTAL:    [  ] /100"
      echo ""
      echo "INTERPRETAÇÃO:"
      echo "• 90–100: PRONTO para publicar"
      echo "• 75–89:  AJUSTES necessários"
      echo "• <75:    REEDIÇÃO estrutural"
    fi
    
    echo ""
    echo -e "${YELLOW}📚 Referência: $AGENT_DIR/references/qc-scorecards.md${NC}"
    ;;
    
  spec|especificar)
    FORMATO=${2:-vsl}
    OBJETIVO=${3:-venda}
    
    echo -e "${BLUE}📝 VIDEO EDITOR PRO — Especificação de Edição${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "PROJETO: [Nome do projeto]"
    echo "FORMATO: $(echo "$FORMATO" | tr '[:lower:]' '[:upper:]')"
    echo "OBJETIVO: $(echo "$OBJETIVO" | tr '[:lower:]' '[:upper:]')"
    echo "DATA: $(date '+%d/%m/%Y %H:%M')"
    echo ""
    
    if [ "$FORMATO" == "vsl" ]; then
      echo "📐 PLANO DE EDIÇÃO — VSL:"
      echo "────────────────────────────────────────────────────"
      echo ""
      echo "1. HOOK (0–30s)"
      echo "   → Pattern interrupt visual"
      echo "   → Curiosidade ou identificação imediata"
      echo "   → Legendas grandes, impactantes"
      echo ""
      echo "2. AUTORIDADE (15–35s)"
      echo "   → Quem fala e por que ouvir"
      echo "   → Credibilidade rápida"
      echo ""
      echo "3. PROBLEMA (35–70s)"
      echo "   → Dor específica"
      echo "   → Custo de não resolver"
      echo "   → Reset atencional aos 60s"
      echo ""
      echo "4. MECANISMO (70–140s)"
      echo "   → 'Como funciona'"
      echo "   → Diferencial único"
      echo "   → Inserts de demonstração"
      echo ""
      echo "5. PROVA (140–220s)"
      echo "   → Resultados, cases"
      echo "   → Depoimentos"
      echo "   → Dados/prints"
      echo ""
      echo "6. OBJEÇÕES (220–300s)"
      echo "   → 'Mas e se...'"
      echo "   → Garantias"
      echo ""
      echo "7. OFERTA (300–360s)"
      echo "   → O que inclui"
      echo "   → Valor"
      echo "   → Urgência"
      echo ""
      echo "8. CTA (final)"
      echo "   → Ação específica"
      echo "   → Botão/link visível"
      echo ""
      
    elif [ "$FORMATO" == "reels" ] || [ "$FORMATO" == "stories" ]; then
      echo "📐 PLANO DE EDIÇÃO — SHORT-FORM:"
      echo "────────────────────────────────────────────────────"
      echo ""
      echo "0–2s   → HOOK VISUAL/TEXTUAL"
      echo "         • Pára o scroll imediatamente"
      echo "         • Texto grande, cor de destaque"
      echo ""
      echo "2–6s   → CONTEXTO RÁPIDO"
      echo "         • Qual é o problema"
      echo "         • Por que importa"
      echo ""
      echo "6–20s  → PROVA/BENEFÍCIO"
      echo "         • Resultado real"
      echo "         • Transformação"
      echo ""
      echo "20–45s → 2–3 PONTOS"
      echo "         • Pattern interrupts a cada 5–8s"
      echo "         • Cortes dinâmicos"
      echo "         • Legendas com ênfase"
      echo ""
      echo "FINAL  → CTA CLARO"
      echo "         • Ação específica"
      echo "         • Loop consideration"
      echo ""
    fi
    
    echo "🎨 ESTILO VISUAL:"
    echo "────────────────────────────────────────────────────"
    echo "• [Definir baseado no objetivo]"
    echo "• Premium Clean / Performance Aggressive / UGC"
    echo ""
    
    echo "🔊 SOUND DESIGN:"
    echo "────────────────────────────────────────────────────"
    echo "• Música: [estilo] — [BPM]"
    echo "• SFX: whoosh, ding, pop (pontuais)"
    echo "• Mix: voz dominante, música -18dB"
    echo ""
    
    echo "📤 EXPORT:"
    echo "────────────────────────────────────────────────────"
    echo "• Resolução: [1080x1920 / 1920x1080]"
    echo "• Codec: H.264"
    echo "• Bitrate: [conforme plataforma]"
    echo ""
    
    echo -e "${GREEN}✅ Especificação gerada!${NC}"
    echo ""
    echo -e "${YELLOW}💡 Salve este plano e use como guia durante a edição${NC}"
    ;;
    
  checklist|check)
    ETAPA=${2:-edicao}
    
    echo -e "${BLUE}✅ VIDEO EDITOR PRO — Checklist${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    case $ETAPA in
      gravacao)
        echo "🎥 CHECKLIST DE GRAVAÇÃO:"
        echo "────────────────────────────────────────────────────"
        echo "□ Equipamento testado"
        echo "□ Áudio nível correto (-12dB a -6dB)"
        echo "□ Iluminação adequada"
        echo "□ Roteiro disponível"
        echo "□ Backup de cartões"
        echo "□ Takes organizados"
        ;;
      edicao)
        echo "✂️ CHECKLIST DE EDIÇÃO:"
        echo "────────────────────────────────────────────────────"
        echo "□ Timeline organizada"
        echo "□ Cortes limpos"
        echo "□ Legendas sincronizadas"
        echo "□ Inserts de prova"
        echo "□ Color grading"
        echo "□ Sound design"
        echo "□ Mix de áudio"
        ;;
      export)
        echo "📤 CHECKLIST DE EXPORT:"
        echo "────────────────────────────────────────────────────"
        echo "□ Resolução correta"
        echo "□ Frame rate consistente"
        echo "□ Áudio incluído"
        echo "□ Início/fim cortados"
        echo "□ Nome padronizado"
        echo "□ Teste de reprodução"
        ;;
      *)
        echo "Checklists disponíveis: gravacao, edicao, export"
        ;;
    esac
    echo ""
    ;;
    
  tools)
    shift
    $AGENT_DIR/video-tools.sh "$@"
    ;;
    
  organize|organizar)
    shift
    $AGENT_DIR/video-organize.sh "$@"
    ;;
    
  qc|quality|check)
    shift
    $AGENT_DIR/video-qc.sh "$@"
    ;;
    
  analyze-deep|analisar)
    shift
    $AGENT_DIR/video-analyze-deep.sh "$@"
    ;;
    
  help|*)
    echo -e "${BLUE}🎬 VIDEO EDITOR PRO — Editor Sênior Master${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Uso: video [comando] [args]"
    echo ""
    echo "Comandos Principais:"
    echo ""
    echo "  spec [formato] [obj]     Especificação de edição"
    echo "  scorecard [tipo]         Scorecard de revisão (short/vsl)"
    echo "  qc [arquivo] [formato]   Checklist pré-entrega (QUALIDADE)"
    echo "  analyze-deep [arquivo]   Análise profunda de referência"
    echo "  organize [pasta]         Organizar footage automaticamente"
    echo "  check [etapa]            Checklist genérico"
    echo ""
    echo "Ferramentas FFmpeg (Gratuitas):"
    echo ""
    echo "  tools analyze [arquivo]       Análise técnica real"
    echo "  tools thumbnail [arquivo]     Extrair thumbnail"
    echo "  tools convert [arq] [fmt]     Converter formato"
    echo "  tools optimize [arquivo]      Otimizar para web"
    echo "  tools trim [arq] [ini] [dur]  Cortar vídeo"
    echo ""
    echo "Exemplos:"
    echo "  video spec reels venda"
    echo "  video scorecard vsl"
    echo "  video qc meu-video.mp4 short"
    echo "  video analyze-deep referencia.mp4"
    echo "  video organize ./footage-bruta/"
    echo "  video tools analyze meu-video.mp4"
    echo ""
    echo "Referências:"
    echo "  $AGENT_DIR/references/"
    echo ""
    ;;
esac
