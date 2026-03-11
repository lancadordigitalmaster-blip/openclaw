# Template de Projeto Premiere Pro — Wolf Agency

> Estrutura de projeto gratuita para edição profissional

---

## Estrutura de Pastas no Projeto

```
WOLF_PROJECT/
├── 📁 01_FOOTAGE/
│   ├── 📁 A_Roll/
│   ├── 📁 B_Roll/
│   └── 📁 Screen_Recordings/
├── 📁 02_AUDIO/
│   ├── 📁 Voiceover/
│   ├── 📁 Music/
│   └── 📁 SFX/
├── 📁 03_GRAPHICS/
│   ├── 📁 Logos/
│   ├── 📁 Lower_Thirds/
│   └── 📁 Callouts/
├── 📁 04_EXPORTS/
│   ├── 📁 Review/
│   └── 📁 Final/
└── 📁 05_ARCHIVE/
    └── 📁 Old_Versions/
```

---

## Sequências Padrão

### VSL (Video Sales Letter)

```
SEQUÊNCIA: VSL_Master
├── V1: HOOK (0–30s)
├── V2: AUTORIDADE (15–35s)
├── V3: PROBLEMA (35–70s)
├── V4: MECANISMO (70–140s)
├── V5: PROVA (140–220s)
├── V6: OBJEÇÕES (220–300s)
├── V7: OFERTA (300–360s)
└── V8: CTA (final)

TRACKS:
├── V1-V8: Vídeo principal
├── A1-A2: Áudio principal
├── A3: Música
└── A4-A6: SFX
```

### Reels/Stories

```
SEQUÊNCIA: Reels_Master
├── V1: HOOK (0–2s)
├── V2: CONTEXTO (2–6s)
├── V3: PROVA (6–20s)
├── V4: PONTOS (20–45s)
└── V5: CTA (final)

TRACKS:
├── V1-V5: Vídeo
├── A1-A2: Voz/SFX
├── A3: Música
└── V6: Legendas (Graphics)
```

---

## Configurações de Sequência

### Reels/Stories (9:16)

```
Editing Mode: Custom
Frame Size: 1080 x 1920
Frame Rate: 30 fps
Pixel Aspect Ratio: Square Pixels
Fields: No Fields (Progressive)
Audio Sample Rate: 48000 Hz
```

### YouTube/VSL (16:9)

```
Editing Mode: Custom
Frame Size: 1920 x 1080
Frame Rate: 30 fps (ou 24 fps cinematic)
Pixel Aspect Ratio: Square Pixels
Fields: No Fields (Progressive)
Audio Sample Rate: 48000 Hz
```

---

## Presets de Export (Gratuitos)

### H.264 Web (Reels/Stories)

```
Format: H.264
Preset: Match Source – Adaptive High Bitrate
Resolution: 1080 x 1920
Frame Rate: 30 fps
Field Order: Progressive
Aspect: Square Pixels
Performance: Hardware Encoding (se disponível)

Video:
  Codec: H.264
  Profile: High
  Level: 4.2
  Target Bitrate: 12 Mbps
  Maximum Bitrate: 16 Mbps

Audio:
  Codec: AAC
  Sample Rate: 48000 Hz
  Channels: Stereo
  Bitrate: 320 kbps
```

### H.264 Web (YouTube)

```
Format: H.264
Preset: Match Source – High Bitrate
Resolution: 1920 x 1080
Frame Rate: 30 fps

Video:
  Target Bitrate: 10 Mbps
  Maximum Bitrate: 12 Mbps

Audio:
  Bitrate: 320 kbps
```

### ProRes Master (Arquivo)

```
Format: QuickTime
Codec: Apple ProRes 422 HQ
Resolution: Conforme projeto
Audio: PCM 24-bit 48000 Hz
```

---

## Mogrt (Motion Graphics Templates)

### Legendas Básicas (Gratuito)

```
Lower Third Simples:
├── Fonte: Montserrat Bold
├── Tamanho: 72 pt
├── Cor: Branco (#FFFFFF)
├── Stroke: Preto 4 px
├── Posição: Centro inferior
└── Animação: Fade in 0.3s, hold 3s, fade out 0.3s
```

### Callout de Prova

```
Proof Card:
├── Fundo: Brand color ou escuro
├── Borda: 2 px branca
├── Título: Montserrat Bold 48 pt
├── Dado: 96 pt cor destaque
├── Contexto: Montserrat Regular 24 pt
└── Duração: 3–5 segundos
```

---

## Atalhos de Teclado Úteis

| Ação | Atalho |
|------|--------|
| Cortar no playhead | C |
| Selecionar tudo | Cmd+A |
| Desfazer | Cmd+Z |
| Refazer | Cmd+Shift+Z |
| Salvar | Cmd+S |
| Exportar | Cmd+M |
| Play/Pause | Space |
| Voltar 5 segundos | Shift+Left |
| Avançar 5 segundos | Shift+Right |
| Aumentar zoom | + |
| Diminuir zoom | - |

---

## Checklist de Projeto

### Início
- [ ] Criar estrutura de pastas
- [ ] Importar footage organizado
- [ ] Criar sequência com specs corretas
- [ ] Salvar projeto com versionamento

### Durante
- [ ] Autosave ativado (a cada 5 min)
- [ ] Timeline organizada (cores por tipo)
- [ ] Playback fluido (render preview quando necessário)

### Final
- [ ] Render preview completo
- [ ] Export teste (review)
- [ ] Export final em múltiplos formatos
- [ ] Backup do projeto

---

## Dicas de Performance (Gratuito)

### Proxy Workflow
1. Selecionar footage pesado
2. Clique direito → Proxy → Create Proxies
3. Usar QuickTime ProRes Low Resolution
4. Alternar entre Proxy/Full no preview

### Render Preview
- Tecla Enter: renderizar timeline vermelha
- Tecla 0: renderizar e preview

### Media Cache
- Limpar regularmente: Edit → Preferences → Media Cache
- Localizar em SSD rápido

---

*Template Premiere Pro v1.0 — Wolf Agency (Gratuito)*
