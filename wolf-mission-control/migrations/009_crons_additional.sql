-- =============================================================
-- Wolf Mission Control — Migration 009
-- Adiciona: pg_cron jobs para cleanup e relatório diário
-- Criado: 2026-03-05 | ADDITIVE — não quebra schema existente
-- Job existente: recheck-stale-missions (migration 001) — mantido
-- =============================================================

-- =============================================================
-- FUNÇÃO: cleanup_old_memory
-- Remove memórias antigas e pouco relevantes
-- Mantém: memórias permanentes (expires_at NULL) + relevância > 0.5
-- =============================================================
CREATE OR REPLACE FUNCTION cleanup_old_memory()
RETURNS void AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM agent_memory
  WHERE expires_at < NOW()
     OR (relevance < 0.3 AND created_at < NOW() - INTERVAL '7 days');

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  IF deleted_count > 0 THEN
    INSERT INTO system_logs (level, source, message, payload)
    VALUES ('info', 'pg_cron', 'Cleanup de memória concluído',
            jsonb_build_object('deleted_records', deleted_count, 'ran_at', NOW()));
  END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- FUNÇÃO: cleanup_old_logs
-- Remove logs do sistema mais antigos que 7 dias
-- Escalações resolvidas há mais de 30 dias também são limpas
-- =============================================================
CREATE OR REPLACE FUNCTION cleanup_old_logs()
RETURNS void AS $$
DECLARE
  logs_deleted       INTEGER;
  escalations_deleted INTEGER;
BEGIN
  -- Logs mais antigos que 7 dias (info/warning)
  DELETE FROM system_logs
  WHERE created_at < NOW() - INTERVAL '7 days'
    AND level IN ('info', 'warning');

  GET DIAGNOSTICS logs_deleted = ROW_COUNT;

  -- Escalações resolvidas há mais de 30 dias
  DELETE FROM escalations
  WHERE resolved_at < NOW() - INTERVAL '30 days';

  GET DIAGNOSTICS escalations_deleted = ROW_COUNT;

  INSERT INTO system_logs (level, source, message, payload)
  VALUES ('info', 'pg_cron', 'Cleanup de logs concluído',
          jsonb_build_object(
            'logs_deleted', logs_deleted,
            'escalations_cleaned', escalations_deleted,
            'ran_at', NOW()
          ));
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- FUNÇÃO: generate_daily_report
-- Compila métricas do dia e insere para o telegram-notifier enviar
-- =============================================================
CREATE OR REPLACE FUNCTION generate_daily_report()
RETURNS void AS $$
DECLARE
  report_payload JSONB;
  today_start    TIMESTAMPTZ := DATE_TRUNC('day', NOW());
BEGIN
  SELECT jsonb_build_object(
    'date',             to_char(NOW(), 'DD/MM/YYYY'),
    'missions_today',   COUNT(*) FILTER (WHERE created_at >= today_start),
    'completed_today',  COUNT(*) FILTER (WHERE status = 'done' AND updated_at >= today_start),
    'blocked_open',     COUNT(*) FILTER (WHERE status = 'blocked'),
    'in_progress',      COUNT(*) FILTER (WHERE status = 'in_progress'),
    'total_tokens',     (SELECT COALESCE(SUM(tokens_used), 0) FROM mission_outputs WHERE created_at >= today_start),
    'avg_quality',      ROUND((SELECT AVG(quality)::NUMERIC FROM mission_outputs WHERE created_at >= today_start AND quality IS NOT NULL), 2)
  )
  INTO report_payload
  FROM missions;

  -- Insere log para edge function telegram-notifier processar
  INSERT INTO system_logs (level, source, message, payload)
  VALUES ('info', 'daily-report', 'Relatório diário gerado', report_payload);

  -- Insere escalação tipo info para notificação
  INSERT INTO escalations (type, level, title, message, metadata)
  VALUES (
    'alert', 'L1',
    '📊 Wolf — Relatório do dia ' || to_char(NOW(), 'DD/MM'),
    'Missões hoje: ' || (report_payload->>'missions_today') ||
    ' | Concluídas: ' || (report_payload->>'completed_today') ||
    ' | Bloqueadas: ' || (report_payload->>'blocked_open'),
    report_payload
  );
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- AGENDAR JOBS
-- Remover se existir (idempotente)
-- =============================================================

SELECT cron.unschedule('wolf-cleanup-memory')  WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'wolf-cleanup-memory'
);
SELECT cron.unschedule('wolf-cleanup-logs')  WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'wolf-cleanup-logs'
);
SELECT cron.unschedule('wolf-daily-report')  WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'wolf-daily-report'
);

-- Cleanup de memória: todo dia às 3h
SELECT cron.schedule(
  'wolf-cleanup-memory',
  '0 3 * * *',
  'SELECT cleanup_old_memory()'
);

-- Cleanup de logs: toda segunda-feira às 4h
SELECT cron.schedule(
  'wolf-cleanup-logs',
  '0 4 * * 1',
  'SELECT cleanup_old_logs()'
);

-- Relatório diário: dias úteis às 18h (Horário de Brasília = UTC-3 → 21h UTC)
SELECT cron.schedule(
  'wolf-daily-report',
  '0 21 * * 1-5',
  'SELECT generate_daily_report()'
);

-- =============================================================
-- VERIFICAÇÃO
-- =============================================================
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname LIKE 'wolf-%' OR jobname LIKE 'recheck-%'
ORDER BY jobname;
