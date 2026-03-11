-- =============================================================
-- Wolf Mission Control — Migration 007
-- Adiciona: system_logs, escalations, evaluate_output_quality,
--           get_agent_metrics, updated_at em missions
-- Criado: 2026-03-05 | ADDITIVE — não quebra schema existente
-- =============================================================

-- =============================================================
-- TABELA: system_logs
-- Logs internos do sistema (trigger-mission, quality-gate, etc.)
-- =============================================================
CREATE TABLE IF NOT EXISTS system_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  level       TEXT NOT NULL DEFAULT 'info',  -- info|warning|error|critical
  source      TEXT NOT NULL,                 -- "trigger-mission"|"quality-gate"|"memory-writer"
  message     TEXT NOT NULL,
  payload     JSONB DEFAULT '{}',
  agent_id    UUID REFERENCES agents(id),
  mission_id  UUID REFERENCES missions(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_level   ON system_logs(level, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_source  ON system_logs(source, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_mission ON system_logs(mission_id);

ALTER TABLE system_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON system_logs
  FOR ALL USING (auth.role() = 'service_role');

-- =============================================================
-- TABELA: escalations
-- Alertas e escalações que chegam no Telegram do Netto
-- =============================================================
CREATE TABLE IF NOT EXISTS escalations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type         TEXT NOT NULL,  -- "alert"|"sla_breach"|"quality_failure"|"agent_error"
  level        TEXT NOT NULL,  -- "L1"|"L2"|"L3"|"L4"
  title        TEXT NOT NULL,
  message      TEXT NOT NULL,
  agent_id     UUID REFERENCES agents(id),
  mission_id   UUID REFERENCES missions(id),
  resolved_at  TIMESTAMPTZ,
  resolved_by  TEXT,           -- "netto"|"alfred"|"auto"
  metadata     JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_escalations_level     ON escalations(level, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_escalations_resolved  ON escalations(resolved_at) WHERE resolved_at IS NULL;

ALTER TABLE escalations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON escalations
  FOR ALL USING (auth.role() = 'service_role');

-- =============================================================
-- FUNÇÃO: evaluate_output_quality
-- Avaliação básica de qualidade (fallback sem LLM)
-- A avaliação real é feita pela edge function quality-gate
-- =============================================================
CREATE OR REPLACE FUNCTION evaluate_output_quality(
  p_output        TEXT,
  p_mission_title TEXT DEFAULT ''
) RETURNS FLOAT AS $$
DECLARE
  score FLOAT := 0.75;
BEGIN
  -- Penalizar outputs muito curtos
  IF length(p_output) < 50 THEN
    RETURN 0.1;
  END IF;

  IF length(p_output) < 200 THEN
    score := 0.4;
  END IF;

  -- Penalizar se output é apenas boilerplate
  IF p_output ILIKE '%não posso%' OR p_output ILIKE '%desculpe%' OR
     p_output ILIKE '%não tenho acesso%' THEN
    score := LEAST(score, 0.3);
  END IF;

  -- Bônus se contém elementos estruturados
  IF p_output LIKE '%##%' OR p_output LIKE '%**%' OR
     p_output LIKE '%[SIGNALS]%' THEN
    score := LEAST(1.0, score + 0.1);
  END IF;

  RETURN score;
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- FUNÇÃO: get_agent_metrics
-- Retorna métricas de performance de um agente
-- =============================================================
CREATE OR REPLACE FUNCTION get_agent_metrics(p_agent_slug TEXT)
RETURNS JSONB AS $$
DECLARE
  v_agent_id UUID;
  result     JSONB;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE slug = p_agent_slug;
  IF NOT FOUND THEN RETURN '{"error": "agent not found"}'::JSONB; END IF;

  SELECT jsonb_build_object(
    'agent',          p_agent_slug,
    'total_missions', COUNT(m.id),
    'completed',      COUNT(m.id) FILTER (WHERE m.status = 'done'),
    'blocked',        COUNT(m.id) FILTER (WHERE m.status = 'blocked'),
    'in_progress',    COUNT(m.id) FILTER (WHERE m.status = 'in_progress'),
    'avg_quality',    ROUND(AVG(mo.quality)::NUMERIC, 3),
    'total_tokens',   COALESCE(SUM(mo.tokens_used), 0),
    'success_rate',   CASE
                        WHEN COUNT(m.id) = 0 THEN NULL
                        ELSE ROUND(
                          COUNT(m.id) FILTER (WHERE m.status = 'done')::NUMERIC
                          / COUNT(m.id) * 100, 1
                        )
                      END,
    'period',         '30d'
  )
  INTO result
  FROM missions m
  LEFT JOIN mission_outputs mo ON mo.mission_id = m.id
  WHERE m.agent_id = v_agent_id
    AND m.created_at > NOW() - INTERVAL '30 days';

  RETURN COALESCE(result, '{}'::JSONB);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- COLUNA: missions.updated_at (se não existir)
-- Necessário para dashboards e ordenação
-- =============================================================
ALTER TABLE missions
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_missions_updated_at ON missions;
CREATE TRIGGER set_missions_updated_at
  BEFORE UPDATE ON missions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- VERIFICAÇÃO
-- =============================================================
SELECT
  (SELECT COUNT(*) FROM information_schema.tables
   WHERE table_name IN ('system_logs', 'escalations')
   AND table_schema = 'public') AS new_tables_created,
  (SELECT COUNT(*) FROM information_schema.routines
   WHERE routine_name IN ('evaluate_output_quality', 'get_agent_metrics', 'update_updated_at')
   AND routine_schema = 'public') AS new_functions_created;
