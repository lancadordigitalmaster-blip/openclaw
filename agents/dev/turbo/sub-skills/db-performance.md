# db-performance.md — Turbo Sub-Skill: Database Performance
# Ativa quando: "query lenta", "banco lento", "EXPLAIN", "índice"

---

## Como Ler EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.nome, COUNT(p.id) as total_pedidos
FROM usuarios u
LEFT JOIN pedidos p ON p.usuario_id = u.id
WHERE u.criado_em > '2024-01-01'
GROUP BY u.id, u.nome
ORDER BY total_pedidos DESC;
```

```
SAÍDA TÍPICA:
=============
Sort  (cost=1250.45..1265.23 rows=5912 width=48)
      (actual time=185.234..186.102 rows=4821 loops=1)
  Sort Key: (count(p.id)) DESC
  Sort Method: external merge  Disk: 1024kB   ← PROBLEMA: ordenação em disco
  ->  HashAggregate  (cost=780.12..892.34 rows=5912 width=40)
        (actual time=120.45..150.23 rows=4821 loops=1)
        Batches: 5  Memory Usage: 4096kB  Disk Usage: 2048kB  ← memória insuficiente
        ->  Hash Left Join  (cost=245.67..650.89 rows=25892 width=32)
              (actual time=15.23..89.45 rows=25892 loops=1)
              Hash Cond: (p.usuario_id = u.id)
              ->  Seq Scan on pedidos p                         ← PROBLEMA: full scan
                    (cost=0.00..350.12 rows=25892 width=8)
                    (actual time=0.12..35.67 rows=25892 loops=1)
              ->  Hash  (cost=180.45..180.45 rows=5217 width=36)
                    (actual time=14.89..14.89 rows=5217 loops=1)
                    ->  Index Scan using idx_usuarios_criado_em on usuarios u
                          (actual time=0.08..10.23 rows=5217 loops=1)
                          Index Cond: (criado_em > '2024-01-01'::date)
Planning Time: 1.234 ms
Execution Time: 187.456 ms                                      ← total real
```

### Decodificando cada elemento

```
cost=1250.45..1265.23
      ↑          ↑
      startup   total (unidades arbitrárias do planner)
      (custo para primeira linha)

actual time=185.234..186.102
             ↑          ↑
             startup    total em MILISSEGUNDOS (real!)
             real       real

rows=5912       → estimativa do planner
rows=4821       → real executado (divergência = estatísticas desatualizadas)

loops=1         → quantas vezes esse nó executou
                  Se loops=1000 e time=5ms → 5000ms total!
```

---

## Identificação de Gargalos

### Seq Scan vs Index Scan
```sql
-- RED FLAG: Seq Scan em tabela grande
Seq Scan on pedidos  (cost=0..350 rows=25892 ...)
-- → tabela inteira percorrida, sem índice

-- BOM: Index Scan
Index Scan using idx_pedidos_usuario_id on pedidos
-- → usa índice, só lê linhas necessárias

-- BOM EM CERTOS CASOS: Bitmap Index Scan
-- Para quando múltiplas condições filtram muitas linhas
-- Mais eficiente que Seq Scan, menos que Index Scan puro
```

```sql
-- DIAGNÓSTICO: tabelas sem índices usados
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'pedidos'
ORDER BY n_distinct DESC;

-- Quantas vezes cada índice é usado
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'pedidos'
ORDER BY idx_scan DESC;
```

### Sort em Memória vs Disco
```
Sort Method: quicksort  Memory: 4096kB   → BOM: cabe em memória
Sort Method: external merge  Disk: 1024kB → RUIM: vai para disco (10-100x mais lento)
```

```sql
-- Aumentar work_mem para operações de sort pesadas
-- NÃO mude globalmente — use por sessão ou por query
SET work_mem = '64MB';

-- Ou na configuração de pool/conexão específica
-- .env
# PGSSLMODE=require
# PGCONNECT_TIMEOUT=10
```

### Nested Loop vs Hash Join
```
Nested Loop → bom para conjuntos pequenos (< 1000 linhas)
Hash Join   → bom para conjuntos grandes (requer memória para hash table)
Merge Join  → bom quando ambas as tabelas já estão ordenadas
```

---

## Criação de Índices — Estratégia Wolf

```sql
-- 1. Índice básico — coluna usada no WHERE
CREATE INDEX CONCURRENTLY idx_pedidos_usuario_id
ON pedidos(usuario_id);
-- CONCURRENTLY → não bloqueia a tabela durante criação

-- 2. Índice composto — para queries com múltiplas condições
-- Ordem importa: coluna com maior seletividade primeiro
CREATE INDEX CONCURRENTLY idx_pedidos_usuario_status
ON pedidos(usuario_id, status)
WHERE status != 'cancelado';  -- partial index: ignora linhas irrelevantes

-- 3. Índice para ORDER BY + LIMIT (pattern muito comum)
CREATE INDEX CONCURRENTLY idx_pedidos_criado_desc
ON pedidos(criado_em DESC);

-- 4. Índice para busca de texto
CREATE INDEX CONCURRENTLY idx_produtos_nome_gin
ON produtos USING gin(to_tsvector('portuguese', nome));

-- Busca full-text
SELECT * FROM produtos
WHERE to_tsvector('portuguese', nome) @@ to_tsquery('portuguese', 'tênis & corrida');
```

### Índices que Não São Usados
```sql
-- Índices nunca ou raramente usados (candidatos a remover)
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE idx_scan < 10
  AND indexrelname NOT LIKE 'pk_%'  -- não remova PKs
  AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Índices duplicados (mesmas colunas)
SELECT a.indexrelid::regclass, b.indexrelid::regclass,
       a.indrelid::regclass AS tabela
FROM pg_index a
JOIN pg_index b ON a.indrelid = b.indrelid
  AND a.indexrelid < b.indexrelid
  AND a.indkey = b.indkey;
```

---

## pg_stat_statements — Encontrar Queries Mais Lentas

```sql
-- Habilitar (postgresql.conf ou RDS parameter group)
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.max = 1000
-- pg_stat_statements.track = all

-- Criar extensão
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 20 queries mais lentas (por tempo médio)
SELECT
  LEFT(query, 100) AS query_resumida,
  calls,
  round(total_exec_time::numeric / calls, 2) AS avg_ms,
  round(total_exec_time::numeric, 2) AS total_ms,
  rows / calls AS avg_rows,
  round(100.0 * total_exec_time / sum(total_exec_time) OVER (), 2) AS pct_total
FROM pg_stat_statements
WHERE calls > 10
ORDER BY avg_ms DESC
LIMIT 20;

-- Queries com mais I/O (shared buffers hit vs read)
SELECT
  LEFT(query, 100) AS query_resumida,
  calls,
  shared_blks_hit,
  shared_blks_read,
  round(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 2) AS cache_hit_rate
FROM pg_stat_statements
WHERE shared_blks_hit + shared_blks_read > 0
ORDER BY shared_blks_read DESC
LIMIT 20;

-- Resetar estatísticas após otimização
SELECT pg_stat_statements_reset();
```

---

## Connection Pool Sizing

```
FÓRMULA POSTGRES:
=================
Conexões máximas recomendadas por servidor PostgreSQL = 4 × núcleos de CPU

Exemplo: 4 vCPUs → máximo 16 conexões ativas
(PostgreSQL não escala linearmente acima disso — context switching mata)

Pool por instância de app:
- min: 2
- max: 10 (para 4 vCPU)

Se múltiplas instâncias de app:
- PgBouncer como pooler intermediário
- Modo transaction pooling (melhor utilização)
```

```javascript
// Prisma — configuração de pool
// schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  // connection_limit e pool_timeout via URL
}

// DATABASE_URL com pool settings
// postgresql://user:pass@host:5432/db?connection_limit=10&pool_timeout=30

// Drizzle ORM com pg pool
import { Pool } from 'pg'
import { drizzle } from 'drizzle-orm/node-postgres'

const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 10,           // conexões máximas no pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

export const db = drizzle(pool)
```

---

## Queries N+1 — Identificação e Fix

```javascript
// PROBLEMA: N+1 com Prisma
// Gera 1 query para usuários + N queries para pedidos
const usuarios = await prisma.usuario.findMany()
for (const usuario of usuarios) {
  const pedidos = await prisma.pedido.findMany({
    where: { usuarioId: usuario.id }
  })
}

// FIX: include (eager loading)
const usuarios = await prisma.usuario.findMany({
  include: {
    pedidos: {
      select: { id: true, valor: true, status: true }
    }
  }
})

// FIX: se só precisa de count
const usuarios = await prisma.usuario.findMany({
  include: {
    _count: { select: { pedidos: true } }
  }
})
```

---

## Checklist DB Performance Wolf

```
Diagnóstico
[ ] pg_stat_statements habilitado e analisado
[ ] Top 10 queries mais lentas identificadas
[ ] EXPLAIN ANALYZE nas queries problemáticas
[ ] Verificados Seq Scans em tabelas grandes

Índices
[ ] Colunas de WHERE frequente têm índice
[ ] Índices compostos para queries com múltiplas condições
[ ] Índices não usados identificados (candidatos a remover)
[ ] CONCURRENTLY usado para criar índices em produção

Connection Pool
[ ] Pool configurado (max ≤ 4 × CPU cores)
[ ] PgBouncer avaliado para apps com muitas instâncias
[ ] Connection timeout configurado (evita hanging connections)

Manutenção
[ ] VACUUM ANALYZE rodando (autovacuum configurado)
[ ] Estatísticas atualizadas (divergência planner vs real < 20%)
[ ] Tabelas grandes particionadas se > 50M rows
[ ] Monitoramento de slow queries em produção (> 1s → alerta)
```
