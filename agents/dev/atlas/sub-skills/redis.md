# redis.md — ATLAS Sub-Skill: Redis
# Ativa quando: "Redis", "cache", "sessão", "fila Redis"

## Casos de Uso Redis no Sistema Wolf

| Caso de Uso         | TTL          | Eviction Policy       | Lib          |
|---------------------|--------------|-----------------------|--------------|
| Cache de API Meta   | 5-15 min     | allkeys-lru           | ioredis      |
| Sessões de usuário  | 7 dias       | volatile-lru          | ioredis      |
| Filas BullMQ        | Sem expiração| noeviction (dedicado) | bullmq       |
| Rate limiting       | 1-60 seg     | volatile-lru          | ioredis      |
| Lock distribuído    | 5-30 seg     | volatile-lru          | ioredis      |
| Cache de dashboard  | 2 min        | allkeys-lru           | ioredis      |

---

## Padrão de Keys Wolf

Formato: `namespace:recurso:identificador[:detalhe]`

```
wolf:session:{userId}
wolf:api:meta:{accountId}:campaigns:{dateRange}
wolf:ratelimit:{endpoint}:{userId}
wolf:lock:report-generation:{reportId}
wolf:cache:dashboard:{organizationId}:{period}
wolf:cache:user:{userId}:permissions
```

```typescript
// lib/redis-keys.ts — centralize keys aqui, nunca espalhadas pelo código

export const RedisKeys = {
  session: (userId: string) =>
    `wolf:session:${userId}`,

  metaCampaigns: (accountId: string, period: string) =>
    `wolf:api:meta:${accountId}:campaigns:${period}`,

  rateLimit: (endpoint: string, userId: string) =>
    `wolf:ratelimit:${endpoint}:${userId}`,

  reportLock: (reportId: string) =>
    `wolf:lock:report:${reportId}`,

  dashboardCache: (orgId: string, period: string) =>
    `wolf:cache:dashboard:${orgId}:${period}`,

  userPermissions: (userId: string) =>
    `wolf:cache:user:${userId}:permissions`,
} as const
```

---

## Conexão com ioredis

```typescript
// lib/redis.ts

import Redis from 'ioredis'

const redisConfig = {
  host: process.env.REDIS_HOST ?? 'localhost',
  port: parseInt(process.env.REDIS_PORT ?? '6379'),
  password: process.env.REDIS_PASSWORD,
  db: parseInt(process.env.REDIS_DB ?? '0'),
  maxRetriesPerRequest: 3,
  retryStrategy: (times: number) => {
    if (times > 10) return null  // desiste após 10 tentativas
    return Math.min(times * 100, 3000)
  },
  lazyConnect: true,
}

// Singleton — evita múltiplas conexões
let redisInstance: Redis | null = null

export function getRedis(): Redis {
  if (!redisInstance) {
    redisInstance = new Redis(redisConfig)

    redisInstance.on('error', (err) => {
      console.error('[Redis] Connection error:', err.message)
    })

    redisInstance.on('connect', () => {
      console.log('[Redis] Connected')
    })
  }
  return redisInstance
}

// Para BullMQ — conexão separada (BullMQ gerencia o lifecycle)
export function createBullMQConnection(): Redis {
  return new Redis({
    ...redisConfig,
    maxRetriesPerRequest: null,  // obrigatório para BullMQ
    enableReadyCheck: false,
  })
}
```

---

## Cache de API com TTL

```typescript
// lib/cache.ts

import { getRedis } from './redis'
import { RedisKeys } from './redis-keys'

interface CacheOptions {
  ttl: number  // segundos
}

export async function withCache<T>(
  key: string,
  fn: () => Promise<T>,
  options: CacheOptions
): Promise<T> {
  const redis = getRedis()

  // Tenta buscar do cache
  const cached = await redis.get(key)
  if (cached) {
    return JSON.parse(cached) as T
  }

  // Executa a função original
  const result = await fn()

  // Armazena no cache
  await redis.setex(key, options.ttl, JSON.stringify(result))

  return result
}

// Uso:
const campaigns = await withCache(
  RedisKeys.metaCampaigns(accountId, '2024-03'),
  () => metaApi.getCampaigns(accountId, '2024-03'),
  { ttl: 10 * 60 }  // 10 minutos
)

// Invalidação de cache
export async function invalidateCache(pattern: string): Promise<void> {
  const redis = getRedis()
  const keys = await redis.keys(pattern)
  if (keys.length > 0) {
    await redis.del(...keys)
  }
}

// Invalidar cache de dashboard ao salvar relatório
await invalidateCache(`wolf:cache:dashboard:${orgId}:*`)
```

---

## Rate Limiting

```typescript
// middleware/rate-limit.ts

import { getRedis } from '../lib/redis'
import { RedisKeys } from '../lib/redis-keys'
import type { NextRequest } from 'next/server'

interface RateLimitOptions {
  limit: number    // requests permitidos
  window: number   // janela em segundos
}

export async function checkRateLimit(
  endpoint: string,
  userId: string,
  options: RateLimitOptions
): Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
  const redis = getRedis()
  const key = RedisKeys.rateLimit(endpoint, userId)
  const now = Date.now()

  // Sliding window com sorted set
  const windowStart = now - options.window * 1000

  await redis.zremrangebyscore(key, '-inf', windowStart)
  const count = await redis.zcard(key)

  if (count >= options.limit) {
    const oldestTimestamp = await redis.zrange(key, 0, 0, 'WITHSCORES')
    const resetAt = oldestTimestamp[1]
      ? parseInt(oldestTimestamp[1]) + options.window * 1000
      : now + options.window * 1000

    return { allowed: false, remaining: 0, resetAt }
  }

  await redis.zadd(key, now, `${now}-${Math.random()}`)
  await redis.expire(key, options.window)

  return {
    allowed: true,
    remaining: options.limit - count - 1,
    resetAt: now + options.window * 1000,
  }
}

// Uso no endpoint:
const { allowed, remaining } = await checkRateLimit(
  'meta-sync',
  userId,
  { limit: 10, window: 60 }  // 10 req/min
)

if (!allowed) {
  return Response.json(
    { error: 'Rate limit exceeded' },
    { status: 429, headers: { 'X-RateLimit-Remaining': '0' } }
  )
}
```

---

## BullMQ — Filas de Jobs

```typescript
// lib/queues.ts

import { Queue, Worker, QueueEvents } from 'bullmq'
import { createBullMQConnection } from './redis'

const connection = createBullMQConnection()

// Definição de filas
export const reportQueue = new Queue('reports', {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 500 },
  },
})

export const metaSyncQueue = new Queue('meta-sync', {
  connection,
  defaultJobOptions: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 5000 },
  },
})

// Worker
export const reportWorker = new Worker(
  'reports',
  async (job) => {
    const { reportId, organizationId, period } = job.data

    await job.updateProgress(10)
    const data = await fetchReportData(organizationId, period)

    await job.updateProgress(60)
    await generatePDF(reportId, data)

    await job.updateProgress(100)
    return { reportId, generatedAt: new Date().toISOString() }
  },
  {
    connection,
    concurrency: 3,  // processa 3 jobs simultâneos
  }
)

// Adicionar job à fila
await reportQueue.add(
  'generate-monthly',
  { reportId, organizationId, period: '2024-03' },
  { priority: 1 }  // 1 = alta prioridade
)
```

---

## Eviction Policies

| Policy              | Quando usar                                    |
|---------------------|------------------------------------------------|
| `allkeys-lru`       | Cache geral — remove o menos recente           |
| `volatile-lru`      | Mix cache + dados persistentes com TTL         |
| `noeviction`        | Filas BullMQ — NUNCA perder jobs               |
| `allkeys-lfu`       | Cache com acesso uniforme frequente            |

```bash
# Redis para cache (instância 1)
redis-cli CONFIG SET maxmemory-policy allkeys-lru
redis-cli CONFIG SET maxmemory 512mb

# Redis para BullMQ (instância 2 — separada)
redis-cli CONFIG SET maxmemory-policy noeviction
# SEM limite de memória para filas críticas
```

---

## Checklist Redis

- [ ] Keys seguem padrão `namespace:recurso:id`
- [ ] Keys centralizadas em `redis-keys.ts`
- [ ] TTL definido para todo cache (nenhuma key sem expiração exceto dados críticos)
- [ ] Conexão singleton com ioredis (sem múltiplas conexões desnecessárias)
- [ ] BullMQ usa conexão separada com `maxRetriesPerRequest: null`
- [ ] Rate limiting implementado nos endpoints críticos
- [ ] Eviction policy correta por instância (cache vs filas)
- [ ] Cache invalidado após mutations relevantes
- [ ] Monitoramento de memória Redis configurado (alerta em 80%)
