# integration.md — VEGA Sub-Skill: Integration Testing
# Ativa quando: "teste de integração", "Supertest", "testa endpoint"

## Supertest + Vitest — Padrão Wolf

Stack: **Supertest** para chamadas HTTP + **Vitest** como runner + banco de teste com rollback de transação.

```bash
# Instalação
pnpm add -D supertest @types/supertest

# Rodar apenas testes de integração
pnpm test --run src/**/*.integration.test.ts
```

---

## Setup de Banco de Teste

Estratégia: cada teste roda dentro de uma transação que é revertida ao final. Zero limpeza manual, zero conflito entre testes.

```typescript
// test/helpers/db.ts

import { PrismaClient } from '@prisma/client'

// Banco de teste separado — nunca aponta para produção ou staging
const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL
  ?? 'postgresql://postgres:postgres@localhost:5432/wolf_test'

export function createTestDb() {
  const prisma = new PrismaClient({
    datasources: { db: { url: TEST_DATABASE_URL } },
    log: [],
  })

  return prisma
}

// Wrapper para isolar cada teste em transação
export async function withTestTransaction<T>(
  prisma: PrismaClient,
  fn: (tx: PrismaClient) => Promise<T>
): Promise<T> {
  return new Promise((resolve, reject) => {
    prisma.$transaction(async (tx) => {
      try {
        const result = await fn(tx as unknown as PrismaClient)
        resolve(result)
        // Rejeita a transação para fazer rollback automático
        throw new Error('__rollback__')
      } catch (err) {
        if (err instanceof Error && err.message === '__rollback__') {
          return  // rollback intencional
        }
        reject(err)
        throw err
      }
    }).catch(() => {})  // ignora o erro de rollback
  })
}
```

---

## Setup de Aplicação para Testes

```typescript
// test/helpers/app.ts

import express from 'express'
import { createRouter } from '../../src/routes'
import { createTestDb } from './db'

export function createTestApp() {
  const app = express()
  const db = createTestDb()

  app.use(express.json())
  app.use('/api', createRouter(db))

  return { app, db }
}
```

---

## Autenticação em Testes

```typescript
// test/helpers/auth.ts

import jwt from 'jsonwebtoken'

const TEST_JWT_SECRET = process.env.JWT_SECRET ?? 'test-secret-wolf'

export function createTestToken(overrides: Partial<JWTPayload> = {}): string {
  const payload: JWTPayload = {
    sub: 'user-test-uuid',
    organizationId: 'org-test-uuid',
    role: 'admin',
    ...overrides,
  }

  return jwt.sign(payload, TEST_JWT_SECRET, { expiresIn: '1h' })
}

// Tokens prontos para reuso nos testes
export const tokens = {
  admin: createTestToken({ role: 'admin' }),
  viewer: createTestToken({ role: 'viewer' }),
  owner: createTestToken({ role: 'owner' }),
  otherOrg: createTestToken({ organizationId: 'other-org-uuid' }),
}
```

---

## Testes de Endpoint — Estrutura Completa

```typescript
// src/routes/__tests__/campaigns.integration.test.ts

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { createTestApp } from '../../../test/helpers/app'
import { tokens } from '../../../test/helpers/auth'
import type { Express } from 'express'
import type { PrismaClient } from '@prisma/client'

describe('POST /api/campaigns', () => {
  let app: Express
  let db: PrismaClient

  beforeAll(() => {
    const testSetup = createTestApp()
    app = testSetup.app
    db = testSetup.db
  })

  afterAll(async () => {
    await db.$disconnect()
  })

  // Happy path
  it('creates campaign successfully for admin user', async () => {
    const response = await request(app)
      .post('/api/campaigns')
      .set('Authorization', `Bearer ${tokens.admin}`)
      .send({
        name: 'Campanha Black Friday 2024',
        platform: 'meta',
        adAccountId: 'acc-test-uuid',
        budgetDaily: 500.00,
        startDate: '2024-11-25',
        endDate: '2024-11-30',
      })

    expect(response.status).toBe(201)
    expect(response.body).toMatchObject({
      id: expect.any(String),
      name: 'Campanha Black Friday 2024',
      status: 'draft',
      platform: 'meta',
      budgetDaily: 500,
    })
    expect(response.body.organizationId).toBe('org-test-uuid')
  })

  // Erro de validação
  it('returns 400 when required fields are missing', async () => {
    const response = await request(app)
      .post('/api/campaigns')
      .set('Authorization', `Bearer ${tokens.admin}`)
      .send({ name: 'Incompleto' })  // sem platform e adAccountId

    expect(response.status).toBe(400)
    expect(response.body).toMatchObject({
      error: expect.any(String),
      fields: expect.arrayContaining(['platform', 'adAccountId']),
    })
  })

  // Autorização
  it('returns 403 when viewer tries to create campaign', async () => {
    const response = await request(app)
      .post('/api/campaigns')
      .set('Authorization', `Bearer ${tokens.viewer}`)
      .send({
        name: 'Teste Viewer',
        platform: 'meta',
        adAccountId: 'acc-test-uuid',
      })

    expect(response.status).toBe(403)
  })

  // Isolamento de tenant
  it('returns 404 when adAccount belongs to different org', async () => {
    const response = await request(app)
      .post('/api/campaigns')
      .set('Authorization', `Bearer ${tokens.admin}`)
      .send({
        name: 'Cross-tenant attempt',
        platform: 'meta',
        adAccountId: 'acc-other-org-uuid',  // conta de outra org
      })

    expect(response.status).toBe(404)
  })

  // Sem autenticação
  it('returns 401 when no token provided', async () => {
    const response = await request(app)
      .post('/api/campaigns')
      .send({ name: 'Sem auth' })

    expect(response.status).toBe(401)
  })
})

describe('GET /api/campaigns', () => {
  let app: Express
  let db: PrismaClient

  beforeAll(async () => {
    const testSetup = createTestApp()
    app = testSetup.app
    db = testSetup.db

    // Seed: cria dados de teste
    await db.adCampaign.createMany({
      data: [
        {
          id: 'camp-1',
          organizationId: 'org-test-uuid',
          name: 'Campanha A',
          status: 'active',
          platform: 'meta',
          adAccountId: 'acc-test-uuid',
        },
        {
          id: 'camp-2',
          organizationId: 'org-test-uuid',
          name: 'Campanha B',
          status: 'paused',
          platform: 'google',
          adAccountId: 'acc-test-uuid',
        },
        {
          id: 'camp-other-org',
          organizationId: 'other-org-uuid',  // outra org
          name: 'Campanha C - Outra Org',
          status: 'active',
          platform: 'meta',
          adAccountId: 'acc-other-uuid',
        },
      ],
    })
  })

  afterAll(async () => {
    // Limpa dados de seed
    await db.adCampaign.deleteMany({
      where: { organizationId: 'org-test-uuid' },
    })
    await db.$disconnect()
  })

  it('returns only campaigns from user org', async () => {
    const response = await request(app)
      .get('/api/campaigns')
      .set('Authorization', `Bearer ${tokens.admin}`)

    expect(response.status).toBe(200)
    expect(response.body.items).toHaveLength(2)
    expect(response.body.items.every(
      (c: { organizationId: string }) => c.organizationId === 'org-test-uuid'
    )).toBe(true)
  })

  it('filters by status', async () => {
    const response = await request(app)
      .get('/api/campaigns?status=active')
      .set('Authorization', `Bearer ${tokens.admin}`)

    expect(response.status).toBe(200)
    expect(response.body.items).toHaveLength(1)
    expect(response.body.items[0].id).toBe('camp-1')
  })

  it('returns paginated response with metadata', async () => {
    const response = await request(app)
      .get('/api/campaigns?limit=1')
      .set('Authorization', `Bearer ${tokens.admin}`)

    expect(response.status).toBe(200)
    expect(response.body).toMatchObject({
      items: expect.any(Array),
      total: 2,
      limit: 1,
      hasMore: true,
    })
    expect(response.body.items).toHaveLength(1)
  })
})
```

---

## Checklist Integration Testing

- [ ] Banco de teste separado (nunca desenvolvimento, nunca produção)
- [ ] Happy path testado para cada endpoint
- [ ] Erros de validação testados (400 com campos corretos)
- [ ] Autorização testada: 401 sem token, 403 com role insuficiente
- [ ] Isolamento de tenant testado (não vaza dados de outra org)
- [ ] Respostas de paginação validadas (items, total, hasMore)
- [ ] Setup/teardown limpa dados de seed após os testes
- [ ] Tokens de teste criados com `createTestToken()` centralizado
- [ ] Sem chamadas reais a APIs externas (mockadas com vi.mock ou MSW)
- [ ] Testes rodam em < 60 segundos total
