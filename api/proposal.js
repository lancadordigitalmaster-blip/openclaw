const { getSupabaseClient } = require('../_lib/supabase-client');
const { isValidSlug } = require('../_lib/slug-utils');

module.exports = async function handler(req, res) {
  const slug = req.query.slug;
  if (!slug || !isValidSlug(slug)) {
    return res.status(400).send('Invalid slug');
  }

  const supabase = getSupabaseClient();
  const { data, error } = await supabase.storage
    .from('proposals')
    .download(`${slug}.html`);

  if (error || !data) {
    return res.status(404).send('Proposta não encontrada');
  }

  const html = await data.text();
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=60, s-maxage=300');
  return res.status(200).send(html);
};
