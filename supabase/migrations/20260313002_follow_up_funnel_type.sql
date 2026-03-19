ALTER TABLE proposals ADD COLUMN IF NOT EXISTS follow_up_date date;
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS funnel_type text NOT NULL DEFAULT 'prospecting';
