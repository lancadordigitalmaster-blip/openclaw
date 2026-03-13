const https = require('https');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://dqhiafxbljujahmpcdhf.supabase.co';

module.exports = async function handler(req, res) {
  const slug = req.query.slug;
  if (!slug || !/^[a-z0-9-]+$/.test(slug)) {
    return res.status(400).send('Invalid proposal slug');
  }

  const storageUrl = `${SUPABASE_URL}/storage/v1/object/public/proposals/${slug}.html`;

  return new Promise((resolve) => {
    https.get(storageUrl, (upstream) => {
      if (upstream.statusCode === 404) {
        res.status(404).send('Proposta não encontrada');
        return resolve();
      }
      if (upstream.statusCode !== 200) {
        res.status(502).send('Erro ao carregar proposta');
        return resolve();
      }
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cache-Control', 'public, max-age=300');
      upstream.pipe(res);
      upstream.on('end', resolve);
    }).on('error', () => {
      res.status(502).send('Erro de conexão');
      resolve();
    });
  });
};
