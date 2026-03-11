#!/usr/bin/env node
/**
 * build-proposal.js — Wolf Agency Proposal Builder
 *
 * Reads the design-system proposal template and replaces body content
 * with data from a JSON file, keeping CSS and JS exactly as-is.
 *
 * Usage: node build-proposal.js input.json output.html [--template classic|wesley]
 *        cat input.json | node build-proposal.js - output.html --template wesley
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const TEMPLATES = {
  classic: path.resolve(__dirname, '../design-system/references/proposal-template.html'),
  wesley: path.resolve(__dirname, '../design-system/references/proposal-template-wesley.html'),
};
const TEMPLATE_BACKUP = path.resolve(__dirname, '../design-system/references/backups/proposal-template.LOCKED.html');
const TEMPLATE_CHECKSUM = 'f84d6ae8bc3d38fd71c2cb9392e8f8dd'; // MD5 of production template

// ── Helpers ────────────────────────────────────────────────────────

function esc(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Convert markdown **bold** to <strong> (after HTML-escaping).
 *  Also handles inputs that already contain literal <strong> tags. */
function md(str) {
  if (!str) return '';
  return esc(str)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/&lt;strong&gt;([\s\S]*?)&lt;\/strong&gt;/g, '<strong>$1</strong>');
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function encodeWAText(text) {
  return encodeURIComponent(text);
}

// ── Portuguese accent auto-correction ─────────────────────────────

const PT_ACCENT_MAP = [
  // Longest first to avoid partial matches
  ['Transferencia Bancaria', 'Transferência Bancária'],
  ['transferencia bancaria', 'transferência bancária'],
  ['Producao de Conteudo', 'Produção de Conteúdo'],
  ['producao de conteudo', 'produção de conteúdo'],
  ['Gestao de Rede Social', 'Gestão de Rede Social'],
  ['Stories e Conteudo Dinamico', 'Stories e Conteúdo Dinâmico'],
  ['Estruturacao Digital', 'Estruturação Digital'],
  ['Estrategia e Planejamento', 'Estratégia e Planejamento'],
  // Individual words (case-sensitive pairs)
  ['Estruturacao', 'Estruturação'], ['estruturacao', 'estruturação'],
  ['Comunicacao', 'Comunicação'], ['comunicacao', 'comunicação'],
  ['Organizacao', 'Organização'], ['organizacao', 'organização'],
  ['Padronizacao', 'Padronização'], ['padronizacao', 'padronização'],
  ['Transferencia', 'Transferência'], ['transferencia', 'transferência'],
  ['Producao', 'Produção'], ['producao', 'produção'],
  ['Definicao', 'Definição'], ['definicao', 'definição'],
  ['Estrategico', 'Estratégico'], ['estrategico', 'estratégico'],
  ['Estrategica', 'Estratégica'], ['estrategica', 'estratégica'],
  ['Estrategicos', 'Estratégicos'], ['estrategicos', 'estratégicos'],
  ['Diagnostico', 'Diagnóstico'], ['diagnostico', 'diagnóstico'],
  ['Conteudo', 'Conteúdo'], ['conteudo', 'conteúdo'],
  ['Conteudos', 'Conteúdos'], ['conteudos', 'conteúdos'],
  ['Gestao', 'Gestão'], ['gestao', 'gestão'],
  ['Reuniao', 'Reunião'], ['reuniao', 'reunião'],
  ['Relatorio', 'Relatório'], ['relatorio', 'relatório'],
  ['Presenca', 'Presença'], ['presenca', 'presença'],
  ['Audiencia', 'Audiência'], ['audiencia', 'audiência'],
  ['Expansao', 'Expansão'], ['expansao', 'expansão'],
  ['Sugestoes', 'Sugestões'], ['sugestoes', 'sugestões'],
  ['Sugestao', 'Sugestão'], ['sugestao', 'sugestão'],
  ['Bancaria', 'Bancária'], ['bancaria', 'bancária'],
  ['Bancario', 'Bancário'], ['bancario', 'bancário'],
  ['Credito', 'Crédito'], ['credito', 'crédito'],
  ['Dinamico', 'Dinâmico'], ['dinamico', 'dinâmico'],
  ['Dinamica', 'Dinâmica'], ['dinamica', 'dinâmica'],
  ['Referencias', 'Referências'], ['referencias', 'referências'],
  ['Referencia', 'Referência'], ['referencia', 'referência'],
  ['Construcao', 'Construção'], ['construcao', 'construção'],
  ['Necessario', 'Necessário'], ['necessario', 'necessário'],
  ['Tambem', 'Também'], ['tambem', 'também'],
  ['acrescimo', 'acréscimo'], ['Acrescimo', 'Acréscimo'],
  ['Analise', 'Análise'], ['analise', 'análise'],
  ['Tecnico', 'Técnico'], ['tecnico', 'técnico'],
  ['Tecnica', 'Técnica'], ['tecnica', 'técnica'],
  ['Pagina', 'Página'], ['pagina', 'página'],
  ['Codigo', 'Código'], ['codigo', 'código'],
  ['Logica', 'Lógica'], ['logica', 'lógica'],
  ['Midia', 'Mídia'], ['midia', 'mídia'],
  ['Midias', 'Mídias'], ['midias', 'mídias'],
  ['Trafico', 'Tráfego'],
  ['Orcamento', 'Orçamento'], ['orcamento', 'orçamento'],
  ['Servico', 'Serviço'], ['servico', 'serviço'],
  ['Servicos', 'Serviços'], ['servicos', 'serviços'],
  ['Numero', 'Número'], ['numero', 'número'],
  ['Unico', 'Único'], ['unico', 'único'],
  ['Valido', 'Válido'], ['valido', 'válido'],
  ['Periodo', 'Período'], ['periodo', 'período'],
  ['Inicio', 'Início'], ['inicio', 'início'],
  ['Acompanhamento', 'Acompanhamento'], // correct, no change
];

/** Fix Portuguese accents in all string values of an object (recursive) */
function fixAccents(obj) {
  if (typeof obj === 'string') {
    let s = obj;
    for (const [wrong, right] of PT_ACCENT_MAP) {
      if (wrong !== right) {
        s = s.split(wrong).join(right);
      }
    }
    return s;
  }
  if (Array.isArray(obj)) return obj.map(fixAccents);
  if (obj && typeof obj === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      out[k] = fixAccents(v);
    }
    return out;
  }
  return obj;
}

// ── Section builders ───────────────────────────────────────────────

function buildCover(data, options = {}) {
  const tagline = esc(data.tagline || '');
  const clientName = esc(data.client_name || '');
  const serviceType = esc(data.service_type || '');
  const year = esc(data.year || new Date().getFullYear().toString());
  const templateName = (options.templateName || 'classic').toLowerCase();

  if (templateName === 'wesley') {
    return `
  <!-- ══════════════════════════════
       COVER
  ══════════════════════════════ -->
  <section class="cover">
    <div class="cover-backdrop" aria-hidden="true">
      <div class="cover-backdrop-shell">
        <div class="cover-backdrop-stage">
          <div class="cover-backdrop-unicorn" data-us-project="sajpUiTp7MIKdX6daDCu"></div>
        </div>
      </div>
      <div class="cover-tint"></div>
      <div class="cover-grid-glow"></div>
      <div class="cover-vignette"></div>
    </div>
    <div class="cover-noise"></div>

    <div class="cover-top">
      <!-- badge removed per feedback -->
    </div>

    <div class="cover-body">
      <p class="cover-label reveal">${tagline}</p>
      <h1 class="cover-title reveal">
        Proposta<br class="mobile-br"> Comercial<span class="accent">.</span>
      </h1>
      <div class="cover-divider reveal"></div>
      <div class="cover-client reveal">
        <span class="cover-client-label">Para</span>
        <span class="cover-client-name">${clientName}</span>
      </div>
    </div>

    <div class="cover-bottom">
      <div class="cover-meta reveal">
        <span>Wolf Agency</span>
        <span>${year} · ${serviceType}</span>
      </div>
      <div class="cover-scroll-hint reveal">
        <span class="scroll-line"></span>
        <span>Scroll</span>
      </div>
    </div>
  </section>`;
  }

  return `
  <!-- ══════════════════════════════
       COVER
  ══════════════════════════════ -->
  <section class="cover">
    <div class="cover-noise"></div>
    <div class="cover-iridescence"></div>
    <canvas id="coverCanvas"></canvas>

    <div class="cover-top">
      <!-- badge removed per feedback -->
    </div>

    <div class="cover-body">
      <p class="cover-label reveal">${tagline}</p>
      <h1 class="cover-title reveal">
        Proposta<br class="mobile-br"> Comercial<span class="accent">.</span>
      </h1>
      <div class="cover-divider reveal"></div>
      <div class="cover-client reveal">
        <span class="cover-client-label">Para</span>
        <span class="cover-client-name">${clientName}</span>
      </div>
    </div>

    <div class="cover-bottom">
      <div class="cover-meta reveal">
        <span>Wolf Agency</span>
        <span>${year} · ${serviceType}</span>
      </div>
      <div class="cover-scroll-hint reveal">
        <span class="scroll-line"></span>
        <span>Scroll</span>
      </div>
    </div>
  </section>`;
}

function buildTicker(data) {
  const items = data.ticker_items || [];
  if (items.length === 0) return '';

  // Build ticker items with numbering, duplicated for seamless scroll
  const buildItems = () => items.map((item, i) =>
    `        <div class="ticker-item"><span class="dot"></span><strong>${pad2(i + 1)}</strong> ${esc(item)}</div>`
  ).join('\n');

  return `
  <!-- ticker -->
  <div class="ticker-section">
    <div class="ticker-mask">
      <div class="ticker-track">
${buildItems()}
${buildItems()}
      </div>
    </div>
  </div>`;
}

function buildContext(data) {
  const ctx = data.context || {};
  const heading = esc(ctx.heading || '');
  const paragraphs = ctx.bio_paragraphs || [];
  const badges = ctx.badges || [];
  const objectives = ctx.objectives || [];

  const bioHTML = paragraphs.map(p =>
    `        <p class="context-bio-text">${md(p)}</p>`
  ).join('\n');

  const badgesHTML = badges.map(b =>
    `          <span class="context-badge"><span class="dot"></span>${esc(b)}</span>`
  ).join('\n');

  const objectivesHTML = objectives.map((obj, i) =>
    `        <div class="context-obj-item">
          <span class="context-obj-num">${pad2(i + 1)}</span>
          <span class="context-obj-text">${esc(obj)}</span>
        </div>`
  ).join('\n');

  return `
  <!-- ══════════════════════════════
       CONTEXT & OBJECTIVE (dark)
  ══════════════════════════════ -->
  <section class="dark-section">
    <div class="section-header reveal">
      <div class="section-num">Resumo & Objetivo</div>
      <h2 class="section-heading">${heading}<span class="accent">.</span></h2>
    </div>

    <div class="context-grid">

      <div class="context-bio reveal">
${bioHTML}
        <div class="context-badges">
${badgesHTML}
        </div>
      </div>

      <div class="context-objectives reveal">
        <p class="context-obj-label">Objetivos do projeto</p>

${objectivesHTML}
      </div>

    </div>
  </section>`;
}

function buildServices(data) {
  const services = data.services || [];
  if (services.length === 0) return '';

  const arrowSVG = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';

  const itemsHTML = services.map((svc, i) => {
    const bulletsHTML = (svc.bullets || []).map(b =>
      `              <p class="service-bullet">${esc(b)}</p>`
    ).join('\n');

    return `
      <div class="service-item reveal">
        <div class="service-trigger">
          <div class="service-trigger-left">
            <span class="service-num">${pad2(i + 1)}</span>
            <span class="service-name">${esc(svc.name)}</span>
            <span class="service-tag">${esc(svc.tag || '')}</span>
          </div>
          <div class="service-arrow">
            ${arrowSVG}
          </div>
        </div>
        <div class="service-body">
          <div class="service-inner">
            <div class="service-bullets-col">
${bulletsHTML}
            </div>
          </div>
        </div>
      </div>`;
  }).join('\n');

  const count = services.length;
  const subText = `${count} frente${count > 1 ? 's' : ''} integrada${count > 1 ? 's' : ''}`;

  return `
  <!-- ══════════════════════════════
       SERVICES (dark)
  ══════════════════════════════ -->
  <section class="dark-section">
    <div class="section-header reveal">
      <div class="section-num">O que entregamos</div>
      <h2 class="section-heading">Do planejamento<br>ao resultado<span class="accent">.</span></h2>
      <p class="section-sub">${subText} — cada uma essencial para o sucesso do projeto.</p>
    </div>

    <div class="service-list">
${itemsHTML}

    </div>
  </section>`;
}

function buildDeliverables(data) {
  const deliverables = data.deliverables || [];
  if (deliverables.length === 0) return '';

  const cardsHTML = deliverables.map((del, i) => {
    const highlight = del.highlight ? ' highlight' : '';
    const rowsHTML = (del.rows || []).map(row => {
      const accentClass = row.accent ? ' deliv-accent' : '';
      return `        <div class="deliv-row">
          <span class="deliv-label">${esc(row.label)}</span>
          <span class="deliv-value${accentClass}">${esc(row.value)}</span>
        </div>`;
    }).join('\n');

    return `      <div class="deliverable-card${highlight} reveal">
        <span class="deliv-badge">${esc(del.badge)}</span>
        <div class="deliv-title">${esc(del.title)}</div>

${rowsHTML}
      </div>`;
  }).join('\n\n');

  return `
  <!-- ══════════════════════════════
       DELIVERABLES (paper — light break)
  ══════════════════════════════ -->
  <div class="paper-topline"></div>
  <section class="paper-section">
    <span class="crosshair left"></span>
    <span class="crosshair right"></span>

    <div class="section-header reveal">
      <div class="section-num dark-text">Resumo de Entregáveis</div>
      <h2 class="section-heading dark-text">O que você<br>recebe todo mês<span class="accent">.</span></h2>
    </div>

    <div class="deliverables-grid">

${cardsHTML}

    </div>
  </section>`;
}

function buildInvestment(data) {
  const inv = data.investment || {};
  const currency = esc(inv.currency || 'R$');
  const amount = esc(inv.amount || '0');
  const suffix = esc(inv.suffix || '');
  const paymentOptions = inv.payment_options || [];

  // Payment icon SVGs
  const paymentIcons = {
    pix: '<svg viewBox="0 0 24 24"><path d="M12 2L3.5 12.5H9.5L8 22L20.5 11.5H14.5L12 2Z"/></svg>',
    card: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.4" fill="none"/><path d="M2 10h20" stroke="currentColor" stroke-width="1.4" fill="none"/></svg>',
    boleto: '<svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>',
    transfer: '<svg viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>',
  };
  const defaultIcon = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.4" fill="none"/><path d="M12 8v4l2 2" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>';

  const paymentsHTML = paymentOptions.map(opt => {
    const highlightClass = opt.highlight ? ' highlight' : '';
    const titleLower = (opt.title || '').toLowerCase();
    const icon = paymentIcons[titleLower] || defaultIcon;

    return `      <div class="payment-card${highlightClass} reveal">
        <div class="payment-icon">
          ${icon}
        </div>
        <div>
          <div class="payment-title">${esc(opt.title)}</div>
          <div class="payment-desc">${esc(opt.desc)}</div>
        </div>
      </div>`;
  }).join('\n\n');

  const suffixHTML = suffix ? `<span class="suffix">${suffix}</span>` : '';

  return `
  <!-- ══════════════════════════════
       INVESTMENT (dark)
  ══════════════════════════════ -->
  <section class="dark-section">
    <div class="section-header reveal">
      <div class="section-num">Investimento</div>
      <h2 class="section-heading">Vamos fazer<br>acontecer<span class="accent">?</span></h2>
    </div>

    <div class="value-display">
      <div class="value-label">Valor mensal</div>
      <div class="value-amount reveal">
        <span class="currency">${currency}</span>${amount}${suffixHTML}
      </div>
      <div class="value-bar" id="valueBar"></div>
    </div>

    <div class="payment-options">
${paymentsHTML}
    </div>
  </section>`;
}

function buildSupport(data) {
  const items = data.support || [];
  if (items.length === 0) return '';

  const itemsHTML = items.map((item, i) =>
    `      <div class="support-item">
        <span class="support-num">${pad2(i + 1)}</span>
        <span class="support-dot"></span>
        <span class="support-text">${esc(item)}</span>
      </div>`
  ).join('\n');

  return `
  <!-- ══════════════════════════════
       SUPPORT (paper — light break)
  ══════════════════════════════ -->
  <div class="paper-topline"></div>
  <section class="paper-section">
    <span class="crosshair left"></span>
    <span class="crosshair right"></span>

    <div class="section-header reveal">
      <div class="section-num dark-text">Suporte & Acompanhamento</div>
      <h2 class="section-heading dark-text">Sempre presentes<span class="accent">.</span></h2>
    </div>

    <div class="support-list reveal">
${itemsHTML}
    </div>
  </section>`;
}

function buildClose(data) {
  const close = data.close || {};
  const whatsapp = data.whatsapp || '5573991484716';
  const clientName = esc(data.client_name || '');
  const year = esc(data.year || new Date().getFullYear().toString());

  const heading = close.heading || 'Vamos começar.';
  const body = esc(close.body || '');
  const ctaText = esc(close.cta_text || 'Falar com a Wolf');

  const waAcceptURL = `https://wa.me/${whatsapp}?text=${encodeWAText('Olá, quero aceitar a proposta comercial!')}`;
  const waQuestionURL = `https://wa.me/${whatsapp}?text=${encodeWAText('Olá, tenho dúvidas sobre a proposta comercial.')}`;

  // WhatsApp SVG icon
  const waSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>';

  return `
  <!-- ══════════════════════════════
       CLOSE
  ══════════════════════════════ -->
  <section class="close-section">
    <!-- image slot for close section -->
    <div class="close-img-slot empty" id="closeImgSlot">
      <!-- <img src="YOUR_BASE64_OR_URL_HERE" alt="" /> -->
    </div>
    <div>
      <h2 class="close-heading reveal">
        ${heading}
      </h2>
      <p class="close-body reveal">
        ${body}
      </p>
      <div class="close-actions">
        <a href="${waAcceptURL}" target="_blank" class="btn-primary reveal">
          ${waSVG}
          ${ctaText}
        </a>
        <a href="${waQuestionURL}" target="_blank" class="btn-secondary reveal">Tenho dúvidas</a>
      </div>
    </div>

    <div class="close-bottom">
      <div class="footer-logo">Wolf Agency<span>.</span></div>
      <div class="footer-note">
        ${clientName} · Proposta Comercial<br>
        Wolf Agency · ${year} · Válida 7 dias
      </div>
    </div>
  </section>`;
}

// ── Main ───────────────────────────────────────────────────────────

function main() {
  // Parse arguments
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node build-proposal.js <input.json | -> <output.html> [--template classic|wesley]');
    console.error('  input.json  Path to JSON data file (use - for stdin)');
    console.error('  output.html Path where the HTML will be written');
    console.error('  --template  Template style: classic (default) or wesley');
    process.exit(1);
  }

  const inputPath = args[0];
  const outputPath = args[1];

  // Parse --template flag
  let templateName = 'classic';
  const tplIdx = args.indexOf('--template');
  if (tplIdx !== -1 && args[tplIdx + 1]) {
    templateName = args[tplIdx + 1].toLowerCase();
  }
  const TEMPLATE_PATH = TEMPLATES[templateName] || TEMPLATES.classic;

  // Read JSON data
  let jsonStr;
  if (inputPath === '-') {
    jsonStr = fs.readFileSync(0, 'utf-8'); // stdin
  } else {
    const resolvedInput = path.resolve(inputPath);
    if (!fs.existsSync(resolvedInput)) {
      console.error(`Error: input file not found: ${resolvedInput}`);
      process.exit(1);
    }
    jsonStr = fs.readFileSync(resolvedInput, 'utf-8');
  }

  let data;
  try {
    data = JSON.parse(jsonStr);
  } catch (e) {
    console.error(`Error: invalid JSON — ${e.message}`);
    process.exit(1);
  }

  // Read template with integrity check
  if (!fs.existsSync(TEMPLATE_PATH)) {
    // Try to restore from backup
    if (fs.existsSync(TEMPLATE_BACKUP)) {
      console.error(`Warning: template missing, restoring from backup`);
      fs.copyFileSync(TEMPLATE_BACKUP, TEMPLATE_PATH);
    } else {
      console.error(`Error: template not found: ${TEMPLATE_PATH}`);
      process.exit(1);
    }
  }
  let template = fs.readFileSync(TEMPLATE_PATH, 'utf-8');
  // Verify template integrity
  const currentChecksum = crypto.createHash('md5').update(fs.readFileSync(TEMPLATE_PATH)).digest('hex');
  if (templateName === 'classic' && currentChecksum !== TEMPLATE_CHECKSUM) {
    console.error(`Warning: template checksum mismatch (got ${currentChecksum}, expected ${TEMPLATE_CHECKSUM})`);
    if (fs.existsSync(TEMPLATE_BACKUP)) {
      console.error(`Restoring template from LOCKED backup`);
      fs.copyFileSync(TEMPLATE_BACKUP, TEMPLATE_PATH);
      template = fs.readFileSync(TEMPLATE_PATH, 'utf-8');
    }
  }

  // Extract CSS (everything inside <style>...</style>)
  const styleMatch = template.match(/<style>([\s\S]*?)<\/style>/);
  const css = styleMatch ? styleMatch[1] : '';

  // Extract JS (all <script>...</script> blocks)
  const scriptBlocks = [];
  const scriptRegex = /<script(?:\s[^>]*)?>[\s\S]*?<\/script>/g;
  let match;
  while ((match = scriptRegex.exec(template)) !== null) {
    scriptBlocks.push(match[0]);
  }

  // Extract <head> content before <style> (meta, links, external scripts)
  const headMatch = template.match(/<head>([\s\S]*?)<style>/);
  let headPre = headMatch ? headMatch[1].trim() : '';
  // Fix title to use client name instead of template default
  const clientTitle = esc(data.client_name || 'Proposta Comercial');
  headPre = headPre.replace(/<title>[^<]*<\/title>/, `<title>Proposta Comercial — ${clientTitle}</title>`);

  // Auto-fix Portuguese accents in all data fields
  data = fixAccents(data);

  // Build body sections
  const bodySections = [
    buildCover(data, { templateName }),
    buildTicker(data),
    buildContext(data),
    buildServices(data),
    buildDeliverables(data),
    buildInvestment(data),
    buildSupport(data),
    buildClose(data),
  ].filter(Boolean).join('\n');

  // Assemble final HTML
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  ${headPre}
  <style>${css}  </style>
</head>
<body>
${bodySections}

  ${scriptBlocks.join('\n\n  ')}
</body>
</html>
`;

  // Write output
  const resolvedOutput = path.resolve(outputPath);
  fs.writeFileSync(resolvedOutput, html, 'utf-8');
  console.log(`Proposal generated: ${resolvedOutput}`);
}

main();
