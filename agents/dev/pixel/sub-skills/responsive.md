# responsive.md — Pixel Sub-Skill: Design Responsivo
# Ativa quando: "responsivo", "mobile", "breakpoint", "layout"

---

## PRINCÍPIO: MOBILE-FIRST

```
REGRA FUNDAMENTAL: Começa pelo menor tamanho e escala para cima.
Nunca escreve para desktop e tenta "encaixar" no mobile depois.

Por quê mobile-first:
  1. Força priorização de conteúdo (o que é essencial vs o que é extra)
  2. Estilos base mais leves (mobile carrega o CSS todo, não usa media queries)
  3. Mais fácil adicionar complexidade do que remover
  4. Tailwind é mobile-first por design — sem prefixo = mobile

PROCESSO:
  1. Layout mobile (320px) — conteúdo em coluna única, essencial visível
  2. Tablet (768px) — grid de 2 colunas, sidebar aparece
  3. Desktop (1280px) — grid completo, elementos extras visíveis
```

---

## BREAKPOINTS TAILWIND WOLF

```yaml
breakpoints_wolf:
  default (sem prefixo):  "< 640px" — mobile (320px - 639px)
  sm:   "≥ 640px"        — mobile landscape, iPhone Plus
  md:   "≥ 768px"        — tablet portrait (iPad)
  lg:   "≥ 1024px"       — tablet landscape, desktop pequeno
  xl:   "≥ 1280px"       — desktop padrão
  2xl:  "≥ 1536px"       — desktop grande (usa com moderação)

dispositivos_referencia:
  320px:  "iPhone SE, Android entry-level"  — menor suportado
  375px:  "iPhone 12/13/14"                 — mais comum mobile
  390px:  "iPhone 14 Pro"
  768px:  "iPad portrait"                   — referência tablet
  1280px: "MacBook Air, desktop comum"      — referência desktop

tamanhos_para_testar:
  320px:  menor suportado — garante que não quebra
  375px:  mais comum — deve parecer ótimo aqui
  768px:  transição mobile/tablet
  1280px: desktop padrão
```

---

## PADRÕES DE LAYOUT RESPONSIVO

### Grid Responsivo

```typescript
// Layout de dashboard — 1 coluna no mobile, 3 no desktop
<div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
  {campaigns.map(c => <CampaignCard key={c.id} campaign={c} />)}
</div>

// Layout com sidebar — sidebar esconde no mobile, aparece no desktop
<div className="flex flex-col lg:flex-row gap-6">
  <main className="flex-1 min-w-0">
    {/* min-w-0 previne overflow em flex */}
    <PageContent />
  </main>
  <aside className="hidden lg:block w-80 shrink-0">
    <Sidebar />
  </aside>
</div>

// Formulário — campos full width no mobile, lado a lado no desktop
<div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
  <FormField label="Nome" />
  <FormField label="Email" />
  <div className="sm:col-span-2">
    <FormField label="Mensagem" type="textarea" />
  </div>
</div>
```

### Navegação Responsiva

```typescript
// ✅ Navegação mobile-first com hamburger
const Navigation = () => {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <nav>
      {/* Mobile: botão hamburger */}
      <button
        type="button"
        className="lg:hidden p-2"
        onClick={() => setIsOpen(!isOpen)}
        aria-expanded={isOpen}
        aria-label="Abrir menu de navegação"
      >
        <MenuIcon />
      </button>

      {/* Links: coluna no mobile, linha no desktop */}
      <ul className={`
        flex-col gap-1 lg:flex-row lg:flex lg:gap-6
        ${isOpen ? 'flex' : 'hidden lg:flex'}
      `}>
        {navItems.map(item => (
          <li key={item.href}>
            <NavLink href={item.href}>{item.label}</NavLink>
          </li>
        ))}
      </ul>
    </nav>
  )
}
```

### Tipografia Responsiva

```typescript
// ✅ Tamanho de fonte escala com o viewport
// Títulos
<h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold">
  Título Principal
</h1>

<h2 className="text-xl sm:text-2xl font-semibold">
  Subtítulo
</h2>

// Corpo — base no mobile, levemente maior no desktop
<p className="text-sm sm:text-base leading-relaxed">
  Conteúdo do parágrafo
</p>

// ❌ Tamanho fixo que fica pequeno demais ou grande demais
<h1 className="text-4xl">Título</h1>
// → 36px no mobile é grande demais, cria overflow horizontal
```

### Espaçamento Responsivo

```typescript
// ✅ Padding e margin escala com breakpoint
<section className="px-4 sm:px-6 lg:px-8 py-8 sm:py-12 lg:py-16">
  <div className="max-w-7xl mx-auto">
    {/* Conteúdo centralizado com padding adaptável */}
  </div>
</section>

// ✅ Gap em grids escala com breakpoint
<div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6 lg:gap-8">
  ...
</div>

// ❌ Padding fixo que fica apertado no mobile ou enorme no desktop
<section className="px-16 py-20"> ... </section>
```

### Imagens e Mídia Responsivas

```typescript
// ✅ Imagem que ocupa diferentes proporções por breakpoint
<Image
  src="/hero.jpg"
  alt="Hero da campanha"
  width={1200}
  height={600}
  className="w-full h-48 sm:h-64 lg:h-96 object-cover rounded-lg"
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 100vw, 1200px"
/>

// ✅ Aspect ratio consistente em diferentes tamanhos
<div className="aspect-video w-full">
  <video className="w-full h-full object-cover" />
</div>

// ✅ Tabela responsiva — scroll horizontal no mobile
<div className="overflow-x-auto -mx-4 sm:mx-0">
  <table className="min-w-full">
    ...
  </table>
</div>
```

---

## CHECKLIST DE TESTE RESPONSIVO

```
TESTE EM 320px (menor iPhone):
  □ Sem overflow horizontal (scrollbar lateral)
  □ Texto legível sem zoom (mínimo 14px)
  □ Botões com altura mínima de 44px (área de toque)
  □ Formulários têm zoom desabilitado (font-size >= 16px em inputs)
  □ Imagens não saem do container
  □ Navegação funciona (hamburger menu se necessário)
  □ Conteúdo crítico visível sem scroll horizontal

TESTE EM 375px (iPhone padrão):
  □ Layout parece intencional, não "comprimido"
  □ Cards e componentes têm espaçamento adequado
  □ Hierarquia visual clara

TESTE EM 768px (tablet):
  □ Layout de 2 colunas se aplicável
  □ Sidebar aparece se o design prevê
  □ Imagens em proporção correta

TESTE EM 1280px (desktop):
  □ Layout completo como projetado
  □ Max-width configurado (conteúdo não estica infinitamente)
  □ Hover states funcionando
  □ Sidebar e elementos extras visíveis

COMPORTAMENTO:
  □ Sem texto truncado inesperado (overflow: hidden sem texto)
  □ Animações e transições funcionam em mobile
  □ Dropdown menus não saem da tela
  □ Modais são scrolláveis no mobile (não cortados)
  □ Inputs nativos (date, select) têm estilo consistente
```

---

## PROBLEMAS COMUNS E SOLUÇÕES

```yaml
problema: "Conteúdo sai da tela lateralmente"
causa: "Elemento com width fixo maior que a viewport"
solucao: |
  Adiciona no CSS global:
  * { box-sizing: border-box; }
  html, body { max-width: 100%; overflow-x: hidden; }
  Ou encontra o elemento com devtools: document.querySelectorAll('*').forEach(el => {
    if (el.offsetWidth > document.documentElement.offsetWidth) console.log(el)
  })

problema: "Input com zoom automático no iOS"
causa: "font-size menor que 16px em inputs"
solucao: |
  input, select, textarea {
    font-size: 16px; /* mínimo para evitar zoom automático no iOS */
  }
  No Tailwind: className="text-base" (16px)

problema: "Clique em elementos pequenos difícil no mobile"
causa: "Área de toque menor que 44x44px"
solucao: |
  Adiciona padding transparente ou usa min-h-[44px] min-w-[44px]
  No Tailwind: className="min-h-[44px] min-w-[44px] flex items-center"

problema: "Modal não scrollável no mobile"
causa: "overflow: hidden no body sem alternativa"
solucao: |
  const Modal = ({ children }) => {
    useEffect(() => {
      document.body.style.overflow = 'hidden'
      return () => { document.body.style.overflow = '' }
    }, [])
    return (
      <div className="fixed inset-0 z-50 overflow-y-auto">
        <div className="min-h-full flex items-center justify-center p-4">
          {children}
        </div>
      </div>
    )
  }

problema: "Layout quebrado em telas muito lardes (> 1920px)"
causa: "Sem max-width no container principal"
solucao: |
  <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    {/* Conteúdo não passa de 1280px */}
  </div>
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: responsivo [componente/página] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: responsive.md | Agente: Pixel | Atualizado: 2026-03-04*
