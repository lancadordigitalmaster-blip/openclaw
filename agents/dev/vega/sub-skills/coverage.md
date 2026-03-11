# coverage.md — VEGA Sub-Skill: Coverage
# Ativa quando: "coverage", "cobertura", "relatório de testes"

## Thresholds Wolf

| Métrica      | Threshold mínimo | Bloqueia PR se abaixo |
|--------------|------------------|------------------------|
| Functions    | 80%              | Sim                    |
| Lines        | 75%              | Sim                    |
| Branches     | 70%              | Sim                    |
| Statements   | 75%              | Sim (igual a lines)    |

Thresholds são limites mínimos, não metas. O objetivo é cobertura **significativa**, não cobertura **por cobertura**.

---

## Configuração Istanbul/c8 com Vitest

```typescript
// vitest.config.ts

import { defineConfig } from 'vitest/config'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    environment: 'node',
    globals: true,
    coverage: {
      provider: 'v8',                            // v8 é nativo, mais rápido que istanbul
      reporter: [
        'text',                                  // output no terminal
        'lcov',                                  // formato para Codecov/SonarQube
        'html',                                  // relatório visual em coverage/
        'json-summary',                          // resumo para badge
      ],
      reportsDirectory: './coverage',
      include: ['src/**/*.ts', 'src/**/*.tsx'],
      exclude: [
        // Configs e boilerplate
        'src/**/*.config.ts',
        'src/**/*.config.tsx',
        'src/app/layout.tsx',
        'src/app/page.tsx',                      // páginas Next.js (testar via E2E)

        // Tipos puros — não há lógica para testar
        'src/types/**',
        'src/**/*.d.ts',

        // Constantes e enums
        'src/constants/**',
        'src/lib/prisma.ts',                     // apenas instância do Prisma

        // Mocks e fixtures
        'src/**/__mocks__/**',
        'src/**/__fixtures__/**',

        // Gerado automaticamente
        'src/generated/**',
        'src/prisma/client/**',
      ],
      thresholds: {
        functions: 80,
        lines: 75,
        branches: 70,
        statements: 75,
        // Per-file thresholds para arquivos críticos
        perFile: false,  // habilitar se quiser threshold por arquivo
      },
      watermarks: {
        functions: [70, 80],  // amarelo abaixo de 70, verde acima de 80
        lines: [65, 75],
        branches: [60, 70],
      },
    },
  },
})
```

---

## O Que NÃO Precisa de Teste

### Não teste — resultado é distração, não qualidade:

```typescript
// Tipos puros — sem lógica executável
// src/types/campaign.ts
export type CampaignStatus = 'draft' | 'active' | 'paused' | 'archived'
export interface Campaign { id: string; name: string; status: CampaignStatus }
// Nenhum teste necessário

// Constantes
// src/constants/platforms.ts
export const SUPPORTED_PLATFORMS = ['meta', 'google', 'tiktok'] as const
// Nenhum teste necessário

// Re-exports
// src/lib/index.ts
export * from './calculate-pacing'
export * from './validate-budget'
// Nenhum teste necessário

// Configuração de cliente Prisma
// src/lib/prisma.ts
import { PrismaClient } from '@prisma/client'
export const prisma = new PrismaClient()
// Nenhum teste unitário — testado via integração

// Páginas Next.js / componentes de rota
// Testar via E2E (Playwright), não unit test
```

### Teste — contém lógica de negócio real:
```typescript
// Funções com cálculo / transformação
export function calculatePacing(budget: CampaignBudget): PacingResult { ... }

// Validadores com regras de negócio
export function validateBudget(input: BudgetInput): ValidationResult { ... }

// Formatadores com lógica condicional
export function formatMetricsDelta(current: number, previous: number): DeltaResult { ... }

// Handlers de API com lógica de autorização
export async function createCampaignHandler(req, res) { ... }

// Hooks com lógica de estado complexa
export function useCampaignFilters(campaigns: Campaign[]) { ... }
```

---

## Coverage no CI — Bloqueia PR se Cair

```yaml
# .github/workflows/test.yml

name: Tests & Coverage

on:
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile

      - name: Run tests with coverage
        run: pnpm test --run --coverage

      # Falha automaticamente se thresholds não forem atingidos
      # (o próprio Vitest retorna exit code 1 quando abaixo do threshold)

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Upload coverage report as artifact
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          retention-days: 14
```

---

## Badge de Coverage no README

```bash
# Após configurar Codecov (codecov.io):

# No README.md do projeto:
[![Coverage](https://codecov.io/gh/wolfagency/project-name/branch/main/graph/badge.svg?token=TOKEN)](https://codecov.io/gh/wolfagency/project-name)
```

```typescript
// Alternativa: gerar badge local com o JSON summary
// scripts/update-coverage-badge.ts

import { readFileSync, writeFileSync } from 'fs'

const summary = JSON.parse(
  readFileSync('./coverage/coverage-summary.json', 'utf-8')
)

const total = summary.total
const lineCoverage = Math.round(total.lines.pct)

const color = lineCoverage >= 80 ? 'brightgreen'
  : lineCoverage >= 70 ? 'yellow'
  : 'red'

const badge = `https://img.shields.io/badge/coverage-${lineCoverage}%25-${color}`
console.log(`Coverage badge URL: ${badge}`)
```

---

## Leitura de Relatório de Coverage

```
--------------------|---------|----------|---------|---------|
File                | % Stmts | % Branch | % Funcs | % Lines |
--------------------|---------|----------|---------|---------|
All files           |   82.4  |   74.1   |   85.2  |   81.9  |
 lib/               |         |          |         |         |
  calculate-pacing  |   95.2  |   88.0   |  100.0  |   94.7  | <-- bom
  validate-budget   |   78.4  |   65.3   |   83.3  |   77.8  | <-- branches baixo
  format-metrics    |   55.1  |   40.0   |   60.0  |   54.3  | <-- precisa atenção
--------------------|---------|----------|---------|---------|
```

### Interpretação:
- **% Stmts:** linhas de código executadas
- **% Branch:** caminhos condicionais testados (if/else, ternary, &&)
- **% Funcs:** funções chamadas nos testes
- **% Lines:** linhas físicas executadas

**Branch coverage baixo** (< 70%) é o mais preocupante: indica que caminhos de erro e edge cases não estão sendo testados.

---

## Checklist Coverage

- [ ] `v8` configurado como provider no vitest.config.ts
- [ ] Thresholds definidos: functions 80, lines 75, branches 70
- [ ] Paths excluídos: types, constants, configs, boilerplate
- [ ] CI bloqueia PR quando coverage cai abaixo do threshold
- [ ] Relatório HTML gerado e acessível como artifact no CI
- [ ] Codecov ou equivalente configurado para histórico de coverage
- [ ] Badge de coverage no README atualizado
- [ ] Revisão de coverage feita em code review (não apenas CI)
- [ ] Branch coverage > 70% validado (indica edge cases cobertos)
- [ ] Coverage não é meta — qualidade dos testes é o que importa
