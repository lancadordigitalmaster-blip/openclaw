const { createClient } = require('@supabase/supabase-js');
const { readFileSync } = require('fs');
const { join } = require('path');
const { generateHTML } = require('../_lib/builder');

const TEMPLATES = {
  classic: readFileSync(join(__dirname, '../_lib/template.html'), 'utf-8'),
  wesley: readFileSync(join(__dirname, '../_lib/template-wesley.html'), 'utf-8'),
};

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { id, proposal_data, seller } = req.body || {};

    if (!id) return res.status(400).json({ error: 'ID da proposta obrigatorio' });
    if (!proposal_data || !proposal_data.client_name) {
      return res.status(400).json({ error: 'proposal_data invalido' });
    }

    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    // Fetch current record to preserve template
    const { data: current } = await supabase.from('proposals').select('template').eq('id', id).single();
    const templateName = (current?.template && TEMPLATES[current.template]) ? current.template : 'classic';
    const templateHTML = TEMPLATES[templateName];

    // Generate new HTML from updated data using original template
    const html = generateHTML(proposal_data, templateHTML, { templateName });

    // Derive slug from client_name
    const clientSlug = proposal_data.client_name
      .toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

    // Upload to Supabase Storage
    const { error: uploadErr } = await supabase.storage
      .from('proposals')
      .upload(`${clientSlug}.html`, Buffer.from(html, 'utf-8'), {
        contentType: 'text/html; charset=utf-8',
        upsert: true,
      });

    if (uploadErr) return res.status(500).json({ error: `Erro ao salvar: ${uploadErr.message}` });

    const publicUrl = `https://comercial.wolfpacks.com.br/proposta/${clientSlug}`;

    const inv = proposal_data.investment || {};
    const amountNum = parseFloat((inv.amount || '0').toString().replace(/\./g, '').replace(',', '.'));

    // Update DB record
    const { error: dbErr } = await supabase.from('proposals').update({
      client_name: proposal_data.client_name,
      slug: clientSlug,
      service_type: proposal_data.service_type || null,
      amount: amountNum || null,
      currency: inv.currency || 'R$',
      suffix: inv.suffix || '/mês',
      netlify_url: publicUrl,
      proposal_data,
    }).eq('id', id);

    if (dbErr) console.error('DB update error:', dbErr.message);

    // Log activity
    const actor = seller || 'Sistema';
    await supabase.from('proposal_activities').insert({
      proposal_id: id,
      type: 'updated',
      description: `Proposta atualizada por ${actor}`,
      actor,
    }).catch(() => {});

    return res.status(200).json({ ok: true, url: publicUrl });
  } catch (err) {
    console.error('update-proposal error:', err);
    return res.status(500).json({ error: err.message });
  }
};
