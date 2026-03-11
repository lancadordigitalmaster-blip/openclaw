# caching.md — Turbo Sub-Skill: Caching Strategy
# Ativa quando: "cache", "Redis", "CDN", "invalidação", "estratégia"

---

## Matriz de Decisão de Cache

| Dado | Frequência de mudança | Custo de gerar | Compartilhado? | Cache? | Onde | TTL |
|------|-----------------------|----------------|----------------|--------|------|-----|
| Assets estáticos (JS, CSS) | Nunca (por deploy) | Baixo | Sim | Sim | CDN | Imutável (1 ano) |
| Imagens de produto | Raramente | Médio | Sim | Sim | CDN | 30 dias |
| Lista de categorias | Raramente | Baixo | Sim | Sim | Redis | 1 hora |
| Resultado de busca | Frequente | Alto | Parcialmente | Sim | Redis | 5 min |
| Dados do usuário autenticado | Por ação | Baixo | Não | Parcial | Redis | 15 min |
| Dados em tempo real | Constante | Baixo | Depende | Não | — | — |
| Carrinho de compras | Por ação | Baixo | Não | Sim | Redis/Session | 24h |
| Preço de produto | Frequente | Baixo | Sim | Cuidado | Redis | 1-5 min |

**Regra Wolf:** Se você não sabe a frequência de mudança e o custo de gerar, meça antes de cachear.

---

## Estratégias de Cache

### 1. Cache-Aside (Lazy Loading) — Padrão Wolf
```typescript
// Mais comum e flexível
// App busca do cache → se miss → busca do banco → salva no cache
async function getProduto(id: string): Promise<Produto> {
  const cacheKey = `produto:${id}`

  // 1. Tenta cache
  const cached = await redis.get(cacheKey)
  if (cached) {
    return JSON.parse(cached)
  }

  // 2. Cache miss — busca fonte de verdade
  const produto = await db.produto.findUnique({ where: { id } })
  if (!produto) throw new NotFoundError()

  // 3. Salva no cache
  await redis.setex(cacheKey, 300, JSON.stringify(produto)) // 5 min

  return produto
}

// Invalidação ao atualizar
async function atualizarProduto(id: string, dados: Partial<Produto>) {
  const produto = await db.produto.update({ where: { id }, data: dados })

  // Invalida cache imediatamente
  await redis.del(`produto:${id}`)
  // Invalida caches relacionados
  await redis.del(`lista:produtos:*`) // padrão — use com cuidado

  return produto
}
```

### 2. TTL-Based — Para Dados que Tolerem Staleness
```typescript
// Bom para: listas públicas, dados de referência, rankings
async function getCategoriasPopulares(): Promise<Categoria[]> {
  const TTL = 60 * 60 // 1 hora — mudanças são raras

  return cachedOr('categorias:populares', TTL, async () => {
    return db.categoria.findMany({
      where: { ativa: true },
      orderBy: { totalProdutos: 'desc' },
    })
  })
}

// Helper genérico
async function cachedOr<T>(
  key: string,
  ttl: number,
  fn: () => Promise<T>
): Promise<T> {
  const cached = await redis.get(key)
  if (cached) return JSON.parse(cached)

  const value = await fn()
  await redis.setex(key, ttl, JSON.stringify(value))
  return value
}
```

### 3. Event-Based Invalidation — Para Dados Críticos
```typescript
// Invalida cache quando evento específico ocorre
// Garante consistência sem TTL baixo

// Ao criar pedido
async function criarPedido(dados: CriarPedidoInput) {
  const pedido = await db.pedido.create({ data: dados })

  // Invalida todos os caches afetados pelo evento
  await Promise.all([
    redis.del(`estoque:produto:${dados.produtoId}`),
    redis.del(`usuario:${dados.usuarioId}:pedidos`),
    redis.del(`metricas:vendas:hoje`),
  ])

  // Publica evento para outros serviços
  await queue.publish('pedido.criado', { pedidoId: pedido.id })

  return pedido
}
```

### 4. Write-Through — Escrita Simultânea
```typescript
// Escreve no cache E no banco ao mesmo tempo
// Bom quando: leitura é muito mais frequente que escrita

async function salvarConfiguracao(userId: string, config: Config) {
  const [dbResult] = await Promise.all([
    db.configuracao.upsert({
      where: { userId },
      create: { userId, ...config },
      update: config,
    }),
    redis.setex(`config:usuario:${userId}`, 3600, JSON.stringify(config)),
  ])
  return dbResult
}
```

---

## Redis — Padrões Práticos

```typescript
// Configuração com ioredis
import Redis from 'ioredis'

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: 6379,
  password: process.env.REDIS_PASSWORD,
  db: 0,
  maxRetriesPerRequest: 3,
  enableOfflineQueue: false,     // falha rápido se Redis cair
  connectTimeout: 10000,
  lazyConnect: true,
})

redis.on('error', (err) => {
  console.error('Redis error:', err)
  // NÃO derrube a app — Redis deve ser não-crítico
})
```

```typescript
// Padrão de fallback gracioso — Redis não pode derrubar a app
async function getProdutoComFallback(id: string): Promise<Produto> {
  try {
    const cached = await redis.get(`produto:${id}`)
    if (cached) return JSON.parse(cached)
  } catch (err) {
    // Redis indisponível — continua sem cache
    console.warn('Cache indisponível, usando banco diretamente:', err.message)
  }

  const produto = await db.produto.findUnique({ where: { id } })

  try {
    await redis.setex(`produto:${id}`, 300, JSON.stringify(produto))
  } catch {
    // Falha silenciosa ao escrever no cache
  }

  return produto
}
```

```bash
# Comandos Redis úteis para debug
redis-cli KEYS "produto:*"          # lista chaves (cuidado em prod com muitas chaves)
redis-cli SCAN 0 MATCH "produto:*"  # melhor em prod (não bloqueia)
redis-cli TTL produto:123           # tempo restante de TTL
redis-cli GET produto:123           # valor da chave
redis-cli INFO memory               # uso de memória
redis-cli MONITOR                   # stream de comandos em tempo real (debug)
redis-cli FLUSHDB                   # limpa TUDO do DB atual (cuidado!)
```

---

## HTTP Cache Headers

```typescript
// Next.js App Router — cache headers
// app/api/categorias/route.ts
export async function GET() {
  const categorias = await getCategorias()

  return Response.json(categorias, {
    headers: {
      // Cache por 1 hora na CDN, 5 min no cliente
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=300',
    },
  })
}

// Para dados privados (por usuário)
export async function GET(req: Request) {
  const dados = await getDadosUsuario()
  return Response.json(dados, {
    headers: {
      'Cache-Control': 'private, max-age=0, must-revalidate',
    },
  })
}
```

```nginx
# Nginx — cache headers para assets estáticos
location ~* \.(js|css|woff2|png|jpg|webp|svg)$ {
  # Assets com hash no nome (bundle-abc123.js) → imutável
  add_header Cache-Control "public, max-age=31536000, immutable";
  expires 1y;
}

location ~* \.(html)$ {
  # HTML → sem cache (sempre busca versão mais recente)
  add_header Cache-Control "no-cache, no-store, must-revalidate";
  expires 0;
}

# ETag para validação
etag on;
```

---

## CDN (Cloudflare) para Assets Estáticos

```javascript
// next.config.js — configurar CDN
module.exports = {
  assetPrefix: process.env.CDN_URL || '', // https://cdn.seudominio.com
  // Ou use Cloudflare Pages / Vercel Edge automaticamente
}
```

```
CLOUDFLARE — CONFIGURAÇÕES WOLF:
=================================
Page Rule para /static/* ou /_next/static/*:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month
  - Browser Cache TTL: 1 year (para assets com hash)

Page Rule para /api/*:
  - Cache Level: Bypass
  - (APIs não devem ser cacheadas no CDN sem cuidado)

Page Rule para / (HTML):
  - Cache Level: Standard
  - Edge Cache TTL: 4 hours
  - Usar Cloudflare Cache Reserve para hot pages
```

---

## Armadilhas de Cache

### Thundering Herd / Cache Stampede
```typescript
// PROBLEMA: cache expira → 1000 requests simultâneas batem no banco
// SOLUÇÃO: mutex com lock

import Redlock from 'redlock'
const redlock = new Redlock([redis])

async function getDadosComLock(key: string): Promise<any> {
  const cached = await redis.get(key)
  if (cached) return JSON.parse(cached)

  // Só um processo processa por vez
  const lock = await redlock.acquire([`lock:${key}`], 5000)
  try {
    // Verifica de novo (pode ter sido preenchido enquanto esperava o lock)
    const cachedAfterLock = await redis.get(key)
    if (cachedAfterLock) return JSON.parse(cachedAfterLock)

    const dados = await buscarDadosCaro()
    await redis.setex(key, 300, JSON.stringify(dados))
    return dados
  } finally {
    await lock.release()
  }
}

// SOLUÇÃO ALTERNATIVA: probabilistic early expiration
// Começa a renovar o cache antes de expirar
async function getDadosComEarlyExpire(key: string): Promise<any> {
  const item = await redis.get(key)
  if (!item) return renovarCache(key)

  const { value, expiresAt } = JSON.parse(item)
  const ttlRestante = expiresAt - Date.now()

  // 10% do TTL restante → renova proativamente
  if (ttlRestante < 30_000 && Math.random() < 0.1) {
    renovarCache(key) // assíncrono, não bloqueia
  }

  return value
}
```

### Invalidação Incorreta
```typescript
// ARMADILHA: invalidar com padrão de keys em prod
// redis.del("lista:*") → KEYS * bloqueia Redis em prod com muitas chaves

// SOLUÇÃO: Tags de cache com sets
async function getProdutosDaCategoria(categoriaId: string) {
  const cacheKey = `produtos:categoria:${categoriaId}`
  const tagKey = `tag:categoria:${categoriaId}`

  const cached = await redis.get(cacheKey)
  if (cached) return JSON.parse(cached)

  const produtos = await db.produto.findMany({ where: { categoriaId } })

  const pipeline = redis.pipeline()
  pipeline.setex(cacheKey, 3600, JSON.stringify(produtos))
  pipeline.sadd(tagKey, cacheKey)       // registra a chave na tag
  pipeline.expire(tagKey, 3600)
  await pipeline.exec()

  return produtos
}

// Invalidar toda a tag de uma vez
async function invalidarCacheCategoria(categoriaId: string) {
  const tagKey = `tag:categoria:${categoriaId}`
  const keys = await redis.smembers(tagKey) // busca todas as chaves da tag
  if (keys.length > 0) {
    await redis.del(...keys, tagKey)
  }
}
```

---

## Checklist Cache Wolf

```
Estratégia
[ ] Matriz de decisão preenchida para dados principais
[ ] TTL definido baseado em frequência real de mudança
[ ] Estratégia de invalidação documentada (TTL, event, manual)
[ ] Redis configurado como não-crítico (falha silenciosa)

Implementação
[ ] Cache-aside para dados de leitura frequente
[ ] Fallback gracioso quando Redis indisponível
[ ] Pipeline Redis para operações em lote (menos roundtrips)
[ ] Sem KEYS * em produção (use SCAN)

HTTP / CDN
[ ] Assets estáticos com Cache-Control imutável (hash no nome)
[ ] HTML com no-cache ou TTL curto
[ ] API responses com headers corretos (public vs private)
[ ] CDN configurado para assets estáticos

Armadilhas
[ ] Proteção contra thundering herd em dados de alto acesso
[ ] Invalidação por tags (não por padrão KEYS *)
[ ] Cache de dados privados NUNCA em CDN pública
[ ] Monitoramento de hit rate (< 80% = algo errado)
```
