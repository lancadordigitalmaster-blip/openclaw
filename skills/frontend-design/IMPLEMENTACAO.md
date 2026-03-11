# Frontend Design — Skill de Design de Interfaces

> Cria interfaces frontend distinctive e production-grade com alta qualidade de design, evitando estética genérica de "AI slop".

---

## 📋 RESUMO DA IMPLEMENTAÇÃO

**Status:** ✅ Implementada

| Componente | Status |
|------------|--------|
| Skill instalada | ✅ `skills/frontend-design/` |
| SKILL.md | ✅ 4.2KB |
| LICENSE | ✅ MIT |
| Complexidade | Baixa (skill de orientação) |

---

## 🎯 O QUE FAZ

**Skill de design para interfaces frontend:**

1. **Design Thinking** — Define direção estética ANTES de codar
2. **Criação de código** — HTML/CSS/JS, React, Vue, etc.
3. **Qualidade visual** — Foco em estética única e memorável
4. **Production-grade** — Código funcional e polido

---

## 🎨 FILOSOFIA DE DESIGN

### 🚫 O QUE EVITAR (AI Slop)

| Elemento | Exemplo Genérico |
|----------|------------------|
| Fontes | Inter, Roboto, Arial, system-fonts |
| Cores | Gradientes roxos em fundo branco |
| Layout | Grids previsíveis, simétricos demais |
| Animações | Micro-interações genéricas espalhadas |

### ✅ O QUE BUSCAR

| Princípio | Aplicação |
|-----------|-----------|
| **Tipografia distintiva** | Fontes com personalidade, pairing inesperado |
| **Paleta coesa** | Cores dominantes + accent sharp |
| **Motion intencional** | 1 página load orquestrado > 10 micro-interações |
| **Layout inesperado** | Assimetria, overlap, diagonal flow, grid-breaking |
| **Backgrounds atmosféricos** | Gradient meshes, noise, geometric patterns, camadas |

---

## 🧠 DESIGN THINKING (Processo)

Antes de criar, define:

```
1. PROPÓSITO
   - Qual problema resolve?
   - Quem usa?

2. TOM (escolher extremo)
   - Brutalmente minimalista
   - Maximalista chaos
   - Retro-futuristic
   - Organic/natural
   - Luxury/refined
   - Playful/toy-like
   - Editorial/magazine
   - Brutalist/raw
   - Art deco/geometric
   - Soft/pastel
   - Industrial/utilitarian

3. RESTRIÇÕES
   - Framework (React, Vue, vanilla)
   - Performance
   - Accessibility

4. DIFERENCIAÇÃO
   - O que torna INESQUECÍVEL?
   - Qual o elemento memorável?
```

---

## 🛠️ TECNOLOGIAS SUPORTADAS

| Tecnologia | Uso |
|------------|-----|
| HTML/CSS/JS | Vanilla, zero-dependency |
| React | Componentes, Motion library |
| Vue | Componentes Vue 3 |
| Tailwind | Utility-first styling |
| CSS Variables | Theming consistente |

---

## 📝 EXEMPLOS DE USO

### 1. Landing Page

**Prompt:**
```
Cria uma landing page para curso de marketing digital
Estilo: editorial/magazine
Público: empreendedores 25-40
```

**Resultado:**
- Layout assimétrico tipo revista
- Typography bold (display font + body refinado)
- Scroll reveals com stagger
- Background com textura editorial

### 2. Dashboard

**Prompt:**
```
Dashboard de métricas de ads
Estilo: industrial/utilitarian
Dark mode
```

**Resultado:**
- Grid utilitário, spacing consistente
- Cores: dark charcoal + accent neon
- Fontes: monospace para dados
- Animações: hover states funcionais

### 3. Portfolio

**Prompt:**
```
Portfolio para designer gráfico
Estilo: brutalist/raw
```

**Resultado:**
- Layout grid-breaking
- Typography brutal (espace, space Grotesk)
- Cores: high contrast B/W + 1 accent
- Cursor custom, hover effects raw

---

## 🎨 ELEMENTOS DE DESIGN

### Typography
```css
/* ❌ Genérico */
font-family: 'Inter', system-ui, sans-serif;

/* ✅ Distintivo */
font-family: 'Editorial New', display;
font-family: 'Satoshi Variable', sans-serif;
```

### Color
```css
/* ❌ Tímido */
background: #f5f5f5;
color: #333;

/* ✅ Coeso com propósito */
--dominant: #0a0a0a;
--accent: #ff4d00;  /* International Orange */
--surface: #1a1a1a;
```

### Motion
```css
/* ❌ Micro-interações aleatórias */
.button:hover { transform: scale(1.02); }

/* ✅ Orquestrado */
.fade-in {
  opacity: 0;
  transform: translateY(20px);
  animation: reveal 0.8s ease forwards;
  animation-delay: calc(var(--i) * 0.1s);
}
```

### Background
```css
/* ❌ Solid color */
background: #ffffff;

/* ✅ Atmosférico */
background:
  radial-gradient(circle at 20% 50%, rgba(255,77,0,0.1), transparent 50%),
  url('noise.png'),
  #0a0a0a;
```

---

## 💡 CASOS DE USO (Wolf Agency)

### 1. **Landing Pages de Clientes**
- Cursos, produtos, serviços
- Design único por cliente (não template)
- Production-ready

### 2. **Dashboards Internos**
- Reports de campanhas
- Métricas de equipe
- Estilo utilitário/refined

### 3. **Apresentações**
- Pitch decks (HTML/CSS animado)
- Slides interativos
- Mais impactante que PowerPoint

### 4. **Componentes para Social**
- Cards de posts animados
- Story templates em HTML
- Exporta como imagem via browser

### 5. **Portfolio da Agência**
- Site institucional
- Style: luxury/refined ou editorial
- Diferencia do mercado

---

## 🔧 COMO USAR

**Prompt base:**
```
Cria [COMPONENTE/PÁGINA] para [PROPÓSITO]
Estilo: [TOM ESTÉTICO]
Público: [QUEM USA]
Restrições: [TECH/PERF/A11Y]
```

**Eu faço:**
1. Entendo propósito e público
2. Escolho direção estética (bold choice)
3. Defino elementoschave (typo, color, motion, layout)
4. Gero código production-grade
5. Reviso estética (polish)

---

## 📊 ESTRUTURA INSTALADA

```
frontend-design/
├── SKILL.md          ✅ 4.2KB
├── _meta.json        ✅
└── LICENSE.txt       ✅ MIT
```

**Tipo:** Skill de orientação/guia de design
**Não tem:** Scripts, dependências externas
**Complexidade:** Baixa (conteúdo de referência)

---

## 🎯 VALOR PARA WOLF AGENCY

| Benefício | Impacto |
|-----------|---------|
| **Landing pages únicas** | Clientes não usam template genérico |
| **Dashboards internos** | Visual refinado, funcional |
| **Componentes Social** | Exporta como imagem para posts |
| **Pitch decks** | Apresentações em HTML/CSS |
| **Portfolio Wolf** | Site institucional com design premium |

---

## 🚀 PRÓXIMOS PASSOS SUGERIDOS

1. **Criar biblioteca de componentes**
   - Salvar componentes gerados em `components/`
   - Reutilizar em projetos futuros

2. **Templates por estilo**
   - 1 template editorial
   - 1 template brutalist
   - 1 template minimalista
   - Base para iterações rápidas

3. **Exportação para imagem**
   - Integrar com browser tool
   - Screenshot de componentes para Social

4. **Integração com video-pipeline**
   - Motion graphics em CSS
   - Intro/outro animado para vídeos

---

## 📈 COMPARAÇÃO: Antes vs Depois

| Antes | Depois |
|-------|--------|
| Templates genéricos | Design único por projeto |
| Fontes system | Typography curada |
| Layouts previsíveis | Composição inesperada |
| UI "funcional" | UI memorável + funcional |
| Sem direction | TOM estético definido |

---

*Implementado: 2026-03-05 22:01 BRT*  
*Tipo: Skill de orientação de design*  
*Próximos: biblioteca de componentes Wolf*
