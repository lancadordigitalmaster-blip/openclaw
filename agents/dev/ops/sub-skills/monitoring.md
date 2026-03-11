# monitoring.md — Ops Sub-Skill: Monitoring & Observability
# Ativa quando: "monitoramento", "uptime", "logs", "alertas"

## Stack de Monitoramento Wolf

| Ferramenta     | Função                                    | Self-hosted | Custo     |
|----------------|-------------------------------------------|-------------|-----------|
| Uptime Kuma    | Uptime de URLs, ping, SSL                 | Sim         | Grátis    |
| Betterstack    | Uptime + on-call + incident management    | Não         | Freemium  |
| Grafana + Loki | Logs centralizados + dashboards           | Sim         | Grátis    |
| Prometheus     | Métricas de sistema/aplicação             | Sim         | Grátis    |
| Telegram Bot   | Alertas em tempo real                     | -           | Grátis    |

**Setup mínimo Wolf:** Uptime Kuma + logs estruturados no stdout + alertas no Telegram.

## Uptime Kuma — Setup

```yaml
# docker-compose.monitoring.yml
version: "3.9"

services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    restart: unless-stopped
    volumes:
      - uptime_data:/app/data
    ports:
      - "127.0.0.1:3001:3001"
    labels:
      - "com.wolfagency.service=monitoring"

volumes:
  uptime_data:
```

```bash
docker compose -f docker-compose.monitoring.yml up -d
# Acessar: http://server-ip:3001 (via SSH tunnel ou configurar Nginx proxy)
```

**Monitors a configurar no Uptime Kuma:**
- API health: `https://api.wolfapp.com/health` (HTTP, interval: 60s)
- Frontend: `https://app.wolfapp.com` (HTTP, interval: 60s)
- Banco de dados: TCP na porta 5432 (interval: 60s)
- Redis: TCP na porta 6379 (interval: 60s)
- SSL: Certificado (alerta 14 dias antes de expirar)

## Logs Estruturados — Configuração Docker

```yaml
# Em docker-compose.prod.yml, para cada serviço:
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "5"
    labels: "service,env"
```

## Endpoint /health Padrão

```typescript
// src/routes/health.ts
import { Router } from 'express'
import { db } from '../lib/db'
import { redisConnection } from '../lib/queue'

const router = Router()

router.get('/health', async (req, res) => {
  const startTime = Date.now()
  const checks: Record<string, { status: 'ok' | 'error'; latency?: number }> = {}

  // Check banco de dados
  try {
    const dbStart = Date.now()
    await db.$queryRaw`SELECT 1`
    checks.database = { status: 'ok', latency: Date.now() - dbStart }
  } catch {
    checks.database = { status: 'error' }
  }

  // Check Redis
  try {
    const redisStart = Date.now()
    await redisConnection.ping()
    checks.redis = { status: 'ok', latency: Date.now() - redisStart }
  } catch {
    checks.redis = { status: 'error' }
  }

  const allOk = Object.values(checks).every((c) => c.status === 'ok')
  const statusCode = allOk ? 200 : 503

  res.status(statusCode).json({
    status: allOk ? 'ok' : 'degraded',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version,
    checks,
    responseTime: Date.now() - startTime,
  })
})

export default router
```

## Alertas no Telegram

```typescript
// src/lib/alerts.ts
interface TelegramAlert {
  message: string
  level: 'info' | 'warning' | 'critical'
}

const LEVEL_EMOJI = {
  info: 'ℹ️',
  warning: '⚠️',
  critical: '🚨',
}

export async function sendTelegramAlert(alert: TelegramAlert): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN
  const chatId = process.env.TELEGRAM_ALERT_CHAT_ID

  if (!token || !chatId) {
    console.warn('[ALERTS] Telegram not configured, skipping alert')
    return
  }

  const text = `${LEVEL_EMOJI[alert.level]} *[${alert.level.toUpperCase()}]*\n${alert.message}\n_${new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}_`

  try {
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: 'Markdown',
      }),
    })
  } catch (err) {
    console.error('[ALERTS] Failed to send Telegram alert', err)
  }
}

// Uso no error handler para erros críticos:
// if (err.statusCode >= 500) {
//   sendTelegramAlert({ message: `Server error: ${err.message}`, level: 'critical' })
// }
```

**Criar bot Telegram:**
1. Falar com @BotFather no Telegram → `/newbot`
2. Pegar o token
3. Adicionar bot ao grupo/canal de alertas
4. Pegar chat ID via `https://api.telegram.org/bot{TOKEN}/getUpdates`

## Logs Estruturados com Contexto

```typescript
// src/middleware/request-logger.ts
import { Request, Response, NextFunction } from 'express'

export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const startTime = Date.now()

  res.on('finish', () => {
    const duration = Date.now() - startTime
    const log = {
      level: res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info',
      message: 'HTTP Request',
      timestamp: new Date().toISOString(),
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration,
      userId: req.user?.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    }

    // Logar erros e requests lentos com mais visibilidade
    if (res.statusCode >= 500 || duration > 2000) {
      process.stderr.write(JSON.stringify(log) + '\n')
    } else {
      process.stdout.write(JSON.stringify(log) + '\n')
    }
  })

  next()
}
```

## Grafana + Loki (Stack Avançada)

```yaml
# docker-compose.monitoring-full.yml
version: "3.9"

services:
  loki:
    image: grafana/loki:latest
    restart: unless-stopped
    volumes:
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:latest
    restart: unless-stopped
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/config.yml

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  loki_data:
  grafana_data:
```

**Configuração Promtail para coletar logs Docker:**
```yaml
# /etc/promtail/config.yml
server:
  http_listen_port: 9080

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_label_com_wolfagency_service']
        target_label: service
      - source_labels: ['__meta_docker_container_name']
        target_label: container
```

## Checklist de Monitoramento

- [ ] Endpoint `/health` implementado com checks de banco e Redis
- [ ] Uptime Kuma configurado para todas as URLs críticas
- [ ] Monitor de SSL com alerta de 14 dias antes da expiração
- [ ] Logs estruturados em JSON com timestamp
- [ ] Request logger com duração e status code
- [ ] Alertas Telegram para erros 5xx
- [ ] Alertas Telegram para downtime (via Uptime Kuma webhook)
- [ ] Logs com retenção máxima configurada (evitar disco cheio)
- [ ] Dashboard básico de métricas (CPU, memória, disco)
