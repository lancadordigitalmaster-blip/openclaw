# Integrações — Wolf Mission Control v1.0
# Criado: 2026-03-05

---

## Telegram Bot

### Setup do webhook

```bash
# Registrar webhook apontando para alfred-router
curl -s -X POST "https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://dqhiafxbljujahmpcdhf.supabase.co/functions/v1/alfred-router",
    "allowed_updates": ["message", "callback_query"]
  }'
```

### Comandos configurados

| Comando | Handler | Ação |
|---------|---------|------|
| `/missao` | alfred-router | Cria nova missão com contexto do usuário |
| `/status` | alfred-router | Snapshot: agentes ativos, missões abertas, alertas |
| `/decidir` | alfred-router | Aprovação/rejeição de escalação L3 |
| `/agentes` | alfred-router | Lista agentes com status e última missão |

### Formato de mensagem de entrada

O alfred-router recebe o update do Telegram e cria a missão no Supabase:
```json
{
  "mission_title": "extraído do texto do comando",
  "agent_slug": "alfred",
  "client_slug": "wolf-agency",
  "created_by": "telegram"
}
```

---

## ClickUp

### Configuração (em `.env`)

```bash
CLICKUP_API_TOKEN=pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
CLICKUP_LIST_ID=901306028132
```

### Endpoints usados pelo Alfred (wolf-clickup-digest)

```
# Todas as tarefas abertas
GET https://api.clickup.com/api/v2/list/901306028132/task?include_closed=false
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP

# Tarefas com prazo hoje
GET /list/901306028132/task?due_date_gt={inicio_dia_ms}&due_date_lt={fim_dia_ms}&include_closed=false

# Tarefas atrasadas
GET /list/901306028132/task?due_date_lt={agora_ms}&include_closed=false
```

> ⚠️ Header é `Authorization: TOKEN` (sem Bearer)
> ⚠️ Timestamps em milissegundos

### Sincronização bidirecional (futuro — via Atlas)

Quando implementado, Atlas vai:
1. Criar tarefa no ClickUp quando missão é criada no WMC
2. Atualizar status quando missão muda para `done` ou `blocked`
3. Detectar tarefas novas no ClickUp e criar missão correspondente no WMC

---

## Evolution API (WhatsApp)

### Setup local com Docker

```bash
docker run -d \
  --name evolution-api \
  -p 8080:8080 \
  -e API_KEY=wolf-evolution-key \
  -e AUTHENTICATION_TYPE=apikey \
  atendai/evolution-api:latest
```

### Variáveis de ambiente necessárias

```bash
EVOLUTION_API_URL=http://localhost:8080
EVOLUTION_API_KEY=wolf-evolution-key
EVOLUTION_INSTANCE=wolf-instance
```

### Handler (Edge Function — a implementar)

Recebe mensagens do WhatsApp e cria missões no WMC, similar ao alfred-router do Telegram.
Útil para:
- Netto criar missões via WhatsApp
- Echo enviar atualizações de cliente via WhatsApp
- Atlas notificar clientes sobre status de entrega

---

## N8N Workflows

### Workflow 1: Relatório Diário (18h)

```
Cron (18h) → GET Supabase (missions hoje) → Formatar → POST telegram-notifier
```

Alternativa ao pg_cron da migration 009 para quem prefere visual.

### Workflow 2: Monitor CPA (a cada hora)

```
Cron (1h) → GET Meta Ads API → Calcular CPA →
  SE CPA > meta × 1.5 → POST WMC (criar missão Gabi) → POST telegram-notifier (alerta)
```

Necessita `META_ADS_ACCESS_TOKEN` (ainda não configurado).

### Workflow 3: Sync ClickUp → WMC

```
ClickUp Webhook → N8N → GET task details → POST Supabase (criar missão Atlas)
```

Registrar webhook no ClickUp:
```bash
curl -X POST https://api.clickup.com/api/v2/team/{team_id}/webhook \
  -H "Authorization: pk_3138195_..." \
  -d '{"endpoint": "{N8N_WEBHOOK_URL}", "events": ["taskUpdated", "taskCreated"]}'
```

---

## Status das Integrações

| Integração | Status | Bloqueio |
|-----------|--------|---------|
| Telegram Bot | ✅ Ativo | — |
| ClickUp (leitura) | ✅ Ativo | — |
| ClickUp (sync bidirecional) | ⏳ Pendente | Requer implementação Atlas |
| WhatsApp (Evolution) | ⏳ Pendente | Docker local + handler Edge Function |
| N8N | ⏳ Pendente | Instância N8N não configurada |
| Meta Ads API | ❌ Bloqueado | `META_ADS_ACCESS_TOKEN` não configurado |
| Google Ads API | ❌ Bloqueado | Credenciais não configuradas |
| GA4 | ❌ Bloqueado | `GA4_PROPERTY_ID` não configurado |

---

*Wolf Mission Control · Integrações v1.0 · 2026-03-05*
