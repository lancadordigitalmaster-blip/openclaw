# animation.md — Pixel Sub-Skill: Animações e Transições
# Ativa quando: "animação", "transição", "motion", "hover"

---

## FILOSOFIA DE ANIMAÇÃO WOLF

```
REGRA #1: Animação serve ao usuário, não ao designer.
REGRA #2: A melhor animação é a que o usuário não percebe conscientemente.
REGRA #3: Se tirar a animação e o produto ainda funcionar bem: era desnecessária.

QUANDO ANIMAR (justificativas válidas):
  Feedback    — "sua ação funcionou" (botão que muda ao clicar)
  Orientação  — "de onde veio esse conteúdo?" (slide-in de modal)
  Deleite     — micro-interação que torna o uso mais agradável
  Continuidade — conecta estados para o usuário não se perder

QUANDO NÃO ANIMAR:
  ✗ Para "parecer moderno"
  ✗ Animações longas em fluxos críticos (checkout, formulários)
  ✗ Movimento que distrai do conteúdo principal
  ✗ Loops contínuos sem propósito (a menos que loading)

DURAÇÃO COMO REGRA:
  Micro-interações (hover, click): 150ms — 200ms
  Transições de componente (modal, drawer): 200ms — 300ms
  Page transitions: 300ms — 400ms
  Animações decorativas: máximo 500ms
  Qualquer coisa > 500ms: questiona se é necessário
```

---

## RESPEITAR prefers-reduced-motion

```typescript
// OBRIGATÓRIO: sempre respeita a preferência do usuário

// Tailwind — classe motion-reduce desativa animações
<div className="transition-all duration-300 motion-reduce:transition-none">
  ...
</div>

// CSS puro
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

// Framer Motion — hook para detectar preferência
import { useReducedMotion } from 'framer-motion'

const MyComponent = () => {
  const shouldReduceMotion = useReducedMotion()

  const variants = {
    hidden: { opacity: 0, y: shouldReduceMotion ? 0 : 20 },
    visible: { opacity: 1, y: 0 },
  }

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={variants}
      transition={{ duration: shouldReduceMotion ? 0 : 0.3 }}
    >
      {children}
    </motion.div>
  )
}
```

---

## CSS ANIMATIONS — Casos Simples

```typescript
// ✅ Tailwind para transições de UI

// Hover em botão
<button className="
  bg-blue-600 text-white px-4 py-2 rounded
  transition-colors duration-150
  hover:bg-blue-700
  active:bg-blue-800
  focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2
">
  Ativar Campanha
</button>

// Card com hover lift
<div className="
  rounded-lg border bg-white p-4
  transition-all duration-200
  hover:shadow-md hover:-translate-y-0.5
  motion-reduce:hover:translate-y-0
">
  <CardContent />
</div>

// Fade in de elemento
<div className="animate-fade-in">
  {/* Adiciona ao tailwind.config.js:
    extend: {
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
      animation: {
        'fade-in': 'fade-in 0.3s ease-out',
      },
    }
  */}
</div>

// Loading spinner
<svg
  className="animate-spin h-5 w-5 text-blue-600"
  xmlns="http://www.w3.org/2000/svg"
  fill="none"
  viewBox="0 0 24 24"
  aria-label="Carregando"
>
  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
</svg>

// Skeleton loading
<div className="animate-pulse space-y-3">
  <div className="h-4 w-3/4 rounded bg-gray-200" />
  <div className="h-4 w-full rounded bg-gray-200" />
  <div className="h-4 w-1/2 rounded bg-gray-200" />
</div>
```

---

## FRAMER MOTION — Animações Complexas

### Instalação e Setup

```bash
npm install framer-motion
```

### Padrões de Uso

```typescript
import { motion, AnimatePresence } from 'framer-motion'
import { useReducedMotion } from 'framer-motion'

// ========================
// FADE IN ao montar
// ========================
const FadeIn = ({ children, delay = 0 }: { children: React.ReactNode; delay?: number }) => {
  const reduced = useReducedMotion()

  return (
    <motion.div
      initial={{ opacity: 0, y: reduced ? 0 : 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reduced ? 0 : 0.25, delay }}
    >
      {children}
    </motion.div>
  )
}

// Uso em lista (stagger — cada item entra com delay)
const CampaignList = ({ campaigns }) => (
  <ul>
    {campaigns.map((campaign, i) => (
      <FadeIn key={campaign.id} delay={i * 0.05}>
        <li><CampaignCard campaign={campaign} /></li>
      </FadeIn>
    ))}
  </ul>
)

// ========================
// MODAL com AnimatePresence
// ========================
const Modal = ({ isOpen, onClose, children }) => (
  <AnimatePresence>
    {isOpen && (
      <>
        {/* Overlay */}
        <motion.div
          key="overlay"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="fixed inset-0 z-40 bg-black/50"
          onClick={onClose}
        />

        {/* Conteúdo */}
        <motion.div
          key="modal"
          initial={{ opacity: 0, scale: 0.95, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 10 }}
          transition={{ duration: 0.2, ease: 'easeOut' }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          role="dialog"
          aria-modal="true"
        >
          <div className="bg-white rounded-lg shadow-xl p-6 max-w-lg w-full">
            {children}
          </div>
        </motion.div>
      </>
    )}
  </AnimatePresence>
)

// ========================
// DRAWER / SIDEBAR
// ========================
const Drawer = ({ isOpen, onClose, children }) => (
  <AnimatePresence>
    {isOpen && (
      <motion.div
        key="drawer"
        initial={{ x: '100%' }}
        animate={{ x: 0 }}
        exit={{ x: '100%' }}
        transition={{ type: 'tween', duration: 0.25, ease: 'easeOut' }}
        className="fixed right-0 top-0 h-full w-80 bg-white shadow-2xl z-50"
      >
        {children}
      </motion.div>
    )}
  </AnimatePresence>
)

// ========================
// TOAST / NOTIFICAÇÃO
// ========================
const Toast = ({ message, type, onDismiss }) => (
  <motion.div
    initial={{ opacity: 0, y: -20, scale: 0.95 }}
    animate={{ opacity: 1, y: 0, scale: 1 }}
    exit={{ opacity: 0, scale: 0.95 }}
    transition={{ duration: 0.2 }}
    className={`
      fixed top-4 right-4 z-50 px-4 py-3 rounded-lg shadow-lg
      ${type === 'success' ? 'bg-green-500 text-white' : ''}
      ${type === 'error' ? 'bg-red-500 text-white' : ''}
    `}
    role="alert"
    aria-live="polite"
  >
    {message}
  </motion.div>
)

// ========================
// ACCORDION / COLLAPSIBLE
// ========================
const Accordion = ({ title, children }) => {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div className="border rounded-lg overflow-hidden">
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        aria-expanded={isOpen}
        className="w-full px-4 py-3 flex justify-between items-center"
      >
        <span>{title}</span>
        <motion.span
          animate={{ rotate: isOpen ? 180 : 0 }}
          transition={{ duration: 0.2 }}
        >
          <ChevronDown aria-hidden="true" />
        </motion.span>
      </button>

      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            key="content"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
            style={{ overflow: 'hidden' }}
          >
            <div className="px-4 pb-4">
              {children}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
```

---

## HOVER STATES PADRÃO WOLF

```typescript
// Catálogo de hover states para reutilizar

// Botão primário
"transition-colors duration-150 hover:bg-blue-700 active:bg-blue-800"

// Botão ghost/outline
"transition-colors duration-150 hover:bg-gray-100 active:bg-gray-200"

// Card clicável
"transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 motion-reduce:hover:translate-y-0 cursor-pointer"

// Link de texto
"transition-colors duration-150 text-blue-600 hover:text-blue-800 underline-offset-2 hover:underline"

// Ícone de ação (ex: delete, edit)
"transition-colors duration-150 text-gray-400 hover:text-gray-700 p-1 rounded hover:bg-gray-100"

// Item de menu/sidebar
"transition-colors duration-150 px-3 py-2 rounded-md hover:bg-gray-100 text-gray-700 hover:text-gray-900"
```

---

## PAGE TRANSITIONS (Next.js)

```typescript
// layout.tsx — aplica transição em todas as páginas
import { AnimatePresence, motion } from 'framer-motion'
import { usePathname } from 'next/navigation'

const pageVariants = {
  initial: { opacity: 0, y: 8 },
  in: { opacity: 1, y: 0 },
  out: { opacity: 0, y: -8 },
}

const pageTransition = {
  type: 'tween',
  ease: 'anticipate',
  duration: 0.25,
}

export default function RootLayout({ children }) {
  const pathname = usePathname()

  return (
    <html lang="pt-BR">
      <body>
        <Navigation />
        <AnimatePresence mode="wait">
          <motion.main
            key={pathname}
            initial="initial"
            animate="in"
            exit="out"
            variants={pageVariants}
            transition={pageTransition}
          >
            {children}
          </motion.main>
        </AnimatePresence>
      </body>
    </html>
  )
}
```

---

## CHECKLIST DE ANIMAÇÕES

```
ANTES DE IMPLEMENTAR:
  □ Esta animação serve feedback, orientação ou deleite?
  □ Sem a animação, o produto funciona igual?
  □ A duração é ≤ 300ms para interações, ≤ 500ms para transições?

IMPLEMENTAÇÃO:
  □ prefers-reduced-motion respeitado (motion-reduce: ou useReducedMotion)
  □ AnimatePresence envolve componentes com animação de saída
  □ exit definido quando há animate e AnimatePresence
  □ Sem animações em loop infinito sem propósito (loading ok)

ACESSIBILIDADE:
  □ Conteúdo dinâmico animado tem aria-live se for alerta/notificação
  □ Animações não piscam > 3 vezes por segundo (risco de convulsão)
  □ Movimento não causa desorientação (paralax sutil, não extremo)

PERFORMANCE:
  □ Usa transform e opacity (não width, height, top, left — causam reflow)
  □ will-change só onde necessário (não em tudo)
  □ Sem animações em componentes que re-renderizam frequentemente
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: animação [tipo] em [componente] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: animation.md | Agente: Pixel | Atualizado: 2026-03-04*
