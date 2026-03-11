# Sound Design Guide — Video Editor Pro

> Procedimento completo de tratamento de áudio

---

## Fluxo de Trabalho de Áudio

```
1. LIMPEZA → 2. EQ → 3. COMPRESSÃO → 4. DE-ESSER → 5. LIMITER → 6. MIX
```

---

## 1. Limpeza

### Remoção de Ruído

**Quando aplicar:**
- Ruído de fundo consistente (ar condicionado, vento)
- Hum elétrico (50/60Hz)
- Ruído de câmera/microfone

**Ferramentas:**
- Premiere: Denoiser (Essential Sound)
- Audition: Noise Reduction
- RX: Voice De-noise

**Configuração conservadora:**
- Sensibilidade: 6–8
- Redução: 6–10dB
- Evitar artefatos "underwater"

### Remoção de Hum

**Frequências:**
- Brasil: 50Hz (e harmônicos 100Hz, 150Hz...)
- EUA: 60Hz (e harmônicos 120Hz, 180Hz...)

**Ferramentas:**
- EQ: notch filter em 50Hz com Q alto (10+)
- RX: De-hum automático

---

## 2. EQ (Equalização)

### EQ por Tipo de Voz

**Voz Masculina:**
```
- Low cut: 80Hz (remove ronco)
- Presence: +2dB em 3–5kHz (clareza)
- Air: +1dB em 10kHz+ (brilho)
```

**Voz Feminina:**
```
- Low cut: 100Hz
- Body: +1dB em 200–400Hz (corpo)
- Presence: +2dB em 4–6kHz
- Air: +1dB em 12kHz+
```

### Problemas Comuns

| Problema | Frequência | Solução |
|----------|------------|---------|
| **Lama** | 120–250Hz | Reduzir 2–3dB |
| **Caixa** | 300–500Hz | Reduzir 2dB |
| **Nasal** | 800Hz–1.2kHz | Reduzir 2–3dB |
| **Harsh** | 2–4kHz | Reduzir 2dB |
| **Sibilância** | 4–8kHz | De-esser (não EQ) |

---

## 3. Compressão

### Compressão de Voz

**Objetivo:** Nivelar dinâmica, voz sempre audível

**Configuração padrão:**
```
Threshold: -18dB a -12dB
Ratio: 3:1 a 4:1
Attack: 5–10ms
Release: 50–100ms
Makeup Gain: Aplicar ganho perdido
```

**Compressão em série (opcional):**
- **Compressor 1:** Suave, nivelar (2:1, -20dB)
- **Compressor 2:** Controle de picos (4:1, -12dB)

---

## 4. De-esser

### Controle de Sibilância

**Frequências:** 4–8kHz (varia por voz)

**Configuração:**
```
Threshold: Ajustar até sibilância controlar
Reduction: 6–10dB
Frequency: 5–7kHz (encontrar por voz)
```

**Cuidado:**
- Não exagerar (voz fica "lisp")
- Ajustar threshold cuidadosamente

---

## 5. Limiter

### Proteção de Pico

**Objetivo:** Evitar clipping, maximizar volume

**Configuração:**
```
Ceiling: -1dB (nunca 0dB)
Threshold: -3dB a -6dB
Release: 10–50ms
```

**True Peak:**
- Ativar se disponível
- Evitar inter-sample peaks

---

## 6. Mix Final

### Níveis de Mix

| Elemento | Nível | Notas |
|----------|-------|-------|
| **Voz principal** | -12dB a -6dB | Pico máximo |
| **Música** | -18dB a -24dB | Abaixo da voz |
| **SFX** | -12dB a -6dB | Pontuais |
| **Ambiente** | -24dB a -30dB | Muito baixo |

### Sidechain (Ducking)

**Quando usar:**
- Música precisa baixar quando há fala
- Voz sempre dominante

**Configuração:**
```
Trigger: Voz principal
Target: Música
Reduction: 6–10dB
Attack: 10ms
Release: 100–200ms
```

---

## Música

### Seleção

| Tipo de Vídeo | Estilo Musical | BPM |
|---------------|----------------|-----|
| VSL (venda) | Orquestral/Epic | 80–100 |
| Tutorial | Lo-fi/Ambient | 70–90 |
| Reels (energia) | Electronic/Pop | 120–140 |
| UGC | Natural/Acoustic | 90–110 |

### Mix de Música

- Sempre abaixo da voz (-18dB a -24dB)
- Cortar frequências conflitantes (1–4kHz)
- Fade in/out suaves
- Loop seamless quando necessário

---

## SFX (Sound Effects)

### Uso Pontual

| Momento | SFX | Função |
|---------|-----|--------|
| Hook | Whoosh, impact | Atenção |
| Reveal | Ding, pop | Ênfase |
| Transição | Whoosh, swipe | Fluxo |
| CTA | Click, confirm | Ação |
| Erro | Buzz, fail | Feedback |

### Biblioteca Essencial

```
sfx/
├── transitions/
│   ├── whoosh_fast.mp3
│   ├── whoosh_slow.mp3
│   └── swipe.mp3
├── accents/
│   ├── ding.mp3
│   ├── pop.mp3
│   └── click.mp3
├── impacts/
│   ├── impact_heavy.mp3
│   └── impact_light.mp3
└── ui/
    ├── notification.mp3
    ├── error.mp3
    └── success.mp3
```

---

## Checklist de Áudio

### Gravação
- [ ] Nível de entrada correto (-12dB a -6dB)
- [ ] Sem clipping
- [ ] Ambiente controlado
- [ ] Microfone posicionado corretamente

### Edição
- [ ] Cortes limpos (sem pops)
- [ ] Transições suaves
- [ ] Volume consistente entre takes
- [ ] Pausas naturais mantidas

### Pós-Produção
- [ ] Limpeza de ruído aplicada
- [ ] EQ otimizado para voz
- [ ] Compressão nivelando dinâmica
- [ ] De-esser controlando sibilância
- [ ] Limiter protegendo de clipping
- [ ] Mix balanceado (voz > música > SFX)

---

## Ferramentas Recomendadas

### Premiere Pro
- Essential Sound panel
- Parametric Equalizer
- Single-band Compressor
- Hard Limiter

### After Effects
- Same as Premiere (copiar áudio)

### Plugins (Opcional)
- **Waves:** Vocal Rider, DeEsser, L1 Limiter
- **iZotope:** RX (restauração), Ozone (master)
- **FabFilter:** Pro-Q 3, Pro-C 2, Pro-L 2

---

*Sound Design Guide v1.0 — Video Editor Pro*
