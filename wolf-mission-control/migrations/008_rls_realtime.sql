-- =============================================================
-- Wolf Mission Control — Migration 008
-- Adiciona: RLS leitura para dashboard + Realtime publication
-- Criado: 2026-03-05 | ADDITIVE — não quebra schema existente
-- =============================================================

-- =============================================================
-- RLS READ — Dashboard pode ler dados via anon/authenticated
-- (Service role já tem acesso total via migration 001)
-- =============================================================

-- agents: qualquer sessão autenticada pode ler (para exibir no dashboard)
CREATE POLICY "read_agents" ON agents
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- missions: leitura autenticada (Netto vê todas)
CREATE POLICY "read_missions" ON missions
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- mission_outputs: leitura autenticada
CREATE POLICY "read_outputs" ON mission_outputs
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- handoffs: leitura autenticada
CREATE POLICY "read_handoffs" ON handoffs
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- agent_memory: somente service_role (dados sensíveis de clientes)
-- Não adicionar política de leitura aqui — service_role já cobre

-- clients: leitura autenticada
CREATE POLICY "read_clients" ON clients
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- system_logs: leitura autenticada (debug no dashboard)
CREATE POLICY "read_logs" ON system_logs
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- escalations: leitura autenticada (alertas visíveis no dashboard)
CREATE POLICY "read_escalations" ON escalations
  FOR SELECT USING (auth.role() IN ('anon', 'authenticated'));

-- =============================================================
-- REALTIME — Publicar tabelas para o dashboard em tempo real
-- Dashboard usa postgres_changes subscriptions
-- =============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE missions;
ALTER PUBLICATION supabase_realtime ADD TABLE handoffs;
ALTER PUBLICATION supabase_realtime ADD TABLE escalations;
ALTER PUBLICATION supabase_realtime ADD TABLE agents;

-- Nota: agent_memory e system_logs não são publicados
-- (volume alto + dados sensíveis)

-- =============================================================
-- INDEXES ADICIONAIS DE PERFORMANCE
-- Para queries do dashboard e realtime
-- =============================================================

-- Missões por status + data (query principal do kanban)
CREATE INDEX IF NOT EXISTS idx_missions_status_created
  ON missions(status, created_at DESC);

-- Missões por prioridade + status (queue do orquestrador)
CREATE INDEX IF NOT EXISTS idx_missions_priority_status
  ON missions(priority_score DESC, status)
  WHERE status NOT IN ('done', 'cancelled');

-- Missões atualizadas recentemente (realtime polling fallback)
CREATE INDEX IF NOT EXISTS idx_missions_updated
  ON missions(updated_at DESC)
  WHERE updated_at IS NOT NULL;

-- Outputs por missão ordenados (para pegar último output)
CREATE INDEX IF NOT EXISTS idx_outputs_mission_created
  ON mission_outputs(mission_id, created_at DESC);

-- Handoffs pendentes por agente destino
CREATE INDEX IF NOT EXISTS idx_handoffs_pending
  ON handoffs(to_agent_id, created_at DESC)
  WHERE status = 'pending';

-- Escalações abertas por nível
CREATE INDEX IF NOT EXISTS idx_escalations_open
  ON escalations(level, created_at DESC)
  WHERE resolved_at IS NULL;

-- =============================================================
-- VERIFICAÇÃO
-- =============================================================
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename IN ('agents', 'missions', 'mission_outputs', 'handoffs', 'clients', 'system_logs', 'escalations')
  AND policyname LIKE 'read_%'
ORDER BY tablename, policyname;
