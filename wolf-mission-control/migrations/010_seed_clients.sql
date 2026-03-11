-- =============================================================
-- Wolf Mission Control — Migration 010
-- Seed: Clientes Wolf Agency (sincronizado do clients.yaml)
-- Criado: 2026-03-05 | IDEMPOTENTE (ON CONFLICT DO NOTHING)
-- =============================================================

INSERT INTO clients (name, slug, status, metadata) VALUES
(
  'Giovani Calçados',
  'giovani-calcados',
  'active',
  jsonb_build_object(
    'segmento', 'varejo / calçados',
    'canais_ativos', '["meta_ads","google_ads"]'::jsonb,
    'objetivo_meta', 'conversão',
    'target_roas', 3.0,
    'alertas', '["Landing Page overdue","Campanha Google Ads em standby"]'::jsonb,
    'notas', 'Preencher account_id, budget e contato'
  )
),
(
  'Studio Beleza',
  'studio-beleza',
  'active',
  jsonb_build_object(
    'segmento', 'beleza / estética',
    'canais_ativos', '["instagram","facebook"]'::jsonb,
    'objetivo_meta', 'reconhecimento',
    'alertas', '["Pack Criativos deadline 24h — produção não iniciada"]'::jsonb,
    'notas', 'Copy Black Friday urgente. Preencher account_id e contato.'
  )
),
(
  'Dr. Marcos',
  'dr-marcos',
  'active',
  jsonb_build_object(
    'segmento', 'saúde / médico',
    'canais_ativos', '["instagram"]'::jsonb,
    'objetivo_meta', 'tráfego',
    'alertas', '["Sem entrega há 8 dias"]'::jsonb,
    'notas', 'Card parado em briefing há 8 dias. Preencher dados completos.'
  )
),
(
  'Stephane Souza',
  'stephane-souza',
  'active',
  jsonb_build_object(
    'segmento', '',
    'canais_ativos', '[]'::jsonb,
    'alertas', '[]'::jsonb,
    'notas', 'Cliente novo — onboarding recém concluído. Preencher segmento e canais.'
  )
)
ON CONFLICT (slug) DO UPDATE SET
  status   = EXCLUDED.status,
  metadata = clients.metadata || EXCLUDED.metadata;  -- merge sem sobrescrever

-- =============================================================
-- VERIFICAÇÃO
-- =============================================================
SELECT id, name, slug, status,
       metadata->>'segmento' AS segmento,
       metadata->>'notas'    AS notas
FROM clients
ORDER BY name;
