-- =============================================================
-- Migration: Unificar schemas (propostas + WMC)
-- Data: 2026-04-01
-- Objetivo: Consolidar tabelas duplicadas clients e system_logs
-- =============================================================

-- ─── 1. CLIENTS: adicionar campos WMC na tabela existente ───

ALTER TABLE clients ADD COLUMN IF NOT EXISTS slug text;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS telegram_id text;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS clickup_list_id text;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}';

-- Criar unique index no slug (se não existir)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_clients_slug') THEN
    CREATE UNIQUE INDEX idx_clients_slug ON clients(slug);
  END IF;
END $$;

-- Gerar slugs para clientes existentes que não têm
UPDATE clients SET slug = lower(
  regexp_replace(
    regexp_replace(
      translate(name, 'áàãâéêíóôõúüçÁÀÃÂÉÊÍÓÔÕÚÜÇ', 'aaaaeeiooouucAAAAEEIOOOUUC'),
      '[^a-zA-Z0-9]+', '-', 'g'
    ),
    '^-|-$', '', 'g'
  )
) WHERE slug IS NULL;

-- ─── 2. SYSTEM_LOGS: adicionar campos WMC na tabela existente ───

ALTER TABLE system_logs ADD COLUMN IF NOT EXISTS payload jsonb DEFAULT '{}';
ALTER TABLE system_logs ADD COLUMN IF NOT EXISTS agent_id uuid;
ALTER TABLE system_logs ADD COLUMN IF NOT EXISTS mission_id uuid;

-- Índices adicionais para queries WMC
CREATE INDEX IF NOT EXISTS idx_logs_agent ON system_logs(agent_id) WHERE agent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_logs_mission ON system_logs(mission_id) WHERE mission_id IS NOT NULL;

-- ─── 3. ESCALATIONS: criar se não existir (era só no WMC) ───

CREATE TABLE IF NOT EXISTS escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  level text NOT NULL DEFAULT 'L1',
  title text NOT NULL,
  message text,
  agent_id uuid,
  mission_id uuid,
  resolved_at timestamptz,
  resolved_by text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE escalations ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='escalations' AND policyname='service_role_escalations') THEN
    CREATE POLICY "service_role_escalations" ON escalations FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_escalations_level ON escalations(level);
CREATE INDEX IF NOT EXISTS idx_escalations_open ON escalations(created_at) WHERE resolved_at IS NULL;

-- ─── 4. VIEW: resumo de saúde do sistema ───

CREATE OR REPLACE VIEW system_health AS
SELECT
  (SELECT count(*) FROM clients WHERE status = 'active') AS active_clients,
  (SELECT count(*) FROM proposals WHERE status IN ('open', 'sent')) AS open_proposals,
  (SELECT count(*) FROM system_logs WHERE level = 'error' AND created_at > now() - interval '24 hours') AS errors_24h,
  (SELECT count(*) FROM escalations WHERE resolved_at IS NULL) AS open_escalations,
  (SELECT count(*) FROM cron_status WHERE last_status = 'error') AS failed_crons;

-- ─── DONE ───
