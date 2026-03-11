# unit.md — VEGA Sub-Skill: Unit Testing
# Ativa quando: "teste unitário", "unit test", "vitest", "jest"

## Vitest — Padrão Wolf

Stack: **Vitest** (não Jest) — mais rápido, configuração zero com Vite, suporte nativo a TypeScript e ESM.

```bash
# Instalação
pnpm add -D vitest @vitest/coverage-v8

# Rodar testes
pnpm test                    # watch mode
pnpm test --run              # CI: executa uma vez e sai
pnpm test --coverage         # com relatório de coverage
pnpm test --reporter=verbose # output detalhado
```

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    environment: 'node',
    globals: true,                    // describe/it/expect sem import
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      include: ['src/**/*.ts'],
      exclude: [
        'src/**/*.d.ts',
        'src/**/*.config.ts',
        'src/types/**',
        'src/**/__mocks__/**',
      ],
      thresholds: {
        functions: 80,
        lines: 75,
        branches: 70,
      },
    },
  },
})
```

---

## Estrutura de Teste Wolf

```typescript
// src/lib/__tests__/calculate-pacing.test.ts

import { describe, it, expect, beforeEach } from 'vitest'
import { calculatePacing } from '../calculate-pacing'
import type { CampaignBudget } from '../../types'

describe('calculatePacing', () => {
  // Contexto: o que a função recebe em condição ideal
  describe('when campaign is on track', () => {
    it('returns pace ratio of 1.0 when spend matches expected', () => {
      const budget: CampaignBudget = {
        total: 3000,
        dailyLimit: 100,
        spent: 1500,
        daysElapsed: 15,
        totalDays: 30,
      }

      const result = calculatePacing(budget)

      expect(result.paceRatio).toBe(1.0)
      expect(result.status).toBe('on_track')
      expect(result.projectedSpend).toBe(3000)
    })
  })

  describe('when campaign is overpacing', () => {
    it('returns status overpacing when spend is 20% above expected', () => {
      const budget: CampaignBudget = {
        total: 3000,
        dailyLimit: 100,
        spent: 1800,    // esperado: 1500 — 20% acima
        daysElapsed: 15,
        totalDays: 30,
      }

      const result = calculatePacing(budget)

      expect(result.paceRatio).toBeCloseTo(1.2, 1)
      expect(result.status).toBe('overpacing')
    })

    it('returns projected spend above budget when overpacing', () => {
      const budget: CampaignBudget = {
        total: 3000,
        dailyLimit: 100,
        spent: 1800,
        daysElapsed: 15,
        totalDays: 30,
      }

      const result = calculatePacing(budget)

      expect(result.projectedSpend).toBeGreaterThan(3000)
    })
  })

  describe('edge cases', () => {
    it('returns status unknown when no days have elapsed', () => {
      const budget: CampaignBudget = {
        total: 3000,
        dailyLimit: 100,
        spent: 0,
        daysElapsed: 0,
        totalDays: 30,
      }

      const result = calculatePacing(budget)

      expect(result.status).toBe('unknown')
    })

    it('handles zero budget without throwing', () => {
      const budget: CampaignBudget = {
        total: 0,
        dailyLimit: 0,
        spent: 0,
        daysElapsed: 5,
        totalDays: 30,
      }

      expect(() => calculatePacing(budget)).not.toThrow()
    })

    it('throws when daysElapsed exceeds totalDays', () => {
      const budget: CampaignBudget = {
        total: 3000,
        dailyLimit: 100,
        spent: 1000,
        daysElapsed: 35,  // impossível
        totalDays: 30,
      }

      expect(() => calculatePacing(budget)).toThrow('daysElapsed cannot exceed totalDays')
    })
  })
})
```

---

## O Que Testar — Regras Wolf

### TESTE:
- Lógica de negócio pura (cálculos, validações, transformações)
- Edge cases (zero, null, limites máximos/mínimos)
- Casos de erro esperados (throws com mensagem correta)
- Comportamento de funções com estado (side effects testáveis)

### NÃO TESTE:
- Implementação interna (detalhes que podem mudar sem quebrar comportamento)
- Getters/setters triviais sem lógica
- Constantes e tipos puros
- Configurações (vitest.config, prisma.schema, etc.)
- Código de terceiros (Meta API, Stripe — mock e teste a integração)

```typescript
// ERRADO — testa implementação, não comportamento
it('calls formatCurrency internally', () => {
  const spy = vi.spyOn(utils, 'formatCurrency')
  calculatePacing(budget)
  expect(spy).toHaveBeenCalled()  // irrelevante, pode mudar
})

// CORRETO — testa comportamento observável
it('returns formatted spend in BRL', () => {
  const result = calculatePacing(budget)
  expect(result.formattedSpend).toBe('R$ 1.500,00')
})
```

---

## Mocking de Dependências

```typescript
// Mocking de módulo inteiro
import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('../lib/meta-api', () => ({
  MetaApi: vi.fn().mockImplementation(() => ({
    getCampaigns: vi.fn().mockResolvedValue([
      { id: 'camp_1', name: 'Campanha Verão', status: 'ACTIVE' }
    ]),
    getInsights: vi.fn().mockResolvedValue({
      impressions: 10000,
      clicks: 350,
      spend: 500.00,
    }),
  })),
}))

// Mocking de função específica
vi.mock('../lib/email', () => ({
  sendEmail: vi.fn().mockResolvedValue({ messageId: 'test-id' }),
}))

// Reset entre testes para evitar contaminação
beforeEach(() => {
  vi.clearAllMocks()
})
```

---

## Exemplo: validateBudget

```typescript
// src/lib/__tests__/validate-budget.test.ts

import { describe, it, expect } from 'vitest'
import { validateBudget } from '../validate-budget'

describe('validateBudget', () => {
  it('accepts valid budget configuration', () => {
    const result = validateBudget({
      daily: 100,
      total: 3000,
      startDate: '2024-04-01',
      endDate: '2024-04-30',
    })

    expect(result.valid).toBe(true)
    expect(result.errors).toHaveLength(0)
  })

  it('rejects daily budget exceeding total', () => {
    const result = validateBudget({
      daily: 200,
      total: 1000,
      startDate: '2024-04-01',
      endDate: '2024-04-30',  // 30 dias * 200 = 6000 > 1000
    })

    expect(result.valid).toBe(false)
    expect(result.errors).toContain('daily budget exceeds total for campaign duration')
  })

  it('rejects end date before start date', () => {
    const result = validateBudget({
      daily: 100,
      total: 3000,
      startDate: '2024-04-30',
      endDate: '2024-04-01',
    })

    expect(result.valid).toBe(false)
    expect(result.errors).toContain('end date must be after start date')
  })

  it('rejects negative budget values', () => {
    const result = validateBudget({ daily: -50, total: -1000, startDate: '2024-04-01', endDate: '2024-04-30' })
    expect(result.valid).toBe(false)
    expect(result.errors.some(e => e.includes('negative'))).toBe(true)
  })
})
```

---

## Checklist Unit Testing

- [ ] Vitest configurado com TypeScript e path aliases
- [ ] Thresholds de coverage definidos (80/75/70)
- [ ] Estrutura `describe/it/expect` consistente
- [ ] Cada `it` testa exatamente uma coisa
- [ ] Edge cases cobertos (zero, null, limites)
- [ ] Erros esperados testados com `expect(() => fn()).toThrow()`
- [ ] Mocks limpos entre testes (`vi.clearAllMocks` no beforeEach)
- [ ] Nenhum teste depende de ordem de execução
- [ ] Nomes de teste descrevem comportamento esperado, não implementação
- [ ] Testes rodam em < 30 segundos total (sem I/O real, sem rede)
