# Wolf Comercial — Sistema de Propostas

Sistema de geração e gestão de propostas comerciais da **Wolf Agency**.

## Arquitetura

```
wolf-comercial.vercel.app
├── /                     → Painel Kanban (propostas)
├── /api/parse-proposal   → Serverless: texto → Claude → HTML → Supabase
├── /api/health           → Health check
└── /proposta/:slug       → Rewrite → Supabase Storage (proposta pública)
```

## Stack

- **Frontend:** HTML/CSS/JS puro (painel kanban com Supabase Realtime)
- **Backend:** Vercel Serverless Functions (Node.js)
- **IA:** Claude Sonnet 4.6 (parsing de propostas)
- **Storage:** Supabase Storage (HTMLs das propostas)
- **Database:** Supabase PostgreSQL (registros + kanban)

## Estrutura

```
├── api/                    # Serverless functions
│   ├── parse-proposal.js   # Recebe texto → gera proposta
│   └── health.js           # Health check
├── _lib/                   # Libs compartilhadas
│   ├── builder.js          # Gerador de HTML (template engine)
│   └── template.html       # Template base das propostas
├── public/                 # Frontend
│   └── index.html          # Painel kanban comercial
├── skills/
│   └── page-architect/     # Builder local (Mac Mini)
│       └── build-proposal.js
├── wolf-comercial.html     # Painel local (localhost:8765)
├── vercel.json             # Config Vercel
└── package.json
```

## Deploy

```bash
npm install
vercel deploy --prod
```

## Variáveis de ambiente (Vercel)

- `ANTHROPIC_API_KEY` — API key do Claude
- `SUPABASE_URL` — URL do projeto Supabase
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key do Supabase
