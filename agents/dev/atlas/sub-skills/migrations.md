# migrations.md — ATLAS Sub-Skill: Migrations
# Ativa quando: "migration", "migrate", "altera tabela", "adiciona coluna"

## Prisma Migrate — Padrão Wolf

Stack: **Prisma Migrate** para controle de schema + migrations SQL auditadas em repositório.

```bash
# Workflow padrão
npx prisma migrate dev --name add_campaign_budget    # cria migration local
npx prisma migrate deploy                             # aplica em staging/prod
npx prisma db pull                                   # introspect banco existente
npx prisma generate                                  # regenera Prisma Client
```

---

## Regras de Migração Segura

### Lei #1: Additive First
Toda alteração destrutiva passa por 3 fases:

```
Fase 1 (deploy atual): Adiciona nova coluna/tabela NULLABLE
Fase 2 (backfill):     Script preenche dados existentes
Fase 3 (deploy futuro): Torna NOT NULL ou dropa coluna antiga
```

### Lei #2: Nunca Dropa Sem Deprecation
```sql
-- ERRADO: dropa direto
ALTER TABLE users DROP COLUMN legacy_field;

-- CORRETO: depreca primeiro
-- Migration 001: marca como deprecated no comentário
COMMENT ON COLUMN users.legacy_field IS 'DEPRECATED: migrado para user_preferences.field — remover após 2026-06-01';

-- Migration 002 (sprint seguinte, após confirmar zero uso):
ALTER TABLE users DROP COLUMN legacy_field;
```

### Lei #3: Cada Migration Faz Uma Coisa
```
RUIM: migration_20240301_big_refactor.sql (20 alterações)
BOM:  20240301_add_campaigns_budget_columns.sql
      20240301_add_campaigns_platform_index.sql
      20240302_rename_users_full_name_to_name.sql
```

---

## Estrutura de Migration Segura

```sql
-- migrations/20240315120000_add_campaign_objectives.sql

-- UP
BEGIN;

-- 1. Adiciona coluna NULLABLE (não quebra nada)
ALTER TABLE ad_campaigns
    ADD COLUMN IF NOT EXISTS objective text NULL,
    ADD COLUMN IF NOT EXISTS objective_details jsonb NULL;

-- 2. Cria índice CONCURRENTLY (não trava a tabela)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_campaigns_objective
    ON ad_campaigns(objective)
    WHERE deleted_at IS NULL;

-- 3. Adiciona constraint check se necessário
ALTER TABLE ad_campaigns
    ADD CONSTRAINT campaigns_objective_check
    CHECK (objective IN ('awareness', 'traffic', 'conversions', 'leads', NULL));

COMMIT;
```

---

## Rollback de Migration

Prisma Migrate não tem rollback automático. Protocolo Wolf:

```sql
-- Sempre documente o rollback no arquivo de migration
-- migrations/20240315120000_add_campaign_objectives.sql

-- ROLLBACK (executar manualmente se necessário)
/*
BEGIN;
DROP INDEX CONCURRENTLY IF EXISTS idx_campaigns_objective;
ALTER TABLE ad_campaigns
    DROP CONSTRAINT IF EXISTS campaigns_objective_check,
    DROP COLUMN IF EXISTS objective,
    DROP COLUMN IF EXISTS objective_details;
COMMIT;
*/
```

```bash
# Script de rollback manual
# scripts/rollback-migration.sh

MIGRATION_NAME=$1
ROLLBACK_SQL="./migrations/rollback/${MIGRATION_NAME}.sql"

if [ ! -f "$ROLLBACK_SQL" ]; then
  echo "ERRO: rollback SQL não encontrado: $ROLLBACK_SQL"
  exit 1
fi

echo "Executando rollback: $MIGRATION_NAME"
psql $DATABASE_URL -f "$ROLLBACK_SQL"

# Remove migration do histórico do Prisma
psql $DATABASE_URL -c "
  DELETE FROM _prisma_migrations
  WHERE migration_name = '$MIGRATION_NAME'
  AND finished_at IS NOT NULL;
"
```

---

## Migration em Produção — Zero Downtime

### Operações SEGURAS (não travam tabela):
```sql
ADD COLUMN ... NULL                    -- seguro
ADD COLUMN ... DEFAULT valor_constante -- seguro no PG 11+
CREATE INDEX CONCURRENTLY              -- seguro
DROP INDEX CONCURRENTLY                -- seguro
ALTER TABLE ADD CONSTRAINT ... NOT VALID -- seguro (valida depois)
```

### Operações PERIGOSAS (travam tabela):
```sql
ALTER TABLE ... ALTER COLUMN ... TYPE   -- TRAVA — precisa rewrite
ALTER TABLE ... ADD COLUMN NOT NULL     -- TRAVA se sem DEFAULT
ALTER TABLE ... DROP COLUMN             -- TRAVA
ADD CONSTRAINT (sem NOT VALID)          -- TRAVA — valida tudo
TRUNCATE                                -- TRAVA
```

### Padrão para ALTER TYPE seguro:
```sql
-- ERRADO: trava a tabela
ALTER TABLE campaigns ALTER COLUMN status TYPE text;

-- CORRETO: zero downtime
BEGIN;
-- 1. Adiciona nova coluna
ALTER TABLE campaigns ADD COLUMN status_new text NULL;

-- 2. Trigger para manter em sync durante transição
CREATE OR REPLACE FUNCTION sync_campaign_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.status_new = NEW.status::text;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_status
    BEFORE INSERT OR UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION sync_campaign_status();
COMMIT;

-- (backfill em batch separado)
UPDATE campaigns SET status_new = status::text WHERE status_new IS NULL;

-- (deploy 2: swap)
BEGIN;
ALTER TABLE campaigns RENAME COLUMN status TO status_old;
ALTER TABLE campaigns RENAME COLUMN status_new TO status;
DROP TRIGGER trg_sync_status ON campaigns;
COMMIT;
```

---

## Checklist Pré-Migration em Produção

### 24h antes:
- [ ] Migration testada em ambiente de staging com dump de produção real
- [ ] Tempo estimado de execução medido em staging
- [ ] Rollback documentado e testado em staging
- [ ] Backup de produção confirmado (Supabase Point-in-Time ou pg_dump manual)
- [ ] Equipe comunicada sobre janela de manutenção (se necessário)

### No momento do deploy:
- [ ] Monitoramento ativo (erro rate, latência, CPU/RAM do banco)
- [ ] Conexão direta com banco disponível (não só via app)
- [ ] Janela fora do horário de pico (para migrations de risco)
- [ ] `npx prisma migrate deploy` executado, não `migrate dev`
- [ ] Output do migrate revisado — sem erros, sem warnings

### Pós-deploy:
- [ ] Queries críticas validadas (timing normal)
- [ ] Logs de erro limpos nos primeiros 10 minutos
- [ ] Índices criados com CONCURRENTLY confirmados como válidos
- [ ] `SELECT * FROM _prisma_migrations ORDER BY finished_at DESC LIMIT 5;` mostra migration como concluída
