CREATE TABLE IF NOT EXISTS config (
  key   text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE config ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='config' AND policyname='anon read config') THEN
    CREATE POLICY "anon read config" ON config FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='config' AND policyname='anon upsert config') THEN
    CREATE POLICY "anon upsert config" ON config FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Seed default bridge URL (will be overwritten by tunnel-watchdog)
INSERT INTO config (key, value) VALUES ('bridge_url', '') ON CONFLICT (key) DO NOTHING;
