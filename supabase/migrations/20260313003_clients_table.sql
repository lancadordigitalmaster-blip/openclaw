CREATE TABLE IF NOT EXISTS clients (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  service_type text,
  monthly_value numeric(10,2),
  contract_start date,
  contract_end date,
  seller text,
  seller_whatsapp text,
  status text NOT NULL DEFAULT 'active',
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon all clients" ON clients FOR ALL USING (true) WITH CHECK (true);
