const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('fs');
const { join } = require('path');

const { generateHTML } = require('../_lib/builder');

const templateHTML = readFileSync(join(__dirname, '../_lib/template.html'), 'utf-8');

const MINIMAL_DATA = {
  client_name: 'Test Client',
  service_type: 'Marketing Digital',
  tagline: 'Crescimento real.',
  year: '2026',
  whatsapp: '5511999999999',
  ticker_items: ['Estratégia', 'Conteúdo', 'Design'],
  context: {
    heading: 'Quem é\nTest Client',
    bio_paragraphs: ['Parágrafo sobre o cliente.'],
    badges: ['10+ anos', 'Líder de mercado'],
    objectives: ['Aumentar vendas', 'Gerar leads'],
  },
  services: [
    { name: 'Gestão de Redes', tag: 'Social', bullets: ['Instagram', 'TikTok', 'LinkedIn'] },
  ],
  deliverables: [
    { badge: 'Mensal', title: 'Conteúdo', rows: [{ label: 'Posts', value: '12/mês' }] },
  ],
  investment: {
    currency: 'R$',
    amount: '3.000',
    suffix: '/mês',
    payment_options: [{ title: 'PIX', desc: 'Pagamento à vista.' }],
  },
  support: ['Suporte via WhatsApp', 'Reunião mensal'],
  close: {
    heading: 'Vamos crescer juntos.',
    body: 'Esta proposta foi feita para você.',
    cta_text: 'Falar com a Wolf',
  },
};

describe('builder.js', () => {
  it('generates valid HTML from minimal data', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('<!DOCTYPE html') || html.includes('<html'));
    assert.ok(html.includes('Test Client'));
    assert.ok(html.includes('Marketing Digital'));
    assert.ok(html.includes('R$'));
    assert.ok(html.includes('3.000'));
  });

  it('includes all services', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('Gestão de Redes'));
    assert.ok(html.includes('Instagram'));
  });

  it('includes deliverables', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('12/mês'));
  });

  it('includes WhatsApp link', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('5511999999999'));
  });

  it('includes support items', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('Suporte via WhatsApp'));
    assert.ok(html.includes('Reunião mensal'));
  });

  it('includes CTA', () => {
    const html = generateHTML(MINIMAL_DATA, templateHTML);
    assert.ok(html.includes('Falar com a Wolf'));
  });

  it('auto-corrects Portuguese accents', () => {
    const data = {
      ...MINIMAL_DATA,
      services: [{ name: 'Producao de Conteudo', tag: 'Mensal', bullets: ['Gestao de redes'] }],
    };
    const html = generateHTML(data, templateHTML);
    assert.ok(html.includes('Produção de Conteúdo'));
    assert.ok(html.includes('Gestão de redes'));
  });

  it('escapes HTML in client data', () => {
    const data = {
      ...MINIMAL_DATA,
      client_name: '<script>alert("xss")</script>',
    };
    const html = generateHTML(data, templateHTML);
    assert.ok(!html.includes('<script>alert'));
    assert.ok(html.includes('&lt;script&gt;'));
  });

  it('handles missing optional fields gracefully', () => {
    const data = {
      client_name: 'Minimal',
      service_type: 'Teste',
      investment: { currency: 'R$', amount: '1000', suffix: '/mês' },
    };
    // Should not throw
    const html = generateHTML(data, templateHTML);
    assert.ok(html.includes('Minimal'));
  });

  it('works with wesley template', () => {
    const wesleyHTML = readFileSync(join(__dirname, '../_lib/template-wesley.html'), 'utf-8');
    const html = generateHTML(MINIMAL_DATA, wesleyHTML, { templateName: 'wesley' });
    assert.ok(html.includes('Test Client'));
  });
});
