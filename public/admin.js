let ADMIN_KEY = sessionStorage.getItem('wolf_admin_key') || '';
const SUPABASE_URL  = 'https://dqhiafxbljujahmpcdhf.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxaGlhZnhibGp1amFobXBjZGhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2ODUyNzAsImV4cCI6MjA4ODI2MTI3MH0._eYfSa0stwIysa12_AObw52hugijfMetzLzkaeNCt2g';

// ─── PIN ───
function togglePinVis() {
  const inp = document.getElementById('pin-input');
  inp.type = inp.type === 'password' ? 'text' : 'password';
}

async function checkPin() {
  const val = document.getElementById('pin-input').value;
  if (!val) return;

  document.getElementById('pin-error').textContent = 'Verificando...';

  try {
    const res = await fetch('/api/admin', { headers: { 'x-admin-key': val } });
    if (res.ok) {
      ADMIN_KEY = val;
      sessionStorage.setItem('wolf_admin_key', val);
      document.getElementById('pin-overlay').classList.add('hidden');
      document.getElementById('app').style.display = '';
      initApp();
    } else {
      document.getElementById('pin-error').textContent = 'Senha incorreta. Tente novamente.';
      document.getElementById('pin-input').value = '';
      document.getElementById('pin-input').focus();
    }
  } catch {
    document.getElementById('pin-error').textContent = 'Erro de conexão. Tente novamente.';
  }
}

function logout() {
  sessionStorage.removeItem('wolf_admin_key');
  ADMIN_KEY = '';
  location.reload();
}

window.addEventListener('DOMContentLoaded', () => {
  if (ADMIN_KEY) {
    fetch('/api/admin', { headers: { 'x-admin-key': ADMIN_KEY } })
      .then(r => {
        if (r.ok) {
          document.getElementById('pin-overlay').classList.add('hidden');
          document.getElementById('app').style.display = '';
          initApp();
        } else {
          sessionStorage.removeItem('wolf_admin_key');
          ADMIN_KEY = '';
          setTimeout(() => document.getElementById('pin-input')?.focus(), 100);
        }
      })
      .catch(() => setTimeout(() => document.getElementById('pin-input')?.focus(), 100));
  } else {
    setTimeout(() => document.getElementById('pin-input')?.focus(), 100);
  }
});

// ─── APP ───
let allProposals = [];
let sortCol = 'created_at';
let sortAsc = false;
let lastFetchTime = null;
let refreshInterval = null;
let refreshCounterInterval = null;

function initApp() {
  loadData(true);
  refreshInterval = setInterval(() => loadData(false), 30000);
  refreshCounterInterval = setInterval(updateRefreshCounter, 1000);
}

function updateRefreshCounter() {
  if (!lastFetchTime) return;
  const sec = Math.floor((Date.now() - lastFetchTime) / 1000);
  document.getElementById('refresh-info').textContent =
    sec < 5 ? 'agora mesmo' : `há ${sec}s`;
}

async function loadData(showLoading) {
  if (showLoading) {
    document.getElementById('proposals-tbody').innerHTML =
      '<tr><td colspan="7" class="empty-state">Carregando…</td></tr>';
    document.getElementById('activity-feed').innerHTML =
      '<div class="empty-state">Carregando…</div>';
    document.getElementById('config-tbody').innerHTML =
      '<tr><td colspan="4" class="empty-state">Carregando…</td></tr>';
  }

  try {
    const res = await fetch('/api/admin', { headers: { 'x-admin-key': ADMIN_KEY } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    lastFetchTime = Date.now();

    renderStats(data.stats);
    renderBridge(data.bridge);
    renderCronStatus(data.cronStatus || []);
    allProposals = data.proposals || [];
    renderProposals();
    renderActivities(data.activities || []);
    renderConfig(data.config || []);

    // Logs
    allLogs = data.logs || [];
    populateSourceFilter(allLogs);
    renderLogs();
    const ec = data.errorCount24h || 0;
    const errPill = document.getElementById('pill-errors');
    if (ec > 0) {
      errPill.style.display = '';
      errPill.className = 'pill red';
      document.getElementById('pill-errors-text').textContent = `${ec} erro${ec!==1?'s':''} 24h`;
      document.getElementById('logs-error-badge').style.display = '';
      document.getElementById('logs-error-badge').textContent = `${ec} erro${ec!==1?'s':''} nas últimas 24h`;
    } else {
      errPill.style.display = 'none';
      document.getElementById('logs-error-badge').style.display = 'none';
    }

    // DB pill
    const dbPill = document.getElementById('pill-db');
    dbPill.className = 'pill green';
    dbPill.innerHTML = '<span class="pill-dot"></span>DB ✓';
    document.getElementById('db-badge').className = 'sys-badge online';
    document.getElementById('db-badge').textContent = 'Online';
    document.getElementById('db-detail').textContent = `${(data.proposals||[]).length} propostas carregadas`;

  } catch (err) {
    console.error('loadData error:', err);
    const dbPill = document.getElementById('pill-db');
    dbPill.className = 'pill red';
    dbPill.innerHTML = '<span class="pill-dot"></span>DB Erro';
  }
}

function fmtBRL(v) {
  const n = parseFloat(v) || 0;
  return n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
}

function renderStats(s) {
  if (!s) return;
  document.getElementById('s-pipeline').textContent = fmtBRL(s.total_pipeline);
  document.getElementById('s-pipeline-sub').textContent = `${s.open_count} propostas abertas`;
  document.getElementById('s-won').textContent = fmtBRL(s.total_revenue);
  document.getElementById('s-won-sub').textContent = `${s.won_count} negócios`;

  const closed = (s.won_count || 0) + (s.lost_count || 0);
  const conv = closed > 0 ? Math.round((s.won_count / closed) * 100) : 0;
  document.getElementById('s-conv').textContent = conv + '%';
  document.getElementById('s-conv-sub').textContent = `${s.won_count} won / ${s.lost_count} lost`;
  document.getElementById('s-views').textContent = s.views_today || 0;
}

function renderBridge(b) {
  const pill = document.getElementById('pill-bridge');
  const badge = document.getElementById('bridge-badge');
  const detail = document.getElementById('bridge-detail');
  const sub = document.getElementById('bridge-url-sub');

  if (!b) return;

  if (b.online) {
    pill.className = 'pill green';
    pill.innerHTML = '<span class="pill-dot"></span>Bridge: Online';
    badge.className = 'sys-badge online';
    badge.textContent = 'Online';
    detail.textContent = 'Respondendo em /status';
  } else {
    pill.className = 'pill red';
    pill.innerHTML = '<span class="pill-dot"></span>Bridge: Offline';
    badge.className = 'sys-badge offline';
    badge.textContent = 'Offline';
    detail.textContent = b.url ? 'Sem resposta em 3s' : 'URL não configurada';
  }
  sub.textContent = b.url ? b.url.replace('https://','').replace('http://','') : '—';
}

function renderProposals() {
  const tbody = document.getElementById('proposals-tbody');
  document.getElementById('prop-count').textContent = allProposals.length;

  if (!allProposals.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty-state">Nenhuma proposta</td></tr>';
    return;
  }

  const sorted = [...allProposals].sort((a, b) => {
    let av = a[sortCol], bv = b[sortCol];
    if (sortCol === 'amount') { av = parseFloat(av)||0; bv = parseFloat(bv)||0; }
    if (sortCol === 'view_count') { av = parseInt(av)||0; bv = parseInt(bv)||0; }
    if (av < bv) return sortAsc ? -1 : 1;
    if (av > bv) return sortAsc ?  1 : -1;
    return 0;
  });

  tbody.innerHTML = sorted.map(p => {
    const date = p.created_at ? new Date(p.created_at).toLocaleDateString('pt-BR') : '—';
    const val  = p.amount ? fmtBRL(p.amount) : '—';
    const href = p.slug ? `/proposta/${p.slug}` : '#';
    return `<tr onclick="window.open('${href}','_blank')">
      <td class="fw6">${esc(p.client_name||'—')}</td>
      <td class="text-ink2">${esc(p.seller||'—')}</td>
      <td class="text-ink2">${esc(p.service_type||'—')}</td>
      <td class="mono">${val}</td>
      <td><span class="badge ${p.status||'draft'}">${p.status||'draft'}</span></td>
      <td class="text-ink2">${p.view_count||0}</td>
      <td class="text-ink3 mono">${date}</td>
    </tr>`;
  }).join('');

  // Update sort arrows
  document.querySelectorAll('#proposals-table th').forEach(th => {
    const col = th.dataset.col;
    th.classList.toggle('sorted', col === sortCol);
    const arrow = th.querySelector('.sort-arrow');
    if (arrow) arrow.textContent = col === sortCol ? (sortAsc ? '↑' : '↓') : '↕';
  });
}

function sortTable(col) {
  if (sortCol === col) sortAsc = !sortAsc;
  else { sortCol = col; sortAsc = true; }
  renderProposals();
}

const ACTIVITY_ICONS = {
  view: '👁', edit: '✏️', follow_up: '📅', status_change: '🔄', note: '📝',
  create: '✨', delete: '🗑', default: '📋'
};

function timeAgo(iso) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60)   return `${Math.floor(diff)}s atrás`;
  if (diff < 3600) return `${Math.floor(diff/60)}min atrás`;
  if (diff < 86400)return `${Math.floor(diff/3600)}h atrás`;
  return `${Math.floor(diff/86400)}d atrás`;
}

function renderActivities(acts) {
  const feed = document.getElementById('activity-feed');
  document.getElementById('feed-count').textContent = acts.length;

  if (!acts.length) {
    feed.innerHTML = '<div class="empty-state">Nenhuma atividade</div>';
    return;
  }

  feed.innerHTML = acts.map(a => {
    const icon = ACTIVITY_ICONS[a.type] || ACTIVITY_ICONS.default;
    const client = a.proposals?.client_name || a.proposal_id || '—';
    const ago = a.created_at ? timeAgo(a.created_at) : '';
    return `<div class="feed-item">
      <div class="feed-icon">${icon}</div>
      <div class="feed-body">
        <div class="feed-top">
          <span class="feed-actor">${esc(a.actor||'Sistema')}</span>
          <span class="text-ink3">→</span>
          <span class="feed-client">${esc(client)}</span>
        </div>
        <div class="feed-desc">${esc(a.description||a.type||'—')}</div>
      </div>
      <span class="feed-time">${ago}</span>
    </div>`;
  }).join('');
}

function renderConfig(cfg) {
  const tbody = document.getElementById('config-tbody');
  document.getElementById('config-count').textContent = cfg.length + ' chaves';

  if (!cfg.length) {
    tbody.innerHTML = '<tr><td colspan="4" class="empty-state">Nenhuma configuração</td></tr>';
    return;
  }

  tbody.innerHTML = cfg.map(row => {
    const updated = row.updated_at
      ? new Date(row.updated_at).toLocaleDateString('pt-BR', {day:'2-digit',month:'2-digit',year:'2-digit',hour:'2-digit',minute:'2-digit'})
      : '—';
    const isBridge = row.key === 'bridge_url';
    const testBtn = isBridge
      ? `<button class="btn-test" onclick="testBridgeUrl(this,'${esc(row.value||'')}')">Testar</button>`
      : '';
    return `<tr id="cfg-row-${esc(row.key)}">
      <td>${esc(row.key)}</td>
      <td title="${esc(row.value||'')}"><span id="cfg-val-${esc(row.key)}">${esc(row.value||'')}</span>${testBtn}</td>
      <td>${updated}</td>
      <td>
        <button class="btn-edit" onclick="editConfig('${esc(row.key)}','${esc((row.value||'').replace(/'/g,"\\'"))}')">Editar</button>
      </td>
    </tr>`;
  }).join('');
}

function editConfig(key, currentVal) {
  const row = document.getElementById(`cfg-row-${key}`);
  if (!row) return;
  const valCell = row.cells[1];
  const actCell = row.cells[3];
  valCell.innerHTML = `<input class="edit-input" id="cfg-input-${key}" value="${esc(currentVal)}">`;
  actCell.innerHTML = `<button class="btn-save" onclick="saveConfig('${key}')">Salvar</button><button class="btn-cancel" onclick="loadData(false)">✕</button>`;
  document.getElementById(`cfg-input-${key}`).focus();
}

async function saveConfig(key) {
  const input = document.getElementById(`cfg-input-${key}`);
  if (!input) return;
  const newVal = input.value;

  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/config?key=eq.${encodeURIComponent(key)}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_ANON,
        'Authorization': `Bearer ${SUPABASE_ANON}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({ value: newVal, updated_at: new Date().toISOString() })
    });
    if (res.ok || res.status === 204) {
      await loadData(false);
    } else {
      alert(`Erro ao salvar: HTTP ${res.status}`);
    }
  } catch (err) {
    alert('Erro ao salvar: ' + err.message);
  }
}

async function testBridgeUrl(btn, url) {
  if (!url) { alert('URL não configurada'); return; }
  btn.textContent = '…';
  btn.disabled = true;
  try {
    const res = await fetch('/api/admin', { headers: { 'x-admin-key': ADMIN_KEY } });
    const data = await res.json();
    const online = data.bridge?.online;
    btn.textContent = online ? '✓ Online' : '✗ Offline';
    btn.style.color = online ? 'var(--green)' : 'var(--red)';
    setTimeout(() => { btn.textContent = 'Testar'; btn.style.color = ''; btn.disabled = false; }, 3000);
  } catch {
    btn.textContent = '✗ Erro';
    btn.style.color = 'var(--red)';
    setTimeout(() => { btn.textContent = 'Testar'; btn.style.color = ''; btn.disabled = false; }, 3000);
  }
}

// ─── CRONS ───
function renderCronStatus(crons) {
  const el = document.getElementById('cron-list');
  const badge = document.getElementById('cron-count-badge');
  if (!crons || !crons.length) {
    el.innerHTML = '<div style="color:var(--ink3);font-size:11px;padding:8px">Sem dados</div>';
    return;
  }
  const errCount = crons.filter(c => c.last_status === 'error').length;
  badge.textContent = errCount > 0 ? `${errCount} erro${errCount>1?'s':''}` : `${crons.length} ativos`;
  badge.className = errCount > 0 ? 'sys-badge offline' : 'sys-badge online';

  el.innerHTML = crons.map(c => {
    const st = c.last_status || 'unknown';
    const stLabel = { ok: 'OK', error: 'ERRO', running: 'RODANDO', unknown: '—' }[st] || st;
    const lastRun = c.last_run
      ? timeAgo(c.last_run)
      : 'nunca rodou';
    const msg = c.last_message ? `<div style="font-size:10px;color:var(--ink3);margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="${esc(c.last_message)}">${esc(c.last_message)}</div>` : '';
    return `<div class="cron-item ${st}">
      <div class="cron-meta">
        <span class="cron-name">${esc(c.label || c.name)}</span>
        <span class="cron-status-dot ${st}">${stLabel}</span>
      </div>
      <span class="cron-schedule">${esc(c.schedule || '—')}</span>
      <span class="cron-last">Última: ${lastRun}</span>
      ${msg}
    </div>`;
  }).join('');
}

// ─── LOGS ───
let allLogs = [];
let logFilter = 'all';

function setLogFilter(level, btn) {
  logFilter = level;
  document.querySelectorAll('.log-filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  renderLogs();
}

function renderLogs() {
  const wrap = document.getElementById('log-list-wrap');
  const search = (document.getElementById('log-search')?.value || '').toLowerCase();
  const srcFilter = document.getElementById('log-source-filter')?.value || '';

  let filtered = allLogs;
  if (logFilter !== 'all') filtered = filtered.filter(l => l.level === logFilter);
  if (srcFilter) filtered = filtered.filter(l => l.source === srcFilter);
  if (search) filtered = filtered.filter(l =>
    (l.message || '').toLowerCase().includes(search) ||
    (l.source || '').toLowerCase().includes(search)
  );

  document.getElementById('logs-count').textContent = `${filtered.length} / ${allLogs.length}`;

  if (!filtered.length) {
    wrap.innerHTML = '<div class="empty-state">Nenhum log encontrado</div>';
    return;
  }

  wrap.innerHTML = '<div class="log-list">' + filtered.map((l, i) => {
    const ts = l.created_at
      ? new Date(l.created_at).toLocaleString('pt-BR', {day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit'})
      : '—';
    const hasDetails = l.details && Object.keys(l.details).length > 0;
    return `<div class="log-row lv-${l.level}" onclick="toggleLogRow(${i})" id="lr-${i}">
      <span class="log-ts">${ts}</span>
      <span class="log-lvl"><span class="log-level-badge ${l.level}">${l.level}</span></span>
      <span class="log-src">${esc(l.source||'—')}</span>
      <span class="log-msg">${esc(l.message||'—')}</span>
      <span class="log-chevron">${hasDetails ? '›' : ''}</span>
    </div>
    ${hasDetails ? `<div class="log-details" id="ld-${i}"><pre>${esc(JSON.stringify(l.details, null, 2))}</pre></div>` : ''}`;
  }).join('') + '</div>';
}

function toggleLogRow(i) {
  const row = document.getElementById(`lr-${i}`);
  const det = document.getElementById(`ld-${i}`);
  if (!det) return;
  const open = det.classList.toggle('vis');
  row.classList.toggle('expanded', open);
}

function populateSourceFilter(logs) {
  const sources = [...new Set(logs.map(l => l.source).filter(Boolean))].sort();
  const sel = document.getElementById('log-source-filter');
  const current = sel.value;
  sel.innerHTML = '<option value="">Todas as fontes</option>' +
    sources.map(s => `<option value="${esc(s)}" ${s===current?'selected':''}>${esc(s)}</option>`).join('');
}

function esc(str) {
  return String(str || '')
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}
