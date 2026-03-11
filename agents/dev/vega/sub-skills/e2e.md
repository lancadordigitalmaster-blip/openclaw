# e2e.md — VEGA Sub-Skill: E2E Testing com Playwright
# Ativa quando: "E2E", "Playwright", "teste de ponta a ponta", "fluxo completo"

## Playwright — Padrão Wolf

Stack: **Playwright** com TypeScript, Page Objects pattern, `data-testid` como seletores únicos.

```bash
# Instalação
pnpm add -D @playwright/test
pnpm exec playwright install chromium  # instala browsers

# Executar testes
pnpm exec playwright test              # headless
pnpm exec playwright test --headed    # visual
pnpm exec playwright test --ui        # Playwright UI (debug)
pnpm exec playwright test --debug     # modo debug linha a linha
```

```typescript
// playwright.config.ts

import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : 2,
  reporter: [
    ['list'],
    ['html', { open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
  ],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:3000',
    screenshot: 'only-on-failure',    // screenshot automático em falha
    video: 'retain-on-failure',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

## Seletores: data-testid Obrigatório

**Regra:** Nunca usar classes CSS, IDs ou texto como seletor em E2E. `data-testid` é imune a redesign.

```tsx
// NO COMPONENTE — adicione data-testid em todos os elementos interativos
export function CampaignForm() {
  return (
    <form data-testid="campaign-form">
      <input
        data-testid="campaign-name-input"
        name="name"
        placeholder="Nome da campanha"
      />
      <select data-testid="campaign-platform-select" name="platform">
        <option value="meta">Meta Ads</option>
        <option value="google">Google Ads</option>
      </select>
      <input
        data-testid="campaign-budget-input"
        name="budget"
        type="number"
      />
      <button data-testid="campaign-submit-btn" type="submit">
        Criar Campanha
      </button>
    </form>
  )
}

// NOS TESTES — use apenas data-testid
await page.getByTestId('campaign-name-input').fill('Campanha Verão')

// NUNCA:
await page.locator('.form-input').fill(...)              // CSS class
await page.locator('#campaignName').fill(...)            // ID
await page.getByText('Criar Campanha').click()          // texto (muda com i18n)
await page.locator('input[name="name"]').fill(...)      // atributo DOM
```

---

## Page Objects Pattern

```typescript
// e2e/pages/login.page.ts

import { Page, expect } from '@playwright/test'

export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/login')
  }

  async fillEmail(email: string) {
    await this.page.getByTestId('login-email-input').fill(email)
  }

  async fillPassword(password: string) {
    await this.page.getByTestId('login-password-input').fill(password)
  }

  async submit() {
    await this.page.getByTestId('login-submit-btn').click()
  }

  async login(email: string, password: string) {
    await this.goto()
    await this.fillEmail(email)
    await this.fillPassword(password)
    await this.submit()
    await expect(this.page).toHaveURL('/dashboard')
  }

  async expectError(message: string) {
    await expect(this.page.getByTestId('login-error-message')).toContainText(message)
  }
}
```

```typescript
// e2e/pages/campaign.page.ts

import { Page, expect } from '@playwright/test'

export class CampaignPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/campaigns')
  }

  async clickCreateNew() {
    await this.page.getByTestId('create-campaign-btn').click()
  }

  async fillCampaignForm(data: {
    name: string
    platform: 'meta' | 'google'
    budget: number
  }) {
    await this.page.getByTestId('campaign-name-input').fill(data.name)
    await this.page.getByTestId('campaign-platform-select').selectOption(data.platform)
    await this.page.getByTestId('campaign-budget-input').fill(String(data.budget))
  }

  async submitForm() {
    await this.page.getByTestId('campaign-submit-btn').click()
  }

  async expectCampaignInList(name: string) {
    await expect(
      this.page.getByTestId(`campaign-row-${name.toLowerCase().replace(/\s/g, '-')}`)
    ).toBeVisible()
  }

  async expectSuccessMessage() {
    await expect(this.page.getByTestId('toast-success')).toBeVisible()
  }
}
```

---

## Fluxos Críticos Wolf

```typescript
// e2e/flows/auth.spec.ts

import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

test.describe('Autenticação', () => {
  test('login com credenciais válidas redireciona ao dashboard', async ({ page }) => {
    const loginPage = new LoginPage(page)

    await loginPage.login(
      process.env.E2E_TEST_USER ?? 'test@wolfagency.com.br',
      process.env.E2E_TEST_PASSWORD ?? 'TestPassword123!'
    )

    await expect(page).toHaveURL('/dashboard')
    await expect(page.getByTestId('dashboard-header')).toBeVisible()
  })

  test('login com senha errada exibe mensagem de erro', async ({ page }) => {
    const loginPage = new LoginPage(page)

    await loginPage.goto()
    await loginPage.fillEmail('test@wolfagency.com.br')
    await loginPage.fillPassword('senha-errada')
    await loginPage.submit()

    await loginPage.expectError('Credenciais inválidas')
    await expect(page).toHaveURL('/login')
  })

  test('logout limpa sessão e redireciona ao login', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.login('test@wolfagency.com.br', 'TestPassword123!')

    await page.getByTestId('user-menu-btn').click()
    await page.getByTestId('logout-btn').click()

    await expect(page).toHaveURL('/login')

    // Tenta acessar rota protegida — deve redirecionar
    await page.goto('/dashboard')
    await expect(page).toHaveURL('/login')
  })
})
```

```typescript
// e2e/flows/campaign-creation.spec.ts

import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'
import { CampaignPage } from '../pages/campaign.page'

test.describe('Criação de Campanha', () => {
  test.beforeEach(async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.login('admin@wolfagency.com.br', 'TestPassword123!')
  })

  test('cria campanha Meta com sucesso', async ({ page }) => {
    const campaignPage = new CampaignPage(page)

    await campaignPage.goto()
    await campaignPage.clickCreateNew()

    await campaignPage.fillCampaignForm({
      name: 'Campanha Verão E2E',
      platform: 'meta',
      budget: 500,
    })

    await campaignPage.submitForm()

    await campaignPage.expectSuccessMessage()
    await campaignPage.expectCampaignInList('Campanha Verão E2E')
  })

  test('formulário exibe erros para campos obrigatórios', async ({ page }) => {
    const campaignPage = new CampaignPage(page)

    await campaignPage.goto()
    await campaignPage.clickCreateNew()
    await campaignPage.submitForm()  // submit sem preencher

    await expect(page.getByTestId('field-error-name')).toBeVisible()
    await expect(page.getByTestId('field-error-platform')).toBeVisible()
  })
})
```

```typescript
// e2e/flows/report-generation.spec.ts

import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

test.describe('Geração de Relatório', () => {
  test.beforeEach(async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.login('admin@wolfagency.com.br', 'TestPassword123!')
  })

  test('gera relatório mensal e faz download do PDF', async ({ page }) => {
    await page.goto('/reports')

    await page.getByTestId('report-period-select').selectOption('2024-03')
    await page.getByTestId('generate-report-btn').click()

    // Aguarda geração (pode demorar)
    await expect(page.getByTestId('report-status')).toHaveText('Concluído', {
      timeout: 30_000
    })

    // Verifica download
    const downloadPromise = page.waitForEvent('download')
    await page.getByTestId('download-pdf-btn').click()
    const download = await downloadPromise

    expect(download.suggestedFilename()).toMatch(/relatorio-\d{4}-\d{2}\.pdf/)
  })
})
```

---

## CI Integration

```yaml
# .github/workflows/e2e.yml

name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile

      - name: Install Playwright browsers
        run: pnpm exec playwright install --with-deps chromium

      - name: Run E2E tests
        run: pnpm exec playwright test
        env:
          E2E_BASE_URL: ${{ secrets.E2E_STAGING_URL }}
          E2E_TEST_USER: ${{ secrets.E2E_TEST_USER }}
          E2E_TEST_PASSWORD: ${{ secrets.E2E_TEST_PASSWORD }}

      - name: Upload screenshots de falha
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-screenshots
          path: test-results/
          retention-days: 7
```

---

## Checklist E2E

- [ ] `data-testid` em todos os elementos interativos dos componentes
- [ ] Page Objects criados para todas as páginas testadas
- [ ] Fluxos críticos cobertos: login, criação de campanha, geração de relatório
- [ ] Screenshots de falha habilitados (`screenshot: 'only-on-failure'`)
- [ ] Retries configurados para CI (flakiness tolerance)
- [ ] Variáveis de ambiente para credenciais de teste (nunca hardcoded)
- [ ] Testes rodando em ambiente de staging, não produção
- [ ] Artifacts de falha publicados no CI (screenshots/videos)
- [ ] Tempo total de E2E < 5 minutos (testes focados, sem redundância)
- [ ] `webServer` configurado para subir app antes dos testes em local
