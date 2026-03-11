# schema-design.md — ATLAS Sub-Skill: Schema Design & Modelagem
# Ativa quando: "schema", "modelagem", "estrutura do banco", "tabela"

## Princípios de Modelagem Wolf

1. **Nomenclatura obrigatória:** snake_case, plural para tabelas, singular para colunas.
2. **Primary keys:** UUID v4 por padrão (`uuid_generate_v4()`). Serial apenas para tabelas de lookup internas sem exposição externa.
3. **Timestamps:** sempre `timestamptz` (com timezone). Nunca `timestamp` sem timezone.
4. **Soft delete:** coluna `deleted_at timestamptz NULL` — nunca `is_deleted boolean`.
5. **Tenant isolation:** coluna `organization_id uuid NOT NULL` em toda tabela de negócio.
6. **Auditoria mínima:** `created_at`, `updated_at`, `created_by_id` em toda tabela principal.

---

## Nomenclatura Wolf

| Elemento         | Padrão                    | Exemplo                        |
|------------------|---------------------------|--------------------------------|
| Tabela           | snake_case plural         | `ad_campaigns`, `meta_accounts`|
| Coluna           | snake_case singular       | `campaign_name`, `budget_daily`|
| FK               | `{tabela_singular}_id`    | `campaign_id`, `user_id`       |
| Index            | `idx_{tabela}_{coluna}`   | `idx_campaigns_org_id`         |
| Constraint       | `{tabela}_{coluna}_check` | `campaigns_status_check`       |
| Enum type        | snake_case singular       | `campaign_status`              |

---

## Tipos de Dado — Regras

```sql
-- CORRETO
id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY
organization_id uuid NOT NULL REFERENCES organizations(id)
created_at      timestamptz NOT NULL DEFAULT now()
updated_at      timestamptz NOT NULL DEFAULT now()
deleted_at      timestamptz NULL
budget_daily    numeric(12, 2) NOT NULL DEFAULT 0
status          campaign_status NOT NULL DEFAULT 'draft'
metadata        jsonb NULL
tags            text[] NULL

-- ERRADO
id              serial PRIMARY KEY              -- expõe volume, sem UUID
created_at      timestamp                       -- perde timezone
is_deleted      boolean DEFAULT false           -- dificulta queries
budget_daily    float                           -- imprecisão monetária
metadata        json                            -- json não tem índice GIN
```

---

## Normalização vs Desnormalização

### Normalize quando:
- Dados são atualizados frequentemente (ex: nome da organização)
- Relação é M:N clara (ex: usuários <-> papéis)
- Integridade referencial é crítica

### Desnormalize quando:
- Dados são imutáveis após criação (ex: snapshot de campanha no momento do relatório)
- Query de read é crítica e JOIN custa caro (ex: dashboard com 50k+ registros)
- Dados externos de API (ex: cache de metrics do Meta Ads na tabela de relatórios)

```sql
-- Exemplo de desnormalização intencional: snapshot de relatório
CREATE TABLE campaign_reports (
    id                  uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id     uuid NOT NULL REFERENCES organizations(id),
    campaign_id         uuid NOT NULL REFERENCES ad_campaigns(id),
    -- snapshot desnormalizado — não usa FK para Meta
    meta_campaign_name  text NOT NULL,           -- desnormalizado intencional
    meta_account_id     text NOT NULL,           -- desnormalizado intencional
    period_start        date NOT NULL,
    period_end          date NOT NULL,
    impressions         bigint NOT NULL DEFAULT 0,
    clicks              bigint NOT NULL DEFAULT 0,
    spend               numeric(12, 2) NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now()
);
```

---

## Schema Completo — Sistema de Clientes Wolf

```sql
-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- full-text search

-- Enums
CREATE TYPE user_role AS ENUM ('owner', 'admin', 'analyst', 'viewer');
CREATE TYPE campaign_status AS ENUM ('draft', 'active', 'paused', 'archived');
CREATE TYPE campaign_platform AS ENUM ('meta', 'google', 'tiktok', 'linkedin');

-- Organizações (tenants)
CREATE TABLE organizations (
    id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name            text NOT NULL,
    slug            text NOT NULL UNIQUE,
    plan            text NOT NULL DEFAULT 'starter',
    settings        jsonb NOT NULL DEFAULT '{}',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz NULL
);

-- Usuários
CREATE TABLE users (
    id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email           text NOT NULL,
    name            text NOT NULL,
    role            user_role NOT NULL DEFAULT 'analyst',
    avatar_url      text NULL,
    last_seen_at    timestamptz NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz NULL,
    UNIQUE(organization_id, email)
);

-- Contas de anúncio
CREATE TABLE ad_accounts (
    id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    platform        campaign_platform NOT NULL,
    external_id     text NOT NULL,           -- ID na plataforma (Meta, Google)
    name            text NOT NULL,
    currency        char(3) NOT NULL DEFAULT 'BRL',
    timezone        text NOT NULL DEFAULT 'America/Sao_Paulo',
    is_active       boolean NOT NULL DEFAULT true,
    metadata        jsonb NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE(platform, external_id)
);

-- Campanhas
CREATE TABLE ad_campaigns (
    id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    ad_account_id   uuid NOT NULL REFERENCES ad_accounts(id),
    external_id     text NOT NULL,
    name            text NOT NULL,
    status          campaign_status NOT NULL DEFAULT 'draft',
    platform        campaign_platform NOT NULL,
    budget_daily    numeric(12, 2) NULL,
    budget_total    numeric(12, 2) NULL,
    start_date      date NULL,
    end_date        date NULL,
    objective       text NULL,
    tags            text[] NOT NULL DEFAULT '{}',
    metadata        jsonb NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz NULL,
    UNIQUE(ad_account_id, external_id)
);

-- Índices principais
CREATE INDEX idx_users_organization_id ON users(organization_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ad_accounts_organization_id ON ad_accounts(organization_id);
CREATE INDEX idx_ad_campaigns_organization_id ON ad_campaigns(organization_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ad_campaigns_ad_account_id ON ad_campaigns(ad_account_id);
CREATE INDEX idx_ad_campaigns_status ON ad_campaigns(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_ad_campaigns_tags ON ad_campaigns USING GIN(tags);

-- Trigger updated_at automático
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_ad_accounts_updated_at BEFORE UPDATE ON ad_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_ad_campaigns_updated_at BEFORE UPDATE ON ad_campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

---

## Checklist Schema Design

- [ ] Todas as tabelas têm `id uuid`, `created_at`, `updated_at`
- [ ] Tabelas de negócio têm `organization_id` (isolamento de tenant)
- [ ] Soft delete com `deleted_at` onde necessário
- [ ] Tipos monetários em `numeric(12, 2)`, nunca `float`
- [ ] Timestamps são `timestamptz`
- [ ] Enums criados para status com valores fixos
- [ ] FKs com `ON DELETE CASCADE` ou `RESTRICT` explícito
- [ ] Índices criados para colunas de filtro frequente
- [ ] Trigger `update_updated_at` configurado
- [ ] UNIQUE constraints onde necessário (ex: email por org)
