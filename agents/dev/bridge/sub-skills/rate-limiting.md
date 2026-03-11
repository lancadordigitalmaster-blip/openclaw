# rate-limiting.md — Bridge Sub-Skill: Rate Limiting de APIs
# Ativa quando: "rate limit", "throttle", "quota", "limite de API"

## Propósito

APIs externas têm limites de chamadas. Estourar o limite significa horas sem dados, bloqueio de conta ou custo extra. Bridge monitora, distribui e respeita limites proativamente — não reativamente.

---

## Rate Limits das APIs Wolf

### Meta Ads Graph API

| Limite | Valor | Janela | Header de Monitoramento |
|--------|-------|--------|------------------------|
| App-level calls | 200 calls/hora/user | Rolling 1h | `X-App-Usage` |
| Business-level | Varia por tier | Rolling 1h | `X-Business-Use-Case-Usage` |
| Ad Account | Varia (baseado em gasto) | Rolling 24h | `X-Ad-Account-Usage` |

```typescript
// Parsear headers de uso Meta
function parseMetaRateLimitHeaders(headers: Record<string, string>) {
  const appUsage = JSON.parse(headers['x-app-usage'] || '{}');
  const businessUsage = JSON.parse(headers['x-business-use-case-usage'] || '{}');

  return {
    app: {
      callCount: appUsage.call_count || 0,      // % usada
      cpuTime: appUsage.total_cputime || 0,
      totalTime: appUsage.total_time || 0,
    },
    isApproachingLimit: (appUsage.call_count || 0) > 80,
    isAtLimit: (appUsage.call_count || 0) >= 100,
  };
}
```

### Google Ads API

| Limite | Valor | Janela |
|--------|-------|--------|
| Operações básicas | 15.000/dia | Daily |
| Relatórios | 1.000/dia | Daily |
| Batch operations | 5.000/op | Por operação |
| Requests simultâneas | 10 | Concorrentes |

### Evolution API (self-hosted)

Sem limite de API em si — o limite é o WhatsApp:
- Envio de mensagens para não-contatos: ~80 msg/dia antes de risco de ban
- Novos números: limite menor (construir reputação gradualmente)
- Mensagens para contatos: sem limite prático

### ClickUp API

| Plano | Limite |
|-------|--------|
| Free | 100 requests/min |
| Unlimited | 100 requests/min |
| Business+ | 100 requests/min |

---

## Monitoramento de Uso

```typescript
class RateLimitMonitor {
  private usage: Map<string, { count: number; windowStart: number; limit: number }> = new Map();

  track(service: string, currentUsagePercent: number, limit: number) {
    this.usage.set(service, {
      count: currentUsagePercent,
      windowStart: Date.now(),
      limit,
    });

    if (currentUsagePercent >= 90) {
      this.triggerAlert(service, currentUsagePercent, 'critical');
    } else if (currentUsagePercent >= 80) {
      this.triggerAlert(service, currentUsagePercent, 'warning');
    }
  }

  private async triggerAlert(service: string, usage: number, severity: string) {
    logger.warn({ service, usage, severity }, `Rate limit ${severity}`);

    await alertsQueue.add('rate-limit-alert', {
      service,
      usagePercent: usage,
      severity,
      timestamp: new Date().toISOString(),
    });
  }

  getUsage(service: string) {
    return this.usage.get(service);
  }
}

export const rateLimitMonitor = new RateLimitMonitor();

// Interceptor Axios para Meta Ads
metaClient.interceptors.response.use((response) => {
  const limits = parseMetaRateLimitHeaders(response.headers);
  rateLimitMonitor.track('meta-ads', limits.app.callCount, 100);
  return response;
});
```

---

## Estratégias de Distribuição de Chamadas

### Token Bucket (para distribuição uniforme)

```typescript
class TokenBucket {
  private tokens: number;
  private lastRefill: number;

  constructor(
    private readonly capacity: number,    // máximo de tokens
    private readonly refillRate: number,  // tokens por segundo
  ) {
    this.tokens = capacity;
    this.lastRefill = Date.now();
  }

  async acquire(count = 1): Promise<void> {
    this.refill();

    if (this.tokens >= count) {
      this.tokens -= count;
      return;
    }

    // Esperar tokens suficientes
    const waitMs = ((count - this.tokens) / this.refillRate) * 1000;
    await sleep(waitMs);
    this.tokens -= count;
  }

  private refill() {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    this.tokens = Math.min(this.capacity, this.tokens + elapsed * this.refillRate);
    this.lastRefill = now;
  }
}

// Meta Ads: ~200 calls/hora = ~3.3/min = 0.055/segundo
const metaAdsBucket = new TokenBucket(200, 200 / 3600);

// Uso
await metaAdsBucket.acquire();
const insights = await metaAdsClient.getInsights(accountId, dateRange);
```

### Queue com Concorrência Limitada

```typescript
import PQueue from 'p-queue';

// Google Ads: máximo 10 requests simultâneos
const googleAdsQueue = new PQueue({
  concurrency: 10,
  interval: 1000,
  intervalCap: 5, // máximo 5 por segundo
});

// Meta Ads: 1 request a cada 200ms para distribuir
const metaAdsQueue = new PQueue({
  concurrency: 3,
  interval: 1000,
  intervalCap: 10,
});

// Todas as chamadas Meta passam pela fila
async function queuedMetaRequest<T>(fn: () => Promise<T>): Promise<T> {
  return metaAdsQueue.add(fn) as Promise<T>;
}
```

---

## Cache para Evitar Chamadas Repetidas

```typescript
class CachedApiClient {
  constructor(private redis: Redis, private ttlSeconds: number) {}

  async get<T>(
    cacheKey: string,
    fetcher: () => Promise<T>,
    options: { ttl?: number; forceRefresh?: boolean } = {},
  ): Promise<T & { _fromCache?: boolean }> {
    const { ttl = this.ttlSeconds, forceRefresh = false } = options;

    if (!forceRefresh) {
      const cached = await this.redis.get(cacheKey);
      if (cached) {
        return { ...JSON.parse(cached), _fromCache: true };
      }
    }

    const data = await fetcher();
    await this.redis.setex(cacheKey, ttl, JSON.stringify(data));
    return data;
  }
}

const apiCache = new CachedApiClient(redis, 3600);

// Insights: cache de 1h (dados não mudam minuto a minuto)
const insights = await apiCache.get(
  `insights:meta:${accountId}:${dateFrom}:${dateTo}`,
  () => metaAdsClient.getInsights(accountId, { since: dateFrom, until: dateTo }),
  { ttl: 3600 },
);

// Campanhas: cache de 5 min (lista muda menos)
const campaigns = await apiCache.get(
  `campaigns:meta:${accountId}`,
  () => metaAdsClient.getCampaigns(accountId),
  { ttl: 300 },
);
```

---

## O que Fazer Quando 429

```typescript
async function handleRateLimitError(error: any, retryAfterMs?: number): Promise<void> {
  const waitMs = retryAfterMs
    ?? parseInt(error.response?.headers?.['retry-after'] || '60') * 1000;

  logger.warn({ waitMs, service: error.config?.baseURL }, 'Rate limit atingido — aguardando');

  // Alertar se espera longa
  if (waitMs > 60000) {
    await alertsQueue.add('rate-limit-long-wait', {
      service: error.config?.baseURL,
      waitSeconds: waitMs / 1000,
    });
  }

  await sleep(waitMs);
}

// Integrado no interceptor
metaClient.interceptors.response.use(
  null,
  async (error) => {
    if (error.response?.status === 429) {
      await handleRateLimitError(error);
      // Retry automático
      return metaClient.request(error.config);
    }
    throw error;
  }
);
```

---

## Alertas Proativos

```typescript
// Cron a cada 15 minutos: verificar usage
async function checkRateLimitUsage() {
  // Meta Ads: fazer uma chamada leve para obter headers atuais
  const response = await metaAdsClient.head('/me?fields=id');
  const limits = parseMetaRateLimitHeaders(response.headers);

  if (limits.app.callCount > 80) {
    await sendAlert({
      channel: '#eng-alerts',
      message: `Meta Ads API: ${limits.app.callCount}% da quota usada. Reduzindo frequência de sync.`,
      severity: limits.app.callCount > 90 ? 'critical' : 'warning',
    });

    // Aumentar TTL do cache automaticamente
    if (limits.app.callCount > 90) {
      await redis.set('meta-ads:cache-ttl-override', '7200'); // 2h
    }
  }
}
```

---

## Checklist de Rate Limiting

- [ ] Rate limits de cada API mapeados e documentados
- [ ] Headers de uso parseados e rastreados
- [ ] Token bucket ou queue com concorrência para distribuir chamadas
- [ ] Cache implementado com TTL adequado por endpoint
- [ ] Retry automático em 429 com respeito ao Retry-After
- [ ] Alertas quando > 80% da quota usada
- [ ] Escalonamento automático de TTL quando próximo ao limite
- [ ] Monitoramento de quota no dashboard de saúde (Grafana)
- [ ] TTL de cache diferenciado por volatilidade dos dados (insights vs campanhas)
- [ ] Fila p-queue para Google Ads (máximo 10 concorrentes)
