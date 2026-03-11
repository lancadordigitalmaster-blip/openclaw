# 🎬 Video AI Training Framework — Wolf Agency

> Como treinar e evoluir a criação de vídeos com Remotion + AI

---

## 🎯 O Problema

Vídeos atuais são bons, mas podem ser **excepcionais**. O que falta:

| Problema | Solução |
|----------|---------|
| Animações genéricas | Biblioteca de easing curves específicas |
| Falta de referências | Banco de referências categorizado |
| Repetição de padrões | Variações paramétricas |
| Sem feedback loop | Sistema de avaliação + iteração |

---

## 🧠 Framework de Treinamento

### 1. REFERENCES — Biblioteca de Referências

**Estrutura:**
```
references/video/
├── brands/
│   ├── rolex/              → Análise de motion, timing
│   ├── apple/              → Minimalismo, transições
│   ├── louis-vuitton/      → Luxo, texturas
│   └── nike/               → Energia, ritmo
├── styles/
│   ├── kinetic-typography/ → Texto em movimento
│   ├── 3d-product/         → Rotações, iluminação
│   ├── glitch/             → Efeitos modernos
│   └── cinematic/          → Color grading, mood
└── techniques/
    ├── easing-curves.md    → Curvas específicas
    ├── transitions.md      → Cortes criativos
    └── effects.md          → Glow, blur, particles
```

**Como usar:**
1. Antes de criar, consultar 3 referências do estilo desejado
2. Extrair: timing, cores, easing, composição
3. Aplicar no código Remotion

---

### 2. PROMPTS — Estrutura de Prompts

**Template de Prompt para Vídeo:**

```markdown
# Brief de Vídeo — [Nome do Projeto]

## 🎯 Objetivo
- Tipo: [VSL / Reels / Anúncio / Intro]
- Duração: [X segundos]
- Propósito: [Vender / Engajar / Informar]

## 👥 Público
- Demografia: [Idade, gênero, local]
- Interesses: [Nichos]
- Dor/Desejo: [Problema que resolve]

## 🎨 Estilo Visual
- Referências: [Links ou descrições]
- Cores principais: [#hex codes]
- Mood: [Luxury / Energético / Calmo / Tecnológico]
- Fontes: [Serif / Sans / Custom]

## 📝 Conteúdo
- Hook: [Primeiros 2-3 segundos]
- Mensagem principal: [O que comunicar]
- CTA: [Ação final]
- Assets: [Imagens, vídeos, áudio disponíveis]

## ⚡ Motion
- Ritmo: [Lento / Médio / Rápido]
- Transições: [Suaves / Cortes secos / Efeitos]
- Easing preferido: [ease-out / spring / bounce]

## 📐 Especificações Técnicas
- Resolução: [1080x1920 / 1920x1080]
- FPS: [30 / 60]
- Formato: [MP4 / GIF / WebM]
```

---

### 3. COMPONENTS — Biblioteca de Componentes Reutilizáveis

**Estrutura de Componentes:**

```typescript
// components/
├── animations/
│   ├── FadeIn.tsx          // Opacity 0→1 com easing
│   ├── SlideIn.tsx         // Translate X/Y
│   ├── ScaleIn.tsx         // Zoom suave
│   ├── Rotate3D.tsx        // Rotação 3D
│   └── Parallax.tsx        // Movimento de fundo
├── effects/
│   ├── Glow.tsx            // Brilho dourado/prateado
│   ├── LightSweep.tsx      // Varredura de luz
│   ├── Particles.tsx       // Partículas flutuantes
│   ├── Reflection.tsx      // Reflexo em superfície
│   └── Grain.tsx           // Textura de filme
├── text/
│   ├── Typewriter.tsx      // Texto digitando
│   ├── Reveal.tsx          // Revelação letra a letra
│   ├── Scramble.tsx        // Efeito de scramble
│   └── GradientText.tsx    // Texto com gradiente
└── product/
    ├── Watch.tsx           // Componente de relógio
    ├── Phone.tsx           // Mockup de celular
    ├── Card.tsx            // Card de produto
    └── Bottle.tsx          // Garrafa/produto
```

**Exemplo de Componente Reutilizável:**

```tsx
// components/effects/LightSweep.tsx
import {useCurrentFrame, interpolate, Easing} from 'remotion';

interface LightSweepProps {
  startFrame: number;
  duration: number;
  color?: string;
}

export const LightSweep: React.FC<LightSweepProps> = ({
  startFrame,
  duration,
  color = 'rgba(255,255,255,0.4)'
}) => {
  const frame = useCurrentFrame();
  
  const position = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [-200, 1280],
    {easing: Easing.inOut(Easing.ease)}
  );
  
  return (
    <div style={{
      position: 'absolute',
      left: position,
      width: 100,
      height: '100%',
      background: `linear-gradient(90deg, transparent, ${color}, transparent)`,
      transform: 'skewX(-20deg)',
    }} />
  );
};
```

---

### 4. EASING CURVES — Curvas de Animação

**Biblioteca de Easings:**

```typescript
// lib/easings.ts

// Luxury - Suave, elegante
export const luxury = {
  entrance: Easing.out(Easing.ease),
  exit: Easing.in(Easing.ease),
  emphasis: Easing.inOut(Easing.ease),
};

// Energetic - Rápido, dinâmico
export const energetic = {
  entrance: Easing.out(Easing.back(1.5)),
  exit: Easing.in(Easing.back(1.2)),
  bounce: Easing.elastic(1),
};

// Cinematic - Filme, drama
export const cinematic = {
  slow: Easing.inOut(Easing.ease),
  dramatic: Easing.inOut(Easing.circ),
  reveal: Easing.out(Easing.quad),
};

// Tech - Moderno, digital
export const tech = {
  snap: Easing.out(Easing.expo),
  glitch: Easing.linear,
  morph: Easing.inOut(Easing.sine),
};
```

---

### 5. FEEDBACK LOOP — Sistema de Melhoria

**Processo:**

```
1. CRIAR → Gerar vídeo com prompt estruturado
2. AVALIAR → Scorecard de qualidade (0-100)
3. COLETAR → Feedback do cliente/equipe
4. ITERAR → Ajustar e re-renderizar
5. DOCUMENTAR → Salvar aprendizado
```

**Scorecard de Vídeo:**

| Critério | Peso | Nota |
|----------|------|------|
| Impacto visual (hook) | 25% | 0-10 |
| Clareza da mensagem | 20% | 0-10 |
| Qualidade técnica | 20% | 0-10 |
| Timing/ritmo | 15% | 0-10 |
| Brand consistency | 10% | 0-10 |
| CTA efetividade | 10% | 0-10 |

**Score total:** Soma ponderada
- 90-100: Excelente
- 75-89: Bom
- 60-74: Regular
- <60: Refazer

---

### 6. PROMPT ENGINEERING — Melhorando os Prompts

**Antes (genérico):**
> "Crie um vídeo de relógio de luxo"

**Depois (estruturado):**
> "Crie um anúncio de 10s para relógio de luxo. Estilo: cinematic dark luxury. Cores: black #0a0a0a, gold #c9a227. Motion: slow zoom + light sweep. Referências: Rolex Oyster campaign, Apple Watch Series 8. Público: homens 35-55 anos, renda alta. Hook: close-up do mostrador aparecendo da escuridão. CTA: 'Discover the Collection'"

**Elementos que melhoram o resultado:**
1. **Duração específica** → Timing preciso
2. **Referências concretas** → Direção visual clara
3. **Cores em hex** → Consistência exata
4. **Público definido** → Tom adequado
5. **Hook descrito** → Primeiros segundos fortes
6. **CTA clara** → Objetivo definido

---

## 🚀 Implementação

### Passo 1: Criar Biblioteca de Referências
```bash
mkdir -p references/video/{brands,styles,techniques}
# Coletar 10-20 vídeos de referência por categoria
# Extrair: timing, cores, easing, composição
```

### Passo 2: Componentizar
```bash
# Identificar padrões que se repetem
# Criar componentes reutilizáveis
# Documentar props e uso
```

### Passo 3: Prompts Padronizados
```bash
# Criar template de brief
# Preencher sempre antes de criar
# Revisar com cliente antes de renderizar
```

### Passo 4: Feedback Loop
```bash
# Criar scorecard
# Coletar notas após cada entrega
# Ajustar próximos vídeos baseado no aprendizado
```

---

## 📈 Métricas de Evolução

**Acompanhar:**
- Tempo de criação (meta: reduzir 50%)
- Taxa de aprovação na primeira versão (meta: 80%)
- Score médio dos vídeos (meta: 85+)
- Reutilização de componentes (meta: 60%)

---

*Video AI Training Framework v1.0 — Wolf Agency*
