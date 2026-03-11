# queues.md — Forge Sub-Skill: Queues & Background Jobs
# Ativa quando: "fila", "queue", "job", "agendado", "background"

## Quando Usar Fila vs Síncrono

| Situação                                   | Fila | Síncrono |
|--------------------------------------------|------|----------|
| Envio de email/SMS/WhatsApp                | Sim  | Não      |
| Sync de dados de ads (Meta, Google)        | Sim  | Não      |
| Geração de relatório                       | Sim  | Não      |
| Processamento de imagem/vídeo              | Sim  | Não      |
| Operação > 2 segundos                      | Sim  | Não      |
| Resposta imediata ao usuário necessária    | Não  | Sim      |
| Operação < 500ms sem side effects externos | Não  | Sim      |
| Consulta de banco de dados simples         | Não  | Sim      |

**Regra Wolf:** se o usuário não precisa da resposta agora e a operação pode falhar e ser retentada, use fila.

## Setup BullMQ com Redis

```bash
npm install bullmq ioredis
```

```typescript
// src/lib/queue.ts
import { Queue, Worker, QueueEvents, Job } from 'bullmq'
import IORedis from 'ioredis'

export const redisConnection = new IORedis(process.env.REDIS_URL!, {
  maxRetriesPerRequest: null, // obrigatório para BullMQ
  enableReadyCheck: false,
})

// Configuração padrão Wolf para retry
export const defaultJobOptions = {
  attempts: 3,
  backoff: {
    type: 'exponential' as const,
    delay: 2000, // 2s, 4s, 8s
  },
  removeOnComplete: {
    age: 24 * 3600, // manter por 24h
    count: 1000,    // manter últimos 1000
  },
  removeOnFail: {
    age: 7 * 24 * 3600, // manter falhas por 7 dias
  },
}

// Factory de queue
export function createQueue(name: string) {
  return new Queue(name, {
    connection: redisConnection,
    defaultJobOptions,
  })
}

// Factory de worker
export function createWorker(
  name: string,
  processor: (job: Job) => Promise<any>,
  concurrency = 5
) {
  const worker = new Worker(name, processor, {
    connection: redisConnection,
    concurrency,
  })

  worker.on('completed', (job) => {
    console.info(`[QUEUE:${name}] Job ${job.id} completed`)
  })

  worker.on('failed', (job, err) => {
    console.error(`[QUEUE:${name}] Job ${job?.id} failed`, {
      error: err.message,
      attempts: job?.attemptsMade,
    })
  })

  return worker
}
```

## Estrutura de Job Handler

```typescript
// src/jobs/send-email.job.ts
import { Job } from 'bullmq'
import { createQueue, createWorker } from '../lib/queue'
import { EmailService } from '../services/email.service'
import { z } from 'zod'

// Schema de validação do payload
const SendEmailPayloadSchema = z.object({
  to: z.string().email(),
  subject: z.string(),
  template: z.enum(['welcome', 'campaign-report', 'alert']),
  data: z.record(z.any()),
  organizationId: z.string(),
})

type SendEmailPayload = z.infer<typeof SendEmailPayloadSchema>

// Queue
export const emailQueue = createQueue('email')

// Enfileirar job
export async function enqueueSendEmail(payload: SendEmailPayload) {
  const validated = SendEmailPayloadSchema.parse(payload)
  return emailQueue.add('send-email', validated, {
    // override de opções por job se necessário
    priority: payload.template === 'alert' ? 1 : 10,
  })
}

// Handler
async function sendEmailHandler(job: Job<SendEmailPayload>): Promise<void> {
  const payload = SendEmailPayloadSchema.parse(job.data)

  console.info(`[EMAIL_JOB] Processing`, {
    to: payload.to,
    template: payload.template,
    attempt: job.attemptsMade + 1,
  })

  await EmailService.send({
    to: payload.to,
    subject: payload.subject,
    template: payload.template,
    data: payload.data,
  })
}

// Worker
export const emailWorker = createWorker('email', sendEmailHandler, 10)
```

## Dead Letter Queue (DLQ)

```typescript
// src/jobs/dlq.ts
import { QueueEvents } from 'bullmq'
import { redisConnection, createQueue } from '../lib/queue'

// Fila de jobs que falharam todas as tentativas
export const deadLetterQueue = createQueue('dead-letter')

// Monitorar falhas definitivas e mover para DLQ
export function setupDeadLetterQueue(queueName: string): void {
  const queueEvents = new QueueEvents(queueName, { connection: redisConnection })

  queueEvents.on('failed', async ({ jobId, failedReason }) => {
    // Buscar job original
    const { Queue } = await import('bullmq')
    const originalQueue = new Queue(queueName, { connection: redisConnection })
    const job = await originalQueue.getJob(jobId)

    if (!job || job.attemptsMade < (job.opts.attempts ?? 3)) return

    // Mover para DLQ após esgotar tentativas
    await deadLetterQueue.add(`${queueName}:${job.name}`, {
      originalQueue: queueName,
      originalJobId: jobId,
      originalData: job.data,
      failedReason,
      failedAt: new Date().toISOString(),
    })

    console.error(`[DLQ] Job moved to dead letter queue`, {
      queue: queueName,
      jobId,
      reason: failedReason,
    })
  })
}

// Reprocessar um job da DLQ manualmente
export async function reprocessFromDLQ(dlqJobId: string): Promise<void> {
  const job = await deadLetterQueue.getJob(dlqJobId)
  if (!job) throw new Error('DLQ job not found')

  const { originalQueue, originalData } = job.data
  const targetQueue = createQueue(originalQueue)

  await targetQueue.add('retry-from-dlq', originalData)
  await job.remove()

  console.info(`[DLQ] Job requeued from DLQ`, { dlqJobId, targetQueue: originalQueue })
}
```

## Exemplo: Job de Sync de Dados de Ads

```typescript
// src/jobs/sync-meta-ads.job.ts
import { Job } from 'bullmq'
import { createQueue, createWorker } from '../lib/queue'
import { getAdAccountCampaigns, getCampaignInsights } from '../integrations/meta-ads'
import { db } from '../lib/db'
import { z } from 'zod'

const SyncMetaAdsPayloadSchema = z.object({
  organizationId: z.string(),
  adAccountId: z.string(),
  accessToken: z.string(),
  dateRange: z.object({
    since: z.string(),
    until: z.string(),
  }),
})

type SyncMetaAdsPayload = z.infer<typeof SyncMetaAdsPayloadSchema>

export const metaAdsSyncQueue = createQueue('meta-ads-sync')

export async function enqueueSyncMetaAds(payload: SyncMetaAdsPayload) {
  return metaAdsSyncQueue.add('sync', payload, {
    jobId: `sync-${payload.adAccountId}-${payload.dateRange.since}`, // deduplicação
  })
}

async function syncMetaAdsHandler(job: Job<SyncMetaAdsPayload>): Promise<void> {
  const { organizationId, adAccountId, accessToken, dateRange } = job.data

  // 1. Buscar campanhas
  await job.updateProgress(10)
  const campaigns = await getAdAccountCampaigns(accessToken, adAccountId)

  // 2. Buscar insights para cada campanha
  await job.updateProgress(30)
  const insights = await Promise.all(
    campaigns.map((campaign) =>
      getCampaignInsights(accessToken, campaign.id, dateRange)
    )
  )

  // 3. Upsert no banco
  await job.updateProgress(70)
  await db.$transaction(
    campaigns.map((campaign, i) =>
      db.campaignMetrics.upsert({
        where: {
          campaignId_date: {
            campaignId: campaign.id,
            date: dateRange.since,
          },
        },
        create: {
          campaignId: campaign.id,
          organizationId,
          date: dateRange.since,
          ...flattenInsights(insights[i]),
        },
        update: flattenInsights(insights[i]),
      })
    )
  )

  await job.updateProgress(100)
  console.info(`[META_SYNC] Synced ${campaigns.length} campaigns`, { adAccountId })
}

function flattenInsights(insights: any[]): Record<string, any> {
  const item = insights[0] ?? {}
  return {
    impressions: parseInt(item.impressions ?? '0'),
    clicks: parseInt(item.clicks ?? '0'),
    spend: parseFloat(item.spend ?? '0'),
    reach: parseInt(item.reach ?? '0'),
  }
}

export const metaAdsSyncWorker = createWorker('meta-ads-sync', syncMetaAdsHandler, 3)
```

## Jobs Agendados (Cron)

```typescript
// src/jobs/scheduler.ts
import { emailQueue, metaAdsSyncQueue } from './index'

// Sync de ads diariamente às 3h
export async function setupScheduledJobs(): Promise<void> {
  await metaAdsSyncQueue.add(
    'daily-sync',
    { type: 'all-accounts' },
    {
      repeat: {
        pattern: '0 3 * * *', // 3h todo dia
        tz: 'America/Sao_Paulo',
      },
    }
  )

  // Report semanal às segundas 8h
  await emailQueue.add(
    'weekly-report',
    { template: 'campaign-report', type: 'weekly' },
    {
      repeat: {
        pattern: '0 8 * * 1',
        tz: 'America/Sao_Paulo',
      },
    }
  )

  console.info('[SCHEDULER] Scheduled jobs configured')
}
```

## Inicialização de Workers

```typescript
// src/workers/index.ts — ponto de entrada do processo worker
import { emailWorker } from '../jobs/send-email.job'
import { metaAdsSyncWorker } from '../jobs/sync-meta-ads.job'
import { setupScheduledJobs } from '../jobs/scheduler'
import { setupDeadLetterQueue } from '../jobs/dlq'

async function main(): Promise<void> {
  console.info('[WORKERS] Starting worker process...')

  setupDeadLetterQueue('email')
  setupDeadLetterQueue('meta-ads-sync')
  await setupScheduledJobs()

  console.info('[WORKERS] Workers running:', {
    email: emailWorker.isRunning(),
    metaAdsSync: metaAdsSyncWorker.isRunning(),
  })
}

main().catch((err) => {
  console.error('[WORKERS] Fatal error:', err)
  process.exit(1)
})
```

## Checklist de Novo Job

- [ ] Schema Zod validando payload do job
- [ ] JobId único para evitar duplicatas quando necessário
- [ ] Número de tentativas e backoff configurados
- [ ] `job.updateProgress()` para jobs longos
- [ ] Logging de início, progresso e conclusão
- [ ] Dead letter queue monitorada
- [ ] Worker com concurrency adequada ao tipo de job
- [ ] Testes do handler com job mockado
- [ ] Separar processo worker do processo API (processos diferentes)
