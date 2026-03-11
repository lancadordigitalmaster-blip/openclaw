# Caption Style Guide — Video Editor Pro
# Wolf Agency

---

## Princípios Fundamentais

1. **Legibilidade acima de tudo**
2. **Menos é mais** (texto mínimo necessário)
3. **Ideias quebradas, não frases longas**
4. **Contraste garantido em qualquer fundo**

---

## Formato Técnico

### Fontes Recomendadas

| Uso | Fonte | Peso |
|-----|-------|------|
| Títulos/Destaques | Montserrat, Poppins | Bold (700) |
| Corpo/Legendas | Inter, Open Sans | Semi-bold (600) |
| UGC/Natural | System fonts | Regular (400) |

### Tamanhos

| Plataforma | Título | Legenda | Mínimo |
|------------|--------|---------|--------|
| Reels/Stories (1080x1920) | 72–96px | 48–64px | 32px |
| YouTube/VSL (1920x1080) | 96–120px | 48–72px | 36px |

### Cores

**Texto:**
- Branco puro: `#FFFFFF`
- Off-white: `#F5F5F5`

**Destaques:**
- Wolf Cyan: `#00D4FF`
- Wolf Orange: `#FF6B35`
- Vermelho alerta: `#FF4444`

**Stroke/Sombra:**
- Preto 80%: `rgba(0,0,0,0.8)`
- Stroke: 4–6px

---

## Modos de Legenda

### 1. Word-by-Word (Alta Energia)

**Uso:** Reels, TikTok, conteúdo de alta retenção

**Características:**
- Uma palavra por vez
- Sincronizado com fala
- Cor diferente para palavra ativa
- Animação de entrada (pop, slide)

**Exemplo:**
```
[Você] ← ativa (cyan)
 precisa
 ver
 isso
```

**Timing:**
- Palavra aparece: 100ms antes da fala
- Palavra ativa: duração da sílaba
- Transição: 2–3 frames

---

### 2. Blocos (Premium)

**Uso:** VSL, conteúdo educativo, marca forte

**Características:**
- Frase completa ou ideia
- Máximo 2 linhas
- Fundo semi-transparente (opcional)
- Posição fixa

**Exemplo:**
```
┌─────────────────────────────┐
│  3 estratégias que usamos   │
│  para escalar campanhas     │
└─────────────────────────────┘
```

**Timing:**
- Aparece: com a fala
- Desaparece: 500ms após fala terminar
- Fade: 8–12 frames

---

### 3. Híbrido (Padrão Wolf)

**Uso:** Padrão para maioria dos conteúdos

**Características:**
- Bloco de texto
- Palavras-chave destacadas com cor
- Ênfase em: verbos, números, promessas

**Exemplo:**
```
Com essa estratégia fizemos
[+] R$ 50 mil [+] em 7 dias
```

**Destaques:**
- `[+]` = cor de destaque (cyan)
- Números sempre destacados
- Verbos de ação destacados

---

## Quebra de Texto

### Regras

1. **Quebrar em ideias**, não em sílabas
2. **Máximo 2 linhas** por bloco
3. **Palavras-chave** não quebrar
4. **Números** sempre com unidade na mesma linha

**Exemplo ruim:**
```
Com essa estratégia
fizemos R$ 50
mil em 7 dias
```

**Exemplo bom:**
```
Com essa estratégia fizemos
R$ 50 mil em 7 dias
```

### Quebra por Plataforma

| Plataforma | Máx caracteres/bloco | Máx linhas |
|------------|----------------------|------------|
| Reels | 40 | 2 |
| Stories | 35 | 2 |
| YouTube | 50 | 2 |
| VSL | 60 | 2 |

---

## Ênfase e Destaque

### O que Destacar

| Tipo | Exemplo | Cor |
|------|---------|-----|
| Números | 10x, R$50k, 7 dias | Cyan `#00D4FF` |
| Verbos de ação | Aumente, Ganhe, Descubra | Orange `#FF6B35` |
| Promessas | Resultado garantido, Sem erro | Cyan `#00D4FF` |
| Alertas | Cuidado, Não faça | Red `#FF4444` |
| Benefícios | Grátis, Agora, Exclusivo | Orange `#FF6B35` |

### Como Destacar

1. **Cor diferente** (padrão)
2. **Negrito** (quando cor não disponível)
3. **Background highlight** (caixa colorida atrás)
4. **Scale up** (20–30% maior)

---

## Posicionamento

### Safe Areas

```
1080x1920 (Reels/Stories)
┌─────────────────────────────┐ ← 250px (evitar)
│                             │
│    ┌───────────────────┐    │
│    │   TEXTO SEGURO    │    │ ← Centro
│    └───────────────────┘    │
│                             │
└─────────────────────────────┘ ← 250px (evitar)
         ↑ CTA Instagram
```

### Alinhamento

| Contexto | Alinhamento |
|----------|-------------|
| Título único | Centro |
| Lista/bullet | Esquerda |
| Diálogo | Alternado (quem fala) |
| CTA | Centro, parte inferior segura |

---

## Animações

### Entrada

| Tipo | Uso | Duração |
|------|-----|---------|
| Fade in | Padrão | 8–12 frames |
| Slide up | Energia | 6–10 frames |
| Pop | Atenção | 4–6 frames |
| Typewriter | Tecnologia | Sincronizado |

### Saída

| Tipo | Uso | Duração |
|------|-----|---------|
| Fade out | Padrão | 8–12 frames |
| Slide down | Transição | 6–10 frames |
| Scale down | Finalização | 8 frames |

### Emphasis (Loop)

| Tipo | Uso | Duração |
|------|-----|---------|
| Pulse | CTA | 1s loop |
| Glow | Destaque | 2s loop |
| Shake | Alerta | 0.3s |

---

## Checklist de Qualidade

- [ ] Texto legível em mobile (tamanho mínimo)
- [ ] Contraste suficiente (testar em fundo claro/escuro)
- [ ] Máximo 2 linhas por bloco
- [ ] Palavras-chave destacadas
- [ ] Timing sincronizado com fala
- [ ] Safe areas respeitadas
- [ ] Animações suaves (não agressivas)
- [ ] Consistência visual (mesmo estilo no vídeo)

---

## Templates de Exemplo

### Template 1: Reels Educativo

```
[HOOK - 2s]
┌─────────────────────────────┐
│     VOCÊ ESTÁ PERDENDO      │
│        DINHEIRO?            │
└─────────────────────────────┘

[CONTEÚDO - 10s]
┌─────────────────────────────┐
│  3 erros que custam caro:   │
└─────────────────────────────┘

┌─────────────────────────────┐
│  [1] Não testar criativos   │
└─────────────────────────────┘

┌─────────────────────────────┐
│  [2] Ignorar métricas       │
└─────────────────────────────┘

┌─────────────────────────────┐
│  [3] Copiar concorrente     │
└─────────────────────────────┘

[CTA - 2s]
┌─────────────────────────────┐
│    SALVE PARA NÃO ESQUECER   │
└─────────────────────────────┘
```

### Template 2: VSL

```
[HOOK]
Como fizemos [+] R$ 100 mil [+] em 30 dias

[PROBLEMA]
A maioria das agências comete esse erro

[PROVA]
Resultado do cliente: [+] 300% ROI [+]

[CTA]
Clique no link abaixo
```

---

*Wolf Agency | Video Editor Pro*
