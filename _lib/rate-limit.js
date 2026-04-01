const buckets = new Map();

const CLEANUP_INTERVAL = 60_000;
let lastCleanup = Date.now();

function cleanup(windowMs) {
  const now = Date.now();
  if (now - lastCleanup < CLEANUP_INTERVAL) return;
  lastCleanup = now;
  for (const [key, entry] of buckets) {
    if (now - entry.start > windowMs * 2) buckets.delete(key);
  }
}

/**
 * Simple sliding-window rate limiter for serverless (in-memory, per-instance).
 * @param {string} key - Identifier (e.g. IP address)
 * @param {number} maxRequests - Max requests per window
 * @param {number} windowMs - Window size in milliseconds
 * @returns {{ allowed: boolean, remaining: number, retryAfterMs: number }}
 */
function checkRateLimit(key, maxRequests, windowMs) {
  cleanup(windowMs);

  const now = Date.now();
  let entry = buckets.get(key);

  if (!entry || now - entry.start > windowMs) {
    entry = { start: now, count: 0 };
    buckets.set(key, entry);
  }

  entry.count++;

  if (entry.count > maxRequests) {
    const retryAfterMs = windowMs - (now - entry.start);
    return { allowed: false, remaining: 0, retryAfterMs };
  }

  return { allowed: true, remaining: maxRequests - entry.count, retryAfterMs: 0 };
}

/**
 * Express/Vercel middleware-style rate limit check.
 * Returns true if request was blocked (response already sent).
 */
function rateLimit(req, res, { maxRequests = 10, windowMs = 60_000, keyFn } = {}) {
  const ip = keyFn ? keyFn(req) : (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown');
  const { allowed, retryAfterMs } = checkRateLimit(ip, maxRequests, windowMs);

  if (!allowed) {
    res.setHeader('Retry-After', Math.ceil(retryAfterMs / 1000));
    res.status(429).json({ error: 'Too many requests', retryAfterMs });
    return true;
  }

  return false;
}

module.exports = { checkRateLimit, rateLimit };
