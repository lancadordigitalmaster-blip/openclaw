#!/usr/bin/env node
const { readFileSync } = require('fs');
const { join } = require('path');
const { createClient } = require('@supabase/supabase-js');
const { generateHTML } = require('../../../_lib/builder');

const SUPABASE_URL = 'https://dqhiafxbljujahmpcdhf.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_KEY;

const data = JSON.parse(readFileSync(join(__dirname, 'victor-input.json'), 'utf-8'));
const template = readFileSync(join(__dirname, '../../../_lib/template.html'), 'utf-8');
const html = generateHTML(data, template);

const slug = 'victor';

async function run() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Upload HTML
  const { error: uploadErr } = await supabase.storage
    .from('proposals')
    .upload(`${slug}.html`, Buffer.from(html, 'utf-8'), {
      contentType: 'text/html; charset=utf-8',
      upsert: true,
    });

  if (uploadErr) {
    console.error('Upload error:', uploadErr.message);
    process.exit(1);
  }

  console.log('Storage upload OK');

  // Insert DB record
  const inv = data.investment || {};
  const amountNum = parseFloat((inv.amount || '0').replace(/\./g, '').replace(',', '.'));

  const { data: inserted, error: dbErr } = await supabase
    .from('proposals')
    .insert({
      client_name: data.client_name,
      service_type: data.service_type,
      amount: amountNum || null,
      currency: inv.currency || 'R$',
      suffix: inv.suffix || '/mês',
      status: 'open',
      template: 'classic',
      netlify_url: `https://propostas.wolfpacks.com.br/proposta/${slug}`,
      proposal_data: data,
    })
    .select('id')
    .single();

  if (dbErr) console.warn('DB insert warning:', dbErr.message);
  else console.log('DB record ID:', inserted.id);

  console.log('\nURL pública: https://propostas.wolfpacks.com.br/proposta/' + slug);
}

run().catch(e => { console.error(e); process.exit(1); });
