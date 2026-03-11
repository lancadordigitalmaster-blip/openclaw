# bundle.md — Turbo Sub-Skill: Bundle Optimization
# Ativa quando: "bundle", "tamanho", "JS pesado", "otimiza frontend"

---

## Budgets de Bundle Wolf

| Recurso | Limite Warning | Limite Erro | Meta Ideal |
|---------|---------------|-------------|------------|
| JS total (parsed) | 300KB | 500KB | < 200KB |
| CSS total | 50KB | 100KB | < 30KB |
| Chunk inicial | 150KB | 250KB | < 100KB |
| Imagem individual | 200KB | 500KB | < 100KB |
| Total da página | 800KB | 1.5MB | < 500KB |

**Regra Wolf:** Se o usuário precisa baixar mais de 500KB de JS para ver a página inicial, algo está errado.

---

## Passo 1: Analisar o Bundle Antes de Otimizar

### Webpack Bundle Analyzer
```bash
# Instalar
npm install --save-dev webpack-bundle-analyzer

# package.json — adicionar script
{
  "scripts": {
    "analyze": "ANALYZE=true next build"
  }
}

# next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})
module.exports = withBundleAnalyzer({})
```

### Vite Plugin Visualizer
```bash
npm install --save-dev rollup-plugin-visualizer
```

```javascript
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer'

export default {
  plugins: [
    visualizer({
      open: true,           // abre no browser automaticamente
      gzipSize: true,       // mostra tamanho gzippado
      brotliSize: true,     // mostra tamanho brotli
      filename: 'dist/stats.html',
    }),
  ],
}
```

### O que procurar no analyzer
```
RED FLAGS no bundle analyzer:
- Mesmo módulo em múltiplos chunks (duplicação)
- Biblioteca pesada inteira quando só 10% é usado (lodash, moment)
- node_modules dominando o chunk principal
- Código de dev em build de produção
- Ícones de biblioteca inteira (heroicons, lucide completo)
```

---

## Passo 2: Code Splitting com Dynamic Import

```javascript
// ANTES — tudo no bundle principal
import { EditorDeTexto } from './editor'
import { RelatorioComplexo } from './relatorio'

// DEPOIS — carrega só quando precisa
const EditorDeTexto = dynamic(() => import('./editor'), {
  loading: () => <Skeleton />,
  ssr: false, // para componentes que usam window/document
})

const RelatorioComplexo = dynamic(() => import('./relatorio'), {
  loading: () => <div>Carregando relatório...</div>,
})
```

```javascript
// Lazy loading de rotas em React Router
import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'

const Dashboard = lazy(() => import('./pages/Dashboard'))
const Relatorios = lazy(() => import('./pages/Relatorios'))
const Configuracoes = lazy(() => import('./pages/Configuracoes'))

function App() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/relatorios" element={<Relatorios />} />
        <Route path="/configuracoes" element={<Configuracoes />} />
      </Routes>
    </Suspense>
  )
}
```

```javascript
// Dynamic import com prefetch (carrega em background quando browser está ocioso)
const handleMouseEnter = () => {
  import('./ComponentePesado') // prefetch on hover
}

const ComponentePesado = lazy(() => import('./ComponentePesado'))
```

---

## Passo 3: Tree Shaking — Importações Corretas

```javascript
// ERRADO — importa tudo do lodash (70KB gzippado)
import _ from 'lodash'
const resultado = _.groupBy(items, 'categoria')

// CORRETO — importa só a função necessária
import groupBy from 'lodash/groupBy'
const resultado = groupBy(items, 'categoria')

// MELHOR — usa lodash-es (ESM, tree shakeable)
import { groupBy } from 'lodash-es'
const resultado = groupBy(items, 'categoria')

// MELHOR AINDA — implementa direto (groupBy é simples)
const groupBy = (arr, key) =>
  arr.reduce((acc, item) => {
    const group = item[key]
    return { ...acc, [group]: [...(acc[group] || []), item] }
  }, {})
```

```javascript
// ERRADO — importa todos os ícones do lucide (2MB+)
import { Home, User, Settings } from 'lucide-react'

// CORRETO — importação direta do arquivo
import Home from 'lucide-react/dist/esm/icons/home'
import User from 'lucide-react/dist/esm/icons/user'
import Settings from 'lucide-react/dist/esm/icons/settings'

// OU configure o bundler para deep imports automáticos
// vite.config.ts
optimizeDeps: {
  include: ['lucide-react/dist/esm/icons/*']
}
```

---

## Passo 4: Substituições de Dependências Pesadas

| Biblioteca Pesada | Tamanho | Alternativa Leve | Tamanho |
|-------------------|---------|-----------------|---------|
| moment.js | 230KB | date-fns (tree-shakeable) | ~8KB usado |
| moment.js | 230KB | dayjs | 7KB |
| lodash | 70KB | lodash-es + tree shaking | ~2KB usado |
| axios | 13KB | fetch nativo | 0KB |
| chart.js | 200KB | lightweight-charts / uPlot | 40KB / 15KB |
| react-icons (tudo) | 5MB+ | lucide-react (direto) | ~1KB/ícone |
| highlight.js (tudo) | 900KB | highlight.js (linguagem específica) | ~40KB |
| validator.js | 40KB | zod | 14KB |

```javascript
// date-fns — só as funções que usa
import { format, addDays, isAfter } from 'date-fns'
import { ptBR } from 'date-fns/locale'

format(new Date(), "dd 'de' MMMM", { locale: ptBR })
```

---

## Passo 5: Lazy Loading de Imagens

```html
<!-- HTML nativo — suporte amplo -->
<img src="/produto.jpg" loading="lazy" width="400" height="300" alt="Produto">
```

```javascript
// Next.js — lazy por padrão para todas exceto priority
import Image from 'next/image'

// Abaixo do fold — lazy (default)
<Image src="/produto.jpg" width={400} height={300} alt="Produto" />

// Hero / above the fold — eager
<Image src="/hero.jpg" width={1200} height={600} alt="Hero" priority />
```

---

## Antes e Depois — Otimização Típica Wolf

```
PROJETO E-COMMERCE — ANTES
==========================
Bundle inicial: 1.2MB (parsed)
  - node_modules: 890KB
    - moment.js: 230KB
    - lodash: 95KB (só usava 5 funções)
    - chart.js: 200KB (só um gráfico)
    - react-icons: 320KB (importava tudo)
  - código próprio: 310KB

Lighthouse Performance: 42
LCP: 4.8s

PROJETO E-COMMERCE — DEPOIS
===========================
Bundle inicial: 180KB (parsed)
  - node_modules: 95KB
    - date-fns: 8KB (tree-shaken)
    - lodash-es: 3KB (tree-shaken)
    - lightweight-charts: 38KB
    - lucide-react: 6KB (4 ícones)
  - código próprio: 85KB (code split, lazy routes)
  - Chunks lazy: 420KB (carregados sob demanda)

Lighthouse Performance: 91
LCP: 1.6s

Redução: 85% no bundle inicial
```

---

## Configuração de Bundle Budget no CI

```javascript
// next.config.js — alerta de bundle size
module.exports = {
  experimental: {
    bundlePagesRouterDependencies: true,
  },
  // Limite por página
  onDemandEntries: {
    maxInactiveAge: 25 * 1000,
    pagesBufferLength: 2,
  },
}
```

```yaml
# .github/workflows/bundle-size.yml
name: Bundle Size Check
on: [pull_request]

jobs:
  bundle-size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci && npm run build

      - name: Check bundle size
        uses: preactjs/compressed-size-action@v2
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          pattern: '.next/static/**/*.js'
          exclude: '{**/*.map,**/node_modules/**}'
```

---

## Checklist Bundle Wolf

```
Análise
[ ] Bundle analyzer rodou e mapa visual analisado
[ ] Identificadas as 3 maiores dependências
[ ] Verificada duplicação de módulos

Code Splitting
[ ] Rotas com lazy loading (React.lazy ou next/dynamic)
[ ] Componentes pesados below-the-fold com dynamic import
[ ] Modais, drawers, tabs carregam sob demanda

Tree Shaking
[ ] Sem imports de barrel completo de libs grandes
[ ] lodash → lodash-es ou funções individuais
[ ] Ícones: imports diretos, não pacote inteiro

Dependências
[ ] moment.js → date-fns ou dayjs
[ ] axios → fetch nativo (se não precisa de interceptors)
[ ] Alternativas leves avaliadas para top 5 dependências

Budget
[ ] Bundle budget configurado no CI
[ ] PR bloqueado se ultrapassar limite
[ ] Baseline documentado para comparação
```
