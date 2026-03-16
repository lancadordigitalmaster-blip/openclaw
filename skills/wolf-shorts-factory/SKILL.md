---
name: wolf-shorts-factory
description: Pipeline completo Wolf Agency para criar Shorts/Reels/TikToks monetizáveis. Dado um link de vídeo longo, corta nos timestamps certos, gera legendas animadas word-by-word, converte pra 9:16, exporta pronto para publicar. Acionar quando o usuário pedir corte de vídeo, short, reel ou TikTok.
---

# Wolf Shorts Factory 🎬🐺

Pipeline end-to-end para transformar vídeo longo em Shorts monetizáveis.

## Técnica de Monetização Rápida

O segredo não é só o corte — é a **combinação de 5 elementos**:

1. **Hook nos primeiros 2s** — pergunta, afirmação chocante ou conflito
2. **Legendas word-by-word** — retém 40%+ a mais de audiência (padrão CapCut)
3. **Ritmo de corte** — jump cuts a cada 3-5s para manter atenção
4. **CTA embutido** — no último segundo, direcionar ação
5. **Loop potential** — o fim do vídeo conecta ao início

## Workflow Completo

### Fase 1 — Input
```
Usuário fornece:
- Link do vídeo (YouTube, Drive, Vimeo, MP4 direto)
- Plataforma alvo (TikTok | Reels | Shorts | todos)
- Tom (educativo | entretenimento | vendas | motivacional)
- Timestamps (opcional — Alfred pode sugerir automaticamente)
```

### Fase 2 — Download + Transcrição
```bash
# 1. Download
yt-dlp -o "source.%(ext)s" [URL]

# 2. Transcrição com timestamps por palavra
whisper source.mp4 --model base --language Portuguese \
  --word_timestamps True --output_format srt --output_dir ./
```

### Fase 3 — Análise e Seleção de Clipes
```
auto-shorts-repurposer analisa o transcript e retorna:
- Top 5 momentos com maior potencial viral
- Hook sugerido para cada clipe
- Caption draft
- Hashtags
```

### Fase 4 — Corte + Edição
```bash
# Cortar clipe (ex: 2min30s até 5min00s)
ffmpeg -ss 00:02:30 -to 00:05:00 -i source.mp4 -c copy clip_01.mp4

# Converter para 9:16 vertical (1080x1920)
ffmpeg -i clip_01.mp4 \
  -vf "scale=1920:1080,rotate=PI/2,scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
  clip_01_vertical.mp4

# OU: crop inteligente (mantém o rosto centralizado)
ffmpeg -i clip_01.mp4 \
  -vf "crop=ih*9/16:ih,scale=1080:1920" \
  clip_01_vertical.mp4
```

### Fase 5 — Legendas Animadas (Word-by-Word)
```bash
# Gerar SRT com timestamps por palavra
whisper clip_01.mp4 --model base --language Portuguese \
  --word_timestamps True --highlight_words True \
  --max_words_per_line 4 --output_format srt

# Queimar legendas estilo CapCut no vídeo
ffmpeg -i clip_01_vertical.mp4 \
  -vf "subtitles=clip_01.srt:force_style='FontName=Arial Black,FontSize=18,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=3,Shadow=2,Alignment=2,MarginV=80'" \
  clip_01_final.mp4
```

### Fase 6 — Empacotamento
```
Output por clipe:
├── clip_01_final.mp4     → Vídeo pronto 9:16 com legendas
├── clip_01_caption.txt   → Legenda/copy para post
├── clip_01_hashtags.txt  → Hashtags por plataforma
└── clip_01_hook.txt      → Hook text para thumbnail/capa
```

## Uso pelo Alfred

Quando Netto mandar link + intenção:

```
1. analyze_viral.sh → baixa + transcreve com timestamps por palavra
2. Alfred lê o transcript e identifica os N melhores momentos virais
   → retorna: timestamp, viral_score, motivo, hook, caption, hashtags
3. Netto confirma (L1) ou Alfred procede direto (se já deu OK geral)
4. cut_short.sh → corta cada clipe, converte 9:16, queima legendas, fade
5. Arquivos caem em ~/Desktop/wolf-shorts/ prontos para publicar
```

## Critérios de Viralidade (Alfred analisa automaticamente)

- Hook magnético nos primeiros 2s (dado chocante, conflito, pergunta)
- Momento de surpresa ou revelação inesperada
- Número ou estatística impactante
- Opinião forte / ponto de vista controverso
- Pico emocional de uma história
- Insight acionável e raro
- One-liner memorável e quotável
- Tensão seguida de resolução

## Parâmetros de Qualidade por Plataforma

| Plataforma | Resolução | Duração | FPS |
|-----------|-----------|---------|-----|
| TikTok | 1080x1920 | 15-60s | 30fps |
| Reels | 1080x1920 | 15-90s | 30fps |
| Shorts | 1080x1920 | 15-60s | 30fps |

## Skills Dependentes

- `auto-shorts-repurposer` — análise de conteúdo e sugestão de clipes
- `video-subtitles` — geração de legendas SRT com Whisper
- `ffmpeg` (sistema) — corte, conversão, burn-in de legendas
- `yt-dlp` (sistema) — download de qualquer plataforma

## Status

- Download: ✅ yt-dlp instalado
- Transcrição: ✅ whisper instalado
- Corte/Conversão: ✅ ffmpeg instalado
- Análise de clipes: ✅ auto-shorts-repurposer instalado
- Legendas SRT: ✅ video-subtitles instalado
- Legendas word-by-word animadas: ⚙️ Em desenvolvimento
