# testing.md — Forge Sub-Skill: Testing
# Ativa quando: "teste", "unit", "integration", "mock"

## Stack de Testes Wolf

| Ferramenta | Uso                                                        |
|------------|------------------------------------------------------------|
| Vitest     | Test runner principal (mais rápido que Jest para TS)       |
| Jest       | Alternativa quando já está no projeto                      |
| Supertest  | Testes de endpoint HTTP                                    |
| MSW        | Mock de APIs externas (intercept a nível de rede)          |
| @faker-js  | Geração de dados de teste                                  |

```bash
npm install -D vitest @vitest/coverage-v8 supertest @types/supertest msw @faker-js/faker
```

## Configuração Vitest

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      exclude: ['node_modules', 'dist', 'src/test'],
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
    },
  },
})
```

```typescript
// src/test/setup.ts
import { beforeAll, afterAll, afterEach } from 'vitest'
import { server } from './mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

## Estrutura de Test Suite

```
src/
  routes/
    campaigns.ts
    campaigns.test.ts       ← testes de integração do endpoint
  services/
    campaign.service.ts
    campaign.service.test.ts ← testes unitários do service
  test/
    setup.ts
    helpers.ts              ← factories e utilitários
    mocks/
      server.ts             ← MSW server
      handlers/
        meta-ads.ts
        evolution-api.ts
```

## Helpers e Factories

```typescript
// src/test/helpers.ts
import { faker } from '@faker-js/faker'
import request from 'supertest'
import app from '../app'
import { db } from '../lib/db'
import { generateTokens } from '../services/auth.service'

export function createTestUser(overrides: Partial<any> = {}) {
  return {
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    role: 'admin' as const,
    organizationId: faker.string.uuid(),
    ...overrides,
  }
}

export function createTestCampaign(overrides: Partial<any> = {}) {
  return {
    id: faker.string.uuid(),
    name: faker.commerce.productName(),
    platform: 'meta' as const,
    status: 'active' as const,
    budget: { type: 'daily', amount: 100, currency: 'BRL' },
    ...overrides,
  }
}

export function getAuthHeaders(user = createTestUser()) {
  const { accessToken } = generateTokens(user)
  return { Authorization: `Bearer ${accessToken}` }
}

export const api = request(app)
```

## Mock com MSW

```typescript
// src/test/mocks/server.ts
import { setupServer } from 'msw/node'
import { metaAdsHandlers } from './handlers/meta-ads'
import { evolutionApiHandlers } from './handlers/evolution-api'

export const server = setupServer(
  ...metaAdsHandlers,
  ...evolutionApiHandlers
)

// src/test/mocks/handlers/meta-ads.ts
import { http, HttpResponse } from 'msw'

export const metaAdsHandlers = [
  http.get('https://graph.facebook.com/v21.0/:campaignId/insights', ({ params }) => {
    return HttpResponse.json([
      {
        impressions: '10000',
        clicks: '500',
        spend: '250.00',
        reach: '8000',
      },
    ])
  }),

  http.get('https://graph.facebook.com/v21.0/act_:adAccountId/campaigns', () => {
    return HttpResponse.json({
      data: [
        { id: 'campaign_123', name: 'Test Campaign', status: 'ACTIVE', objective: 'LEAD_GENERATION' },
      ],
    })
  }),
]
```

## Testes de Endpoint — Happy Path + Erros

```typescript
// src/routes/campaigns.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { api, createTestUser, createTestCampaign, getAuthHeaders } from '../test/helpers'
import { CampaignService } from '../services/campaign.service'

vi.mock('../services/campaign.service')

describe('GET /api/v1/campaigns', () => {
  const user = createTestUser()
  const headers = getAuthHeaders(user)

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns paginated campaigns', async () => {
    const campaigns = [createTestCampaign(), createTestCampaign()]
    vi.mocked(CampaignService.list).mockResolvedValue({ campaigns, total: 2 })

    const res = await api
      .get('/api/v1/campaigns')
      .set(headers)
      .query({ page: 1, limit: 20 })

    expect(res.status).toBe(200)
    expect(res.body.data).toHaveLength(2)
    expect(res.body.meta.pagination).toMatchObject({
      page: 1,
      limit: 20,
      total: 2,
      pages: 1,
    })
  })

  it('returns 401 when not authenticated', async () => {
    const res = await api.get('/api/v1/campaigns')

    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('UNAUTHENTICATED')
  })

  it('returns 422 for invalid query params', async () => {
    const res = await api
      .get('/api/v1/campaigns')
      .set(headers)
      .query({ limit: 'not-a-number' })

    expect(res.status).toBe(422)
    expect(res.body.error.code).toBe('VALIDATION_ERROR')
    expect(res.body.error.details).toContainEqual(
      expect.objectContaining({ field: 'limit' })
    )
  })
})

describe('POST /api/v1/campaigns', () => {
  const user = createTestUser()
  const headers = getAuthHeaders(user)

  const validPayload = {
    name: 'Black Friday 2026',
    platform: 'meta',
    objective: 'leads',
    budget: { type: 'daily', amount: 500, currency: 'BRL' },
    schedule: { startDate: '2026-11-01' },
    targetAudience: { locations: ['BR'] },
  }

  it('creates campaign and returns 201', async () => {
    const created = createTestCampaign({ name: validPayload.name })
    vi.mocked(CampaignService.create).mockResolvedValue(created)

    const res = await api
      .post('/api/v1/campaigns')
      .set(headers)
      .send(validPayload)

    expect(res.status).toBe(201)
    expect(res.body.data.name).toBe(created.name)
    expect(CampaignService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        name: validPayload.name,
        organizationId: user.organizationId,
      })
    )
  })

  it('returns 422 when name is missing', async () => {
    const { name, ...withoutName } = validPayload

    const res = await api
      .post('/api/v1/campaigns')
      .set(headers)
      .send(withoutName)

    expect(res.status).toBe(422)
    expect(res.body.error.details).toContainEqual(
      expect.objectContaining({ field: 'name' })
    )
  })

  it('returns 422 when budget amount is negative', async () => {
    const res = await api
      .post('/api/v1/campaigns')
      .set(headers)
      .send({ ...validPayload, budget: { type: 'daily', amount: -100, currency: 'BRL' } })

    expect(res.status).toBe(422)
    expect(res.body.error.details).toContainEqual(
      expect.objectContaining({ field: 'budget.amount' })
    )
  })

  it('returns 409 when campaign name already exists', async () => {
    vi.mocked(CampaignService.create).mockRejectedValue(
      new ConflictError('Campaign name already exists.')
    )

    const res = await api.post('/api/v1/campaigns').set(headers).send(validPayload)

    expect(res.status).toBe(409)
    expect(res.body.error.code).toBe('CONFLICT')
  })
})

describe('GET /api/v1/campaigns/:id', () => {
  const user = createTestUser()
  const headers = getAuthHeaders(user)

  it('returns campaign by id', async () => {
    const campaign = createTestCampaign()
    vi.mocked(CampaignService.findById).mockResolvedValue(campaign)

    const res = await api.get(`/api/v1/campaigns/${campaign.id}`).set(headers)

    expect(res.status).toBe(200)
    expect(res.body.data.id).toBe(campaign.id)
  })

  it('returns 404 when campaign does not exist', async () => {
    vi.mocked(CampaignService.findById).mockResolvedValue(null)

    const res = await api.get(`/api/v1/campaigns/${faker.string.uuid()}`).set(headers)

    expect(res.status).toBe(404)
    expect(res.body.error.code).toBe('RESOURCE_NOT_FOUND')
  })

  it('returns 422 for invalid UUID', async () => {
    const res = await api.get('/api/v1/campaigns/not-a-uuid').set(headers)

    expect(res.status).toBe(422)
  })
})
```

## Testes Unitários de Service

```typescript
// src/services/campaign.service.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { CampaignService } from './campaign.service'
import { db } from '../lib/db'

vi.mock('../lib/db', () => ({
  db: {
    campaign: {
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
    },
  },
}))

describe('CampaignService.findById', () => {
  beforeEach(() => vi.clearAllMocks())

  it('returns campaign when found', async () => {
    const campaign = createTestCampaign()
    vi.mocked(db.campaign.findUnique).mockResolvedValue(campaign)

    const result = await CampaignService.findById(campaign.id, campaign.organizationId)

    expect(result).toEqual(campaign)
    expect(db.campaign.findUnique).toHaveBeenCalledWith({
      where: { id: campaign.id, organizationId: campaign.organizationId },
    })
  })

  it('returns null when not found', async () => {
    vi.mocked(db.campaign.findUnique).mockResolvedValue(null)

    const result = await CampaignService.findById('non-existent', 'org-123')

    expect(result).toBeNull()
  })
})
```

## Comandos de Teste

```bash
# Rodar todos os testes
npx vitest run

# Watch mode (desenvolvimento)
npx vitest

# Com cobertura
npx vitest run --coverage

# Testes específicos
npx vitest run campaigns

# Verbose
npx vitest run --reporter=verbose
```

## Checklist de Testes

- [ ] Happy path coberto (fluxo principal funciona)
- [ ] Casos de erro cobertos (404, 401, 422, 409)
- [ ] Mocks de dependências externas (db, APIs externas)
- [ ] Mocks resetados entre testes (`beforeEach(() => vi.clearAllMocks())`)
- [ ] Testes independentes (sem ordem, sem estado compartilhado)
- [ ] Cobertura >= 80% em branches e statements
- [ ] Nenhum teste real chama APIs externas (usar MSW)
- [ ] Factories para dados de teste (não hardcodar IDs)
- [ ] Assertions específicas (não apenas `expect(res.status).toBe(200)`)
