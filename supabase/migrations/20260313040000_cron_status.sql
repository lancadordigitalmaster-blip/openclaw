CREATE TABLE IF NOT EXISTS cron_status (
  name        text        PRIMARY KEY,  -- identificador do cron
  label       text,                     -- nome amigável
  schedule    text,                     -- ex: "08:00 diário"
  last_run    timestamptz,
  last_status text DEFAULT 'unknown',   -- ok | error | running | unknown
  last_message text,
  next_run    timestamptz,
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE cron_status ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='cron_status' AND policyname='service role cron') THEN
    CREATE POLICY "service role cron" ON cron_status FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Seed com os crons conhecidos
INSERT INTO cron_status (name, label, schedule) VALUES
  ('follow-up-alert',   'Follow-up Alert',      '08:00 diário'),
  ('lost-analysis',     'Análise de Perdas',     '09:00 segundas'),
  ('design-report',     'Relatório Design',      '22:00 diário'),
  ('sales-report',      'Relatório Vendas',      '22:00 diário'),
  ('wolf-monitor',      'Wolf Monitor',          'cada 30min'),
  ('tunnel-watchdog',   'Tunnel Watchdog',       'cada 5min'),
  ('git-sync',          'Git Auto-sync',         'cada 30min')
ON CONFLICT (name) DO NOTHING;
