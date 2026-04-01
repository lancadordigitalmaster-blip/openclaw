#!/usr/bin/env node
// Run a SQL migration against Supabase using the service role key
// Usage: node scripts/run-migration.js <path-to-sql>

const { readFileSync } = require('fs');
const { join } = require('path');

// Load env
const envPath = join(process.env.HOME, '.openclaw', '.env');
try {
  const envContent = readFileSync(envPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const match = line.match(/^([A-Z_]+)=(.+)$/);
    if (match) {
      const val = match[2].replace(/^["']|["']$/g, '').trim();
      if (!process.env[match[1]]) process.env[match[1]] = val;
    }
  }
} catch {}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const sqlFile = process.argv[2];
if (!sqlFile) {
  console.error('Usage: node scripts/run-migration.js <path-to-sql>');
  process.exit(1);
}

const sql = readFileSync(sqlFile, 'utf-8');

// Split into individual statements (skip comments and empty lines)
const statements = sql
  .split(/;\s*$/m)
  .map(s => s.trim())
  .filter(s => s && !s.startsWith('--'));

async function runSQL(statement) {
  // Use Supabase's PostgREST RPC or direct pg connection
  // Since we don't have direct pg access, we'll use the management API
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
  });
  return res;
}

// Alternative: use createClient and .rpc() for individual DDL
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function main() {
  console.log(`Running migration: ${sqlFile}`);
  console.log(`Supabase: ${SUPABASE_URL}`);
  console.log(`Statements: ${statements.length}`);
  console.log('---');

  // Supabase JS client doesn't support raw SQL.
  // We need to use the SQL endpoint that's available via management API.
  // Let's try the Supabase pg_net or pg extension approach.

  // Actually, the best approach without psql is via Supabase Dashboard SQL Editor
  // or via the management API with an access token.
  // Let's output the SQL in a ready-to-paste format for the SQL Editor.

  console.log('⚠️  Supabase JS client não suporta SQL raw.');
  console.log('');
  console.log('Opções para executar a migration:');
  console.log('1. Cole o SQL no Supabase Dashboard → SQL Editor');
  console.log(`   URL: https://supabase.com/dashboard/project/dqhiafxbljujahmpcdhf/sql`);
  console.log('');
  console.log('2. Instale psql e rode:');
  console.log(`   psql "postgresql://postgres:[PASSWORD]@db.dqhiafxbljujahmpcdhf.supabase.co:5432/postgres" -f ${sqlFile}`);
  console.log('');
  console.log('3. Use supabase db push (requer migrations sincronizadas)');
  console.log('');
  console.log('--- SQL A EXECUTAR ---');
  console.log(sql);
}

main().catch(console.error);
