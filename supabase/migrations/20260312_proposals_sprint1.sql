ALTER TABLE proposals ADD COLUMN IF NOT EXISTS expected_close_date date;
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS view_count integer NOT NULL DEFAULT 0;
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS last_viewed_at timestamptz;
