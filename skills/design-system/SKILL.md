---
name: design-system
description: >
  Extrai e gera Design Systems completos a partir de qualquer input visual ou textual.
  Use esta skill SEMPRE que o usuário mencionar: design system, tokens de design, paleta de cores de um site,
  extrair estilo visual, criar página de componentes, UI kit, style guide, brand guidelines, "olha esse site
  e replica o estilo", "extrai as cores desse layout", "gera o design system da marca X", referência visual
  para componentes, análise de identidade visual, CSS variables de um site, Tailwind config baseado em marca,
  ou qualquer pedido de capturar/replicar/documentar a estética de um produto digital ou criativo.
  Também aplique quando o usuário enviar screenshots, imagens de UI, URLs de sites ou arquivos CSS/HTML
  pedindo para "entender o estilo", "montar os componentes" ou "criar uma referência visual".
---

# Design Extractor

Skill de extração, análise e geração de Design Systems completos para a Wolf Agency.
Pipeline de 3 fases: **Análise → Tokens → Output**.

---

## FASE 1 — ANÁLISE VISUAL

Antes de qualquer geração, execute silenciosamente esta análise:

### 1.1 Detectar Input
| Tipo de Input | Ação |
|---|---|
| URL de site | Usar web_fetch para capturar HTML/CSS, extrair variáveis |
| Imagem / Screenshot | Análise visual direta (Claude Vision) |
| Multi-screenshot (2-3 prints) | Análise cruzada — consolidar tokens de todas as imagens |
| Arquivo CSS/HTML | Parse das variáveis e classes |
| Descrição textual | Inferir estética pelo contexto |
| Criativo (banner, post) | Análise de composição e elementos |

### 1.1.1 Protocolo Multi-Screenshot (recomendado para maior fidelidade)

Quando o usuário enviar **2 ou mais screenshots** de uma página/produto:

1. **Analisar cada imagem separadamente** — extrair cores, tipografia, espaçamento, componentes visíveis
2. **Cruzar dados entre imagens** — identificar tokens que se repetem (cores consistentes, famílias tipográficas, padrões de radius/spacing)
3. **Resolver conflitos** — se uma cor aparece diferente entre prints (ex: shadow vs luz), priorizar a versão mais frequente
4. **Mapear componentes únicos** — cada screenshot pode revelar componentes diferentes (hero, cards, forms, footer)
5. **Consolidar em um único Token Map** antes de gerar output

**Prints recomendados para melhor resultado:**
- Print 1: **Hero/Header** — captura cores primárias, tipografia display, CTAs, navegação
- Print 2: **Conteúdo/Cards** — captura surface colors, borders, sombras, espaçamento entre elementos
- Print 3: **Footer/Forms** (opcional) — captura cores secundárias, inputs, badges, estados

**Instrução ao usuário via WhatsApp:**
Quando o usuário pedir design system de um site/app, sugerir:
> "Me manda 2-3 prints da página: um do topo (hero), um do meio (cards/conteúdo) e opcionalmente um do rodapé. Quanto mais prints, mais fiel fica o design system."

**Se receber apenas 1 print:** funciona, mas avisar que mais prints = resultado mais completo.

**Extração visual por print (checklist):**
- [ ] Cor de fundo (background) — pegar o hex exato pelo pixel dominante
- [ ] Cor das superfícies (cards, modais) — comparar com o fundo
- [ ] Cor das bordas — se visíveis
- [ ] Cor do texto principal e secundário
- [ ] Cor do accent/CTA — botões, links, destaques
- [ ] Família tipográfica — identificar pelo desenho das letras (sans-serif/serif/mono)
- [ ] Escala de tamanhos — comparar H1 vs body vs caption
- [ ] Border-radius — sharp (0-4px), soft (8-12px), rounded (16-24px), pill (9999px)
- [ ] Sombras — nenhuma, sutil, média, pesada
- [ ] Espaçamento — compacto (4-8px base), normal (8-16px), generoso (16-32px)

### 1.2 Extrair Tokens Primários

Identificar e mapear:

**Cores** (em ordem de prioridade):
- Background principal e secundário
- Surface/card
- Border/separator
- Texto primário, secundário, desabilitado
- Accent/CTA primário
- Accent secundário
- Estado: success, warning, error, info
- Hex exato + nome semântico

**Tipografia:**
- Família(s) — display vs body vs mono
- Escala de tamanhos (px)
- Pesos utilizados (sem 800/900)
- Line-height e letter-spacing notáveis

**Espacamento:**
- Unidade base (4px ou 8px)
- Escala aplicada (xs/sm/md/lg/xl/2xl)
- Border radius pattern (sharp/soft/pill)

**Sombras e Efeitos:**
- Box-shadow layers
- Backdrop-filter (glassmorphism)
- Gradientes (direção + stops)
- Glow/neon effects

### 1.3 Detectar Estética Predominante

| Estética | Indicadores |
|---|---|
| **Minimal/Clean** | ≤3 cores, espaço generoso, sem sombras pesadas |
| **Glassmorphism** | backdrop-filter, rgba, bordas translúcidas |
| **Industrial/Dark** | bg #0d-1a, acentos LED, sombras metálicas inset |
| **Cyberpunk** | neons, clip-path, bg #050a, glows coloridos |
| **Brutalist** | bordas espessas, cores chapadas, ausência de sombras suaves |
| **Corporate/SaaS** | azuis/roxos, cards limpos, tipografia Inter/Geist |
| **Luxury/Premium** | dourados, serif, espaçamento maximalista |
| **Playful/Consumer** | cores vibrantes, rounded-full, gradientes suaves |

Estéticas podem ser **híbridas** — detecte e documente as duas.

Para referência detalhada de cada estética com CSS de exemplo, leia `references/aesthetics.md`.

---

## FASE 2 — TOKEN MAP (Estrutura Interna)

Monte mentalmente (ou em comentário no código) este mapa antes de gerar qualquer output:

```
DESIGN TOKENS
─────────────────────────────────────────
CORES
  bg:           #_____
  surface:      #_____
  border:       #_____
  text:         #_____
  text-muted:   #_____
  accent:       #_____
  accent-2:     #_____
  success:      #_____
  warning:      #_____
  error:        #_____

TIPOGRAFIA
  família display:  ___________
  família mono:     ___________
  escala: 12/14/16/20/24/32/40/56px
  pesos: 400/500/600/700

ESPAÇAMENTO
  base: ___px
  escala: 4/8/12/16/24/32/48/64/96px
  radius: sm=___px md=___px lg=___px full=9999px

EFEITOS
  shadow-sm: ___________
  shadow-md: ___________
  shadow-lg: ___________
  ease: cubic-bezier(.44,0,.56,1)

ESTÉTICA: ___________
─────────────────────────────────────────
```

---

## FASE 3 — OUTPUT

Selecione o modo conforme pedido do usuário. Se não especificado, use **Modo A (padrão)**.

---

### MODO A — Design System HTML (padrão)

Gera página HTML completa de documentação visual.

**Seções obrigatórias:**

```
1. HERO          — Título do sistema + baseline + 2 CTAs
2. TYPOGRAPHY    — Escala H1-H6, body, caption, code/mono
3. COLORS        — Swatches com hex, nome semântico, uso
4. COMPONENTS    — Card, botões (primary/secondary/ghost/danger),
                   toggle, input (default/focus/error),
                   badge (5 variantes), avatar, tooltip, alert
5. ELEVATION     — Escala de sombras/depth visualizada
6. MOTION        — Demonstração das easing curves
```

**Especificações técnicas:**
```html
<!-- SEMPRE usar -->
- HTML único com <style> embutido
- Google Fonts: Plus Jakarta Sans (400-700) + DM Mono (400-500)
- 2 breakpoints: base 390px + @media (min-width: 1440px)
- CSS Variables em :root para TODOS os tokens
- Transições: cubic-bezier(.44,0,.56,1) padrão
- :hover e :active em todos elementos interativos
- Comentários de seção: /* ─── SECTION NAME ─── */

<!-- NUNCA usar -->
- Pesos 800/900
- !important
- px fixos para font-size em body (use rem)
- Cores hardcoded fora do :root
```

**Adaptar à estética detectada:**

*Industrial/Dark:* gradientes metálicos, box-shadow múltiplos (inset + outer), acentos LED

*Glassmorphism:* backdrop-filter: blur(Xpx), rgba backgrounds, border 1px rgba(255,255,255,0.1)

*Cyberpunk:* text-shadow neon, clip-path em botões, animações de scan/glitch

*Brutalist:* border 3-4px solid, zero border-radius, cores chapadas sem sombras suaves

*Corporate/SaaS:* sistema de grid limpo, componentes com estados claros, acessibilidade

*Luxury:* tipografia serif para display, dourado como accent, espaçamento generoso

---

### MODO B — Design Tokens JSON

Exporta tokens no formato Style Dictionary / W3C Design Tokens:

```json
{
  "color": {
    "bg": { "value": "#0d0d0d", "type": "color", "description": "Background principal" },
    "surface": { "value": "#1a1a1a", "type": "color" },
    "accent": { "value": "#ff4444", "type": "color", "role": "primary-action" }
  },
  "typography": {
    "family-display": { "value": "Plus Jakarta Sans", "type": "fontFamily" },
    "size-hero": { "value": "56px", "type": "dimension" },
    "weight-heading": { "value": 600, "type": "fontWeight" }
  },
  "spacing": {
    "base": { "value": "8px", "type": "dimension" },
    "md": { "value": "16px", "type": "dimension" }
  },
  "radius": {
    "sm": { "value": "8px" }, "md": { "value": "12px" }, "lg": { "value": "20px" }
  },
  "shadow": {
    "card": { "value": "0 4px 24px rgba(0,0,0,0.4)" }
  }
}
```

Trigger: usuário pede "tokens", "JSON", "Style Dictionary", "Figma tokens", "exportar variáveis"

---

### MODO C — Tailwind Config

Exporta configuração para `tailwind.config.js`:

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        bg: '#0d0d0d',
        surface: '#1a1a1a',
        border: '#2a2a2a',
        accent: { DEFAULT: '#ff4444', hover: '#cc3333' }
      },
      fontFamily: {
        display: ['Plus Jakarta Sans', 'sans-serif'],
        mono: ['DM Mono', 'monospace']
      },
      boxShadow: {
        card: '0 4px 24px rgba(0,0,0,0.4)',
        glow: '0 0 20px rgba(255,68,68,0.4)'
      },
      borderRadius: { sm: '8px', md: '12px', lg: '20px' },
      animation: {
        'ease-wolf': 'cubic-bezier(.44,0,.56,1)'
      }
    }
  }
}
```

Trigger: usuário menciona "Tailwind", "config", "tema Tailwind"

---

### MODO D — Brand Audit Report

Gera análise crítica de consistência visual em Markdown:

```markdown
# Brand Audit — [Nome]

## Resumo Executivo
[Consistência geral: score /10, principais achados]

## Tokens Identificados
[tabela de cores, tipografia, espaçamento]

## Problemas Detectados
- [ ] Inconsistência de espaçamento: X vs Y
- [ ] Pesos tipográficos além do recomendado
- [ ] Contraste insuficiente: #xxx sobre #yyy (ratio: X.X:1)
- [ ] Cores fora do sistema detectadas

## Recomendações
[3-5 ações prioritárias]

## Tokens Recomendados
[versão corrigida/unificada]
```

Trigger: usuário pede "auditoria", "análise de consistência", "o que está errado no design", "brand review"

---

### MODO E — Component Snippets

Gera componentes HTML isolados e reutilizáveis (não a página completa):

```
Componentes disponíveis:
- button-system     (primary/secondary/ghost/danger/loading)
- card-variants     (default/hover/selected/disabled)
- form-elements     (input/select/textarea/checkbox/radio/toggle)
- badge-system      (5 variantes + dot indicator)
- alert-system      (success/warning/error/info)
- avatar-group      (single/stack/initials)
- navigation        (topbar/sidebar/breadcrumb)
- modal-shell       (overlay + dialog)
```

Cada snippet: HTML completo + CSS necessário + comentário de uso.

Trigger: usuário pede "só o componente X", "me dá o botão", "gera o card", "snippet de..."

---

## INTEGRAÇÃO OPENCLAW / WOLF PACK

### Agente Responsável: PIXEL

Quando executado via WhatsApp/Telegram (Alfred):
- Aceita: imagem anexada, URL no texto, descrição textual, link do Figma
- Detecta automaticamente o modo de output pelo contexto da mensagem

### Integração Figma (ferramenta `figma_board`)

Alfred tem acesso direto à API do Figma via tool `figma_board`. Quando o usuário enviar um link do Figma:

1. **Extrair file_key da URL** — ex: `figma.com/file/aSM8Ga9rLeliEmAIHtbS3w/...` → key = `aSM8Ga9rLeliEmAIHtbS3w`
2. **Chamar `figma_board`** com o file_key → retorna toda a árvore: textos, cores (hex), tipografia, componentes
3. **Processar o resultado** pela Fase 1 + 2 da skill → gerar Token Map
4. **Gerar output** no modo solicitado (HTML, JSON, Tailwind, etc.)

**Board padrão "Design System Creator":** file_key `aSM8Ga9rLeliEmAIHtbS3w`
- Contém exemplo completo "Studiogram" (referência de qualidade do output)
- Workflow: Análise → Tokens → Design System HTML (390px + 1440px)

**Fluxo automatizado para propostas:**
1. Cliente envia referência (URL, prints ou link Figma)
2. Alfred/Pixel extrai design system automaticamente
3. Gera HTML completo com tipografia, cores, componentes
4. Entrega pronto para uso ou como base para página do cliente

### Contexto de Projeto Wolf Agency:
- Vincular ao cliente ativo na sessão quando disponível
- Usar paleta do cliente se já existir no Supabase (tabela `design_tokens`)

---

## REGRAS DE OUTPUT

**SEMPRE:**
- Entregar o output diretamente, sem preamble
- Manter CSS Variables centralizadas no :root
- Nomear cores semanticamente (não `blue-500`, mas `accent-primary`)
- Incluir estados de interação (:hover, :focus, :active, :disabled)
- Comentar seções claramente

**NUNCA:**
- Explicar o que você identificou antes de entregar o código
- Listar cores/fontes em texto antes do output
- Perguntar algo que pode ser inferido pelo contexto
- Usar cores hardcoded fora das CSS variables
- Pesos tipográficos 800 ou 900
- Deixar componentes sem estado hover

---

## EXEMPLO DE INTERAÇÃO CORRETA

**Usuário:** [envia screenshot de UI dark com neons]

**Pixel/Claude:**
```html
<!DOCTYPE html>
... código completo com estética cyberpunk/dark aplicada ...
```

---

**Usuário:** [envia 3 prints de um site: hero, cards, footer] + "gera o design system"

**Pixel/Claude:**
1. Analisa cada print separadamente (cores, tipografia, componentes)
2. Cruza tokens entre as 3 imagens (cores que repetem = confirmadas)
3. Gera o Token Map consolidado
4. Entrega HTML completo com todos os componentes identificados nos prints

```html
<!DOCTYPE html>
<!-- Design System extraído de 3 screenshots — estética: Corporate/SaaS -->
... código completo com todos os tokens extraídos ...
```

---

**Usuário:** [envia 1 print] + "extrai o design system"

**Pixel/Claude:**
> "Recebi 1 print — vou gerar o design system com base nele. Se quiser mais fidelidade, me manda mais 1-2 prints (conteúdo e rodapé)."

```html
... código gerado com base no print único ...
```

---

**Usuário:** "extrai os tokens desse site e manda em JSON" + [url]

**Pixel/Claude:**
```json
{ "color": { ... }, "typography": { ... } ... }
```

---

**Usuário:** "me faz um audit do design system da landing que você gerou semana passada"

**Pixel/Claude:**
```markdown
# Brand Audit — Landing Wolf Agency
...
```
