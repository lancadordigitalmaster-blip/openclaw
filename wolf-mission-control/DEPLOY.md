# Wolf Mission Control — Guia de Deploy
# Versão: 1.0 | 2026-03-05

---

## PRÉ-REQUISITOS

- [ ] Conta no Supabase (supabase.com)
- [ ] Anthropic API Key (console.anthropic.com)
- [ ] Supabase CLI instalado: `npm install -g supabase`

---

## PASSO 1 — Criar Projeto Supabase

1. Acesse [supabase.com](https://supabase.com) → New Project
2. Nome: `wolf-mission-control`
3. Região: South America (São Paulo)
4. Anote a senha do banco

---

## PASSO 2 — Pegar Credenciais

Em **Settings → API** do seu projeto:

```
SUPABASE_URL=https://SEU_PROJETO.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

Adicionar no `.env` do OpenClaw:

```bash
# Wolf Mission Control — Supabase
SUPABASE_URL=https://SEU_PROJETO.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-...
```

---

## PASSO 3 — Executar Migrations

No **Supabase SQL Editor**:

1. Copiar e colar `migrations/001_mission_control.sql`
2. Substituir os placeholders no final do arquivo:
   - `SEU_PROJETO.supabase.co` → sua URL real
   - `SUA_SERVICE_ROLE_KEY` → sua service role key
3. Executar
4. Copiar e colar `migrations/002_seed_agents.sql`
5. Executar

---

## PASSO 4 — Deploy das Edge Functions

```bash
# Instalar CLI e fazer login
npx supabase login

# Linkar com seu projeto
npx supabase link --project-ref SEU_PROJECT_REF

# Deploy da função trigger-mission
npx supabase functions deploy trigger-mission \
  --project-ref SEU_PROJECT_REF

# Configurar variáveis de ambiente das Edge Functions
npx supabase secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  TELEGRAM_BOT_TOKEN=8301223491:AAESur71nn4u5OBblCGlsddOymKMNhEMUjk \
  --project-ref SEU_PROJECT_REF
```

---

## PASSO 5 — Configurar Alfred para usar o WMC

Adicionar skill `wolf-mission-control` ao Alfred.
Alfred passa a inserir missões no Supabase quando recebe comandos via Telegram.

Formato de inserção de missão:
```json
{
  "title": "Diagnosticar CTR baixo — Campanha X",
  "description": "CTR atual 0.6% na campanha X (meta 1.5%). Período: 7 dias. Conjunto: Lookalike 1%.",
  "agent_id": "<uuid do Gabi>",
  "client_id": "<uuid do cliente>",
  "priority": "high",
  "status": "assigned"
}
```

---

## PASSO 6 — Testar o Fluxo Completo

1. Inserir missão de teste pelo SQL Editor:
```sql
INSERT INTO missions (title, description, agent_id, client_id, status, priority)
VALUES (
  'Teste — Missão Gabi',
  'Analisar performance da campanha de teste. CTR: 0.5%. Meta: 1.5%. Período: 7 dias.',
  (SELECT id FROM agents WHERE slug = 'gabi'),
  (SELECT id FROM clients WHERE slug = 'wolf-agency'),
  'assigned',
  'medium'
);
```

2. Verificar em `mission_outputs` que o output foi salvo
3. Confirmar que `missions.status` mudou para `done`

---

## VERIFICAÇÃO RÁPIDA

```sql
-- Ver agentes cadastrados
SELECT name, emoji, squad, type, status FROM agents ORDER BY squad, type;

-- Ver missões recentes
SELECT title, status, priority, created_at
FROM missions ORDER BY created_at DESC LIMIT 10;

-- Ver outputs gerados
SELECT m.title, o.tokens_used, o.created_at
FROM mission_outputs o
JOIN missions m ON m.id = o.mission_id
ORDER BY o.created_at DESC LIMIT 10;
```

---

## TROUBLESHOOTING

| Problema | Causa | Solução |
|---------|-------|---------|
| Edge Function erro 401 | ANTHROPIC_API_KEY inválida | Verificar `supabase secrets set` |
| Trigger não dispara | pg_net não habilitado | Habilitar em Database → Extensions |
| Missão fica em `in_progress` | Edge Function com erro | Verificar logs em Functions → Logs |
| pg_cron não funciona | Extensão não habilitada | Habilitar em Database → Extensions → pg_cron |

---

## ESTRUTURA DE ARQUIVOS

```
wolf-mission-control/
├── DEPLOY.md                          ← Este arquivo
├── README.md                          ← Visão geral
├── migrations/
│   ├── 001_mission_control.sql        ← Schema completo
│   └── 002_seed_agents.sql            ← Agentes iniciais
└── functions/
    └── trigger-mission/
        └── index.ts                   ← Edge Function principal
```
