# mocking.md — VEGA Sub-Skill: Mocking & Fake Data
# Ativa quando: "mock", "stub", "MSW", "fake data"

## Quando Usar Mock vs Teste Real

| Situação                              | Estratégia                         |
|---------------------------------------|------------------------------------|
| API externa (Meta, Google, Stripe)    | Mock obrigatório — nunca chame real |
| Banco de dados em unit test           | Mock ou banco in-memory            |
| Banco de dados em integration test    | Banco real de teste (não mock)     |
| Serviço de email                      | Mock — nunca envie email real      |
| Serviço interno da própria aplicação  | Teste real (integration test)      |
| Clock/Data atual                      | Mock para testes determinísticos   |
| Variáveis de ambiente                 | Mock com valores de teste          |

**Regra:** Mocke o que você não controla. Teste real o que você controla.

---

## vi.mock — Módulos (Vitest)

```typescript
// src/services/__tests__/campaign-sync.test.ts

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { syncCampaignsFromMeta } from '../campaign-sync'

// Mock completo de módulo
vi.mock('../../lib/meta-api', () => ({
  MetaApiClient: vi.fn().mockImplementation(() => ({
    getCampaigns: vi.fn().mockResolvedValue([
      {
        id: 'meta_camp_1',
        name: 'Campanha Meta Teste',
        status: 'ACTIVE',
        daily_budget: 10000,  // centavos
        effective_status: 'ACTIVE',
      }
    ]),
    getInsights: vi.fn().mockResolvedValue({
      data: [
        {
          campaign_id: 'meta_camp_1',
          impressions: '15000',
          clicks: '450',
          spend: '150.00',
          date_start: '2024-03-01',
          date_stop: '2024-03-31',
        }
      ]
    }),
  })),
}))

// Mock de módulo com implementação parcial
vi.mock('../../lib/email', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../lib/email')>()
  return {
    ...actual,
    sendEmail: vi.fn().mockResolvedValue({ messageId: 'mock-id-123' }),
    // mantém outras funções reais
  }
})

// Mock de clock para testes com datas
vi.useFakeTimers()
vi.setSystemTime(new Date('2024-03-15T10:00:00Z'))

describe('syncCampaignsFromMeta', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('syncs campaigns and creates new ones from Meta response', async () => {
    const result = await syncCampaignsFromMeta({
      adAccountId: 'acc-test-uuid',
      organizationId: 'org-test-uuid',
    })

    expect(result.synced).toBe(1)
    expect(result.created).toBe(1)
    expect(result.errors).toHaveLength(0)
  })

  it('handles Meta API error gracefully', async () => {
    const { MetaApiClient } = await import('../../lib/meta-api')
    vi.mocked(MetaApiClient).mockImplementationOnce(() => ({
      getCampaigns: vi.fn().mockRejectedValue(new Error('Meta API rate limit')),
    } as any))

    const result = await syncCampaignsFromMeta({
      adAccountId: 'acc-test-uuid',
      organizationId: 'org-test-uuid',
    })

    expect(result.errors).toHaveLength(1)
    expect(result.errors[0]).toContain('rate limit')
  })
})
```

---

## MSW — Mock Service Worker

MSW intercepta requests HTTP no nível da rede. Funciona em testes (Node) e no browser.

```bash
pnpm add -D msw
```

```typescript
// test/mocks/handlers.ts — handlers centralizados

import { http, HttpResponse } from 'msw'

const META_API_BASE = 'https://graph.facebook.com/v19.0'

export const metaApiHandlers = [
  // GET campanhas Meta
  http.get(`${META_API_BASE}/:accountId/campaigns`, ({ params, request }) => {
    const url = new URL(request.url)
    const fields = url.searchParams.get('fields')

    return HttpResponse.json({
      data: [
        {
          id: 'meta_123',
          name: 'Campanha Verão Mock',
          status: 'ACTIVE',
          daily_budget: '5000',
          effective_status: 'ACTIVE',
          created_time: '2024-01-15T10:00:00+0000',
        },
        {
          id: 'meta_456',
          name: 'Campanha Black Friday Mock',
          status: 'PAUSED',
          daily_budget: '10000',
          effective_status: 'PAUSED',
          created_time: '2024-02-01T10:00:00+0000',
        }
      ],
      paging: {
        cursors: {
          before: 'cursor_before',
          after: 'cursor_after',
        }
      }
    })
  }),

  // POST insights Meta
  http.post(`${META_API_BASE}`, ({ request }) => {
    return HttpResponse.json({
      data: [
        {
          campaign_id: 'meta_123',
          impressions: '10000',
          clicks: '350',
          spend: '250.50',
          cpc: '0.716',
          ctr: '3.5',
          date_start: '2024-03-01',
          date_stop: '2024-03-31',
        }
      ]
    })
  }),

  // Simular erro de rate limit
  http.get(`${META_API_BASE}/rate-limited/*`, () => {
    return HttpResponse.json(
      {
        error: {
          message: 'User request limit reached',
          type: 'OAuthException',
          code: 4,
        }
      },
      { status: 429 }
    )
  }),
]

export const stripeHandlers = [
  http.post('https://api.stripe.com/v1/subscriptions', () => {
    return HttpResponse.json({
      id: 'sub_mock_123',
      status: 'active',
      current_period_end: 1735689600,
    })
  }),
]

export const handlers = [
  ...metaApiHandlers,
  ...stripeHandlers,
]
```

```typescript
// test/mocks/server.ts — servidor MSW para Node (testes)

import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

```typescript
// test/setup.ts — configuração global do Vitest

import { beforeAll, afterAll, afterEach } from 'vitest'
import { server } from './mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }))
afterEach(() => server.resetHandlers())  // reseta overrides entre testes
afterAll(() => server.close())
```

```typescript
// vitest.config.ts — adiciona setup global
export default defineConfig({
  test: {
    setupFiles: ['./test/setup.ts'],
    // ...
  }
})
```

### Override de handler por teste:
```typescript
it('handles Meta API error in this specific test', async () => {
  server.use(
    http.get('https://graph.facebook.com/v19.0/:accountId/campaigns', () => {
      return HttpResponse.json(
        { error: { code: 190, message: 'Invalid OAuth token' } },
        { status: 401 }
      )
    })
  )

  const result = await syncCampaigns('acc-test')
  expect(result.error).toContain('OAuth')
})
// server.resetHandlers() é chamado após o teste automaticamente (afterEach)
```

---

## Factories com Faker.js

```bash
pnpm add -D @faker-js/faker
```

```typescript
// test/factories/campaign.factory.ts

import { faker } from '@faker-js/faker/locale/pt_BR'
import type { AdCampaign } from '../../src/types'

export function buildCampaign(overrides: Partial<AdCampaign> = {}): AdCampaign {
  return {
    id: faker.string.uuid(),
    organizationId: faker.string.uuid(),
    adAccountId: faker.string.uuid(),
    externalId: `meta_${faker.string.numeric(10)}`,
    name: `${faker.commerce.productAdjective()} ${faker.commerce.product()} ${faker.date.month()}`,
    status: faker.helpers.arrayElement(['draft', 'active', 'paused', 'archived']),
    platform: faker.helpers.arrayElement(['meta', 'google', 'tiktok']),
    budgetDaily: parseFloat(faker.finance.amount({ min: 50, max: 5000, dec: 2 })),
    budgetTotal: null,
    startDate: faker.date.recent({ days: 30 }).toISOString().split('T')[0],
    endDate: null,
    tags: faker.helpers.arrayElements(['black-friday', 'branding', 'conversao', 'awareness'], 2),
    metadata: null,
    createdAt: faker.date.recent({ days: 60 }),
    updatedAt: faker.date.recent({ days: 30 }),
    deletedAt: null,
    ...overrides,  // overrides sempre por último
  }
}

export function buildCampaignList(count: number, overrides?: Partial<AdCampaign>): AdCampaign[] {
  return Array.from({ length: count }, () => buildCampaign(overrides))
}

// Uso nos testes:
const campaign = buildCampaign({ status: 'active', platform: 'meta' })
const campaigns = buildCampaignList(10, { organizationId: 'org-fixed-uuid' })
```

```typescript
// test/factories/user.factory.ts

import { faker } from '@faker-js/faker/locale/pt_BR'
import type { User } from '../../src/types'

export function buildUser(overrides: Partial<User> = {}): User {
  return {
    id: faker.string.uuid(),
    organizationId: faker.string.uuid(),
    email: faker.internet.email({ provider: 'wolfagency.com.br' }),
    name: faker.person.fullName(),
    role: faker.helpers.arrayElement(['owner', 'admin', 'analyst', 'viewer']),
    avatarUrl: faker.image.avatar(),
    lastSeenAt: faker.date.recent(),
    createdAt: faker.date.past(),
    updatedAt: faker.date.recent(),
    deletedAt: null,
    ...overrides,
  }
}
```

---

## Checklist Mocking

- [ ] MSW configurado com `setupServer` para testes Node
- [ ] Handlers centralizados em `test/mocks/handlers.ts`
- [ ] `server.resetHandlers()` no `afterEach` (evita contaminação entre testes)
- [ ] Overrides de handler por teste quando cenário de erro é necessário
- [ ] Factories com faker.js para todos os tipos principais
- [ ] Factories aceitam `overrides` para controle em casos específicos
- [ ] `vi.clearAllMocks()` no `beforeEach` para mocks Vitest
- [ ] Clock mockado (`vi.useFakeTimers()`) quando testa lógica com datas
- [ ] Nenhuma chamada real a APIs externas em testes unitários ou de integração
- [ ] `onUnhandledRequest: 'warn'` no MSW (detecta requests não mockados)
