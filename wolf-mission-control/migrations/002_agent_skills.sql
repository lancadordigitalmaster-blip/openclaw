-- =============================================================
-- Wolf Mission Control — Agent Skills/Capabilities v1.0
-- Adição à schema existente
-- Criado: 2026-03-07
-- =============================================================

-- =============================================================
-- TABELA: agent_skills  
-- Armazena skills estruturados de cada agente
-- =============================================================
CREATE TABLE agent_skills (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id        UUID REFERENCES agents(id) ON DELETE CASCADE,
  skill_name      TEXT NOT NULL,
  -- "copywriting", "ads_management", "seo", "ui_design", "backend", etc
  category        TEXT NOT NULL,
  -- "marketing"|"dev"|"design"|"strategy"|"ops"
  proficiency     INTEGER DEFAULT 3,
  -- 1=beginner, 2=intermediate, 3=advanced, 4=expert, 5=master
  description     TEXT,
  tools           TEXT[] DEFAULT '{}',
  -- ["Meta API", "Google Ads", "Canva"]
  is_strength     BOOLEAN DEFAULT TRUE,
  -- TRUE = ponto forte | FALSE = área de melhoria
  experience_years FLOAT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(agent_id, skill_name)
);

-- Index
CREATE INDEX idx_skills_agent ON agent_skills(agent_id);
CREATE INDEX idx_skills_category ON agent_skills(category);
CREATE INDEX idx_skills_strength ON agent_skills(is_strength);

-- =============================================================
-- VIEW: agent_capability_summary
-- Resume Skills para exibição rápida
-- =============================================================
CREATE OR REPLACE VIEW agent_capability_summary AS
SELECT
  a.id,
  a.name,
  a.emoji,
  a.squad,
  jsonb_build_object(
    'strengths',
    jsonb_agg(
      jsonb_build_object(
        'skill', s.skill_name,
        'proficiency', s.proficiency,
        'category', s.category,
        'tools', s.tools
      )
      FILTER (WHERE s.is_strength = TRUE)
    ),
    'improvements',
    jsonb_agg(
      jsonb_build_object(
        'skill', s.skill_name,
        'proficiency', s.proficiency,
        'category', s.category
      )
      FILTER (WHERE s.is_strength = FALSE)
    )
  ) AS capabilities
FROM agents a
LEFT JOIN agent_skills s ON a.id = s.agent_id
GROUP BY a.id, a.name, a.emoji, a.squad;

-- =============================================================
-- ROW LEVEL SECURITY
-- =============================================================
ALTER TABLE agent_skills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON agent_skills 
FOR ALL USING (auth.role() = 'service_role');
