# replication.md — ATLAS Sub-Skill: Replication & Alta Disponibilidade
# Ativa quando: "replicação", "read replica", "alta disponibilidade", "failover"

## Quando Replicação Faz Sentido

### Escala Wolf (projetos padrão):
- Banco primário único com connection pooling é suficiente
- Supabase já oferece HA automático no plano Pro+
- Até ~5.000 requests/minuto: sem necessidade de read replica

### Quando considerar read replica:
- Relatórios pesados derrubando performance do sistema transacional
- Queries analíticas > 30 segundos bloqueando writes
- > 50.000 requests/dia concentrados em reads
- Dashboard BI precisando de dados quase-realtime (vs ETL batch)

### Quando replicação enterprise faz sentido:
- Multi-região (latência para usuários em diferentes países)
- RPO < 1 minuto (perda de dados aceitável)
- SLA de 99.99% (4 noves)
- Regulatório: dados não podem sair de uma região

---

## Read Replica para Queries Pesadas

### Supabase Read Replicas (plano Enterprise)
```typescript
// lib/prisma.ts — conexões separadas por tipo de operação

import { PrismaClient } from '@prisma/client'

// Conexão primária: writes + reads transacionais críticos
export const prisma = new PrismaClient({
  datasources: {
    db: { url: process.env.DATABASE_URL },
  },
})

// Conexão read replica: relatórios, dashboards, queries analíticas
export const prismaReadOnly = new PrismaClient({
  datasources: {
    db: { url: process.env.DATABASE_READ_REPLICA_URL ?? process.env.DATABASE_URL },
  },
})

// Uso: sempre usar prismaReadOnly para relatórios
export async function getReportData(orgId: string, period: string) {
  // Query pesada vai para read replica
  return prismaReadOnly.campaignReport.findMany({
    where: { organizationId: orgId, period },
    include: { campaign: true },
  })
}

// Write vai para primário
export async function createCampaign(data: CreateCampaignInput) {
  return prisma.adCampaign.create({ data })
}
```

### Segregação de queries por tipo:
```typescript
// lib/db-router.ts

type QueryType = 'read' | 'write' | 'analytics'

export function getConnection(type: QueryType): PrismaClient {
  switch (type) {
    case 'analytics':
    case 'read':
      // Lag de replicação aceitável para leitura não-crítica
      return prismaReadOnly
    case 'write':
      // Sempre primário para consistência
      return prisma
  }
}

// Aviso: após write, read imediato pode ter lag de replicação (50ms-2s)
// Para reads pós-write críticos, use sempre primário
```

---

## Connection Pooling com PgBouncer

PgBouncer reduz overhead de conexão PostgreSQL — crítico em ambientes serverless.

### Por que PgBouncer é necessário:
- PostgreSQL aguenta ~100-300 conexões ativas
- Next.js serverless: cada instância abre nova conexão
- 50 deploys simultâneos = 50 conexões — sem pool, banco colapsa

### Configuração PgBouncer:
```ini
# pgbouncer.ini

[databases]
wolf_prod = host=db.supabase.co port=5432 dbname=postgres

[pgbouncer]
listen_port = 6432
listen_addr = *
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Transaction mode: ideal para serverless
# Connection mode NÃO funciona com prepared statements do Prisma
pool_mode = transaction

# Conexões por banco
default_pool_size = 25
max_client_conn = 1000
reserve_pool_size = 5
reserve_pool_timeout = 3

# Logging
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1
```

### Prisma com PgBouncer:
```bash
# .env — adiciona parâmetros de compatibilidade PgBouncer
DATABASE_URL="postgresql://user:pass@pgbouncer:6432/wolf_prod?pgbouncer=true&connection_limit=1"

# pgbouncer=true: desativa prepared statements (incompatível com transaction mode)
# connection_limit=1: limita conexões por instância serverless
```

---

## Supabase Replication Nativa

```sql
-- Supabase usa PostgreSQL Streaming Replication nativamente
-- Configurado automaticamente no plano Pro+

-- Verificar status da replicação
SELECT
  application_name,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  write_lag,
  flush_lag,
  replay_lag,
  sync_state
FROM pg_stat_replication;

-- Lag de replicação atual (em bytes)
SELECT
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replication_lag_bytes
FROM pg_stat_replication;

-- Publicações para Realtime (Supabase gerencia automaticamente)
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
```

### Habilitar tabela para Supabase Realtime:
```sql
-- Via Dashboard: Supabase > Database > Replication
-- Ou via SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE ad_campaigns;
ALTER PUBLICATION supabase_realtime ADD TABLE campaign_reports;
```

---

## Conceitos de Failover Automático

### Tipos de failover:

| Tipo               | RTO        | RPO         | Configuração          |
|--------------------|------------|-------------|-----------------------|
| Manual             | ~30 min    | ~5 min      | Básico                |
| Automatic (hot standby) | ~30 seg | ~1 seg   | PostgreSQL HA         |
| Supabase HA        | ~10-30 seg | ~0 (sincrono) | Automático Pro+    |
| Multi-region       | ~10 seg    | ~0          | Enterprise            |

### Supabase HA (High Availability):
- Plano Pro e superior: standby automático na mesma região
- Failover automático sem intervenção manual
- DNS atualizado automaticamente para o novo primário
- Configurado pelo Supabase — sem ação Wolf necessária

### Verificar saúde do banco Supabase:
```bash
# Via Supabase CLI
supabase db status --project-ref $SUPABASE_PROJECT_REF

# Health check endpoint
curl "https://${SUPABASE_PROJECT_REF}.supabase.co/rest/v1/" \
  -H "apikey: ${SUPABASE_ANON_KEY}"
```

---

## Monitoramento de Replicação

```sql
-- Dashboard de saúde para monitorar lag
SELECT
  NOW() AS checked_at,
  pg_is_in_recovery() AS is_replica,
  CASE
    WHEN pg_is_in_recovery()
    THEN pg_last_wal_receive_lsn() - pg_last_wal_replay_lsn()
    ELSE 0
  END AS replication_lag_bytes,
  pg_postmaster_start_time() AS db_started_at;
```

```typescript
// monitoring/db-health.ts — inclua em health check da aplicação

export async function checkDatabaseHealth() {
  const start = Date.now()

  try {
    await prisma.$queryRaw`SELECT 1`
    const latency = Date.now() - start

    return {
      status: 'healthy',
      latency_ms: latency,
      timestamp: new Date().toISOString(),
    }
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    }
  }
}
```

---

## Checklist Alta Disponibilidade

- [ ] Supabase plano Pro+ para HA automático em produção
- [ ] PgBouncer/Supabase Pooler configurado para ambiente serverless
- [ ] `pgbouncer=true` no DATABASE_URL quando usando transaction pool mode
- [ ] Read replica configurada se há queries analíticas pesadas (> 10s)
- [ ] Conexões separadas (prisma vs prismaReadOnly) para read/write splitting
- [ ] Health check endpoint verifica conexão com banco
- [ ] Alertas de replication lag configurados (alerta se > 5 segundos)
- [ ] Plano de failover documentado (quem faz o que quando banco cai)
- [ ] RTO e RPO definidos e comunicados ao cliente
- [ ] Teste de failover executado em staging pelo menos 1x por trimestre
