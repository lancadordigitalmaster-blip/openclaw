const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const { readFileSync } = require('fs');
const { join } = require('path');
const { generateHTML } = require('../_lib/builder');

const TEMPLATE = readFileSync(join(__dirname, '../_lib/template.html'), 'utf-8');

const PARSE_PROMPT = `Voce e um parser de propostas comerciais da Wolf Agency. Converta o texto abaixo (formato de slides do WhatsApp) para JSON estruturado.

EXEMPLO DE REFERENCIA (proposta real aprovada — siga este padrao):
{
  "client_name": "Wesley Ramos",
  "service_type": "Marca Pessoal",
  "tagline": "Autoridade construida. Audiencia conquistada.",
  "year": "2026",
  "whatsapp": "5573991484716",
  "ticker_items": ["Estrategia e Planejamento", "Gestao Instagram", "Producao de Conteudo", "Design Estrategico", "Edicao de Video", "Estruturacao Digital"],
  "context": {
    "heading": "Quem e\\nWesley Ramos",
    "bio_paragraphs": ["Paragrafo 1 com **negrito**", "Paragrafo 2"],
    "badges": ["16+ anos experiencia", "Professor", "Concursos policiais", "Metodo integrado"],
    "objectives": ["Construir autoridade", "Desenvolver audiencia", "Validar metodo", "Preparar lancamento"]
  },
  "services": [
    { "name": "Estrategia e Planejamento", "tag": "Estrategia", "bullets": ["diagnostico", "posicionamento", "pilares", "planejamento"] },
    { "name": "Design Estrategico", "tag": "12 criativos/mes", "bullets": ["12 criativos", "carrosseis", "prova social"] }
  ],
  "deliverables": [
    { "badge": "Onboarding", "title": "Primeiro Mes", "rows": [{"label": "Identidade visual", "value": "Incluso"}, {"label": "Padronizacao", "value": "Incluso"}] },
    { "badge": "Mensal", "title": "Conteudo", "highlight": true, "rows": [{"label": "Criativos", "value": "12/mes", "accent": true}] },
    { "badge": "Mensal", "title": "Video", "rows": [{"label": "Reels", "value": "4/mes", "accent": true}] },
    { "badge": "Mensal", "title": "Gestao", "rows": [{"label": "Planejamento", "value": "Mensal"}, {"label": "Relatorio", "value": "Mensal"}] }
  ],
  "investment": {
    "currency": "R$", "amount": "3.000", "suffix": "/mes",
    "payment_options": [
      {"title": "PIX", "desc": "Pagamento a vista sem acrescimo.", "highlight": true},
      {"title": "Transferencia Bancaria", "desc": "TED ou DOC."}
    ]
  },
  "support": [
    "Suporte estrategico continuo via WhatsApp",
    "Reuniao estrategica mensal de alinhamento",
    "Relatorio mensal de desempenho",
    "Ajustes no planejamento apos aprovacao mensal",
    "Direcionamento de melhorias com base em dados",
    "Grupo exclusivo para comunicacao e alinhamento"
  ],
  "close": {
    "heading": "Construir autoridade e o primeiro passo para escalar resultados.",
    "body": "Esta proposta foi desenvolvida para estruturar sua presenca digital.",
    "cta_text": "Falar com a Wolf"
  }
}

REGRAS IMPORTANTES:
1. ticker_items: nomes dos servicos + palavras-chave do nicho do cliente (6-10 itens)
2. context.badges: caracteristicas CURTAS e ESPECIFICAS do cliente/nicho (4-6 badges). NAO use titulos de secao como "Resumo & Objetivo"
3. context.bio_paragraphs: 2-3 paragrafos RICOS sobre quem e o cliente e seu negocio/momento
4. context.objectives: 4-6 objetivos estrategicos do projeto
5. services: cada servico com nome, tag (quantidade se houver), e 4-6 bullets detalhados
6. deliverables: SEPARAR EM MULTIPLOS GRUPOS por categoria:
   - Onboarding/Primeiro Mes: itens de setup inicial (minimo 3 itens)
   - Mensal Conteudo: posts, criativos COM QUANTIDADES (usar "accent": true)
   - Mensal Video: reels, roteiros COM QUANTIDADES (se aplicavel)
   - Mensal Gestao: planejamento, gestao, relatorio, reuniao
   CADA GRUPO DEVE TER 3-5 ROWS.
7. support: 5-6 FRASES COMPLETAS de suporte
8. close.heading: frase inspiracional longa e personalizada ao cliente
9. investment: extrair valor e formas de pagamento do texto
10. Se um dado nao estiver explicito no texto, INFIRA baseado no contexto
11. ACENTUACAO OBRIGATORIA: TODOS os textos devem ter acentos corretos em portugues. Nomes proprios de clientes e produtos devem ser escritos EXATAMENTE como informados.

Responda APENAS com o JSON valido, sem markdown, sem explicacao, sem comentarios.

TEXTO DA PROPOSTA:
`;

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { text, seller, origin, proposal_code, whatsapp } = req.body || {};

    if (!text || text.length < 50) {
      return res.status(400).json({ error: 'Texto da proposta muito curto (minimo 50 chars)' });
    }

    // 1. Parse with Claude
    const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 4000,
      messages: [{ role: 'user', content: PARSE_PROMPT + text }],
    });

    const jsonText = response.content[0].text.trim();
    let data;
    try {
      const cleaned = jsonText.replace(/^```json?\n?/i, '').replace(/\n?```$/i, '').trim();
      data = JSON.parse(cleaned);
    } catch (parseErr) {
      return res.status(500).json({ error: 'Claude retornou JSON invalido', raw: jsonText.substring(0, 200) });
    }

    // Override whatsapp if provided by seller
    if (whatsapp) data.whatsapp = whatsapp;

    // 2. Generate HTML
    const html = generateHTML(data, TEMPLATE);

    // 3. Upload to Supabase Storage
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    const clientSlug = (data.client_name || 'cliente')
      .toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

    if (!clientSlug) {
      return res.status(400).json({ error: 'Nome do cliente invalido' });
    }

    const { error: uploadErr } = await supabase.storage
      .from('proposals')
      .upload(`${clientSlug}.html`, Buffer.from(html, 'utf-8'), {
        contentType: 'text/html; charset=utf-8',
        upsert: true,
      });

    if (uploadErr) {
      return res.status(500).json({ error: `Erro ao salvar proposta: ${uploadErr.message}` });
    }

    // 4. Get public URL
    const { data: urlData } = supabase.storage.from('proposals').getPublicUrl(`${clientSlug}.html`);
    const storageUrl = urlData.publicUrl;

    // Clean URL via rewrite
    const baseUrl = req.headers['x-forwarded-host'] || req.headers.host || 'comercial.wolfpacks.com.br';
    const protocol = req.headers['x-forwarded-proto'] || 'https';
    const publicUrl = `${protocol}://${baseUrl}/proposta/${clientSlug}`;

    // 5. Register in Supabase DB
    let supabaseId = null;
    const inv = data.investment || {};
    const amountNum = parseFloat((inv.amount || '0').toString().replace(/\./g, '').replace(',', '.'));
    const record = {
      client_name: data.client_name || clientSlug,
      service_type: data.service_type || null,
      amount: amountNum || null,
      currency: inv.currency || 'R$',
      suffix: inv.suffix || '/mês',
      status: 'open',
      template: 'classic',
      netlify_url: publicUrl,
      proposal_data: data,
    };
    if (seller) record.seller = seller;
    if (origin) record.origin = origin;
    if (proposal_code) record.proposal_code = proposal_code;

    const { data: inserted, error: dbErr } = await supabase
      .from('proposals')
      .insert(record)
      .select('id')
      .single();

    if (inserted) supabaseId = inserted.id;
    if (dbErr) console.error('Supabase DB error:', dbErr.message);

    return res.status(200).json({
      ok: true,
      url: publicUrl,
      storage_url: storageUrl,
      message: `Proposta gerada e publicada com sucesso!\n\nURL publica: ${publicUrl}${supabaseId ? `\nID: ${supabaseId}` : ''}`,
      parsed_data: data,
    });
  } catch (err) {
    console.error('parse-proposal error:', err);
    return res.status(500).json({ error: err.message });
  }
};
