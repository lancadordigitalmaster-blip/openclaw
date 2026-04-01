CREATE TABLE IF NOT EXISTS proposal_activities (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  proposal_id uuid REFERENCES proposals(id) ON DELETE CASCADE,
  type        text NOT NULL,       -- created, won, lost, edit, view, stale, note
  description text NOT NULL,
  actor       text DEFAULT 'Sistema',
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pa_proposal_id ON proposal_activities(proposal_id);
CREATE INDEX IF NOT EXISTS idx_pa_created_at  ON proposal_activities(created_at DESC);

-- RLS: allow anon read/insert (same pattern as proposals)
ALTER TABLE proposal_activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon read activities"   ON proposal_activities FOR SELECT USING (true);
CREATE POLICY "anon insert activities" ON proposal_activities FOR INSERT WITH CHECK (true);
