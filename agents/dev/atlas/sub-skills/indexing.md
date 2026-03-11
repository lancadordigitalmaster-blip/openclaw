# indexing.md — ATLAS Sub-Skill: Indexing
# Ativa quando: "índice", "index", "busca lenta", "performance de banco"

## Quando Criar Índice

### Crie índice em colunas que aparecem frequentemente em:
- `WHERE` com alta seletividade (filtra muitas linhas)
- `JOIN ON` (FK sempre deve ter índice)
- `ORDER BY` em queries paginadas
- `GROUP BY` em relatórios pesados
- Buscas por texto (`LIKE 'prefix%'`, full-text search)

### NÃO crie índice quando:
- Tabela tem < 1.000 linhas (overhead supera ganho)
- Coluna tem baixa cardinalidade (`status` com 3 valores sem filtros adicionais)
- Tabela tem carga de escrita muito alta e leitura baixa
- Coluna raramente usada em queries

---

## Tipos de Índice PostgreSQL

### B-tree (padrão — use na maioria dos casos)
```sql
-- Equalidade e range queries: =, <, >, BETWEEN, LIKE 'prefix%'
CREATE INDEX idx_campaigns_org_id ON ad_campaigns(organization_id);
CREATE INDEX idx_campaigns_created_at ON ad_campaigns(created_at DESC);

-- Índice composto: ordena pela coluna mais seletiva primeiro
CREATE INDEX idx_campaigns_org_status
  ON ad_campaigns(organization_id, status)
  WHERE deleted_at IS NULL;   -- partial index: exclui deletados
```

### GIN (Generalized Inverted Index — para JSONB e arrays)
```sql
-- JSONB: qualquer chave/valor dentro do JSON
CREATE INDEX idx_campaigns_metadata ON ad_campaigns USING GIN(metadata);

-- Array: contém elemento
CREATE INDEX idx_campaigns_tags ON ad_campaigns USING GIN(tags);

-- Full-text search
CREATE INDEX idx_campaigns_name_fts
  ON ad_campaigns USING GIN(to_tsvector('portuguese', name));

-- Uso:
SELECT * FROM ad_campaigns
WHERE metadata @> '{"objective": "conversions"}';   -- usa GIN

SELECT * FROM ad_campaigns
WHERE tags @> ARRAY['black-friday'];                  -- usa GIN

SELECT * FROM ad_campaigns
WHERE to_tsvector('portuguese', name) @@ to_tsquery('portuguese', 'campanha & verão');
```

### GiST (Generalized Search Tree — para full-text e geoespacial)
```sql
-- Full-text com ranking (pg_trgm para LIKE genérico)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_campaigns_name_trgm
  ON ad_campaigns USING GIN(name gin_trgm_ops);

-- Uso: busca parcial (LIKE '%texto%') — diferente do B-tree
SELECT * FROM ad_campaigns
WHERE name ILIKE '%verão%';   -- usa trigram index
```

### BRIN (Block Range Index — para dados temporais ordenados)
```sql
-- Muito eficiente para tabelas grandes com dados inseridos em ordem
-- Ideal para logs, eventos, métricas com timestamp crescente
CREATE INDEX idx_reports_created_at_brin
  ON campaign_reports USING BRIN(created_at);

-- Custo mínimo em escrita, bom para range queries em séries temporais
-- NÃO usar para acesso pontual — use B-tree nesse caso
```

---

## Índices Parciais (Partial Index)

Indexa apenas subconjunto de linhas — menor tamanho, mais rápido:

```sql
-- Só campanhas ativas (não deletadas) — elimina 70% das linhas do índice
CREATE INDEX idx_campaigns_active
  ON ad_campaigns(organization_id, created_at DESC)
  WHERE deleted_at IS NULL AND status = 'active';

-- Só usuários sem deleção
CREATE INDEX idx_users_email_active
  ON users(email)
  WHERE deleted_at IS NULL;

-- Só relatórios do último ano
CREATE INDEX idx_reports_recent
  ON campaign_reports(organization_id, period_start)
  WHERE period_start >= '2025-01-01';
```

---

## Identificar Índices Faltando

```sql
-- Queries com Seq Scan em tabelas grandes
SELECT
  schemaname,
  tablename,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  n_live_tup AS row_count,
  seq_tup_read / NULLIF(seq_scan, 0) AS avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
  AND n_live_tup > 10000
ORDER BY seq_tup_read DESC
LIMIT 20;

-- Colunas de FK sem índice
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = tc.table_name
      AND indexdef LIKE '%' || kcu.column_name || '%'
  );
```

---

## Identificar Índices Não Usados

```sql
-- Índices que não estão sendo usados (candidatos a remoção)
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan AS index_scans,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexname NOT LIKE '%pkey'      -- nunca remova PKs
  AND indexname NOT LIKE '%unique%'   -- nunca remova UNIQUEs
ORDER BY pg_relation_size(indexrelid) DESC;

-- Índices duplicados ou redundantes
SELECT
  a.indexname AS index_a,
  b.indexname AS index_b,
  a.tablename
FROM pg_indexes a
JOIN pg_indexes b ON a.tablename = b.tablename
  AND a.indexname < b.indexname
  AND a.indexdef = b.indexdef;
```

---

## Custo de Índice em Writes

Cada índice em uma tabela:
- Aumenta tempo de `INSERT` em ~5-15%
- Aumenta tempo de `UPDATE` nas colunas indexadas em ~10-30%
- Ocupa espaço em disco (B-tree típico: 10-30% do tamanho da tabela)
- Aumenta tempo de `VACUUM` e `AUTOVACUUM`

### Regra prática Wolf:
- Tabela com > 80% de writes e < 20% reads: máximo 3-4 índices essenciais
- Tabela com > 80% de reads (relatórios, histórico): índices liberados conforme necessidade

```sql
-- Verificar tamanho de todos os índices
SELECT
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
```

---

## Checklist de Índices

- [ ] Toda FK tem índice correspondente
- [ ] Colunas de `WHERE` em queries frequentes têm índice
- [ ] `organization_id` em toda tabela multi-tenant tem índice
- [ ] Colunas de `ORDER BY` em listas paginadas têm índice
- [ ] Índices em campos JSONB usam GIN
- [ ] Índices em arrays usam GIN
- [ ] Partial index para soft delete (`WHERE deleted_at IS NULL`)
- [ ] Índices não usados identificados e removidos (reduz custo de write)
- [ ] Índices criados com `CONCURRENTLY` em produção (não trava tabela)
- [ ] Tamanho total de índices monitorado (não deve superar 50% do tamanho da tabela)
