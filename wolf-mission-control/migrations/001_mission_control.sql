-- =============================================================
-- Wolf Mission Control — Schema v1.0
-- Criado: 2026-03-05
-- Executar no Supabase SQL Editor
-- =============================================================

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- =============================================================
-- TABELA: clients
-- =============================================================
CREATE TABLE clients (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,       -- "wolf-agency", "cliente-x"
  telegram_id TEXT,                       -- ID do grupo/chat do cliente no Telegram
  clickup_list_id TEXT,                   -- ID da lista no ClickUp
  status      TEXT DEFAULT 'active',      -- active|inactive|paused
  metadata    JSONB DEFAULT '{}',         -- dados extras (nicho, budget, etc)
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================
-- TABELA: agents
-- =============================================================
CREATE TABLE agents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,            -- "Alfred", "Rex", "Luna"
  emoji         TEXT,                     -- "🐺", "🎯", "✍️"
  slug          TEXT UNIQUE NOT NULL,     -- "alfred", "rex", "luna"
  squad         TEXT NOT NULL,            -- "core"|"marketing"|"dev"|"ops"
  type          TEXT NOT NULL,            -- "LEAD"|"SPEC"|"INT"
  role          TEXT NOT NULL,            -- descrição da especialidade
  system_prompt TEXT NOT NULL,            -- prompt completo do agente
  skill_ref     TEXT,                     -- "workspace/agents/traffic/SKILL.md"
  status        TEXT DEFAULT 'idle',      -- "idle"|"working"|"busy"
  model         TEXT DEFAULT 'claude-sonnet-4-6',
  max_tokens    INTEGER DEFAULT 8192,
  governance    TEXT DEFAULT 'L1',        -- "L1"|"L2"|"L3"|"L4"
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================
-- TABELA: missions
-- =============================================================
CREATE TABLE missions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  status          TEXT DEFAULT 'inbox',
  -- inbox | assigned | in_progress | blocked | handoff | done | cancelled
  priority        TEXT DEFAULT 'medium',  -- low|medium|high|critical
  priority_score  FLOAT DEFAULT 0.5,      -- calculado automaticamente
  agent_id        UUID REFERENCES agents(id),
  client_id       UUID REFERENCES clients(id),
  tags            TEXT[] DEFAULT '{}',
  context         JSONB DEFAULT '{}',     -- contexto acumulado de handoffs
  parent_id       UUID REFERENCES missions(id),
  blocked_reason  TEXT,
  due_at          TIMESTAMPTZ,
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  created_by      TEXT DEFAULT 'telegram', -- "telegram"|"cron"|"handoff"|"dashboard"
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Index para consultas frequentes
CREATE INDEX idx_missions_status ON missions(status);
CREATE INDEX idx_missions_agent ON missions(agent_id);
CREATE INDEX idx_missions_client ON missions(client_id);
CREATE INDEX idx_missions_priority ON missions(priority_score DESC);

-- =============================================================
-- TABELA: mission_outputs
-- =============================================================
CREATE TABLE mission_outputs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id  UUID REFERENCES missions(id) ON DELETE CASCADE,
  agent_id    UUID REFERENCES agents(id),
  output      TEXT NOT NULL,
  signals     JSONB DEFAULT '{}',        -- sinais [SIGNALS] parseados
  quality     FLOAT,                     -- score 0-1 (auto-avaliado)
  tokens_used INTEGER DEFAULT 0,
  model_used  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================
-- TABELA: agent_memory
-- =============================================================
CREATE TABLE agent_memory (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    UUID REFERENCES agents(id),
  client_id   UUID REFERENCES clients(id),
  memory_type TEXT NOT NULL,
  -- "soul_md"|"performance"|"context"|"signal"|"lesson"
  key         TEXT,                       -- chave da memória (ex: "cpa_meta")
  content     JSONB NOT NULL,
  relevance   FLOAT DEFAULT 1.0,
  expires_at  TIMESTAMPTZ,               -- NULL = permanente
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(agent_id, client_id, memory_type, key)
);

CREATE INDEX idx_memory_agent_client ON agent_memory(agent_id, client_id);

-- =============================================================
-- TABELA: handoffs
-- =============================================================
CREATE TABLE handoffs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_agent_id   UUID REFERENCES agents(id),
  to_agent_id     UUID REFERENCES agents(id),
  mission_id      UUID REFERENCES missions(id),
  signal_type     TEXT NOT NULL,
  -- "boost_candidate"|"hook_fix"|"copy_review"|"seo_angle"|"deploy_done"
  payload         JSONB NOT NULL,
  status          TEXT DEFAULT 'pending',  -- pending|accepted|ignored
  processed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_handoffs_to_agent ON handoffs(to_agent_id, status);

-- =============================================================
-- FUNÇÃO: calculate_priority_score
-- =============================================================
CREATE OR REPLACE FUNCTION calculate_priority_score(
  p_urgency         FLOAT,   -- 0 a 1 (0=baixa, 1=crítico)
  p_financial_impact FLOAT,  -- 0 a 1 (% do faturamento em risco)
  p_due_hours       FLOAT    -- horas até prazo (NULL = sem prazo)
) RETURNS FLOAT AS $$
DECLARE
  deadline_pressure FLOAT := 0;
BEGIN
  IF p_due_hours IS NOT NULL AND p_due_hours >= 0 THEN
    deadline_pressure := GREATEST(0, 1 - (p_due_hours / 48.0));
    deadline_pressure := POWER(deadline_pressure, 0.5);
  END IF;

  RETURN LEAST(1.0,
    (p_urgency * 0.4) +
    (p_financial_impact * 0.4) +
    (deadline_pressure * 0.2)
  );
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- FUNÇÃO: trigger após INSERT em missions
-- Notifica Edge Function via pg_net (webhook)
-- =============================================================
CREATE OR REPLACE FUNCTION notify_new_mission()
RETURNS trigger AS $$
DECLARE
  edge_function_url TEXT := 'https://dqhiafxbljujahmpcdhf.supabase.co/functions/v1';
  service_role_key  TEXT := 'SET_YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE';
BEGIN
  -- Dispara apenas quando missão vai para "assigned"
  IF NEW.status = 'assigned' AND NEW.agent_id IS NOT NULL THEN
    PERFORM net.http_post(
      url     := edge_function_url || '/trigger-mission',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body    := jsonb_build_object('mission_id', NEW.id)::text
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_mission_assigned
  AFTER INSERT OR UPDATE ON missions
  FOR EACH ROW EXECUTE FUNCTION notify_new_mission();

-- =============================================================
-- FUNÇÃO: re-check missões paradas (chamada pelo pg_cron)
-- =============================================================
CREATE OR REPLACE FUNCTION recheck_stale_missions()
RETURNS void AS $$
DECLARE
  stale_mission RECORD;
BEGIN
  FOR stale_mission IN
    SELECT id, title, agent_id, started_at
    FROM missions
    WHERE status = 'in_progress'
      AND started_at < NOW() - INTERVAL '30 minutes'
  LOOP
    -- Marcar como bloqueada e notificar
    UPDATE missions
    SET status = 'blocked',
        blocked_reason = 'Missão sem resposta por mais de 30 minutos'
    WHERE id = stale_mission.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Agendar verificação a cada 30 minutos
SELECT cron.schedule(
  'recheck-stale-missions',
  '*/30 * * * *',
  'SELECT recheck_stale_missions()'
);

-- =============================================================
-- ROW LEVEL SECURITY
-- =============================================================
ALTER TABLE agents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE missions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE mission_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memory  ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoffs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients       ENABLE ROW LEVEL SECURITY;

-- Service role tem acesso total (Edge Functions usam service role)
CREATE POLICY "service_role_all" ON agents        FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON missions      FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON mission_outputs FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON agent_memory  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON handoffs      FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON clients       FOR ALL USING (auth.role() = 'service_role');
