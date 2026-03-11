# SKILL.md — Wolf Mission Control · Bridge Supabase
# Wolf Agency AI System | Versao: 1.0 | Criado: 2026-03-06

> Registra TODA interacao relevante no Supabase para o dashboard Mission Control.
> Cada mensagem processada = 1 missao no WMC. Dashboard mostra tudo em tempo real.

---

## Agent

**Alfred** — registra automaticamente no WMC apos CADA interacao (grupo ou DM).

---

## Triggers

```
AUTOMATICO — esta skill e executada em TODA resposta relevante.
Nao depende de trigger keyword. O ORCHESTRATOR.md chama este passo ao final.
```

---

## Configuracao

Variaveis ja disponiveis no .env:
```
SUPABASE_URL=https://dqhiafxbljujahmpcdhf.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ... (JWT real)
```

---

## Como registrar uma missao

Apos processar qualquer pedido do usuario, faca um POST na REST API do Supabase:

```
POST $SUPABASE_URL/rest/v1/missions
Headers:
  apikey: $SUPABASE_ANON_KEY
  Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY
  Content-Type: application/json
  Prefer: return=representation
```

IMPORTANTE: O header `apikey` usa a ANON_KEY, mas o `Authorization` usa a SERVICE_ROLE_KEY.
Ambas estao no .env.

### Payload — Missao nova (status: done se ja respondeu)

```json
{
  "title": "[resumo curto da tarefa em 1 linha]",
  "description": "[contexto completo: o que foi pedido e o que foi entregue]",
  "agent_id": "[UUID do agente que executou — ver tabela abaixo]",
  "client_id": "[UUID do cliente se mencionado — ver tabela abaixo]",
  "status": "done",
  "priority": "medium",
  "priority_score": 0.5,
  "created_by": "telegram"
}
```

### Se a tarefa esta EM ANDAMENTO (ex: subagente processando):

```json
{
  "status": "in_progress",
  "priority": "high",
  "created_by": "telegram"
}
```

Quando concluir, UPDATE:
```
PATCH $SUPABASE_URL/rest/v1/missions?id=eq.[MISSION_ID]
Headers: (mesmos)
Body: { "status": "done", "completed_at": "[ISO timestamp]" }
```

---

## UUIDs — Agentes (usar na field agent_id)

UUIDs fixos (nao precisa consultar):

```
alfred  = a1abe880-f1e3-40aa-bb62-0f748f5ac2c2
gabi    = 2917064f-c5e0-488a-85fa-e1ee494dd74e
luna    = 62013484-3fae-4c0f-b767-50862aace334
sage    = ca48acd3-ad6d-45b6-88aa-5e123dae95ef
nova    = 2990278a-26bb-4f10-a056-03bcbc74d058
gabi    = 800e7e7a-5c54-4aad-a8d2-8b4a4b147a51
titan   = 10c5e66f-d2c2-4bef-a3ff-c604c1070882
pixel   = a80ea966-4c6d-49a0-863e-7420ca5d82b3
forge   = c106b8d2-b0a5-47e9-ab06-baf2885ef423
shield  = 5fa9ee7e-b33e-4c90-ad99-d35a08ff6f5a
atlas   = 2ccfa51e-eda1-49b1-967d-6fb423cb4448
echo    = 2c01996c-ff7f-46d4-99d6-310ecd5391a0
flux    = b9db11f2-cae1-40f6-bc4f-703d7bf1bf69
```

---

## UUIDs — Clientes (usar na field client_id)

```
GET $SUPABASE_URL/rest/v1/clients?select=id,slug&slug=eq.[SLUG]
Headers: apikey + Authorization com service key
```

Slugs disponiveis: wolf-agency (adicionar clientes reais em shared/memory/clients.yaml)

---

## Regras

1. **SEMPRE registre** — toda interacao que gera uma resposta substantiva vira missao
2. **Nao registre** — saudacoes simples ("oi", "ok", "obrigado"), confirmacoes curtas
3. **title** deve ser claro e curto: "Diagnostico CTR campanha [cliente]" (nao "Resposta ao pedido do usuario")
4. **agent_id** = quem executou (se Alfred respondeu direto, usar UUID do Alfred)
5. **client_id** = NULL se nao for sobre nenhum cliente especifico
6. **created_by** = "telegram" para mensagens do Telegram, "dashboard" para o frontend, "cron" para crons
7. Se o pedido envolve HANDOFF entre agentes, criar missoes separadas com parent_id

---

## Exemplo completo

Usuario no Telegram: "Gabi, analisa o CPA da campanha da Giovani Calcados"

1. Alfred roteia para Gabi (inline)
2. Gabi executa analise
3. Alfred registra no WMC:

```
POST $SUPABASE_URL/rest/v1/missions
{
  "title": "Analise CPA campanha Giovani Calcados",
  "description": "CPA atual analisado. [resumo do output do Gabi]",
  "agent_id": "[UUID do Gabi]",
  "client_id": "[UUID da Giovani Calcados]",
  "status": "done",
  "priority": "medium",
  "priority_score": 0.5,
  "created_by": "telegram"
}
```

Dashboard mostra automaticamente via Supabase Realtime.
