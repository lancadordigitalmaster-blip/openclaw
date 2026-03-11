-- =============================================================
-- Wolf Agency — Agent Skills Seed Data
-- Insira no Supabase após rodar migration 002
-- =============================================================

-- GABI — Traffic Manager
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Meta Ads Management', 'marketing', 5, TRUE, 'Gerenciamento avançado de campanhas Meta', ARRAY['Meta Ads API', 'Meta Business Suite'], 3
FROM agents WHERE slug = 'gabi'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'ROI Optimization', 'marketing', 5, TRUE, 'Otimização contínua de retorno', ARRAY['Google Analytics', 'Meta Pixel'], 4
FROM agents WHERE slug = 'gabi'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'CPC/CPA Management', 'marketing', 4, TRUE, 'Redução de custo por clique/ação', ARRAY['Ads Dashboard'], 3.5
FROM agents WHERE slug = 'gabi'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Organic Content Strategy', 'marketing', 2, FALSE, 'Estratégia de conteúdo orgânico', ARRAY[], 0.5
FROM agents WHERE slug = 'gabi'
ON CONFLICT DO NOTHING;

-- LUNA — Social Media
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Copywriting', 'marketing', 5, TRUE, 'Copy persuasivo para redes', ARRAY['Notion', 'Canva'], 4
FROM agents WHERE slug = 'luna'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Content Calendar Management', 'marketing', 5, TRUE, 'Planejamento de conteúdo', ARRAY['Meta Business Suite', 'Buffer'], 3.5
FROM agents WHERE slug = 'luna'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Engagement & Community', 'marketing', 4, TRUE, 'Gestão de comunidade online', ARRAY['Instagram', 'TikTok'], 3
FROM agents WHERE slug = 'luna'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Technical SEO', 'marketing', 2, FALSE, 'SEO técnico aprofundado', ARRAY[], 1
FROM agents WHERE slug = 'luna'
ON CONFLICT DO NOTHING;

-- SAGE — SEO
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Keyword Research', 'marketing', 5, TRUE, 'Pesquisa e análise de palavras-chave', ARRAY['Google Keyword Planner', 'Ahrefs', 'SEMrush'], 4
FROM agents WHERE slug = 'sage'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Technical SEO Audit', 'marketing', 4, TRUE, 'Auditoria técnica e otimização', ARRAY['Google Search Console', 'Lighthouse'], 3.5
FROM agents WHERE slug = 'sage'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Content Optimization', 'marketing', 5, TRUE, 'Otimização de conteúdo pra ranking', ARRAY['Yoast SEO'], 4
FROM agents WHERE slug = 'sage'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Paid Ads Strategy', 'marketing', 2, FALSE, 'Estratégia de ads pagos', ARRAY[], 1
FROM agents WHERE slug = 'sage'
ON CONFLICT DO NOTHING;

-- NOVA — Strategy
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Market Research', 'strategy', 5, TRUE, 'Pesquisa profunda de mercado', ARRAY['Google Trends', 'Semrush'], 4
FROM agents WHERE slug = 'nova'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Competitor Analysis', 'strategy', 5, TRUE, 'Análise SWOT de concorrentes', ARRAY['Behance', 'Pinterest'], 4
FROM agents WHERE slug = 'nova'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Positioning & Messaging', 'strategy', 4, TRUE, 'Posicionamento e mensagem de marca', ARRAY['Notion'], 3.5
FROM agents WHERE slug = 'nova'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Execution & Deployment', 'dev', 1, FALSE, 'Execução técnica de campanhas', ARRAY[], 0
FROM agents WHERE slug = 'nova'
ON CONFLICT DO NOTHING;

-- TITAN — Tech Lead
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'System Architecture', 'dev', 5, TRUE, 'Design de arquitetura de sistemas', ARRAY['Figma', 'Miro'], 5
FROM agents WHERE slug = 'titan'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Code Review & Standards', 'dev', 5, TRUE, 'Revisão de código e padrões', ARRAY['GitHub'], 5
FROM agents WHERE slug = 'titan'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Team Leadership', 'strategy', 4, TRUE, 'Liderança técnica de squad', ARRAY['Notion', 'ClickUp'], 4
FROM agents WHERE slug = 'titan'
ON CONFLICT DO NOTHING;

-- PIXEL — Frontend
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'React/Vue Development', 'dev', 5, TRUE, 'Desenvolvimento frontend moderno', ARRAY['React', 'TypeScript', 'Tailwind'], 4
FROM agents WHERE slug = 'pixel'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'UI/UX Design', 'design', 4, TRUE, 'Design de interfaces e experiência', ARRAY['Figma', 'Framer'], 3.5
FROM agents WHERE slug = 'pixel'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Performance Optimization', 'dev', 4, TRUE, 'Otimização de performance frontend', ARRAY['Lighthouse', 'DevTools'], 3
FROM agents WHERE slug = 'pixel'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Backend Integration', 'dev', 2, FALSE, 'Integração com backend', ARRAY['REST', 'GraphQL'], 1.5
FROM agents WHERE slug = 'pixel'
ON CONFLICT DO NOTHING;

-- FORGE — Backend
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'API Development', 'dev', 5, TRUE, 'Desenvolvimento de APIs robustas', ARRAY['Node.js', 'Python', 'TypeScript'], 5
FROM agents WHERE slug = 'forge'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Database Design', 'dev', 4, TRUE, 'Design e otimização de BD', ARRAY['PostgreSQL', 'MongoDB'], 4
FROM agents WHERE slug = 'forge'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Security & Auth', 'dev', 4, TRUE, 'Implementação segura de auth', ARRAY['JWT', 'OAuth2'], 4
FROM agents WHERE slug = 'forge'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Frontend Integration', 'dev', 2, FALSE, 'Integração com frontend', ARRAY[], 1.5
FROM agents WHERE slug = 'forge'
ON CONFLICT DO NOTHING;

-- VEGA — QA/Data
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Test Automation', 'dev', 5, TRUE, 'Automação de testes', ARRAY['Cypress', 'Jest', 'Selenium'], 4
FROM agents WHERE slug = 'vega'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Data Analytics', 'strategy', 5, TRUE, 'Análise de dados e BI', ARRAY['SQL', 'Tableau', 'Looker'], 4
FROM agents WHERE slug = 'vega'
ON CONFLICT DO NOTHING;

INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength, description, tools, experience_years)
SELECT id, 'Bug Investigation', 'dev', 4, TRUE, 'Investigação e triagem de bugs', ARRAY['GitHub Issues'], 3
FROM agents WHERE slug = 'vega'
ON CONFLICT DO NOTHING;

-- Adicione mais agents conforme necessário
-- ...

-- =============================================================
-- VERIFICAÇÃO
-- =============================================================
-- SELECT * FROM agent_capability_summary;
