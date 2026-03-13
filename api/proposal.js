const { createClient } = require('@supabase/supabase-js');

module.exports = async function handler(req, res) {
  const slug = req.query.slug;
  if (!slug || !/^[a-z0-9-]+$/.test(slug)) {
    return res.status(400).send('Invalid slug');
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).send('Server configuration error');
  }

  const supabase = createClient(supabaseUrl, supabaseKey);
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
