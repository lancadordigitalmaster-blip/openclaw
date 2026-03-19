const { createClient } = require('@supabase/supabase-js');
const https = require('https');

function pingUrl(url, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const u = new URL(url + '/status');
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
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-admin-key');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const adminKey = req.headers['x-admin-key'];
  const expectedKey = process.env.ADMIN_SECRET || 'wolf2026';
  if (!adminKey || adminKey !== expectedKey) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({ error: 'Missing Supabase env vars' });
  }

  const sb = createClient(supabaseUrl, supabaseKey);

  // --- Proposals ---
  let proposals = [];
  let stats = {
    open_count: 0,
    won_count: 0,
    lost_count: 0,
    total_pipeline: 0,
    total_revenue: 0,
    views_today: 0,
  };

  try {
    const { data: allProposals } = await sb
      .from('proposals')
      .select('id, client_name, seller, status, amount, service_type, created_at, view_count, slug, last_viewed_at')
      .order('created_at', { ascending: false })
      .limit(20);

    if (allProposals) {
      proposals = allProposals;

      const today = new Date().toISOString().slice(0, 10);

      for (const p of allProposals) {
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
    }
  } catch (err) {
    console.error('proposals fetch error:', err.message);
    proposals = [];
  }

  // --- Activities ---
  let activities = [];
  try {
    const { data: acts } = await sb
      .from('proposal_activities')
      .select('id, proposal_id, type, description, actor, created_at, proposals(client_name)')
      .order('created_at', { ascending: false })
      .limit(30);

    if (acts) activities = acts;
  } catch (err) {
    console.error('activities fetch error:', err.message);
    activities = [];
  }

  // --- Config ---
  let config = [];
  let bridgeUrl = null;
  try {
    const { data: cfg } = await sb.from('config').select('*');
    if (cfg) {
      config = cfg;
      const bridgeRow = cfg.find((r) => r.key === 'bridge_url');
      if (bridgeRow) bridgeUrl = bridgeRow.value || null;
    }
  } catch (err) {
    console.error('config fetch error:', err.message);
    config = [];
  }

  // --- Bridge ping ---
  let bridge = { online: false, url: null };
  if (bridgeUrl) {
    try {
      const online = await pingUrl(bridgeUrl, 3000);
      bridge = { online, url: bridgeUrl };
    } catch {
      bridge = { online: false, url: bridgeUrl };
    }
  }

  // --- Cron Status ---
  let cronStatus = [];
  try {
    const { data: cronRows } = await sb.from('cron_status').select('*').order('name');
    if (cronRows) cronStatus = cronRows;
  } catch (err) {
    console.error('cron_status fetch error:', err.message);
  }

  // --- System Logs ---
  let logs = [];
  try {
    const { data: logRows } = await sb
      .from('system_logs')
      .select('id, created_at, level, source, message, details')
      .order('created_at', { ascending: false })
      .limit(200);
    if (logRows) logs = logRows;
  } catch (err) {
    console.error('logs fetch error:', err.message);
  }

  // --- Error count (last 24h) ---
  const cutoff24h = new Date(Date.now() - 86400000).toISOString();
  const errorCount24h = logs.filter(l => l.level === 'error' && l.created_at >= cutoff24h).length;

  return res.status(200).json({ stats, proposals, activities, config, bridge, logs, errorCount24h, cronStatus });
};
