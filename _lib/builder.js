/**
 * builder.js — Wolf Agency Proposal Builder (Serverless version)
 * Exports generateHTML(data, templateHTML) → HTML string
 */

// ── Helpers
function esc(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function md(str) {
  if (!str) return '';
  // normaliza <strong> HTML que o LLM às vezes retorna → markdown, antes do esc()
  str = str.replace(/<strong>(.*?)<\/strong>/gi, '**$1**');
  return esc(str).replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
}
function pad2(n) { return String(n).padStart(2, '0'); }
function encodeWAText(t) { return encodeURIComponent(t); }

// ── Portuguese accent auto-correction
const PT_ACCENT_MAP = [
  ['Transferencia Bancaria','Transferência Bancária'],['transferencia bancaria','transferência bancária'],
  ['Producao de Conteudo','Produção de Conteúdo'],['producao de conteudo','produção de conteúdo'],
  ['Gestao de Rede Social','Gestão de Rede Social'],['Stories e Conteudo Dinamico','Stories e Conteúdo Dinâmico'],
  ['Estruturacao Digital','Estruturação Digital'],['Estrategia e Planejamento','Estratégia e Planejamento'],
  ['Estruturacao','Estruturação'],['estruturacao','estruturação'],['Comunicacao','Comunicação'],['comunicacao','comunicação'],
  ['Organizacao','Organização'],['organizacao','organização'],['Padronizacao','Padronização'],['padronizacao','padronização'],
  ['Transferencia','Transferência'],['transferencia','transferência'],['Producao','Produção'],['producao','produção'],
  ['Definicao','Definição'],['definicao','definição'],['Estrategico','Estratégico'],['estrategico','estratégico'],
  ['Estrategica','Estratégica'],['estrategica','estratégica'],['Estrategicos','Estratégicos'],['estrategicos','estratégicos'],
  ['Diagnostico','Diagnóstico'],['diagnostico','diagnóstico'],['Conteudo','Conteúdo'],['conteudo','conteúdo'],
  ['Conteudos','Conteúdos'],['conteudos','conteúdos'],['Gestao','Gestão'],['gestao','gestão'],
  ['Reuniao','Reunião'],['reuniao','reunião'],['Relatorio','Relatório'],['relatorio','relatório'],
  ['Presenca','Presença'],['presenca','presença'],['Audiencia','Audiência'],['audiencia','audiência'],
  ['Expansao','Expansão'],['expansao','expansão'],['Sugestoes','Sugestões'],['sugestoes','sugestões'],
  ['Sugestao','Sugestão'],['sugestao','sugestão'],['Bancaria','Bancária'],['bancaria','bancária'],
  ['Bancario','Bancário'],['bancario','bancário'],['Credito','Crédito'],['credito','crédito'],
  ['Dinamico','Dinâmico'],['dinamico','dinâmico'],['Dinamica','Dinâmica'],['dinamica','dinâmica'],
  ['Referencias','Referências'],['referencias','referências'],['Referencia','Referência'],['referencia','referência'],
  ['Construcao','Construção'],['construcao','construção'],['Necessario','Necessário'],['necessario','necessário'],
  ['Tambem','Também'],['tambem','também'],['acrescimo','acréscimo'],['Acrescimo','Acréscimo'],
  ['Analise','Análise'],['analise','análise'],['Tecnico','Técnico'],['tecnico','técnico'],
  ['Tecnica','Técnica'],['tecnica','técnica'],['Pagina','Página'],['pagina','página'],
  ['Midia','Mídia'],['midia','mídia'],['Midias','Mídias'],['midias','mídias'],['Trafico','Tráfego'],
  ['Orcamento','Orçamento'],['orcamento','orçamento'],['Servico','Serviço'],['servico','serviço'],
  ['Servicos','Serviços'],['servicos','serviços'],
];

function fixAccents(obj) {
  if (typeof obj === 'string') { let s = obj; for (const [w,r] of PT_ACCENT_MAP) { if (w !== r) s = s.split(w).join(r); } return s; }
  if (Array.isArray(obj)) return obj.map(fixAccents);
  if (obj && typeof obj === 'object') { const o = {}; for (const [k,v] of Object.entries(obj)) o[k] = fixAccents(v); return o; }
  return obj;
}

// ── Section builders
function buildCover(data) {
  return `<section class="cover"><div class="cover-noise"></div><canvas id="coverCanvas"></canvas><div class="cover-top"></div><div class="cover-body"><p class="cover-label reveal">${esc(data.tagline||'')}</p><h1 class="cover-title reveal">Proposta<br class="mobile-br"> Comercial<span class="accent">.</span></h1><div class="cover-divider reveal"></div><div class="cover-client reveal"><span class="cover-client-label">Para</span><span class="cover-client-name">${esc(data.client_name||'')}</span></div></div><div class="cover-bottom"><div class="cover-meta reveal"><span>Wolf Agency</span><span>${esc(data.year||new Date().getFullYear().toString())} · ${esc(data.service_type||'')}</span></div><div class="cover-scroll-hint reveal"><span class="scroll-line"></span><span>Scroll</span></div></div></section>`;
}

function buildTicker(data) {
  const items = data.ticker_items || [];
  if (!items.length) return '';
  const build = () => items.map((t,i) => `<div class="ticker-item"><span class="dot"></span><strong>${pad2(i+1)}</strong> ${esc(t)}</div>`).join('');
  return `<div class="ticker-section"><div class="ticker-mask"><div class="ticker-track">${build()}${build()}</div></div></div>`;
}

function buildContext(data) {
  const ctx = data.context || {};
  const bio = (ctx.bio_paragraphs||[]).map(p => `<p class="context-bio-text">${md(p)}</p>`).join('');
  const badges = (ctx.badges||[]).map(b => `<span class="context-badge"><span class="dot"></span>${esc(b)}</span>`).join('');
  const objs = (ctx.objectives||[]).map((o,i) => `<div class="context-obj-item"><span class="context-obj-num">${pad2(i+1)}</span><span class="context-obj-text">${esc(o)}</span></div>`).join('');
  return `<section class="dark-section"><div class="section-header reveal"><div class="section-num">Resumo & Objetivo</div><h2 class="section-heading">${esc(ctx.heading||'')}<span class="accent">.</span></h2></div><div class="context-grid"><div class="context-bio reveal">${bio}<div class="context-badges">${badges}</div></div><div class="context-objectives reveal"><p class="context-obj-label">Objetivos do projeto</p>${objs}</div></div></section>`;
}

function buildServices(data) {
  const services = data.services || [];
  if (!services.length) return '';
  const arrow = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
  const items = services.map((s,i) => {
    const bullets = (s.bullets||[]).map(b => `<p class="service-bullet">${esc(b)}</p>`).join('');
    return `<div class="service-item reveal"><div class="service-trigger"><div class="service-trigger-left"><span class="service-num">${pad2(i+1)}</span><span class="service-name">${esc(s.name)}</span><span class="service-tag">${esc(s.tag||'')}</span></div><div class="service-arrow">${arrow}</div></div><div class="service-body"><div class="service-inner"><div class="service-bullets-col">${bullets}</div></div></div></div>`;
  }).join('');
  const n = services.length;
  return `<section class="dark-section"><div class="section-header reveal"><div class="section-num">O que entregamos</div><h2 class="section-heading">Do planejamento<br>ao resultado<span class="accent">.</span></h2><p class="section-sub">${n} frente${n>1?'s':''} integrada${n>1?'s':''} — cada uma essencial para o sucesso do projeto.</p></div><div class="service-list">${items}</div></section>`;
}

function buildDeliverables(data) {
  const dels = data.deliverables || [];
  if (!dels.length) return '';
  const cards = dels.map(d => {
    const hl = d.highlight ? ' highlight' : '';
    const rows = (d.rows||[]).map(r => `<div class="deliv-row"><span class="deliv-label">${esc(r.label)}</span><span class="deliv-value${r.accent?' deliv-accent':''}">${esc(r.value)}</span></div>`).join('');
    return `<div class="deliverable-card${hl} reveal"><span class="deliv-badge">${esc(d.badge)}</span><div class="deliv-title">${esc(d.title)}</div>${rows}</div>`;
  }).join('');
  return `<div class="paper-topline"></div><section class="paper-section"><span class="crosshair left"></span><span class="crosshair right"></span><div class="section-header reveal"><div class="section-num dark-text">Resumo de Entregáveis</div><h2 class="section-heading dark-text">O que você<br>recebe todo mês<span class="accent">.</span></h2></div><div class="deliverables-grid">${cards}</div></section>`;
}

function buildInvestment(data) {
  const inv = data.investment || {};
  const icons = {
    pix: '<svg viewBox="0 0 24 24"><path d="M12 2L3.5 12.5H9.5L8 22L20.5 11.5H14.5L12 2Z"/></svg>',
    'cartão de crédito': '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.4" fill="none"/><path d="M2 10h20" stroke="currentColor" stroke-width="1.4" fill="none"/></svg>',
    cartao: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.4" fill="none"/><path d="M2 10h20" stroke="currentColor" stroke-width="1.4" fill="none"/></svg>',
    card: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.4" fill="none"/><path d="M2 10h20" stroke="currentColor" stroke-width="1.4" fill="none"/></svg>',
    boleto: '<svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>',
    'transferência bancária': '<svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>',
    transferencia: '<svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>',
  };
  const defIcon = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.4" fill="none"/></svg>';
  const payments = (inv.payment_options||[]).map(o => {
    const icon = icons[(o.title||'').toLowerCase()] || defIcon;
    return `<div class="payment-card${o.highlight?' highlight':''} reveal"><div class="payment-icon">${icon}</div><div><div class="payment-title">${esc(o.title)}</div><div class="payment-desc">${esc(o.desc)}</div></div></div>`;
  }).join('');
  const sfx = inv.suffix ? `<span class="suffix">${esc(inv.suffix)}</span>` : '';
  return `<section class="dark-section"><div class="section-header reveal"><div class="section-num">Investimento</div><h2 class="section-heading">Vamos fazer<br>acontecer<span class="accent">?</span></h2></div><div class="value-display"><div class="value-label">Valor mensal</div><div class="value-amount reveal"><span class="currency">${esc(inv.currency||'R$')}</span>${esc(inv.amount||'0')}${sfx}</div><div class="value-bar" id="valueBar"></div></div><div class="payment-options">${payments}</div></section>`;
}

function buildSupport(data) {
  const items = data.support || [];
  if (!items.length) return '';
  const html = items.map((t,i) => `<div class="support-item"><span class="support-num">${pad2(i+1)}</span><span class="support-dot"></span><span class="support-text">${esc(t)}</span></div>`).join('');
  return `<div class="paper-topline"></div><section class="paper-section"><span class="crosshair left"></span><span class="crosshair right"></span><div class="section-header reveal"><div class="section-num dark-text">Suporte & Acompanhamento</div><h2 class="section-heading dark-text">Sempre presentes<span class="accent">.</span></h2></div><div class="support-list reveal">${html}</div></section>`;
}

function buildClose(data) {
  const c = data.close || {};
  const wa = data.whatsapp || '5573991484716';
  const heading = c.heading || 'Vamos começar.';
  const waAccept = `https://wa.me/${wa}?text=${encodeWAText('Olá, quero aceitar a proposta comercial!')}`;
  const waQ = `https://wa.me/${wa}?text=${encodeWAText('Olá, tenho dúvidas sobre a proposta comercial.')}`;
  const waSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>';
  return `<section class="close-section"><div class="close-img-slot empty" id="closeImgSlot"></div><div><h2 class="close-heading reveal">${heading}</h2><p class="close-body reveal">${esc(c.body||'')}</p><div class="close-actions"><a href="${waAccept}" target="_blank" class="btn-primary reveal">${waSVG} ${esc(c.cta_text||'Falar com a Wolf')}</a><a href="${waQ}" target="_blank" class="btn-secondary reveal">Tenho dúvidas</a></div></div><div class="close-bottom"><div class="footer-logo">Wolf Agency<span>.</span></div><div class="footer-note">${esc(data.client_name||'')} · Proposta Comercial<br>Wolf Agency · ${esc(data.year||new Date().getFullYear().toString())} · Válida 7 dias</div></div></section>`;
}

// ── Main export
function generateHTML(data, templateHTML) {
  data = fixAccents(data);

  const styleMatch = templateHTML.match(/<style>([\s\S]*?)<\/style>/);
  const css = styleMatch ? styleMatch[1] : '';
  const scriptBlocks = [];
  const scriptRegex = /<script(?:\s[^>]*)?>[\s\S]*?<\/script>/g;
  let m;
  while ((m = scriptRegex.exec(templateHTML)) !== null) {
    // skip external script-src tags — they come through headPre already
    if (!/<script\s[^>]*src=/i.test(m[0])) scriptBlocks.push(m[0]);
  }
  const headMatch = templateHTML.match(/<head>([\s\S]*?)<style>/);
  let headPre = headMatch ? headMatch[1].trim() : '';
  const clientTitle = esc(data.client_name || 'Proposta Comercial');
  headPre = headPre.replace(/<title>[^<]*<\/title>/, `<title>Proposta Comercial — ${clientTitle}</title>`);

  const body = [
    buildCover(data), buildTicker(data), buildContext(data), buildServices(data),
    buildDeliverables(data), buildInvestment(data), buildSupport(data), buildClose(data),
  ].filter(Boolean).join('\n');

  return `<!DOCTYPE html>\n<html lang="pt-BR">\n<head>\n  ${headPre}\n  <style>${css}</style>\n</head>\n<body>\n${body}\n  ${scriptBlocks.join('\n  ')}\n</body>\n</html>`;
}

module.exports = { generateHTML, fixAccents };
