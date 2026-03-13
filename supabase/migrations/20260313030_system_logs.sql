CREATE TABLE IF NOT EXISTS system_logs (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL    DEFAULT now(),
  level       text        NOT NULL    DEFAULT 'info', -- info | warn | error | debug
  source      text        NOT NULL,                   -- parse-proposal | track-view | follow-up-alert | lost-analysis | wolf-monitor | etc
  message     text        NOT NULL,
  details     jsonb
);

CREATE INDEX IF NOT EXISTS system_logs_created_idx ON system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS system_logs_level_idx   ON system_logs(level);
CREATE INDEX IF NOT EXISTS system_logs_source_idx  ON system_logs(source);

ALTER TABLE system_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='system_logs' AND policyname='service role full access') THEN
    CREATE POLICY "service role full access" ON system_logs FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Auto-prune: keep only last 7 days (run manually or via cron)
-- DELETE FROM system_logs WHERE created_at < now() - interval '7 days';
