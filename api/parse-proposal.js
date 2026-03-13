const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const { readFileSync } = require('fs');
const { join } = require('path');
const { generateHTML } = require('../_lib/builder');

const TEMPLATE = readFileSync(join(__dirname, '../_lib/template.html'), 'utf-8');

// ─── Templates por tipo de serviço ────────────────────────────────────────────
const SERVICE_TEMPLATES = {
  'Marca Pessoal': {
    ticker_base: ['Estratégia e Planejamento', 'Gestão Instagram', 'Produção de Conteúdo', 'Design Estratégico', 'Edição de Vídeo', 'Estruturação Digital'],
    services: [
      { name: 'Estratégia e Planejamento', tag: 'Estratégia', bullets: ['diagnóstico de presença digital', 'posicionamento de marca pessoal', 'definição de pilares de conteúdo', 'calendário editorial mensal'] },
      { name: 'Gestão de Instagram', tag: 'Gestão', bullets: ['publicação de conteúdos aprovados', 'gestão de comentários e DMs', 'monitoramento de métricas', 'relatório mensal de desempenho'] },
      { name: 'Produção de Conteúdo', tag: '12 criativos/mês', bullets: ['12 criativos estratégicos', 'carrosséis e posts estáticos', 'stories interativos', 'arte para destaques'] },
      { name: 'Edição de Vídeo', tag: '4 reels/mês', bullets: ['4 reels editados e legendados', 'cortes estratégicos', 'motion e efeitos', 'thumbnail personalizada'] }
    ],
    deliverables: [
      { badge: 'Onboarding', title: 'Primeiro Mês', rows: [{ label: 'Diagnóstico digital', value: 'Incluso' }, { label: 'Definição de tom de voz', value: 'Incluso' }, { label: 'Padronização visual', value: 'Incluso' }, { label: 'Calendário inicial', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Conteúdo', highlight: true, rows: [{ label: 'Criativos estáticos', value: '8/mês', accent: true }, { label: 'Carrosséis', value: '4/mês', accent: true }, { label: 'Stories', value: '12/mês' }] },
      { badge: 'Mensal', title: 'Vídeo', rows: [{ label: 'Reels editados', value: '4/mês', accent: true }, { label: 'Roteiro estratégico', value: 'Incluso' }, { label: 'Legendas', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Gestão', rows: [{ label: 'Planejamento editorial', value: 'Mensal' }, { label: 'Gestão de comentários', value: 'Diário' }, { label: 'Relatório de desempenho', value: 'Mensal' }, { label: 'Reunião de alinhamento', value: 'Mensal' }] }
    ],
    support: ['Suporte estratégico contínuo via WhatsApp', 'Reunião de alinhamento mensal', 'Relatório mensal de desempenho e métricas', 'Ajustes de conteúdo após aprovação mensal', 'Direcionamento com base em dados e tendências', 'Grupo exclusivo para comunicação e alinhamento']
  },
  'Gestão de Redes Sociais': {
    ticker_base: ['Gestão Instagram', 'Gestão Facebook', 'Produção de Conteúdo', 'Design Estratégico', 'Planejamento Editorial', 'Relatórios Mensais'],
    services: [
      { name: 'Estratégia e Planejamento', tag: 'Estratégia', bullets: ['diagnóstico de redes sociais', 'definição de personas e público-alvo', 'pilares e calendário editorial', 'benchmarking de concorrentes'] },
      { name: 'Produção de Conteúdo', tag: '16 criativos/mês', bullets: ['16 criativos estratégicos', 'carrosséis educativos', 'posts de engajamento', 'artes de datas comemorativas'] },
      { name: 'Gestão e Publicação', tag: 'Gestão', bullets: ['publicação nos horários estratégicos', 'gestão de comentários e mensagens', 'interação com audiência', 'monitoramento de performance'] }
    ],
    deliverables: [
      { badge: 'Onboarding', title: 'Primeiro Mês', rows: [{ label: 'Diagnóstico de redes', value: 'Incluso' }, { label: 'Identidade visual padronizada', value: 'Incluso' }, { label: 'Bio e links otimizados', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Conteúdo', highlight: true, rows: [{ label: 'Posts estáticos', value: '12/mês', accent: true }, { label: 'Carrosséis', value: '4/mês', accent: true }, { label: 'Stories', value: '15/mês' }] },
      { badge: 'Mensal', title: 'Gestão', rows: [{ label: 'Publicações programadas', value: 'Diário' }, { label: 'Gestão de comunidade', value: 'Diário' }, { label: 'Relatório de performance', value: 'Mensal' }, { label: 'Reunião estratégica', value: 'Mensal' }] }
    ],
    support: ['Suporte via WhatsApp em horário comercial', 'Reunião de alinhamento mensal', 'Relatório completo de métricas mensais', 'Ajustes de estratégia baseados em dados', 'Monitoramento de tendências do setor', 'Grupo exclusivo de comunicação']
  },
  'Tráfego Pago': {
    ticker_base: ['Meta Ads', 'Google Ads', 'Gestão de Campanhas', 'Otimização de ROI', 'Análise de Dados', 'Funil de Vendas'],
    services: [
      { name: 'Estratégia de Tráfego', tag: 'Estratégia', bullets: ['mapeamento de funil de vendas', 'definição de objetivos e KPIs', 'análise de públicos e segmentações', 'plano de mídia mensal'] },
      { name: 'Meta Ads (Facebook + Instagram)', tag: 'Gestão', bullets: ['criação e otimização de campanhas', 'teste A/B de criativos e copys', 'gestão de orçamento diário', 'segmentação avançada de públicos'] },
      { name: 'Google Ads', tag: 'Gestão', bullets: ['campanhas de pesquisa e display', 'otimização de palavras-chave', 'remarketing estratégico', 'análise de qualidade de tráfego'] }
    ],
    deliverables: [
      { badge: 'Onboarding', title: 'Setup Inicial', rows: [{ label: 'Configuração do Pixel', value: 'Incluso' }, { label: 'Configuração do Google Tag', value: 'Incluso' }, { label: 'Estrutura de campanhas', value: 'Incluso' }, { label: 'Públicos personalizados', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Gestão', highlight: true, rows: [{ label: 'Campanhas ativas', value: 'Ilimitadas', accent: true }, { label: 'Otimizações semanais', value: '4/mês', accent: true }, { label: 'Testes A/B', value: 'Contínuos' }] },
      { badge: 'Mensal', title: 'Relatórios', rows: [{ label: 'Relatório de performance', value: 'Mensal' }, { label: 'Análise de ROI', value: 'Mensal' }, { label: 'Reunião estratégica', value: 'Mensal' }] }
    ],
    support: ['Suporte via WhatsApp para ajustes urgentes', 'Reunião mensal de análise de resultados', 'Relatório completo de performance e ROI', 'Otimizações proativas baseadas em dados', 'Alertas de performance fora do padrão', 'Grupo exclusivo de comunicação e alinhamento']
  },
  'Branding': {
    ticker_base: ['Identidade Visual', 'Logotipo', 'Manual de Marca', 'Papelaria Digital', 'Design Estratégico', 'Posicionamento de Marca'],
    services: [
      { name: 'Estratégia de Marca', tag: 'Estratégia', bullets: ['imersão e briefing aprofundado', 'análise de mercado e concorrentes', 'definição de posicionamento', 'arquitetura de marca'] },
      { name: 'Identidade Visual', tag: 'Design', bullets: ['criação de logotipo principal', 'variações e versões do logo', 'paleta de cores estratégica', 'tipografia e elementos visuais'] },
      { name: 'Manual de Marca', tag: 'Entrega', bullets: ['guia de uso da identidade visual', 'aplicações corretas e incorretas', 'tom de voz e linguagem', 'templates para redes sociais'] }
    ],
    deliverables: [
      { badge: 'Entrega', title: 'Identidade Visual', highlight: true, rows: [{ label: 'Logotipo (variações)', value: '3 versões', accent: true }, { label: 'Paleta de cores', value: 'Incluso' }, { label: 'Tipografia', value: 'Incluso' }, { label: 'Elementos visuais', value: 'Incluso' }] },
      { badge: 'Entrega', title: 'Manual e Assets', rows: [{ label: 'Manual de marca completo', value: 'Incluso' }, { label: 'Templates redes sociais', value: '5 templates' }, { label: 'Papelaria digital', value: 'Incluso' }, { label: 'Arquivos editáveis', value: 'AI + PDF' }] }
    ],
    support: ['Suporte via WhatsApp durante todo o projeto', 'Apresentação formal da identidade visual', 'Até 2 rodadas de ajustes incluídas', 'Entrega de todos os arquivos fonte', 'Orientação sobre aplicação da marca']
  },
  'Social Media + Tráfego': {
    ticker_base: ['Gestão de Redes', 'Meta Ads', 'Produção de Conteúdo', 'Google Ads', 'Design Estratégico', 'Funil Completo'],
    services: [
      { name: 'Gestão de Redes Sociais', tag: 'Social', bullets: ['calendário editorial estratégico', 'produção de conteúdo orgânico', 'gestão de comentários e DMs', 'relatório de desempenho mensal'] },
      { name: 'Tráfego Pago — Meta Ads', tag: 'Meta Ads', bullets: ['campanhas de conversão e alcance', 'gestão de orçamento e lances', 'teste A/B contínuo', 'remarketing avançado'] },
      { name: 'Tráfego Pago — Google Ads', tag: 'Google Ads', bullets: ['campanhas de pesquisa', 'rede display e remarketing', 'palavras-chave estratégicas', 'análise de qualidade de tráfego'] },
      { name: 'Produção de Conteúdo', tag: '12 criativos/mês', bullets: ['12 criativos para orgânico e pago', 'adaptação para múltiplos formatos', 'copys estratégicas', 'aprovação prévia do cliente'] }
    ],
    deliverables: [
      { badge: 'Onboarding', title: 'Setup', rows: [{ label: 'Configuração de pixels e tags', value: 'Incluso' }, { label: 'Estrutura de campanhas', value: 'Incluso' }, { label: 'Padronização visual', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Conteúdo', highlight: true, rows: [{ label: 'Criativos', value: '12/mês', accent: true }, { label: 'Stories', value: '15/mês' }, { label: 'Publicações programadas', value: 'Diário' }] },
      { badge: 'Mensal', title: 'Tráfego', rows: [{ label: 'Campanhas ativas', value: 'Ilimitadas', accent: true }, { label: 'Otimizações', value: 'Semanais' }, { label: 'Relatório de ROI', value: 'Mensal' }] },
      { badge: 'Mensal', title: 'Gestão', rows: [{ label: 'Gestão de comunidade', value: 'Diário' }, { label: 'Planejamento editorial', value: 'Mensal' }, { label: 'Reunião estratégica', value: 'Mensal' }] }
    ],
    support: ['Suporte estratégico via WhatsApp em horário comercial', 'Reunião mensal de análise e planejamento', 'Relatório integrado: orgânico + pago', 'Otimizações proativas baseadas em performance', 'Ajustes de estratégia sem custo extra', 'Grupo exclusivo para comunicação e briefings']
  },
  'Produção de Conteúdo': {
    ticker_base: ['Fotografia', 'Produção de Vídeo', 'Reels', 'Edição Profissional', 'Conteúdo Estratégico', 'Stories'],
    services: [
      { name: 'Produção de Foto e Vídeo', tag: 'Produção', bullets: ['sessão de foto mensal', 'produção de vídeos curtos', 'roteirização estratégica', 'direção de arte e styling'] },
      { name: 'Edição e Pós-produção', tag: 'Edição', bullets: ['edição profissional de vídeos', 'tratamento de imagens', 'motion e efeitos', 'adaptação para múltiplos formatos'] }
    ],
    deliverables: [
      { badge: 'Mensal', title: 'Foto', rows: [{ label: 'Fotos editadas', value: '30/mês', accent: true }, { label: 'Sessão de produção', value: '1/mês' }, { label: 'Tratamento profissional', value: 'Incluso' }] },
      { badge: 'Mensal', title: 'Vídeo', highlight: true, rows: [{ label: 'Reels editados', value: '8/mês', accent: true }, { label: 'Vídeos longos', value: '2/mês' }, { label: 'Motion e efeitos', value: 'Incluso' }] }
    ],
    support: ['Suporte via WhatsApp para direcionamentos', 'Alinhamento de pauta mensal', 'Revisões incluídas em cada entrega', 'Entrega de arquivos em múltiplos formatos']
  }
};

function buildStructuredPrompt(structured) {
  const { client_name, service_type, about_client, value, notes, payment_options } = structured;
  const tpl = SERVICE_TEMPLATES[service_type] || SERVICE_TEMPLATES['Gestão de Redes Sociais'];

  const payOpts = payment_options || [
    { title: 'PIX', desc: 'Pagamento à vista sem acréscimo.', highlight: true },
    { title: 'Transferência Bancária', desc: 'TED ou DOC.' }
  ];

  const skeleton = {
    client_name,
    service_type,
    year: new Date().getFullYear().toString(),
    ticker_items: tpl.ticker_base,
    services: tpl.services,
    deliverables: tpl.deliverables,
    investment: {
      currency: 'R$',
      amount: value || '0',
      suffix: '/mês',
      payment_options: payOpts
    },
    support: tpl.support
  };

  return `Você é um especialista em criação de propostas comerciais da Wolf Agency, agência de marketing digital premium.

DADOS DO CLIENTE:
- Nome: ${client_name}
- Serviço contratado: ${service_type}
- Sobre o cliente: ${about_client}
${notes ? `- Observações extras: ${notes}` : ''}
- Valor mensal: R$ ${value || '0'}

Com base nos dados acima, complete o JSON de proposta abaixo. Você deve PREENCHER apenas os campos marcados com "PERSONALIZAR":

${JSON.stringify({
  ...skeleton,
  tagline: 'PERSONALIZAR — tagline inspiracional de 4-8 palavras para este cliente e serviço',
  context: {
    heading: `Quem é\\n${client_name}`,
    bio_paragraphs: ['PERSONALIZAR — parágrafo 1 rico sobre quem é o cliente e seu negócio/momento atual', 'PERSONALIZAR — parágrafo 2 com contexto e desafios', 'PERSONALIZAR — parágrafo 3 com potencial e oportunidade (opcional)'],
    badges: ['PERSONALIZAR — característica 1 do nicho', 'PERSONALIZAR — característica 2', 'PERSONALIZAR — característica 3', 'PERSONALIZAR — característica 4'],
    objectives: ['PERSONALIZAR — objetivo estratégico 1', 'PERSONALIZAR — objetivo 2', 'PERSONALIZAR — objetivo 3', 'PERSONALIZAR — objetivo 4']
  },
  close: {
    heading: 'PERSONALIZAR — frase inspiracional personalizada ao cliente e ao serviço (1 frase longa)',
    body: 'Esta proposta foi desenvolvida exclusivamente para potencializar os resultados de ' + client_name + '.',
    cta_text: 'Falar com a Wolf'
  }
}, null, 2)}

REGRAS:
1. Substitua TODOS os campos "PERSONALIZAR" com conteúdo real baseado nos dados do cliente
2. tagline: curta, impactante, específica ao nicho do cliente
3. bio_paragraphs: 2-3 parágrafos RICOS — use as informações de "Sobre o cliente" para criar texto personalizado
4. badges: características CURTAS e ESPECÍFICAS (ex: "10 anos de mercado", "Clínica estética", "Interior SP") — NÃO use títulos genéricos
5. objectives: objetivos ESPECÍFICOS para este cliente e serviço
6. close.heading: frase longa e inspiracional, específica para ${client_name} e ${service_type}
7. Mantenha EXATAMENTE a estrutura dos campos services, deliverables, support, investment (não altere)
8. ACENTUAÇÃO: todos os textos com acentos corretos em português. Nome do cliente EXATAMENTE como informado
9. ticker_items: adapte com palavras-chave do nicho do cliente (${about_client.split(' ').slice(0, 5).join(', ')}...)

Responda APENAS com o JSON válido, sem markdown, sem explicação, sem comentários.`;
}

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

async function syslog(sb, level, message, details) {
  try { await sb.from('system_logs').insert({ source: 'parse-proposal', level, message, details }); } catch {}
}

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { text, structured, seller, origin, proposal_code, whatsapp, id: existingId } = req.body || {};

    // Validate input — accept either free-text or structured form
    const isStructured = !!(structured && structured.client_name && structured.service_type);
    if (!isStructured && (!text || text.length < 50)) {
      return res.status(400).json({ error: 'Texto da proposta muito curto (minimo 50 chars)' });
    }
    if (isStructured && !structured.about_client) {
      return res.status(400).json({ error: 'Informe pelo menos uma frase sobre o cliente' });
    }

    // Build prompt based on input mode
    const prompt = isStructured ? buildStructuredPrompt(structured) : (PARSE_PROMPT + text);

    // 1. Parse with Claude via OpenRouter (fallback) or Anthropic direct
    let jsonText;
    const openrouterKey = (process.env.OPENROUTER_API_KEY || '').trim();
    const anthropicKey  = process.env.ANTHROPIC_API_KEY;

    // Structured mode benefits from a more capable model for better personalization
    const modelForOpenRouter = isStructured ? 'anthropic/claude-sonnet-4-6' : 'anthropic/claude-haiku-4-5';

    if (openrouterKey) {
      // Use OpenRouter (OpenAI-compatible API)
      const reqBody = JSON.stringify({
        model: modelForOpenRouter,
        max_tokens: 4000,
        messages: [{ role: 'user', content: prompt }],
      });
      const orRes = await new Promise((resolve, reject) => {
        const https = require('https');
        const r = https.request({
          hostname: 'openrouter.ai', path: '/api/v1/chat/completions', method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(reqBody),
            'Authorization': `Bearer ${openrouterKey}`, 'HTTP-Referer': 'https://comercial.wolfpacks.com.br' },
        }, res => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve({ status: res.statusCode, body: d })); });
        r.on('error', reject);
        r.setTimeout(45000, () => { r.destroy(); reject(new Error('OpenRouter timeout')); });
        r.write(reqBody); r.end();
      });
      if (orRes.status !== 200) throw new Error(`OpenRouter ${orRes.status}: ${orRes.body.substring(0, 200)}`);
      const orData = JSON.parse(orRes.body);
      jsonText = orData.choices?.[0]?.message?.content?.trim() || '';
    } else {
      // Use Anthropic direct
      const anthropic = new Anthropic({ apiKey: anthropicKey });
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6', max_tokens: 4000,
        messages: [{ role: 'user', content: prompt }],
      });
      jsonText = response.content[0].text.trim();
    }
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
      await syslog(supabase, 'error', `Upload falhou para ${clientSlug}`, { error: uploadErr.message });
      return res.status(500).json({ error: `Erro ao salvar proposta: ${uploadErr.message}` });
    }

    // 4. Get public URL
    const { data: urlData } = supabase.storage.from('proposals').getPublicUrl(`${clientSlug}.html`);
    const storageUrl = urlData.publicUrl;

    // Always use canonical domain regardless of how the API was called
    const publicUrl = `https://comercial.wolfpacks.com.br/proposta/${clientSlug}`;

    // 5. Register or update in Supabase DB
    let supabaseId = existingId || null;
    const inv = data.investment || {};
    const amountNum = parseFloat((inv.amount || '0').toString().replace(/\./g, '').replace(',', '.'));
    const record = {
      client_name: data.client_name || clientSlug,
      slug: clientSlug,
      service_type: data.service_type || null,
      amount: amountNum || null,
      currency: inv.currency || 'R$',
      suffix: inv.suffix || '/mês',
      template: 'classic',
      netlify_url: publicUrl,
      proposal_data: data,
    };
    if (seller) record.seller = seller;
    if (origin) record.origin = origin;
    if (proposal_code) record.proposal_code = proposal_code;

    if (existingId) {
      const { error: dbErr } = await supabase.from('proposals').update(record).eq('id', existingId);
      if (dbErr) {
        await syslog(supabase, 'error', `DB update falhou para ${clientSlug}`, { error: dbErr.message });
        console.error('Supabase DB update error:', dbErr.message);
      }
    } else {
      record.status = 'open';
      const { data: inserted, error: dbErr } = await supabase
        .from('proposals').insert(record).select('id').single();
      if (inserted) supabaseId = inserted.id;
      if (dbErr) {
        await syslog(supabase, 'error', `DB insert falhou para ${clientSlug}`, { error: dbErr.message });
        console.error('Supabase DB error:', dbErr.message);
      }
    }

    await syslog(supabase, 'info', `Proposta gerada: ${data.client_name}`, {
      slug: clientSlug, seller, service_type: data.service_type, amount: amountNum, mode: isStructured ? 'structured' : 'text'
    });

    return res.status(200).json({
      ok: true,
      url: publicUrl,
      storage_url: storageUrl,
      id: supabaseId,
      message: `Proposta gerada e publicada com sucesso!\n\nURL publica: ${publicUrl}${supabaseId ? `\nID: ${supabaseId}` : ''}`,
      parsed_data: data,
    });
  } catch (err) {
    console.error('parse-proposal error:', err);
    try {
      const sb2 = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
      await syslog(sb2, 'error', `Erro inesperado: ${err.message}`, { stack: err.stack?.slice(0, 500) });
    } catch {}
    return res.status(500).json({ error: err.message });
  }
};
