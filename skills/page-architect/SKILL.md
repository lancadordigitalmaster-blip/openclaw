# SKILL.md — Page Architect

> Gerador automatizado de propostas comerciais cinematográficas em HTML.

## Agent

**Pixel** — design system + geração visual.

---

## Description

Recebe texto de proposta (formato slides) e gera página HTML cinematográfica com deploy automático no Netlify.

**NÃO gere HTML manualmente.** Use a ferramenta `build_proposal` que monta tudo automaticamente.

---

## Como Usar

### Passo 1 — Parsear os slides do usuário

Leia o texto dos slides e extraia os dados para o JSON da ferramenta `build_proposal`.

### Passo 2 — Chamar `build_proposal`

Chame a ferramenta com os dados extraídos. Exemplo:

```json
build_proposal({
  "client_name": "Wesley Ramos",
  "tagline": "Autoridade construída. Audiência conquistada.",
  "service_type": "Marca Pessoal",
  "year": "2026",
  "whatsapp": "5573991484716",
  "ticker_items": ["Estratégia", "Posicionamento", "Conteúdo", "Design", "Vídeos", "Identidade"],
  "context": {
    "heading": "Quem é Wesley Ramos",
    "bio_paragraphs": [
      "**Professor universitário e policial militar** com 16+ anos de experiência.",
      "Objetivo: estruturar presença digital como **referência em concursos policiais**."
    ],
    "badges": ["16+ anos na corporação", "Professor universitário", "Instrutor de formação"],
    "objectives": ["Construir autoridade no nicho", "Desenvolver audiência qualificada", "Preparar lançamento da mentoria"]
  },
  "services": [
    {
      "name": "Gestão de Redes Sociais",
      "tag": "social",
      "bullets": ["Planejamento mensal de conteúdo", "Criação de legendas estratégicas", "Calendário editorial"]
    },
    {
      "name": "Identidade Visual",
      "tag": "branding",
      "bullets": ["Design de posts e stories", "Templates recorrentes", "Manual de marca digital"]
    }
  ],
  "deliverables": [
    {
      "badge": "Fase 1",
      "title": "Setup Inicial",
      "rows": [
        {"label": "Prazo", "value": "2 semanas"},
        {"label": "Entregáveis", "value": "Análise + Personas + Visual"}
      ]
    },
    {
      "badge": "Fase 2",
      "title": "Execução Mensal",
      "highlight": true,
      "rows": [
        {"label": "Posts", "value": "12/mês"},
        {"label": "Stories", "value": "20/mês"},
        {"label": "Reels", "value": "4/mês"}
      ]
    }
  ],
  "investment": {
    "currency": "R$",
    "amount": "4.500",
    "suffix": "/mês",
    "payment_options": [
      {"title": "PIX", "desc": "5% de desconto", "highlight": true},
      {"title": "Boleto", "desc": "Até 3x sem juros"}
    ]
  },
  "support": ["Reuniões quinzenais de alinhamento", "Relatórios mensais de performance", "Canal direto via WhatsApp"],
  "close": {
    "heading": "Vamos construir\nsua autoridade.",
    "body": "Estamos prontos para transformar sua presença digital em resultado.",
    "cta_text": "Falar com a Wolf"
  },
  "template": "classic"
})
```

### Passo 3 — Enviar o link

A ferramenta gera o HTML, faz deploy no Netlify e retorna a URL. Envie ao solicitante:

```
✅ Proposta gerada para [Cliente]!

🔗 https://wolfpack-br.netlify.app/[slug]

Abra no navegador para ver a proposta completa com animações.
```

---

## Mapeamento Slides → JSON

| Slide | Campo JSON |
|-------|-----------|
| Capa | `client_name`, `tagline`, `service_type`, `year` |
| Índice/Serviços listados | `ticker_items` |
| Contexto/Quem é | `context.heading`, `context.bio_paragraphs`, `context.badges`, `context.objectives` |
| Serviços detalhados | `services[]` com `name`, `tag`, `bullets[]` |
| Entregáveis/Fases | `deliverables[]` com `badge`, `title`, `rows[]` |
| Investimento | `investment.amount`, `investment.suffix`, `investment.payment_options[]` |
| Suporte/Incluso | `support[]` |
| Fechamento | `close.heading`, `close.body`, `close.cta_text` |
---

## Sites Netlify

| Site | URL | Uso |
|------|-----|-----|
| **wolfpack-br** | `wolfpack-br.netlify.app/[slug]` | Propostas de produção (clientes reais) |
| **wolfpack-lab** | `wolfpack-lab.netlify.app/[slug]` | Testes de novos templates |

---

## Regras

- **NUNCA** gerar HTML manualmente — SEMPRE usar `build_proposal`
- **NUNCA** colar código na conversa
- **NUNCA** inventar dados — usar APENAS o que está nos slides
- **NUNCA** mexer no template `proposal-template.html` sem aprovação explícita
- WhatsApp padrão: `5573991484716` (Wolf Agency)
- Usar `**negrito**` nos bio_paragraphs para destaques (o script converte para `<strong>`)
- Se algum campo não estiver nos slides, omitir (o script usa defaults)
- Deploy de produção: `wolfpack-br` | Deploy de teste: `wolfpack-lab`

---

*Agente: Pixel | Versão: 2.0 | Criado: 2026-03-09*
