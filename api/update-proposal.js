const { readFileSync } = require('fs');
const { join } = require('path');
const { generateHTML } = require('../_lib/builder');
const { getSupabaseClient } = require('../_lib/supabase-client');
const { toSlug } = require('../_lib/slug-utils');
const { setCors } = require('../_lib/cors');

const TEMPLATES = {
  classic: readFileSync(join(__dirname, '../_lib/template.html'), 'utf-8'),
  wesley: readFileSync(join(__dirname, '../_lib/template-wesley.html'), 'utf-8'),
};

module.exports = async function handler(req, res) {
  if (setCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    // Autenticação via API key
    const apiKey = req.headers['x-api-key'];
    const expectedKey = process.env.WOLF_API_KEY;
    if (!expectedKey || !apiKey || apiKey !== expectedKey) {
      return res.status(401).json({ error: 'API key invalida ou ausente' });
    }

    const { id, proposal_data, seller } = req.body || {};

    if (!id) return res.status(400).json({ error: 'ID da proposta obrigatorio' });
    if (!proposal_data || !proposal_data.client_name) {
      return res.status(400).json({ error: 'proposal_data invalido' });
    }

    const supabase = getSupabaseClient();

    // Fetch current record to preserve template
    const { data: current } = await supabase.from('proposals').select('template').eq('id', id).single();
    const templateName = (current?.template && TEMPLATES[current.template]) ? current.template : 'classic';
    const templateHTML = TEMPLATES[templateName];

    // Generate new HTML from updated data using original template
    const html = generateHTML(proposal_data, templateHTML, { templateName });

    // Derive slug from client_name
    const clientSlug = toSlug(proposal_data.client_name);

    // Upload to Supabase Storage
    const { error: uploadErr } = await supabase.storage
      .from('proposals')
      .upload(`${clientSlug}.html`, Buffer.from(html, 'utf-8'), {
        contentType: 'text/html; charset=utf-8',
        upsert: true,
      });

    if (uploadErr) return res.status(500).json({ error: `Erro ao salvar: ${uploadErr.message}` });

    const baseUrl = process.env.PROPOSAL_BASE_URL || 'https://comercial.wolfpacks.com.br';
    const publicUrl = `${baseUrl}/proposta/${clientSlug}`;

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
    }).catch((err) => console.error('[update-proposal] activity insert error:', err.message));

    return res.status(200).json({ ok: true, url: publicUrl });
  } catch (err) {
    console.error('update-proposal error:', err);
    return res.status(500).json({ error: err.message });
  }
};
