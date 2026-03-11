# SKILL.md — Wolf ClickUp Digest
# Wolf Agency AI System | Versão: 2.1 | Atualizado: 2026-03-05

> Digest de tarefas do ClickUp da Wolf Agency.
> Alfred usa esta skill para consultar tarefas, prazos e pendências diretamente via API.

---

## Agent

**Alfred** — operações internas e gestão de projetos.

---

## Configuração

```
Token:   pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
List ID: 901306028132
Base URL: https://api.clickup.com/api/v2

Header: Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

> ⚠️ O header Authorization no ClickUp NÃO usa "Bearer". É o token puro.
> ⚠️ Timestamps no ClickUp são em **milissegundos** (não segundos).

---

## API — Endpoints Principais

Alfred usa web.fetch para chamar a API. Use estes endpoints:

### Todas as tarefas da lista (principal)

```
GET https://api.clickup.com/api/v2/list/901306028132/task
  ?include_closed=false
  &subtasks=true
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

### Tarefas com prazo HOJE

```
GET https://api.clickup.com/api/v2/list/901306028132/task
  ?due_date_gt=TIMESTAMP_INICIO_HOJE_MS
  &due_date_lt=TIMESTAMP_FIM_HOJE_MS
  &include_closed=false
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

### Tarefas ATRASADAS

```
GET https://api.clickup.com/api/v2/list/901306028132/task
  ?due_date_lt=TIMESTAMP_AGORA_MS
  &include_closed=false
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

### Tarefas da SEMANA

```
GET https://api.clickup.com/api/v2/list/901306028132/task
  ?due_date_gt=TIMESTAMP_SEGUNDA_MS
  &due_date_lt=TIMESTAMP_DOMINGO_MS
  &include_closed=false
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

### Membros da lista (para filtrar por pessoa)

```
GET https://api.clickup.com/api/v2/list/901306028132/member
Authorization: pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP
```

### Campos da resposta

```json
{
  "tasks": [
    {
      "id": "abc123",
      "name": "Nome da tarefa",
      "status": { "status": "in progress" },
      "priority": { "priority": "urgent" },
      "assignees": [{ "id": 123, "username": "netto" }],
      "due_date": "1709856000000",
      "date_updated": "1709769600000",
      "list": { "name": "Wolf Agency" }
    }
  ]
}
```

---

## Protocolo de Digest

```
CLICKUP_DIGEST_PROTOCOL:

  TIMESTAMPS (milissegundos):
    Agora         = int(time.time() * 1000)
    Início do dia = hoje às 00:00:00 em ms
    Fim do dia    = hoje às 23:59:59 em ms
    48h atrás     = agora - (48 * 60 * 60 * 1000)

  PARA O DIGEST PADRÃO:
    1. Busca TODAS as tarefas abertas:
       GET /list/901306028132/task?include_closed=false
    2. Filtra localmente:
       - Atrasadas: due_date presente e < agora
       - Hoje: due_date entre início e fim do dia
       - Paradas 48h+: date_updated < agora - 172800000
       - Urgentes sem prazo: priority = urgent ou high
    3. Monta output consolidado
```

---

## Formato de Output

```
📋 Wolf ClickUp — [DATA]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Concluídas hoje: [N]
⏰ Com prazo hoje:  [N]
🚨 Atrasadas:       [N]
🔄 Paradas (48h+):  [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚨 ATRASADAS:
• [Nome] — [responsável] — venceu [X dias atrás]

⏰ HOJE:
• [Nome] — [responsável] — prioridade: [high/urgent]

🔄 PARADAS (sem update):
• [Nome] — [status] — última atualização: [X dias atrás]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Se não houver itens: "✅ ClickUp limpo — sem pendências críticas."

---

## Triggers

```
"digest do clickup" | "digest do dia" | "tarefas hoje"
"o que tá atrasado" | "tarefas atrasadas"
"digest da semana" | "o que tem pra semana"
"tarefas do [nome]" | "consulta o clickup" | "verifica o clickup"
```

---

## Regras

- Alfred tem acesso **somente leitura**. NUNCA criar/mover/deletar sem aprovação do Netto.
- Erro 401: token inválido → avisar Netto.
- Erro 429: rate limit → aguardar 60s e tentar novamente.

---

## Heartbeat

Incluído no resumo matinal (8h30):
- Tarefas com prazo hoje + atrasadas de alta prioridade

---

*Agente: Alfred | Skill: wolf-clickup-digest | Versão: 2.1 | Atualizado: 2026-03-05*
