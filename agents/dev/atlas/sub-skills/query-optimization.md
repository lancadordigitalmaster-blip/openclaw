# query-optimization.md — ATLAS Sub-Skill: Query Optimization
# Ativa quando: "query lenta", "EXPLAIN", "N+1", "otimiza query"

## EXPLAIN ANALYZE — Como Ler

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.*, a.name as account_name
FROM ad_campaigns c
JOIN ad_accounts a ON a.id = c.ad_account_id
WHERE c.organization_id = 'uuid-aqui'
  AND c.deleted_at IS NULL
  AND c.status = 'active'
ORDER BY c.created_at DESC
LIMIT 20;
```

### Decodificando o output:

```
Limit  (cost=0.56..45.23 rows=20 width=312) (actual time=0.123..1.456 rows=20 loops=1)
  ->  Nested Loop  (cost=0.56..2341.00 rows=1040 width=312) (actual time=0.120..1.440 rows=20 loops=1)
        ->  Index Scan using idx_campaigns_org_status on ad_campaigns c
              (cost=0.28..1200.00 rows=1040 width=280) (actual time=0.080..0.900 rows=20 loops=1)
              Index Cond: ((organization_id = 'uuid') AND (status = 'active'))
              Filter: (deleted_at IS NULL)
        ->  Index Scan using ad_accounts_pkey on ad_accounts a
              (cost=0.28..1.10 rows=1 width=32) (actual time=0.025..0.025 rows=1 loops=20)
              Index Cond: (id = c.ad_account_id)
Planning Time: 0.8 ms
Execution Time: 1.6 ms   <-- META: abaixo de 10ms para queries simples
```

### Métricas críticas:

| Campo               | O que significa                      | Alerta se...          |
|---------------------|--------------------------------------|-----------------------|
| `actual time`       | Tempo real de execução               | > 100ms em query OLTP |
| `rows`              | Linhas processadas                   | Muito maior que retornado |
| `Seq Scan`          | Leitura sequencial (sem índice)      | Em tabelas > 10k rows |
| `Buffers: hit`      | Dados lidos do cache                 | `read` alto = I/O lento |
| `loops`             | Quantas vezes o nó executou          | Alto = N+1 potential  |

---

## Seq Scan vs Index Scan

### Seq Scan é RUIM quando:
- Tabela tem > 10.000 linhas
- Query retorna < 20% das linhas
- Está dentro de um loop (nested)

### Seq Scan é ACEITÁVEL quando:
- Tabela pequena (< 1.000 linhas) — overhead de índice não compensa
- Query retorna > 50% das linhas — full scan é mais eficiente
- Tabela de lookup estática

### Forçar uso de índice para diagnóstico:
```sql
-- Desativa seq scan temporariamente para ver plano com índice
SET enable_seqscan = off;
EXPLAIN ANALYZE SELECT ...;
SET enable_seqscan = on;
```

---

## N+1 Queries — Detecção e Solução

### Sintoma no log:
```
-- 1 query para buscar campanhas
SELECT * FROM ad_campaigns WHERE org_id = $1;

-- N queries para buscar a conta de cada campanha
SELECT * FROM ad_accounts WHERE id = $1;  -- repetida 47 vezes
SELECT * FROM ad_accounts WHERE id = $1;
SELECT * FROM ad_accounts WHERE id = $1;
-- ...
```

### Detectar com Prisma (modo de desenvolvimento):
```typescript
// prisma/client.ts
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development'
    ? [{ level: 'query', emit: 'event' }]
    : [],
})

if (process.env.NODE_ENV === 'development') {
  prisma.$on('query', (e) => {
    if (e.duration > 50) {
      console.warn(`[SLOW QUERY ${e.duration}ms]`, e.query)
    }
  })
}
```

### Resolver N+1 com Prisma:

```typescript
// ERRADO — N+1
const campaigns = await prisma.adCampaign.findMany({
  where: { organizationId, deletedAt: null }
})

// N queries separadas — N+1 clássico
const campaignsWithAccounts = await Promise.all(
  campaigns.map(async (c) => ({
    ...c,
    account: await prisma.adAccount.findUnique({ where: { id: c.adAccountId } })
  }))
)

// CORRETO — 1 query com JOIN
const campaigns = await prisma.adCampaign.findMany({
  where: { organizationId, deletedAt: null },
  include: {
    adAccount: {
      select: { id: true, name: true, platform: true }  // select específico
    }
  },
  orderBy: { createdAt: 'desc' },
  take: 20
})
```

### Resolver N+1 com SQL raw quando Prisma não é suficiente:

```typescript
// Query complexa com múltiplos agregados — usar SQL raw
const results = await prisma.$queryRaw<CampaignWithMetrics[]>`
  SELECT
    c.id,
    c.name,
    c.status,
    a.name AS account_name,
    COUNT(r.id) AS report_count,
    SUM(r.spend) AS total_spend,
    SUM(r.impressions) AS total_impressions
  FROM ad_campaigns c
  JOIN ad_accounts a ON a.id = c.ad_account_id
  LEFT JOIN campaign_reports r ON r.campaign_id = c.id
    AND r.period_start >= ${startDate}
    AND r.period_end <= ${endDate}
  WHERE c.organization_id = ${organizationId}
    AND c.deleted_at IS NULL
  GROUP BY c.id, a.name
  ORDER BY total_spend DESC NULLS LAST
  LIMIT ${limit}
`
```

---

## Queries Prisma Otimizadas

### Regra: select específico sempre em listas

```typescript
// ERRADO — retorna 30+ colunas desnecessárias
const campaigns = await prisma.adCampaign.findMany({
  where: { organizationId }
})

// CORRETO — retorna só o necessário
const campaigns = await prisma.adCampaign.findMany({
  where: { organizationId, deletedAt: null },
  select: {
    id: true,
    name: true,
    status: true,
    budgetDaily: true,
    adAccount: {
      select: { name: true, platform: true }
    }
  },
  orderBy: { createdAt: 'desc' },
  take: 50,
  skip: offset
})
```

### Paginação cursor vs offset:

```typescript
// RUIM para grandes tabelas: offset n degrada linearmente
const page3 = await prisma.adCampaign.findMany({
  skip: 200,  // PostgreSQL lê e descarta 200 linhas
  take: 20
})

// BOM: cursor-based pagination — O(1) independente da página
const nextPage = await prisma.adCampaign.findMany({
  where: {
    organizationId,
    deletedAt: null,
    id: { gt: lastSeenId }  // cursor
  },
  orderBy: { id: 'asc' },
  take: 20
})
```

### Count separado quando necessário:

```typescript
// ERRADO: count + data em query separada sem necessidade
const total = await prisma.adCampaign.count({ where })
const items = await prisma.adCampaign.findMany({ where, ...pagination })

// CORRETO: transaction para garantir consistência
const [total, items] = await prisma.$transaction([
  prisma.adCampaign.count({ where }),
  prisma.adCampaign.findMany({ where, ...pagination })
])
```

---

## Exemplos Antes/Depois

### Antes — 2.3 segundos:
```sql
SELECT * FROM campaign_reports
WHERE organization_id = 'uuid'
ORDER BY created_at DESC;
-- Seq Scan: 180.000 linhas varridas
```

### Depois — 8ms:
```sql
-- Índice adicionado:
CREATE INDEX idx_reports_org_created
  ON campaign_reports(organization_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- Query com LIMIT e campos específicos:
SELECT id, campaign_id, spend, impressions, period_start, period_end
FROM campaign_reports
WHERE organization_id = 'uuid'
ORDER BY created_at DESC
LIMIT 100;
-- Index Scan: 100 linhas retornadas diretamente
```
