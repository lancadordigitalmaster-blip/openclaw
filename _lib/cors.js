const DEFAULT_ORIGINS = [
  'https://comercial.wolfpacks.com.br',
  'https://wolf-comercial.vercel.app',
  'http://localhost:8765',
  'http://127.0.0.1:8765',
];

function getAllowedOrigins() {
  const envOrigins = process.env.ALLOWED_ORIGINS;
  if (envOrigins) {
    return envOrigins.split(',').map(o => o.trim()).filter(Boolean);
  }
  return DEFAULT_ORIGINS;
}

/**
 * Set CORS headers. Returns true if this was a preflight (OPTIONS) request
 * and the response was already sent.
 */
function setCors(req, res, { methods = 'GET, POST, OPTIONS', headers = 'Content-Type, x-api-key, x-admin-key' } = {}) {
  const origin = req.headers.origin;
  const allowed = getAllowedOrigins();

  if (origin && allowed.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  } else if (!origin) {
    // Server-to-server requests (no Origin header) — allow
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
  // If origin is present but not in allowed list, no CORS header is set (browser blocks it)

  res.setHeader('Access-Control-Allow-Methods', methods);
  res.setHeader('Access-Control-Allow-Headers', headers);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return true;
  }

  return false;
}

module.exports = { setCors, getAllowedOrigins };
