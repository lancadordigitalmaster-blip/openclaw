const { createClient } = require('@supabase/supabase-js');

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY,
);

async function syslog(level, message, details) {
  try { await sb.from('system_logs').insert({ source: 'track-view', level, message, details }); } catch {}
}

async function notifyWhatsApp(phone, msg) {
  if (!phone) return;
  try {
    // Busca URL atual do bridge no Supabase config
    const { data } = await sb.from('config').select('value').eq('key', 'bridge_url').single();
    const bridgeUrl = data?.value;
    if (!bridgeUrl) return;

    await fetch(`${bridgeUrl}/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ to: phone, text: msg }),
      signal: AbortSignal.timeout(5000),
    }).catch(() => {});
  } catch (_) {}
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const slug = req.query.slug || (req.body && req.body.slug);
  if (!slug) return res.status(400).json({ error: 'slug required' });

  try {
    // Busca proposta pelo slug direto
    const { data: rows } = await sb
      .from('proposals')
      .select('id, view_count, last_viewed_at, seller, client_name, service_type, whatsapp')
      .eq('slug', slug)
      .limit(1);

    if (!rows || !rows.length) {
      await syslog('warn', `Slug não encontrado: ${slug}`, { slug });
      return res.status(404).end();
    }

    const p = rows[0];
    const viewCount = (p.view_count || 0) + 1;
    const now = new Date().toISOString();

    await sb.from('proposals').update({
      view_count: viewCount,
      last_viewed_at: now,
    }).eq('id', p.id);

    // Log de atividade
    await sb.from('proposal_activities').insert({
      proposal_id: p.id,
      type: 'view',
      description: `Proposta visualizada pelo cliente (${viewCount}ª vez)`,
      actor: 'Cliente',
    }).catch(() => {});

    // Notificar na 1ª, 3ª e a cada 5 views
    const shouldNotify = viewCount === 1 || viewCount === 3 || (viewCount > 3 && viewCount % 5 === 0);
    if (shouldNotify) {
      const seller = p.seller || 'Sistema';
      const icon   = viewCount === 1 ? '🔥' : '👀';
      const intro  = viewCount === 1 ? `Proposta aberta pela 1ª vez!` : `Proposta vista ${viewCount}x`;
      const call   = viewCount === 1 ? '\n\nÉ o momento de entrar em contato! 📞' : '';

      // WhatsApp direto para o vendedor (se tiver número cadastrado na proposta)
      const waMsg = `${icon} *${intro}*\n\n📋 *${p.client_name}*\n💼 ${p.service_type || '—'}${call}`;
      await notifyWhatsApp(p.whatsapp, waMsg);
    }

    await syslog('info', `View #${viewCount}: ${p.client_name}`, { slug, client: p.client_name, views: viewCount });
    return res.status(200).json({ ok: true, views: viewCount });
  } catch (err) {
    console.error('[track-view]', err.message);
    await syslog('error', `Erro inesperado: ${err.message}`, { slug, stack: err.stack?.slice(0, 300) });
    return res.status(500).json({ error: err.message });
  }
};
