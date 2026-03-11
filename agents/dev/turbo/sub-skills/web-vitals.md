# web-vitals.md — Turbo Sub-Skill: Core Web Vitals
# Ativa quando: "Lighthouse", "Core Web Vitals", "LCP", "CLS", "INP"

---

## Metas Wolf por Métrica

| Métrica | Bom | Precisa Melhorar | Ruim | Meta Wolf |
|---------|-----|------------------|------|-----------|
| LCP | < 2.5s | 2.5s – 4.0s | > 4.0s | **< 1.8s** |
| INP | < 200ms | 200ms – 500ms | > 500ms | **< 150ms** |
| CLS | < 0.1 | 0.1 – 0.25 | > 0.25 | **< 0.05** |
| TTFB | < 800ms | 800ms – 1800ms | > 1800ms | **< 400ms** |
| FCP | < 1.8s | 1.8s – 3.0s | > 3.0s | **< 1.2s** |

**Lab data vs Field data:** Lighthouse = lab (condições controladas). CrUX = field (usuários reais). Ambos importam — mas field data é o que o Google ranqueia.

---

## LCP — Largest Contentful Paint

O maior elemento visível carregou. Geralmente: hero image, h1, ou bloco de texto principal.

### O que afeta o LCP

```
1. Imagem de hero sem preload → browser descobre tarde no HTML
2. Server response time alto → TTFB alto → tudo atrasa
3. Render-blocking resources (CSS, JS síncronos no <head>)
4. Imagem sem otimização (formato, compressão, dimensão)
5. Fonts bloqueando texto (FOIT — Flash of Invisible Text)
```

### Como melhorar

```html
<!-- 1. Preload da imagem LCP — sempre no <head> -->
<link rel="preload" as="image" href="/hero.webp"
      imagesrcset="/hero-480.webp 480w, /hero-1024.webp 1024w"
      imagesizes="100vw">

<!-- 2. fetchpriority na imagem hero -->
<img src="/hero.webp" fetchpriority="high" alt="Hero"
     width="1200" height="600">

<!-- 3. Evitar lazy loading no elemento LCP -->
<!-- ERRADO: -->
<img src="/hero.webp" loading="lazy">
<!-- CORRETO: loading="eager" é o default — não adicione lazy no LCP -->
```

```nginx
# 4. Server response time — ajuste no Nginx
worker_processes auto;
worker_connections 1024;

# Compressão gzip/brotli
gzip on;
gzip_comp_level 6;
gzip_types text/html text/css application/javascript image/svg+xml;

# Brotli (melhor que gzip, precisa do módulo)
brotli on;
brotli_comp_level 6;
```

```javascript
// 5. Next.js — configuração de imagem otimizada
// next.config.js
module.exports = {
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    minimumCacheTTL: 60 * 60 * 24 * 30, // 30 dias
  },
}

// Componente com prioridade
import Image from 'next/image'
<Image src="/hero.webp" priority width={1200} height={600} alt="Hero" />
```

---

## INP — Interaction to Next Paint

Responsividade a interações do usuário (clique, toque, teclado). Substituiu FID no Google Search ranking em março 2024.

### O que afeta o INP

```
1. Long tasks no main thread (> 50ms bloqueia input)
2. JavaScript síncrono pesado no event handler
3. Re-renders desnecessários em React
4. Operações de DOM caras (layout thrashing)
5. Third-party scripts bloqueantes (analytics, chat, ads)
```

### Como melhorar

```javascript
// 1. Quebrar long tasks com scheduler
// ANTES — bloqueia main thread
function processarListaGrande(items) {
  items.forEach(item => processarItem(item)) // 500ms bloqueando
}

// DEPOIS — yield ao browser entre chunks
async function processarListaGrande(items) {
  const CHUNK_SIZE = 50
  for (let i = 0; i < items.length; i += CHUNK_SIZE) {
    const chunk = items.slice(i, i + CHUNK_SIZE)
    chunk.forEach(item => processarItem(item))
    // Yield — browser pode processar inputs
    await new Promise(resolve => setTimeout(resolve, 0))
  }
}

// 2. scheduler.yield() (API moderna, Chrome 115+)
async function processarListaGrande(items) {
  for (const item of items) {
    processarItem(item)
    if ('scheduler' in window) {
      await scheduler.yield()
    }
  }
}

// 3. React — evitar re-renders com memo
import { memo, useCallback, useMemo } from 'react'

const ItemCaro = memo(({ item, onSelect }) => {
  return <div onClick={() => onSelect(item.id)}>{item.nome}</div>
})

// 4. Defer third-party scripts
// HTML
<script src="analytics.js" defer></script>
// Ou carregar após interação
document.addEventListener('click', loadAnalytics, { once: true })
```

```javascript
// 5. Medir INP manualmente
import { onINP } from 'web-vitals'

onINP((metric) => {
  console.log('INP:', metric.value, 'ms')
  // Enviar para analytics
  sendToAnalytics({ name: 'INP', value: metric.value })
})
```

---

## CLS — Cumulative Layout Shift

Elementos se movendo durante o carregamento. Causa: conteúdo sem dimensão definida empurra outros elementos.

### Causas comuns e fixes

```html
<!-- 1. Imagens sem dimensões — CLS clássico -->
<!-- ERRADO -->
<img src="/produto.jpg" alt="Produto">

<!-- CORRETO — reserva espaço antes de carregar -->
<img src="/produto.jpg" alt="Produto" width="400" height="300">

<!-- OU com CSS aspect-ratio -->
<style>
  img { aspect-ratio: 4/3; width: 100%; }
</style>
```

```css
/* 2. Fontes customizadas — FOUT causa CLS */

/* font-display: swap evita FOIT, mas causa leve CLS */
/* font-display: optional é mais estável para CLS */
@font-face {
  font-family: 'MinhaFont';
  src: url('/fonts/minha-font.woff2') format('woff2');
  font-display: optional; /* Wolf default para CLS crítico */
}

/* size-adjust para compensar fallback antes de carregar */
@font-face {
  font-family: 'MinhaFontFallback';
  src: local('Arial');
  size-adjust: 105%; /* ajusta para ser similar à font customizada */
}
```

```javascript
// 3. Conteúdo dinâmico — reserve espaço antes de injetar
// ERRADO — banner aparece depois e empurra conteúdo
fetch('/api/banner').then(data => {
  document.querySelector('#banner').innerHTML = data.html
})

// CORRETO — espaço reservado no CSS
// CSS: #banner { min-height: 80px; }
// Ou: skeleton loader com mesma altura do conteúdo final
```

---

## TTFB — Time to First Byte

Tempo até o servidor começar a responder. TTFB alto = servidor lento ou rede ruim.

```bash
# Medir TTFB com curl
curl -w "TTFB: %{time_starttransfer}s\n" -o /dev/null -s https://seusite.com

# Medir em múltiplas localizações
# Use WebPageTest ou Pingdom Tools
```

```javascript
// Next.js — reduzir TTFB com ISR
// pages/produto/[id].js
export async function getStaticProps({ params }) {
  const produto = await fetchProduto(params.id)
  return {
    props: { produto },
    revalidate: 60, // revalida a cada 60s — serve stale enquanto regenera
  }
}

// Para dados que mudam muito: streaming com Suspense (Next.js App Router)
// app/page.tsx
import { Suspense } from 'react'
import { DadosDinamicos } from './componentes'

export default function Page() {
  return (
    <main>
      <ConteudoEstatico /> {/* entrega imediatamente */}
      <Suspense fallback={<Skeleton />}>
        <DadosDinamicos /> {/* stream quando pronto */}
      </Suspense>
    </main>
  )
}
```

---

## Ferramentas Wolf

### Lighthouse CI — Integração no pipeline
```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI
on: [push]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Build
        run: npm ci && npm run build

      - name: Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          urls: |
            http://localhost:3000/
            http://localhost:3000/produtos
          budgetPath: ./lighthouse-budget.json
          uploadArtifacts: true
```

```json
// lighthouse-budget.json — limites Wolf
{
  "budgets": [
    {
      "path": "/*",
      "timings": [
        { "metric": "interactive", "budget": 3000 },
        { "metric": "first-contentful-paint", "budget": 1500 },
        { "metric": "largest-contentful-paint", "budget": 2500 }
      ],
      "resourceSizes": [
        { "resourceType": "script", "budget": 300 },
        { "resourceType": "total", "budget": 1000 }
      ]
    }
  ]
}
```

### Medir Web Vitals em produção
```javascript
// lib/web-vitals.ts
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals'

function sendToAnalytics(metric: any) {
  // Enviar para seu sistema de analytics
  fetch('/api/vitals', {
    method: 'POST',
    body: JSON.stringify(metric),
    headers: { 'Content-Type': 'application/json' },
  })
}

onCLS(sendToAnalytics)
onINP(sendToAnalytics)
onLCP(sendToAnalytics)
onFCP(sendToAnalytics)
onTTFB(sendToAnalytics)
```

---

## Checklist Web Vitals Wolf

```
LCP
[ ] Elemento LCP identificado (DevTools > Performance > LCP marker)
[ ] Imagem hero com fetchpriority="high" e preload
[ ] Sem lazy loading no elemento LCP
[ ] TTFB < 400ms
[ ] Server-side rendering ou static para conteúdo crítico

INP
[ ] Sem long tasks > 50ms no main thread (Performance tab)
[ ] Third-party scripts com defer ou carregados após interação
[ ] Event handlers não bloqueiam main thread
[ ] React: memo/useCallback onde necessário

CLS
[ ] Todas as imagens têm width e height definidos
[ ] Fontes com font-display: optional ou size-adjust configurado
[ ] Sem injeção de conteúdo acima de conteúdo existente sem reserva de espaço
[ ] Ads e embeds com container de tamanho fixo

Geral
[ ] Lighthouse CI rodando no pipeline (bloqueia se baixar de 90)
[ ] Web Vitals medidos em produção com dados reais (CrUX)
[ ] Monitoramento com alerta para regressões
```
