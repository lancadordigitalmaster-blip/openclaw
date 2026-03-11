# performance.md — Pixel Sub-Skill: Performance Frontend
# Ativa quando: "performance", "lento", "LCP", "CLS", "bundle", "otimiza"

---

## METAS CORE WEB VITALS — WOLF STANDARD

```
LCP (Largest Contentful Paint) — velocidade de carregamento
  ✅ BOM:       < 2.5s
  🟡 ATENÇÃO:  2.5s — 4.0s
  🔴 RUIM:     > 4.0s
  Causa principal: imagens sem lazy load, fonts bloqueantes, JS pesado

INP (Interaction to Next Paint) — responsividade
  ✅ BOM:       < 200ms
  🟡 ATENÇÃO:  200ms — 500ms
  🔴 RUIM:     > 500ms
  Causa principal: JS pesado no main thread, handlers lentos, hydration lenta

CLS (Cumulative Layout Shift) — estabilidade visual
  ✅ BOM:       < 0.1
  🟡 ATENÇÃO:  0.1 — 0.25
  🔴 RUIM:     > 0.25
  Causa principal: imagens sem dimensões, fonts com FOUT, conteúdo injetado dinamicamente

TTFB (Time to First Byte) — velocidade do servidor
  ✅ BOM:       < 800ms
  Causa principal: SSR lento, banco sem cache, CDN não configurado
```

---

## DIAGNÓSTICO DE PERFORMANCE

```
PASSO 1 — MEDE ANTES DE OTIMIZAR
  Ferramentas:
  → Lighthouse (DevTools > Performance > Lighthouse)
    Roda em modo incógnito, sem extensões
    Desktop E mobile são métricas diferentes — mede os dois

  → Chrome DevTools Performance tab
    Grava o carregamento ou a interação lenta
    Identifica: long tasks (> 50ms), JS parse time, render blocking

  → Bundle Analyzer
    next build && npx @next/bundle-analyzer
    Identifica: dependências gigantes, código duplicado, chunks mal divididos

PASSO 2 — IDENTIFICA O GARGALO
  → LCP alto: imagens, fonts, JS blocking, SSR lento
  → INP alto: handlers pesados, setState desnecessário, microtask flood
  → CLS alto: imagens sem tamanho, conteúdo injetado sem espaço reservado
  → Bundle grande: dependência desnecessária, falta de tree-shaking, sem code split

PASSO 3 — OTIMIZA O MAIOR GARGALO PRIMEIRO
  Regra: 20% das causas = 80% do problema.
  Não otimiza tudo — otimiza o que mais impacta.
```

---

## TÉCNICAS DE OTIMIZAÇÃO

### Imagens — maior causa de LCP lento

```typescript
// ✅ SEMPRE usar next/image em projetos Next.js
import Image from 'next/image'

// LCP hero image — priority=true carrega antes de tudo
<Image
  src="/hero.jpg"
  alt="Descrição clara do conteúdo"
  width={1200}
  height={600}
  priority // apenas para a imagem above the fold
  sizes="(max-width: 768px) 100vw, 1200px"
/>

// Imagens abaixo do fold — lazy load (padrão do next/image)
<Image
  src="/feature.jpg"
  alt="Feature X do produto"
  width={600}
  height={400}
  // sem priority = lazy load automático
  sizes="(max-width: 768px) 100vw, 50vw"
/>

// ❌ NUNCA — img tag sem dimensões (causa CLS)
<img src="/hero.jpg" />

// ❌ NUNCA — carrega imagem enorme para exibir pequena
<Image src="/4000x3000.jpg" width={100} height={75} />
// → redimensiona a imagem na fonte ou usa sizes corretamente
```

### Code Splitting — reduz bundle inicial

```typescript
// ✅ Lazy load de componentes pesados
import dynamic from 'next/dynamic'

// Componente que só carrega quando visível/interagido
const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // apenas se componente usa browser APIs
})

// Modal — não precisa no bundle inicial
const ReportModal = dynamic(() => import('./ReportModal'), {
  loading: () => null,
})

// ❌ Importa tudo no bundle principal
import HeavyChart from './HeavyChart' // 200kb de biblioteca de gráfico
import { MassiveLibrary } from 'massive-lib' // importa tudo, usa 5%
```

### React.memo, useMemo, useCallback — previne re-renders

```typescript
// ✅ memo — componente com props estáveis que renderiza com frequência
const CampaignRow = memo(({ campaign, onSelect }: CampaignRowProps) => {
  return (
    <tr onClick={() => onSelect(campaign.id)}>
      <td>{campaign.name}</td>
      <td>{formatCurrency(campaign.budget)}</td>
    </tr>
  )
})

// ✅ useMemo — cálculo caro que depende de dados pesados
const sortedCampaigns = useMemo(
  () => campaigns
    .filter(c => c.status === activeFilter)
    .sort((a, b) => b.spent - a.spent),
  [campaigns, activeFilter] // só recalcula quando estes mudam
)

// ✅ useCallback — handler passado para componente filho memoizado
const handleCampaignSelect = useCallback(
  (id: string) => {
    setSelectedId(id)
    onSelect?.(id)
  },
  [onSelect] // referência estável para não quebrar memo() do filho
)

// ❌ useMemo/useCallback desnecessários — overhead sem benefício
const name = useMemo(() => user.firstName + ' ' + user.lastName, [user])
// → só precisa de: const name = `${user.firstName} ${user.lastName}`

// Regra: só memoiza se:
// 1. O cálculo leva > 1ms (use console.time para medir)
// 2. O componente filho é memoizado e precisa de referência estável
```

### Fonts — previne FOUT e layout shift

```typescript
// ✅ next/font — zero layout shift, self-hosted
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap', // mostra fallback enquanto carrega (sem flash)
  variable: '--font-inter',
})

// No layout.tsx:
export default function RootLayout({ children }) {
  return (
    <html lang="pt-BR" className={inter.variable}>
      <body>{children}</body>
    </html>
  )
}

// ❌ Link direto para Google Fonts — blocking, sem controle de cache
// <link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />
```

### Virtualização — listas longas

```typescript
// ✅ Para listas com > 100 itens: virtualiza
import { useVirtualizer } from '@tanstack/react-virtual'

const CampaignList = ({ campaigns }: { campaigns: Campaign[] }) => {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: campaigns.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72, // altura estimada de cada item
  })

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map(item => (
          <div
            key={item.key}
            style={{
              position: 'absolute',
              top: item.start,
              width: '100%',
              height: item.size,
            }}
          >
            <CampaignRow campaign={campaigns[item.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}

// ❌ Renderiza 1000 itens de uma vez no DOM
{campaigns.map(c => <CampaignRow key={c.id} campaign={c} />)}
```

---

## ANÁLISE DE BUNDLE

```bash
# Next.js — analisa bundle com @next/bundle-analyzer
npm install @next/bundle-analyzer

# next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})
module.exports = withBundleAnalyzer({})

# Roda análise
ANALYZE=true npm run build

# O que procurar no relatório:
# → Chunks > 100kb sem lazy load
# → Dependência que deveria ser tree-shaken mas está inteira (ex: lodash)
# → Código duplicado em múltiplos chunks
# → Dependências de dev no bundle de produção

# Identifica dependências pesadas
npx cost-of-modules
```

---

## CHECKLIST DE OTIMIZAÇÃO

```
IMAGENS:
  □ Toda imagem usa next/image (não <img>)
  □ Hero image tem priority={true}
  □ Todas as imagens têm width e height definidos (evita CLS)
  □ sizes prop configurada corretamente para responsive
  □ Formato WebP/AVIF sendo servido (next/image faz isso automaticamente)

JAVASCRIPT:
  □ Componentes pesados têm lazy load com dynamic()
  □ Bibliotecas importadas com tree-shaking (import { específico } from 'lib')
  □ Sem dependências duplicadas no bundle (npm dedupe)
  □ Build sem chunks desnecessariamente grandes (> 200kb)

REACT:
  □ Listas grandes com > 100 itens usam virtualização
  □ Componentes de tabela/lista usam React.memo
  □ Handlers passados para filhos usam useCallback
  □ Cálculos caros usam useMemo
  □ Sem re-renders em cascata desnecessários (React DevTools Profiler)

FONTS E CSS:
  □ Fonts carregadas via next/font (não link direto para Google Fonts)
  □ CSS crítico inline, resto lazy
  □ Sem CSS não utilizado em produção (PurgeCSS / Tailwind já faz isso)

SERVER-SIDE (Next.js):
  □ SSR/SSG para páginas que precisam de SEO
  □ ISR configurado para conteúdo que muda com baixa frequência
  □ API routes não carregam dados desnecessários (select específico no banco)
  □ Cache headers configurados para assets estáticos
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: performance [métrica otimizada] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: performance.md | Agente: Pixel | Atualizado: 2026-03-04*
