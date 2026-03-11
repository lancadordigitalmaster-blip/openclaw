# visual.md — VEGA Sub-Skill: Visual Regression Testing
# Ativa quando: "visual regression", "screenshot", "UI mudou", "Percy"

## Visual Regression com Playwright

Stack: **Playwright** para capturas de screenshot com comparação de baseline. Para projetos com Storybook: **Chromatic** como alternativa gerenciada.

```bash
# Gerar baseline (primeira execução)
pnpm exec playwright test --update-snapshots

# Executar comparação
pnpm exec playwright test

# Atualizar snapshot específico
pnpm exec playwright test --update-snapshots -g "dashboard layout"
```

---

## Configuração Playwright para Visual

```typescript
// playwright.config.ts — adiciona configuração visual

import { defineConfig } from '@playwright/test'

export default defineConfig({
  // ...config base do e2e.md...
  expect: {
    toHaveScreenshot: {
      maxDiffPixels: 50,          // tolerância: até 50 pixels diferentes
      threshold: 0.1,             // 10% de diferença por pixel é aceitável
      animations: 'disabled',     // para screenshots consistentes
    },
  },
})
```

---

## Testes de Screenshot

```typescript
// e2e/visual/dashboard.visual.spec.ts

import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

test.describe('Visual Regression — Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.login('test@wolfagency.com.br', 'TestPassword123!')
  })

  test('dashboard layout matches baseline', async ({ page }) => {
    await page.goto('/dashboard')

    // Aguarda carregamento completo (sem loading states)
    await page.waitForSelector('[data-testid="dashboard-metrics"]')
    await page.waitForLoadState('networkidle')

    // Screenshot da página inteira
    await expect(page).toHaveScreenshot('dashboard-full.png', {
      fullPage: true,
      mask: [
        page.getByTestId('last-updated-timestamp'),  // mascara timestamps dinâmicos
        page.getByTestId('user-avatar'),             // mascara avatar (pode variar)
      ],
    })
  })

  test('campaign cards layout matches baseline', async ({ page }) => {
    await page.goto('/campaigns')
    await page.waitForSelector('[data-testid="campaign-list"]')

    // Screenshot de elemento específico
    const campaignList = page.getByTestId('campaign-list')
    await expect(campaignList).toHaveScreenshot('campaign-list.png')
  })

  test('empty state layout matches baseline', async ({ page }) => {
    // Navega para seção sem dados
    await page.goto('/reports?empty=true')
    await page.waitForSelector('[data-testid="empty-state"]')

    await expect(page.getByTestId('empty-state')).toHaveScreenshot('reports-empty-state.png')
  })
})
```

---

## Elementos a Mascarar

Dados dinâmicos quebram comparações visuais. Sempre mascare:

```typescript
// Helper centralizado para máscaras padrão Wolf
export function getDynamicMasks(page: Page) {
  return [
    page.getByTestId('last-updated-timestamp'),
    page.getByTestId('user-avatar'),
    page.getByTestId('current-date-display'),
    page.getByTestId('notification-badge'),
    page.getByTestId('realtime-metrics'),      // dados em tempo real
    page.locator('[data-dynamic="true"]'),      // marcação genérica
  ]
}

// Uso nos testes
await expect(page).toHaveScreenshot('dashboard.png', {
  mask: getDynamicMasks(page),
  animations: 'disabled',
})
```

---

## Quando Aceitar Mudança Visual

### Mudança INTENCIONAL (aceitar e atualizar baseline):
- Redesign aprovado pelo time de produto
- Correção de bug visual confirmada
- Atualização de tema/paleta de cores deliberada
- Novo componente adicionado ao fluxo

```bash
# Processo de aceitação de mudança intencional:
# 1. Revisar diff visual (screenshot anterior vs novo)
# 2. Confirmar com PM/designer que é intencional
# 3. Atualizar baseline:
pnpm exec playwright test --update-snapshots

# 4. Commitar snapshots atualizados com mensagem clara:
git add e2e/visual/__snapshots__/
git commit -m "chore(visual): update dashboard baseline — new metrics layout"
```

### Mudança NÃO intencional (investigar e corrigir):
- CSS global quebrado por mudança não relacionada
- Componente renderizando fora do lugar
- Fonte não carregando
- Overflow de conteúdo inesperado

---

## Integração com Chromatic (para Storybook)

```bash
# Instalação
pnpm add -D chromatic

# Configuração em package.json
{
  "scripts": {
    "chromatic": "chromatic --project-token=$CHROMATIC_PROJECT_TOKEN"
  }
}
```

```yaml
# .github/workflows/chromatic.yml

name: Chromatic Visual Tests

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  chromatic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # Chromatic precisa do histórico completo

      - uses: pnpm/action-setup@v3

      - run: pnpm install --frozen-lockfile

      - name: Build Storybook
        run: pnpm build-storybook

      - name: Run Chromatic
        uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          buildScriptName: build-storybook
          onlyChanged: true    # testa apenas stories com mudanças
          exitZeroOnChanges: false   # falha o CI se há mudanças visuais não aprovadas
```

---

## Casos de Uso no Sistema Wolf

| Tela                    | O que testar visualmente               | Frequência        |
|-------------------------|----------------------------------------|-------------------|
| Dashboard principal     | Layout de métricas, cards de campanha  | A cada PR         |
| Lista de campanhas      | Tabela, badges de status, paginação    | A cada PR         |
| Relatório PDF preview   | Layout antes de gerar PDF              | A cada PR         |
| Formulário de campanha  | Campos, validação visual               | A cada PR         |
| Estado vazio (empty)    | Empty states de todas as seções        | A cada PR         |
| Tema dark (se aplicável)| Todos os componentes em dark mode      | A cada PR         |

---

## Estrutura de Snapshots

```
e2e/
  visual/
    __snapshots__/
      dashboard-full.png                  # baseline armazenado no repo
      campaign-list.png
      reports-empty-state.png
    dashboard.visual.spec.ts
    campaigns.visual.spec.ts
    reports.visual.spec.ts
```

**Snapshots devem ser commitados no repositório.** Assim o CI compara sempre contra o baseline em Git.

---

## Checklist Visual Regression

- [ ] Playwright configurado com `maxDiffPixels` e `threshold` toleráveis
- [ ] Elementos dinâmicos mascarados (timestamps, avatares, dados realtime)
- [ ] Animações desabilitadas para screenshots consistentes (`animations: 'disabled'`)
- [ ] Snapshots de baseline commitados no repositório (não ignorados no .gitignore)
- [ ] CI falha quando diferença visual não aprovada
- [ ] Processo documentado para aceitar mudanças visuais intencionais
- [ ] Screenshots de falha como artifacts no CI para revisão
- [ ] Chromatic configurado para Storybook (se Storybook for usado no projeto)
- [ ] Testes de visual regression separados dos testes E2E funcionais
- [ ] `networkidle` aguardado antes de screenshot (sem loading states parciais)
