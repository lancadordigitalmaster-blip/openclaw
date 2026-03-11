# ci-quality.md — Craft Sub-Skill: CI e Quality Gates
# Ativa quando: "CI", "qualidade", "gate", "bloqueia merge", "PR check"

---

## Quality Gate Wolf — Pipeline Completo

Ordem importa: fail fast, checks rápidos primeiro.

```
type-check → lint → test → coverage → build → bundle-size
     ↑              ↑           ↑          ↑         ↑
   15-30s        30-60s     30-120s     +10s      +30s

Total típico: 3-5 minutos para projeto médio
```

---

## GitHub Actions — Pipeline Wolf Completo

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # cancela runs anteriores do mesmo PR

jobs:
  quality:
    name: Quality Gate
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      # 1. Type check (rápido, falha antes de tudo)
      - name: Type check
        run: pnpm type-check

      # 2. Lint
      - name: Lint
        run: pnpm lint

      # 3. Testes com coverage
      - name: Test
        run: pnpm test:ci
        env:
          DATABASE_URL: postgresql://wolf:wolf@localhost:5432/wolf_test
          REDIS_URL: redis://localhost:6379

      # 4. Relatório de cobertura no PR
      - name: Coverage Report
        uses: davelosert/vitest-coverage-report-action@v2
        if: always()
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          vite-config-path: vitest.config.ts

      # 5. Build (valida que o build não quebra)
      - name: Build
        run: pnpm build

      # 6. Bundle size check
      - name: Bundle Size Check
        uses: preactjs/compressed-size-action@v2
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          pattern: '.next/static/**/*.js'
          compression: 'brotli'

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: wolf
          POSTGRES_PASSWORD: wolf
          POSTGRES_DB: wolf_test
        options: >-
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
        ports:
          - 6379:6379

  # Job separado: Lighthouse (mais lento, opcional para PRs)
  lighthouse:
    name: Lighthouse CI
    runs-on: ubuntu-latest
    needs: quality
    if: github.event_name == 'pull_request'
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Lighthouse CI
        uses: treosh/lighthouse-ci-action@v11
        with:
          urls: http://localhost:3000
          budgetPath: lighthouse-budget.json
          uploadArtifacts: true
          temporaryPublicStorage: true
        env:
          LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

---

## Pipeline Python Wolf

```yaml
# .github/workflows/ci-python.yml
name: CI Python

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install uv
        uses: astral-sh/setup-uv@v3
        with:
          enable-cache: true

      - name: Install dependencies
        run: uv pip install -e ".[dev]" --system

      # 1. Lint e type check com Ruff + mypy
      - name: Lint
        run: ruff check .

      - name: Format check
        run: ruff format --check .

      - name: Type check
        run: mypy app/ --ignore-missing-imports

      # 2. Testes com coverage
      - name: Test
        run: pytest --cov=app --cov-report=xml --cov-fail-under=80
        env:
          DATABASE_URL: postgresql+asyncpg://wolf:wolf@localhost:5432/wolf_test

      # 3. Coverage no PR
      - name: Coverage comment
        uses: py-cov-action/python-coverage-comment-action@v3
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: wolf
          POSTGRES_PASSWORD: wolf
          POSTGRES_DB: wolf_test
        options: --health-cmd pg_isready --health-interval 5s
        ports: ['5432:5432']
```

---

## Branch Protection Rules — Configuração Wolf

```
CONFIGURAR EM: Settings → Branches → Add rule → "main"

Regras obrigatórias:
✓ Require a pull request before merging
  ✓ Required approvals: 1
  ✓ Dismiss stale pull request approvals when new commits are pushed
  ✓ Require review from Code Owners (se CODEOWNERS existir)

✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging
  Status checks obrigatórios:
    - quality / Quality Gate
    - (opcionais: lighthouse, bundle-size)

✓ Require conversation resolution before merging

✓ Do not allow bypassing the above settings
  (mesmo admins precisam de PR)

Opcionais:
○ Require linear history (squash merge obrigatório)
○ Restrict who can push to matching branches
```

```bash
# Configurar via GitHub CLI (automação)
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["quality / Quality Gate"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null
```

---

## Dependabot — Updates Automáticos

```yaml
# .github/dependabot.yml
version: 2
updates:
  # npm
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
      day: monday
      time: "09:00"
      timezone: America/Sao_Paulo
    open-pull-requests-limit: 10
    groups:
      # Agrupa updates de devDependencies em um PR só
      dev-dependencies:
        dependency-type: development
      # Updates de produção: PRs individuais (mais fácil de revisar)
      production-dependencies:
        dependency-type: production
    labels:
      - dependencies
      - automated
    ignore:
      # Ignora major versions automáticos (revisar manualmente)
      - dependency-name: "next"
        update-types: ["version-update:semver-major"]
      - dependency-name: "react"
        update-types: ["version-update:semver-major"]

  # GitHub Actions
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    labels:
      - dependencies
      - ci
```

---

## Vitest — Configuração com Coverage

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      // Thresholds Wolf
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
      // Ignora arquivos de config, tipos e gerados automaticamente
      exclude: [
        'node_modules',
        '.next',
        'coverage',
        '**/*.d.ts',
        '**/*.config.*',
        '**/types/**',
        'tests/**',
        'src/lib/db.ts',  // boilerplate de configuração
      ],
    },
  },
})
```

---

## Fazer CI Falhar Intencionalmente

Às vezes você precisa bloquear merge por razões específicas:

```yaml
# Bloqueia PR se tiver TODO ou FIXME no código novo
- name: Check for TODO/FIXME
  run: |
    if git diff origin/main...HEAD | grep -E '^\+.*\b(TODO|FIXME|HACK)\b'; then
      echo "ERRO: PR contém TODO/FIXME/HACK. Resolva antes de mergear."
      exit 1
    fi
```

```yaml
# Bloqueia se houver console.log no código de produção
- name: Check for console.log
  run: |
    if grep -r "console\.log" src/ --include="*.ts" --include="*.tsx" \
      --exclude-dir="*.test.*" --exclude-dir="*.spec.*"; then
      echo "ERRO: console.log encontrado em código de produção."
      exit 1
    fi
```

```yaml
# Valida que .env.example está atualizado (toda nova var deve estar lá)
- name: Check .env.example is up to date
  run: node scripts/check-env-example.js
```

```javascript
// scripts/check-env-example.js
const fs = require('fs')

const example = fs.readFileSync('.env.example', 'utf8')
const exampleKeys = example
  .split('\n')
  .filter(l => l && !l.startsWith('#'))
  .map(l => l.split('=')[0])

// Verifica se há variáveis usadas no código que não estão no .env.example
const sourceFiles = require('glob').sync('src/**/*.ts')
const envRefs = new Set()

for (const file of sourceFiles) {
  const content = fs.readFileSync(file, 'utf8')
  const matches = content.matchAll(/process\.env\.(\w+)/g)
  for (const match of matches) {
    envRefs.add(match[1])
  }
}

const missing = [...envRefs].filter(key =>
  !exampleKeys.includes(key) &&
  !['NODE_ENV', 'PORT'].includes(key)
)

if (missing.length > 0) {
  console.error(`Variáveis usadas mas não documentadas no .env.example:\n${missing.join('\n')}`)
  process.exit(1)
}

console.log('.env.example está atualizado.')
```

---

## Checklist CI Quality Wolf

```
Pipeline
[ ] type-check → lint → test → build executados em ordem
[ ] Serviços de banco e Redis configurados no CI
[ ] Timeout por job definido (evita runs presos)
[ ] concurrency configurado (cancela runs antigas do mesmo PR)
[ ] --frozen-lockfile no install (garante versões exatas)

Coverage
[ ] Threshold mínimo: 80% linhas e funções
[ ] Relatório de coverage comentado automaticamente no PR
[ ] Arquivos de boilerplate excluídos do coverage

Branch Protection
[ ] main protegido: requer PR + CI verde + 1 review
[ ] Admins também precisam de PR (enforce_admins: true)
[ ] Stale reviews dispensados ao novo push

Dependabot
[ ] Configurado para npm e GitHub Actions
[ ] Schedule semanal (não diário — muitos PRs)
[ ] Major versions não atualizadas automaticamente
[ ] Label "dependencies" aplicado automaticamente

Performance Budget (integração com Turbo)
[ ] Bundle size check no CI (Turbo define os limites)
[ ] Lighthouse CI no pipeline (bloqueia se abaixo de 90)
[ ] Relatório de Web Vitals no PR
```
