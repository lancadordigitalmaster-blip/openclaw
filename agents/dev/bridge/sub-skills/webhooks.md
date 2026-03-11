# webhooks.md — Bridge Sub-Skill: Webhooks
# Ativa quando: "webhook", "receber evento", "callback", "validar payload"

## Propósito

Webhooks recebem eventos de sistemas externos (Meta, Stripe, GitHub, Evolution). Processamento incorreto = dados corrompidos, ataques de replay, duplicatas silenciosas. Validar sempre antes de processar.

---

## Validação com HMAC — Padrão para Todos os Providers

### Meta Webhooks

```typescript
import { createHmac, timingSafeEqual } from 'crypto';

function validateMetaWebhook(
  rawBody: Buffer,
  signature: string, // Header: X-Hub-Signature-256
  appSecret: string,
): boolean {
  const expectedSignature = 'sha256=' + createHmac('sha256', appSecret)
    .update(rawBody)
    .digest('hex');

  // timingSafeEqual previne timing attacks
  return timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature),
  );
}
```

### Stripe Webhooks

```typescript
import Stripe from 'stripe';

function validateStripeWebhook(
  rawBody: Buffer,
  signature: string, // Header: Stripe-Signature
  webhookSecret: string,
): Stripe.Event {
  // Stripe SDK já valida HMAC E timestamp internamente
  return stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
}
```

### GitHub Webhooks

```typescript
function validateGitHubWebhook(
  rawBody: Buffer,
  signature: string, // Header: X-Hub-Signature-256
  secret: string,
): boolean {
  const expected = 'sha256=' + createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');
  return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}
```

---

## Verificação de Timestamp (Previne Replay Attacks)

```typescript
const WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS = 300; // 5 minutos

function validateTimestamp(timestampHeader: string): void {
  const timestamp = parseInt(timestampHeader, 10);
  const now = Math.floor(Date.now() / 1000);
  const diff = Math.abs(now - timestamp);

  if (diff > WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS) {
    throw new WebhookReplayError(
      `Timestamp fora da janela: ${diff}s atrás (máximo: ${WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS}s)`
    );
  }
}

// Stripe inclui timestamp na própria assinatura — validado automaticamente pelo SDK
// Meta: usar timestamp do campo "time" no body
// Evolution: usar header X-Timestamp
```

---

## Idempotência — Tratamento de Duplicatas

Providers reenviam webhooks quando não recebem confirmação (HTTP 200). O handler precisa ser idempotente: processar o mesmo evento duas vezes = mesmo resultado que processar uma vez.

```typescript
async function handleWebhookWithIdempotency(
  eventId: string,
  eventType: string,
  payload: unknown,
): Promise<void> {
  // Verificar se já processado
  const alreadyProcessed = await redis.set(
    `webhook:processed:${eventId}`,
    '1',
    'EX', 86400,  // TTL de 24h
    'NX',         // Só seta se não existe
  );

  if (!alreadyProcessed) {
    logger.info({ eventId, eventType }, 'Webhook duplicado ignorado');
    return;
  }

  // Processar normalmente
  await processWebhookEvent(eventType, payload);
}
```

---

## Queue de Processamento — Nunca Processa na Hora

```typescript
// Handler do webhook: valida, confirma recebimento, enfileira
app.post('/webhooks/meta', rawBodyMiddleware, async (req, res) => {
  // 1. Validar assinatura PRIMEIRO (antes de qualquer processamento)
  const isValid = validateMetaWebhook(
    req.rawBody,
    req.headers['x-hub-signature-256'] as string,
    process.env.META_APP_SECRET,
  );
  if (!isValid) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  // 2. Confirmar recebimento IMEDIATAMENTE (< 5 segundos para Meta)
  res.status(200).json({ received: true });

  // 3. Enfileirar para processamento assíncrono
  const events = req.body.entry.flatMap(entry => entry.changes);
  for (const event of events) {
    await webhookQueue.add('meta-event', {
      eventId: event.id ?? generateEventId(event),
      eventType: event.field,
      payload: event.value,
      receivedAt: Date.now(),
    });
  }
});

// Worker processa da fila (separado do handler HTTP)
webhookQueue.process('meta-event', async (job) => {
  const { eventId, eventType, payload } = job.data;
  await handleWebhookWithIdempotency(eventId, eventType, payload);
});
```

---

## Middleware para Capturar rawBody

Necessário para validação HMAC (precisa do body cru, antes de parse JSON):

```typescript
// Express: capturar rawBody antes do JSON parse
app.use('/webhooks', express.raw({
  type: 'application/json',
  verify: (req: any, res, buf) => {
    req.rawBody = buf;
  },
}));

// Fastify
fastify.addContentTypeParser(
  'application/json',
  { parseAs: 'buffer' },
  (req, body, done) => {
    (req as any).rawBody = body;
    done(null, JSON.parse(body.toString()));
  }
);
```

---

## Handler de Webhook Wolf Completo

```typescript
// src/api/webhooks/meta.webhook.ts
import { Router } from 'express';
import { webhookQueue } from '../../lib/queues';
import { validateMetaWebhook } from '../../lib/meta-auth';
import { logger } from '../../lib/logger';

const router = Router();

// Verificação inicial do webhook (GET — Meta envia para verificar endpoint)
router.get('/meta', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === process.env.META_WEBHOOK_VERIFY_TOKEN) {
    return res.status(200).send(challenge);
  }
  res.status(403).json({ error: 'Forbidden' });
});

// Recebimento de eventos (POST)
router.post('/meta', express.raw({ type: 'application/json' }), async (req, res) => {
  const signature = req.headers['x-hub-signature-256'] as string;

  if (!signature) {
    return res.status(401).json({ error: 'Missing signature' });
  }

  const isValid = validateMetaWebhook(req.body, signature, process.env.META_APP_SECRET);
  if (!isValid) {
    logger.warn({ signature }, 'Invalid Meta webhook signature');
    return res.status(401).json({ error: 'Invalid signature' });
  }

  // Confirmar antes de processar
  res.status(200).json({ received: true });

  try {
    const body = JSON.parse(req.body.toString());
    const events = body.entry?.flatMap(e => e.changes) ?? [];

    for (const event of events) {
      await webhookQueue.add('meta-webhook', {
        eventId: `meta-${event.uid ?? Date.now()}`,
        eventType: event.field,
        payload: event.value,
      }, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      });
    }
  } catch (err) {
    logger.error({ err }, 'Erro ao enfileirar webhook Meta');
    // Não rejeitar — já confirmamos 200. Log e monitora.
  }
});
```

---

## Retry do Provider — O que Esperar

| Provider | Retry após falha | Janela total |
|----------|-----------------|--------------|
| Meta | 1min, 2min, 4min, 8min... | 72 horas |
| Stripe | 1h, 3h, 6h, 12h, 24h... | 3 dias |
| GitHub | Sem retry automático | — |
| Evolution | Configurável no setup | Configurável |

---

## Checklist de Webhook

- [ ] Validação HMAC antes de qualquer processamento
- [ ] timingSafeEqual usado na comparação de assinaturas
- [ ] Verificação de timestamp (previne replay)
- [ ] Resposta HTTP 200 imediata (< 5 segundos)
- [ ] Processamento assíncrono via fila (BullMQ, Redis)
- [ ] Idempotência implementada com Redis NX + TTL
- [ ] rawBody capturado antes do JSON parse
- [ ] Endpoint de verificação GET implementado (Meta)
- [ ] Logs com eventId para rastreamento
- [ ] Monitoramento de dead-letter queue
- [ ] WEBHOOK_SECRET em variável de ambiente (nunca hardcoded)
