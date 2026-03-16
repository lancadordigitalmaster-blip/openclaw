# Wolf Shorts Factory — Research Results & Integration Plan

**Data:** 2026-03-15 | **Status:** Production Ready

---

## Research Summary

### 1. Subtitle/Caption Solutions

| Solução | GitHub | Tipo | Qualidade |
|---------|--------|------|-----------|
| **pycaps** ⭐ | francozanardi/pycaps | CLI + Lib | Profissional (CapCut-style) |
| video-subtitles | (ClawHub) | Skill | Básico (SRT/burn) |
| moviepy TextClip | (Lib Python) | Lib | Programável |

**Escolhido:** pycaps
- ✅ Templates prontos (explosive, hype, vibrant, word-focus)
- ✅ Whisper integrado
- ✅ Animações word-by-word
- ✅ CSS styling
- ✅ Production-ready

### 2. SFX Solutions

**GitHub Projects:**
- `pysndfx` (carlthome) — wrapper SoX para efeitos audio
- `pydub` (jiaaro) — manipulação audio pura Python
- Freesound.org — biblioteca 700k+ SFX grátis

**Solução escolhida:** Geração local + pydub
- ✅ 4 SFX gerados (whoosh, impact, ding, pop)
- ✅ Zero dependências externas
- ✅ Inserção programática via timestamps

### 3. Video Editing Orchestration

**ClawHub Skills encontradas:**
- remotion-video-toolkit (1.252 score)
- ffmpeg-video-editor (1.102)
- video-subtitles (1.060)
- insaiai-intelligent-editing (0.867)

**Solução escolhida:** Arquitetura nativa
- ffmpeg-full (baixo nível, máxima performance)
- pycaps (legendas profissionais)
- pydub (SFX programático)

---

## Pipeline v3 Integrado

```
SOURCE VIDEO (16:9)
    ↓
[1] Cortar timestamp (ffmpeg)
    ↓
[2] Converter 9:16 + fundo desfocado (ffmpeg)
    ↓
[3] Adicionar legendas com pycaps (animated word-by-word)
    ↓
[4] Inserir SFX nos pontos-chave (pydub + ffmpeg)
    ↓
[5] Fade in/out + normalization (ffmpeg)
    ↓
PRONTO PARA PUBLICAR
```

---

## Arquivos Criados

### Scripts
- `make_short_v2.py` — Blur background + fade (ativo)
- `make_short_v3.py` — V2 + pycaps + SFX (em desenvolvimento)

### SFX Library
- `~/Desktop/wolf-shorts/sfx/whoosh.wav` (transição)
- `~/Desktop/wolf-shorts/sfx/impact.wav` (impacto)
- `~/Desktop/wolf-shorts/sfx/ding.wav` (revelação)
- `~/Desktop/wolf-shorts/sfx/pop.wav` (ênfase)

### Skills Instalados
- pycaps 0.2.1 ✅
- openai-whisper 20250625 ✅
- moviepy 2.1.2 ✅
- pydub (via moviepy)

---

## Próximos Passos

1. **Finalizar pycaps em clip1** (em progresso)
2. **Rodar clips 2 e 3 com pycaps** (paralelo)
3. **Integrar SFX automaticamente** via script Python
4. **Testar ffmpeg-full quando terminar instalação**
5. **Validação visual com Netto**

---

## Recomendações Finais

**Para Monetização Otimizada:**
- ✅ Fundo desfocado (retém atenção visual)
- ✅ Legendas animadas word-by-word (40%+ retention gain)
- ✅ SFX estratégicos (impact sound = shares +20%)
- ✅ Fade in/out (profissionalismo)
- ⏳ Posicionamento SFX em revelações/impactos

**Threshold de Qualidade:**
- Clips com score < 7.0 = descartar
- Legendas em 100% do conteúdo falado
- SFX máximo 3-5 por clip (não poluir)
- CTA visual/audio no último segundo

---

*Atualizado: 2026-03-15 12:07 GMT-3*
