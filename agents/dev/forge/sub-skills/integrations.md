# integrations.md — Forge Sub-Skill: Integrations
# Ativa quando: "integração", "webhook", "terceiros", "conectar"

## Padrão de Integração Wolf

Toda integração com serviço externo deve ter:
1. **Timeout** — nunca depender do timeout padrão
2. **Retry com backoff exponencial** — falhas transitórias são normais
3. **Circuit breaker** — parar de tentar quando o serviço está down
4. **Logging** — saber exatamente o que foi enviado e recebido

## Cliente de API Reutilizável

```typescript
// src/lib/api-client.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios'

interface ApiClientConfig {
  baseURL: string
  timeout?: number
  headers?: Record<string, string>
  maxRetries?: number
}

export class ApiClient {
  private client: AxiosInstance
  private maxRetries: number

  constructor(config: ApiClientConfig) {
    this.maxRetries = config.maxRetries ?? 3
    this.client = axios.create({
      baseURL: config.baseURL,
      timeout: config.timeout ?? 10_000,
      headers: {
        'Content-Type': 'application/json',
        ...config.headers,
      },
    })

    this.setupInterceptors()
  }

  private setupInterceptors(): void {
    this.client.interceptors.request.use((config) => {
      console.info('[API_CLIENT] Request', {
        method: config.method?.toUpperCase(),
        url: config.url,
        params: config.params,
      })
      return config
    })

    this.client.interceptors.response.use(
      (response) => {
        console.info('[API_CLIENT] Response', {
          status: response.status,
          url: response.config.url,
        })
        return response
      },
      (error) => {
        console.error('[API_CLIENT] Error', {
          status: error.response?.status,
          url: error.config?.url,
          message: error.message,
        })
        return Promise.reject(error)
      }
    )
  }

  async request<T>(config: AxiosRequestConfig, attempt = 1): Promise<T> {
    try {
      const response = await this.client.request<T>(config)
      return response.data
    } catch (error: any) {
      const isRetryable =
        !error.response || // timeout ou rede
        error.response.status === 429 || // rate limit
        error.response.status >= 500 // erro do servidor

      if (isRetryable && attempt < this.maxRetries) {
        const delay = Math.pow(2, attempt) * 1000 + Math.random() * 1000
        console.warn(`[API_CLIENT] Retrying in ${Math.round(delay)}ms (attempt ${attempt + 1}/${this.maxRetries})`)
        await sleep(delay)
        return this.request<T>(config, attempt + 1)
      }

      throw error
    }
  }

  async get<T>(url: string, params?: Record<string, any>): Promise<T> {
    return this.request<T>({ method: 'GET', url, params })
  }

  async post<T>(url: string, data?: any): Promise<T> {
    return this.request<T>({ method: 'POST', url, data })
  }

  async put<T>(url: string, data?: any): Promise<T> {
    return this.request<T>({ method: 'PUT', url, data })
  }

  async delete<T>(url: string): Promise<T> {
    return this.request<T>({ method: 'DELETE', url })
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
```

## Circuit Breaker Simples

```typescript
// src/lib/circuit-breaker.ts
type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN'

export class CircuitBreaker {
  private state: CircuitState = 'CLOSED'
  private failureCount = 0
  private lastFailureTime = 0

  constructor(
    private readonly threshold: number = 5,
    private readonly timeout: number = 60_000 // 60s
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN'
      } else {
        throw new Error('Circuit breaker is OPEN. Service unavailable.')
      }
    }

    try {
      const result = await fn()
      this.onSuccess()
      return result
    } catch (err) {
      this.onFailure()
      throw err
    }
  }

  private onSuccess(): void {
    this.failureCount = 0
    this.state = 'CLOSED'
  }

  private onFailure(): void {
    this.failureCount++
    this.lastFailureTime = Date.now()
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN'
      console.error('[CIRCUIT_BREAKER] Circuit opened after', this.failureCount, 'failures')
    }
  }
}
```

## Validação de Webhook com HMAC

```typescript
// src/middleware/verify-webhook.ts
import crypto from 'crypto'
import { Request, Response, NextFunction } from 'express'

export function verifyWebhookSignature(secret: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const signature = req.headers['x-hub-signature-256'] as string

    if (!signature) {
      res.status(401).json({ error: { code: 'MISSING_SIGNATURE', message: 'Webhook signature required.' } })
      return
    }

    // req.body deve ser o buffer raw — usar express.raw() antes deste middleware
    const expected = `sha256=${crypto
      .createHmac('sha256', secret)
      .update(req.body as Buffer)
      .digest('hex')}`

    const isValid = crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expected)
    )

    if (!isValid) {
      res.status(401).json({ error: { code: 'INVALID_SIGNATURE', message: 'Webhook signature mismatch.' } })
      return
    }

    next()
  }
}

// Uso:
app.post(
  '/webhooks/meta',
  express.raw({ type: 'application/json' }),
  verifyWebhookSignature(process.env.META_WEBHOOK_SECRET!),
  metaWebhookHandler
)
```

## Rate Limiting de APIs Externas

```typescript
// src/lib/rate-limiter.ts
export class RateLimiter {
  private queue: Array<() => void> = []
  private running = 0

  constructor(
    private readonly maxConcurrent: number,
    private readonly minDelayMs: number = 0
  ) {}

  async schedule<T>(fn: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await fn()
          resolve(result)
        } catch (err) {
          reject(err)
        } finally {
          this.running--
          if (this.minDelayMs > 0) await sleep(this.minDelayMs)
          this.next()
        }
      })
      this.next()
    })
  }

  private next(): void {
    if (this.running >= this.maxConcurrent || this.queue.length === 0) return
    this.running++
    const task = this.queue.shift()!
    task()
  }
}

// 10 requests simultâneos, 100ms entre cada
const metaRateLimiter = new RateLimiter(10, 100)
```

## Exemplo: Evolution API (WhatsApp)

```typescript
// src/integrations/evolution-api.ts
import { ApiClient } from '../lib/api-client'
import { CircuitBreaker } from '../lib/circuit-breaker'

const evolutionClient = new ApiClient({
  baseURL: process.env.EVOLUTION_API_URL!,
  timeout: 15_000,
  headers: {
    apikey: process.env.EVOLUTION_API_KEY!,
  },
  maxRetries: 3,
})

const circuitBreaker = new CircuitBreaker(5, 30_000)

interface SendMessagePayload {
  number: string
  text: string
}

export async function sendWhatsAppMessage(instance: string, payload: SendMessagePayload): Promise<void> {
  await circuitBreaker.call(() =>
    evolutionClient.post(`/message/sendText/${instance}`, {
      number: payload.number,
      text: payload.text,
      delay: 1200,
    })
  )
}

export async function createInstance(instanceName: string): Promise<{ instanceName: string; apikey: string }> {
  return evolutionClient.post('/instance/create', {
    instanceName,
    integration: 'WHATSAPP-BAILEYS',
    qrcode: true,
  })
}
```

## Exemplo: Meta Ads API

```typescript
// src/integrations/meta-ads.ts
import { ApiClient } from '../lib/api-client'
import { RateLimiter } from '../lib/rate-limiter'

const metaClient = new ApiClient({
  baseURL: 'https://graph.facebook.com/v21.0',
  timeout: 20_000,
  maxRetries: 3,
})

// Meta Ads tem limite de ~200 req/hora por token
const rateLimiter = new RateLimiter(5, 200)

interface CampaignInsights {
  impressions: string
  clicks: string
  spend: string
  reach: string
}

export async function getCampaignInsights(
  accessToken: string,
  campaignId: string,
  dateRange: { since: string; until: string }
): Promise<CampaignInsights[]> {
  return rateLimiter.schedule(() =>
    metaClient.get(`/${campaignId}/insights`, {
      access_token: accessToken,
      fields: 'impressions,clicks,spend,reach',
      time_range: JSON.stringify(dateRange),
    })
  )
}

export async function getAdAccountCampaigns(
  accessToken: string,
  adAccountId: string
): Promise<any[]> {
  return rateLimiter.schedule(() =>
    metaClient.get(`/act_${adAccountId}/campaigns`, {
      access_token: accessToken,
      fields: 'id,name,status,objective,budget_remaining',
      limit: 100,
    })
  )
}
```

## Checklist de Nova Integração

- [ ] Timeout configurado (nunca confiar no padrão)
- [ ] Retry com backoff exponencial + jitter
- [ ] Circuit breaker para serviços críticos
- [ ] Rate limiter respeitando limites da API externa
- [ ] Validação de webhook com HMAC se aplicável
- [ ] Credenciais em variáveis de ambiente (nunca no código)
- [ ] Logging de requests/responses (sem dados sensíveis)
- [ ] Tratamento de erros específicos da API externa
- [ ] Testes com mock do serviço externo (MSW ou jest.mock)
- [ ] Documentação dos endpoints externos utilizados
