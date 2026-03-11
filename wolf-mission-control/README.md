# Wolf Mission Control — WMC v1.0
## Sistema de Orquestração Multi-Agente com Supabase
### Criado: 2026-03-05

---

## O QUE É

O **Wolf Mission Control (WMC)** é o sistema central de distribuição e execução de missões da Wolf Agency.

- Missões chegam via Telegram (Alfred) ou ClickUp
- Alfred distribui para o agente correto com contexto completo
- Supabase aciona automaticamente o agente via Edge Function (trigger-mission)
- Agente executa com Claude API, grava output, dispara handoffs se necessário
- Sistema de memória por agente × cliente acumula contexto entre missões

---

## ARQUITETURA

```
Telegram → Alfred → INSERT missions (status: assigned)
                          ↓
               Trigger PostgreSQL dispara
                          ↓
             Edge Function: trigger-mission
                          ↓
              Claude API (agente específico)
                          ↓
         OUTPUT → mission_outputs + agent_memory
                          ↓
         [SIGNALS] → handoffs → nova missão derivada
```

---

## AGENTES (12)

| Squad | Agente | Papel |
|-------|--------|-------|
| Core | Alfred 🐺 | Orquestrador — distribui missões, monitora, escalona |
| Marketing | Gabi 🎯 | Tráfego pago: Meta, Google, TikTok Ads |
| Marketing | Luna ✍️ | Copy, conteúdo, roteiros, VSL, estratégia |
| Marketing | Sage 🔍 | SEO técnico, keywords, análise orgânica |
| Marketing | Nova ⭐ | Inteligência de mercado, trends, concorrentes |
| Dev | Titan 🔧 | Tech lead, arquitetura, decisões técnicas |
| Dev | Pixel 🏗️ | Frontend: React, UI/UX, performance |
| Dev | Forge ⚡ | Backend: APIs, Edge Functions, banco |
| Dev | Shield 🛡️ | QA e segurança, testes, OWASP |
| Ops | Atlas 📋 | Gestão de projetos, ClickUp, cronogramas |
| Ops | Echo 💬 | Comunicação: Telegram, WhatsApp, relatórios |
| Ops | Flux 🔄 | Automação: N8N, webhooks, rotinas |

---

## TABELAS SUPABASE

| Tabela | Função |
|--------|--------|
| `clients` | Clientes ativos (slug, telegram_id, clickup_list_id) |
| `agents` | 12 agentes com system_prompt, skill_ref, modelo |
| `missions` | Missões com status, prioridade, agente, cliente |
| `mission_outputs` | Output gerado + tokens usados |
| `agent_memory` | Memória por agente × cliente (contexto acumulado) |
| `handoffs` | Sinais entre agentes (boost_candidate, hook_fix, etc.) |

---

## STATUS DE MISSÃO

```
inbox → assigned → in_progress → done
                              → handoff (gera missão filha)
                              → blocked (erro ou crítico)
                → cancelled
```

---

## SISTEMA DE HANDOFFS

Agentes podem sinalizar outros agentes no output:

```
[SIGNALS]
{
  "handoffs": [{ "to_agent": "luna", "signal_type": "hook_fix", "payload": {...} }],
  "alerts": [{ "level": "critical|high", "message": "..." }]
}
[/SIGNALS]
```

A Edge Function processa e cria nova missão derivada automaticamente.

---

## PRIORIDADE

Score calculado: `(urgência × 0.4) + (impacto_financeiro × 0.4) + (deadline_pressure × 0.2)`

| Priority | Uso |
|----------|-----|
| critical | CPA 3x acima da meta, cliente em crise |
| high | Prazo < 24h, decisão de budget > R$5k |
| medium | Tarefas rotineiras com deadline |
| low | Background tasks, análises periódicas |

---

## DEPLOY

Ver [DEPLOY.md](DEPLOY.md) para instruções completas.

**Resumo rápido:**
1. Executar `migrations/001_mission_control.sql` no SQL Editor do Supabase
2. Executar `migrations/002_seed_agents.sql` no SQL Editor do Supabase
3. Deploy da Edge Function: `supabase functions deploy trigger-mission --project-ref dqhiafxbljujahmpcdhf`
4. Configurar secrets da Edge Function (ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN)
5. Atualizar `app.edge_function_url` e `app.service_role_key` no banco

---

## VARIÁVEIS DE AMBIENTE

No `.env` do OpenClaw:
```
SUPABASE_URL=https://dqhiafxbljujahmpcdhf.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=sb_secret_...
```

Na Edge Function (via supabase secrets set):
```
ANTHROPIC_API_KEY=sk-ant-...
TELEGRAM_BOT_TOKEN=...
SUPABASE_URL=https://dqhiafxbljujahmpcdhf.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret_...
```

---

## PRÓXIMAS EVOLUÇÕES (v2.0)

- [ ] Dashboard de missões (interface web)
- [ ] Integração bidirecional com ClickUp (Atlas)
- [ ] Relatório automático diário para Netto
- [ ] Score de qualidade automático por output
- [ ] Agente Monitor de SLA (alerta quando missão > 2h sem resposta)
