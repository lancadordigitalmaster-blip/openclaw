# 🤖 Auto-Video AI — Fluxo Automatizado

> Imagem → Vídeo | Referência → Vídeo | Sem edição manual

---

## 🎯 O Que Você Quer

**Entrada:**
- 1 imagem do produto
- 1 referência de vídeo
- Prompt simples

**Saída:**
- Vídeo pronto (sem tocar em nada)

---

## 🔄 FLUXO AUTOMATIZADO

### Exemplo 1: Imagem → Vídeo

**Entrada:**
```
📸 Foto: relogio-luxe.jpg
📝 Prompt: "Anúncio cyberpunk 15s, neon azul, 
            contagem regressiva, estilo Blade Runner"
```

**Processo Automático:**
```
1. Runway Gen-3
   → Anima a imagem (zoom, pan, light effects)
   
2. ElevenLabs
   → Gera narração: "Em 2 dias... ativaremos o modo ultra"
   
3. Remotion (overlay)
   → Adiciona: texto glitch, loading bar, CTA
   
4. FFmpeg
   → Mixa áudio + vídeo
   → Exporta MP4 final
```

**Saída:**
```
📹 video-final.mp4 (15s, 1080x1920)
```

---

### Exemplo 2: Referência → Vídeo

**Entrada:**
```
🎬 Vídeo: referencia-cyberpunk.mp4
📝 Prompt: "Mesmo estilo, mas com meu produto"
📸 Imagem: meu-produto.png
```

**Processo Automático:**
```
1. Análise AI (nosso script)
   → Extrai: duração, cores, estrutura, timing
   
2. Geração de Script
   → Cria roteiro equivalente
   
3. Runway / Pika
   → Gera cenas baseadas na referência
   
4. Remotion
   → Replica motion graphics
   → Mesmo timing de cortes
   
5. Assembly
   → Concatena tudo
   → Adiciona música (AI generated)
```

**Saída:**
```
📹 video-clonado.mp4 (mesmo estilo, seu produto)
```

---

## 🛠️ STACK DE AUTOMAÇÃO

### Ferramentas Necessárias

| Ferramenta | Função | Custo |
|------------|--------|-------|
| **Runway Gen-3** | Img → Vídeo animado | $28/mês |
| **Pika Labs** | Alternativa mais barata | $8/mês |
| **ElevenLabs** | Voz/narração AI | $5/mês |
| **Remotion** | Motion graphics (nosso) | Grátis |
| **Replicate API** | Modelos open-source | $10-20/mês |
| **Make/Zapier** | Orquestra workflow | $15/mês |

**Total: ~$70-90/mês**

---

## 📋 IMPLEMENTAÇÃO

### Script de Automação (Pseudo-código)

```bash
#!/bin/bash
# auto-video.sh — Gera vídeo automaticamente

INPUT_IMAGE=$1
REFERENCE_VIDEO=$2
PROMPT=$3

# 1. Analisar referência
ANALYSIS=$(video analyze-deep "$REFERENCE_VIDEO")

# 2. Gerar roteiro
SCRIPT=$(ai-generate-script "$PROMPT" "$ANALYSIS")

# 3. Animar imagem
ANIMATED=$(runway-gen3 "$INPUT_IMAGE" "$SCRIPT")

# 4. Gerar narração
VOICE=$(elevenlabs "$SCRIPT" "pt-BR")

# 5. Adicionar motion graphics
WITH_MG=$(remotion-overlay "$ANIMATED" "$ANALYSIS")

# 6. Mixar áudio
FINAL=$(ffmpeg-combine "$WITH_MG" "$VOICE" "music.mp3")

echo "✅ Vídeo pronto: $FINAL"
```

---

## 🎬 EXEMPLO REAL

### Cenário: Lançamento de Curso

**Entrada:**
```
📸 imagem: netto-foto.png
🎬 referência: video-cyberpunk.mp4 (que você enviou)
📝 prompt: "Lançamento curso dark, modo ultra, 15s"
```

**Processo:**
```
1. Análise do cyberpunk
   → 24s, 352x640, estilo neon, contagem regressiva
   
2. Adaptação para 15s
   → Hook: "EM 2 DIAS" (3s)
   → Meio: Foto Netto + animação (7s)
   → CTA: "GARANTA SUA VAGA" (5s)
   
3. Runway anima foto Netto
   → Zoom suave, light sweep, particles
   
4. ElevenLabs gera voz
   → "Em 2 dias... ativaremos o modo ultra"
   
5. Remotion adiciona
   → Texto glitch "EM 2 DIAS"
   → Loading bar animada
   → "GARANTA SUA VAGA" neon
   
6. FFmpeg exporta
   → MP4 1080x1920, 30fps
```

**Saída:**
```
📹 netto-lancamento.mp4
   Duração: 15s
   Estilo: Cyberpunk (igual referência)
   Conteúdo: Seu produto/rosto
   Pronto para postar
```

---

## ⚠️ LIMITAÇÕES ATUAIS

| Problema | Solução Temporária |
|----------|-------------------|
| IA não mantém consistência | Usar mesma seed/prompt |
| Movimentos robóticos | Limitar a zoom/pan simples |
| Tempo de render | 2-5 min por vídeo |
| Custo API | $0.10-0.50 por vídeo |

---

## 🚀 PRÓXIMOS PASSOS

1. **Testar Runway Gen-3** com sua foto
2. **Criar template Remotion** baseado no cyberpunk
3. **Automatizar via API** (Make/Zapier)
4. **Testar batch** (gerar 5 vídeos de uma vez)

Quer que eu implemente esse fluxo?
