# resilience.md — Bridge Sub-Skill: Resiliência de Integrações
# Ativa quando: "retry", "fallback", "circuit breaker", "resiliência"

## Propósito

Integrações externas falham. APIs ficam lentas, retornam 500, têm rate limit. Código que não lida com isso quebra em produção de forma silenciosa ou catastrófica. Resiliência não é opcional nas integrações Wolf.

---

## Retry com Exponential Backoff

```typescript
interface RetryOptions {
  maxAttempts?: number;        // Default: 3
  initialDelayMs?: number;     // Default: 1000ms
  maxDelayMs?: number;         // Default: 30000ms (30s)
  multiplier?: number;         // Default: 2
  jitter?: boolean;            // Default: true (evita thundering herd)
  retryOn?: (error: any) => boolean; // Quais erros fazem retry
}

async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const {
    maxAttempts = 3,
    initialDelayMs = 1000,
    maxDelayMs = 30000,
    multiplier = 2,
    jitter = true,
    retryOn = isRetryableError,
  } = options;

  let lastError: Error;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (attempt === maxAttempts || !retryOn(error)) {
        throw error;
      }

      const baseDelay = Math.min(
        initialDelayMs * Math.pow(multiplier, attempt - 1),
        maxDelayMs,
      );
      const delay = jitter
        ? baseDelay * (0.5 + Math.random() * 0.5) // 50-100% do delay base
        : baseDelay;

      logger.warn(
        { attempt, maxAttempts, delayMs: Math.round(delay), error: error.message },
        'Retry attempt'
      );

      await sleep(delay);
    }
  }

  throw lastError!;
}

// Erros que fazem sentido retentar
function isRetryableError(error: any): boolean {
  const status = error?.response?.status;
  if (status) {
    return [429, 500, 502, 503, 504].includes(status);
  }
  // Network errors
  return ['ECONNRESET', 'ETIMEDOUT', 'ECONNREFUSED'].includes(error.code);
}
```

**Uso:**

```typescript
const insights = await withRetry(
  () => metaAdsClient.getCampaignInsights(accountId, dateRange),
  { maxAttempts: 3, initialDelayMs: 2000, retryOn: (err) => err?.response?.status !== 401 }
);
```

---

## Circuit Breaker

Previne chamadas repetidas a um serviço que está claramente falhando. Após X falhas consecutivas, "abre" o circuito e rejeita chamadas imediatamente (sem tentar) por um período. Protege tanto o serviço externo quanto o próprio sistema.

```typescript
type CircuitState = 'closed' | 'open' | 'half-open';

interface CircuitBreakerOptions {
  failureThreshold?: number;   // Falhas para abrir: default 5
  successThreshold?: number;   // Sucessos para fechar (half-open): default 2
  timeoutMs?: number;          // Tempo aberto antes de tentar: default 60000ms
}

class CircuitBreaker {
  private state: CircuitState = 'closed';
  private failureCount = 0;
  private successCount = 0;
  private lastFailureTime?: number;

  constructor(
    private readonly name: string,
    private readonly options: CircuitBreakerOptions = {},
  ) {}

  private get failureThreshold() { return this.options.failureThreshold ?? 5; }
  private get successThreshold() { return this.options.successThreshold ?? 2; }
  private get timeoutMs() { return this.options.timeoutMs ?? 60000; }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      const timeSinceFailure = Date.now() - (this.lastFailureTime ?? 0);

      if (timeSinceFailure < this.timeoutMs) {
        throw new CircuitOpenError(
          `Circuit '${this.name}' está aberto. Tente em ${Math.round((this.timeoutMs - timeSinceFailure) / 1000)}s`
        );
      }
      // Timeout passou: tenta half-open
      this.state = 'half-open';
      logger.info({ circuit: this.name }, 'Circuit movendo para half-open');
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess() {
    this.failureCount = 0;
    if (this.state === 'half-open') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = 'closed';
        this.successCount = 0;
        logger.info({ circuit: this.name }, 'Circuit fechado — serviço recuperado');
      }
    }
  }

  private onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.state === 'half-open' || this.failureCount >= this.failureThreshold) {
      this.state = 'open';
      this.successCount = 0;
      logger.error(
        { circuit: this.name, failureCount: this.failureCount },
        'Circuit aberto — muitas falhas consecutivas'
      );
    }
  }

  getState() { return this.state; }
}

// Instâncias por integração (singletons)
export const metaAdsCircuit = new CircuitBreaker('meta-ads', { failureThreshold: 5, timeoutMs: 60000 });
export const evolutionCircuit = new CircuitBreaker('evolution-api', { failureThreshold: 3, timeoutMs: 30000 });
export const googleAdsCircuit = new CircuitBreaker('google-ads', { failureThreshold: 5, timeoutMs: 120000 });
```

**Uso combinado com retry:**

```typescript
const data = await metaAdsCircuit.execute(
  () => withRetry(() => metaAdsClient.getInsights(accountId), { maxAttempts: 2 })
);
```

---

## Timeout em Chamadas Externas

```typescript
// Nunca espera indefinidamente
const TIMEOUTS = {
  metaAds: 30000,       // 30s
  googleAds: 45000,     // 45s (relatórios grandes)
  evolution: 10000,     // 10s (mensagens devem ser rápidas)
  clickup: 10000,       // 10s
  default: 15000,       // 15s
};

// Axios com timeout configurado
const metaClient = axios.create({
  baseURL: 'https://graph.facebook.com/v19.0',
  timeout: TIMEOUTS.metaAds,
});

// Fetch com AbortController
async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs: number) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}
```

---

## Fallback Gracioso

```typescript
// O que mostrar quando API externa cai
async function getCampaignInsightsWithFallback(
  accountId: string,
  dateRange: DateRange,
): Promise<CampaignInsights[]> {
  try {
    return await metaAdsCircuit.execute(
      () => withRetry(() => metaAdsClient.getInsights(accountId, dateRange))
    );
  } catch (error) {
    logger.error({ accountId, error }, 'Meta Ads indisponível, usando cache stale');

    // Fallback 1: Cache stale (mesmo expirado é melhor que nada)
    const staleCache = await redis.get(`insights:${accountId}:${dateRange.since}:${dateRange.until}`);
    if (staleCache) {
      return { ...JSON.parse(staleCache), _stale: true };
    }

    // Fallback 2: Dados do dia anterior
    const yesterday = shiftDateRange(dateRange, -1);
    const cached = await redis.get(`insights:${accountId}:${yesterday.since}:${yesterday.until}`);
    if (cached) {
      return { ...JSON.parse(cached), _fallback: true, _note: 'Dados do dia anterior (API indisponível)' };
    }

    // Fallback 3: Retorna estrutura vazia com flag de erro
    return {
      data: [],
      _error: true,
      _message: 'Dados temporariamente indisponíveis',
    } as any;
  }
}
```

---

## Health Check de Integrações

```typescript
interface IntegrationHealth {
  name: string;
  status: 'healthy' | 'degraded' | 'down';
  latencyMs?: number;
  lastCheck: string;
  circuit?: CircuitState;
  error?: string;
}

async function checkIntegrationsHealth(): Promise<IntegrationHealth[]> {
  const checks = [
    {
      name: 'meta-ads',
      circuit: metaAdsCircuit,
      probe: () => metaAdsClient.getAdAccounts({ limit: 1 }),
    },
    {
      name: 'evolution-api',
      circuit: evolutionCircuit,
      probe: () => evolutionClient.get('/instance/fetchInstances'),
    },
    {
      name: 'google-ads',
      circuit: googleAdsCircuit,
      probe: () => googleAdsClient.ping(),
    },
  ];

  return Promise.all(
    checks.map(async ({ name, circuit, probe }) => {
      const start = Date.now();
      try {
        await Promise.race([
          probe(),
          sleep(5000).then(() => { throw new Error('Health check timeout'); }),
        ]);
        return {
          name,
          status: 'healthy' as const,
          latencyMs: Date.now() - start,
          lastCheck: new Date().toISOString(),
          circuit: circuit.getState(),
        };
      } catch (error) {
        return {
          name,
          status: circuit.getState() === 'open' ? 'down' : 'degraded' as const,
          latencyMs: Date.now() - start,
          lastCheck: new Date().toISOString(),
          circuit: circuit.getState(),
          error: error.message,
        };
      }
    })
  );
}

// Endpoint de health integrations
app.get('/health/integrations', async (req, res) => {
  const health = await checkIntegrationsHealth();
  const hasDown = health.some(h => h.status === 'down');
  res.status(hasDown ? 503 : 200).json(health);
});
```

---

## Checklist de Resiliência

- [ ] Retry com exponential backoff + jitter em todas as integrações externas
- [ ] Circuit breaker por integração (instâncias separadas)
- [ ] Timeout configurado em todas as chamadas HTTP (nunca indefinido)
- [ ] Fallback definido: o que mostrar quando a integração cai?
- [ ] Fallback usa cache stale quando disponível
- [ ] Health check endpoint para todas as integrações
- [ ] Logs com nível ERROR para circuit aberto
- [ ] Alertas quando circuit fica aberto por > 5 minutos
- [ ] isRetryableError distingue erros de cliente (4xx) de servidor (5xx)
- [ ] Jitter ativado para evitar thundering herd em falhas simultâneas
