const { getSupabaseClient } = require('../_lib/supabase-client');
const { timingSafeEqual } = require('crypto');
const { setCors } = require('../_lib/cors');
const https = require('https');

function safeCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

const ALLOWED_BRIDGE_HOSTS = new Set(['127.0.0.1', 'localhost']);

function pingUrl(url, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const u = new URL(url + '/status');
      if (!ALLOWED_BRIDGE_HOSTS.has(u.hostname)) return resolve(false);
      const mod = u.protocol === 'https:' ? https : require('http');
      const req = mod.get(u.toString(), { timeout: timeoutMs }, (res) => {
        resolve(true);
        res.resume();
      });
      req.on('timeout', () => { req.destroy(); resolve(false); });
      req.on('error', () => resolve(false));
    } catch {
      resolve(false);
    }
  });
}

module.exports = async function handler(req, res) {
  if (setCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const adminKey = req.headers['x-admin-key'];
  const expectedKey = process.env.ADMIN_SECRET;
  if (!expectedKey) {
    return res.status(500).json({ error: 'ADMIN_SECRET env var not configured' });
  }
  if (!adminKey || !safeCompare(adminKey, expectedKey)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const sb = getSupabaseClient();

  // Auto-prune system_logs older than 7 days (fire-and-forget, runs on each admin request)
  const pruneDate = new Date(Date.now() - 7 * 86400000).toISOString();
  sb.from('system_logs').delete().lt('created_at', pruneDate)
    .then(({ error }) => { if (error) console.error('log prune error:', error.message); })
    .catch((err) => console.error('log prune error:', err.message));

  // Execute all independent queries in parallel
  const [proposalsResult, activitiesResult, configResult, cronResult, logsResult] = await Promise.all([
    sb.from('proposals')
      .select('id, client_name, seller, status, amount, service_type, created_at, view_count, slug, last_viewed_at')
      .order('created_at', { ascending: false })
      .limit(20)
      .then(r => r.data || [])
      .catch((err) => { console.error('proposals fetch error:', err.message); return []; }),

    sb.from('proposal_activities')
      .select('id, proposal_id, type, description, actor, created_at, proposals(client_name)')
      .order('created_at', { ascending: false })
      .limit(30)
      .then(r => r.data || [])
      .catch((err) => { console.error('activities fetch error:', err.message); return []; }),

    sb.from('config')
      .select('*')
      .then(r => r.data || [])
      .catch((err) => { console.error('config fetch error:', err.message); return []; }),

    sb.from('cron_status')
      .select('*')
      .order('name')
      .then(r => r.data || [])
      .catch((err) => { console.error('cron_status fetch error:', err.message); return []; }),

    sb.from('system_logs')
      .select('id, created_at, level, source, message, details')
      .order('created_at', { ascending: false })
      .limit(200)
      .then(r => r.data || [])
      .catch((err) => { console.error('logs fetch error:', err.message); return []; }),
  ]);

  // Compute stats from proposals
  const stats = { open_count: 0, won_count: 0, lost_count: 0, total_pipeline: 0, total_revenue: 0, views_today: 0 };
  const today = new Date().toISOString().slice(0, 10);
  for (const p of proposalsResult) {
    const amt = parseFloat(p.amount) || 0;
    if (p.status === 'open' || p.status === 'sent') {
      stats.open_count++;
      stats.total_pipeline += amt;
    } else if (p.status === 'won') {
      stats.won_count++;
      stats.total_revenue += amt;
    } else if (p.status === 'lost') {
      stats.lost_count++;
    }
    if (p.last_viewed_at && p.last_viewed_at.slice(0, 10) === today) {
      stats.views_today += p.view_count || 0;
    }
  }

  // Bridge ping (depends on config result)
  const bridgeRow = configResult.find((r) => r.key === 'bridge_url');
  const bridgeUrl = bridgeRow?.value || null;
  let bridge = { online: false, url: null };
  if (bridgeUrl) {
    try {
      const online = await pingUrl(bridgeUrl, 3000);
      bridge = { online, url: bridgeUrl };
    } catch {
      bridge = { online: false, url: bridgeUrl };
    }
  }

  // Error count (last 24h)
  const cutoff24h = new Date(Date.now() - 86400000).toISOString();
  const errorCount24h = logsResult.filter(l => l.level === 'error' && l.created_at >= cutoff24h).length;

  return res.status(200).json({
    stats,
    proposals: proposalsResult,
    activities: activitiesResult,
    config: configResult,
    bridge,
    logs: logsResult,
    errorCount24h,
    cronStatus: cronResult,
  });
};
