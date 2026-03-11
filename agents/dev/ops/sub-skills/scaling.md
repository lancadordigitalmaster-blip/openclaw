# scaling.md — Ops Sub-Skill: Scaling & Performance
# Ativa quando: "escala", "performance", "otimiza servidor"

## Quando Escalar — Métricas de Decisão

Antes de escalar, medir. Não escalar por intuição.

| Métrica                  | Sinal de alerta     | Ação                            |
|--------------------------|---------------------|---------------------------------|
| CPU                      | > 70% sustentado    | Otimizar código ou escalar      |
| Memória                  | > 80% sustentado    | Investigar leak ou escalar      |
| Tempo de resposta API    | > 500ms p95         | Cache, query, ou escalar        |
| Error rate               | > 1%                | Investigar bug antes de escalar |
| Queue backlog            | Crescendo sem parar | Mais workers                    |
| Conexões ativas DB       | > 80% do pool       | Pool maior ou read replica      |
| Disco                    | > 80% cheio         | Limpeza ou volume maior         |

```bash
# Coletar métricas do servidor
docker stats --no-stream
htop
df -h
free -h

# Ver queries lentas no PostgreSQL
docker compose exec postgres psql -U wolf wolfapp -c "
  SELECT query, mean_exec_time, calls, total_exec_time
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 10;
"
```

## Vertical vs Horizontal

**Escala vertical (scale up):** aumentar recursos do servidor atual.
- Simples de executar, zero mudança de código
- Limitado pelo hardware máximo disponível
- Downtime durante resize em alguns provedores
- Bom para: banco de dados, aplicações stateful

**Escala horizontal (scale out):** adicionar mais instâncias.
- Sem limite teórico de capacidade
- Requer aplicação stateless (sem sessão em memória local)
- Requer load balancer
- Bom para: APIs, workers

**Decisão Wolf:**
- Primeiro: otimizar o código (cache, queries, algoritmo)
- Segundo: vertical (mais rápido, sem mudança de arquitetura)
- Terceiro: horizontal (quando vertical não é suficiente ou muito caro)

## Cache com Redis

```typescript
// src/lib/cache.ts
import { redisConnection } from './queue'

export async function getCached<T>(
  key: string,
  ttlSeconds: number,
  fetchFn: () => Promise<T>
): Promise<T> {
  // Tentar cache primeiro
  const cached = await redisConnection.get(key)
  if (cached) {
    return JSON.parse(cached) as T
  }

  // Cache miss: buscar dado real
  const data = await fetchFn()
  await redisConnection.setex(key, ttlSeconds, JSON.stringify(data))
  return data
}

export async function invalidateCache(pattern: string): Promise<void> {
  const keys = await redisConnection.keys(pattern)
  if (keys.length > 0) {
    await redisConnection.del(...keys)
  }
}

// Uso:
export async function getCampaignMetrics(campaignId: string) {
  return getCached(
    `metrics:campaign:${campaignId}`,
    300, // 5 minutos
    () => MetricsService.fetchFromDatabase(campaignId)
  )
}

// Invalidar ao atualizar
export async function updateCampaign(id: string, data: any) {
  const campaign = await db.campaign.update({ where: { id }, data })
  await invalidateCache(`metrics:campaign:${id}*`)
  return campaign
}
```

**Estratégias de cache por tipo de dado:**

| Dado                         | TTL       | Invalidação              |
|------------------------------|-----------|--------------------------|
| Configurações da organização | 10 min    | Ao salvar                |
| Métricas de campanha         | 5 min     | Nunca (dados históricos) |
| Perfil do usuário            | 5 min     | Ao atualizar perfil      |
| Lista de campanhas           | 1 min     | Ao criar/editar          |
| Dados de ads (Meta/Google)   | 15 min    | Ao sincronizar           |

## Load Balancer com Nginx

```nginx
# /etc/nginx/sites-available/wolfapp-lb.conf

upstream wolfapp_api {
    least_conn;                          # algoritmo: menor número de conexões ativas

    server 127.0.0.1:3000 weight=1;     # instância 1
    server 127.0.0.1:3001 weight=1;     # instância 2
    server 127.0.0.1:3002 weight=1;     # instância 3

    keepalive 32;
}

server {
    listen 443 ssl;
    server_name api.wolfapp.com;

    location / {
        proxy_pass         http://wolfapp_api;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";   # importante para keepalive
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

**Rodar múltiplas instâncias da API com PM2:**
```bash
npm install -g pm2

# ecosystem.config.js
module.exports = {
  apps: [{
    name: 'wolfapp-api',
    script: 'dist/index.js',
    instances: 'max',       // uma por CPU
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
  }]
}

pm2 start ecosystem.config.js
pm2 save
pm2 startup  # registrar no boot
```

**Com Docker e réplicas:**
```yaml
# docker-compose.prod.yml
services:
  api:
    image: wolfapp-api:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
    ports:
      - "3000-3002:3000"  # mapear range de portas
```

## Otimização de Banco de Dados

```sql
-- Verificar queries sem índice
EXPLAIN ANALYZE SELECT * FROM campaigns WHERE organization_id = 'xxx' AND status = 'active';

-- Criar índice composto
CREATE INDEX CONCURRENTLY idx_campaigns_org_status
  ON campaigns (organization_id, status)
  WHERE status != 'deleted';

-- Índice para full-text search
CREATE INDEX CONCURRENTLY idx_campaigns_name_search
  ON campaigns USING gin(to_tsvector('portuguese', name));

-- Verificar índices existentes
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Verificar índices não utilizados (remover após confirmar)
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

## CDN para Assets Estáticos

```nginx
# Configurar headers de cache para assets estáticos
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2|woff)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Vary "Accept-Encoding";
}
```

**Cloudflare CDN (recomendado):**
1. Adicionar domínio ao Cloudflare
2. Configurar DNS para o servidor
3. Ativar modo proxy (laranja) para assets
4. Configurar Page Rules para cache de `/static/*`

## Connection Pool PostgreSQL

```typescript
// src/lib/db.ts — ajustar pool conforme escala
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
  log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['warn', 'error'],
})

// DATABASE_URL com pool configurado:
// postgresql://user:pass@host:5432/db?connection_limit=20&pool_timeout=30
```

**Regra de pool:** `connection_limit = (num_cpu * 2) + num_spindles`

Para 2 CPUs sem disco de spindle: `(2 * 2) + 0 = 4` por instância da aplicação.

## Checklist de Escalabilidade

- [ ] Métricas coletadas antes de qualquer decisão de escala
- [ ] Queries lentas identificadas e otimizadas com índices
- [ ] Cache Redis em dados consultados com frequência
- [ ] Application stateless (sessão em Redis, não em memória)
- [ ] Connection pool do banco dimensionado corretamente
- [ ] Assets estáticos servidos por CDN
- [ ] Load balancer configurado antes de adicionar instâncias
- [ ] Health check funcionando (load balancer precisa saber quem está up)
- [ ] Deploy zero-downtime configurado (rolling update)
