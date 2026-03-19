# ClickUp API — Skill Wolf Agency
# Versão: 2.0 | Atualizado: 2026-03-18

---

## Agent

**Atlas** — gestão de projetos

---

name: clickup-api
description: |
  ClickUp API integration via Personal API Token. Acessa tarefas, listas, folders, spaces,
  workspaces, users e webhooks. Use quando precisar gerenciar itens de trabalho ou consultar projetos.
compatibility: Requer CLICKUP_API_TOKEN no ~/.openclaw/.env
metadata:
  author: wolf-agency
  version: "2.0"
  requires:
    env:
      - CLICKUP_API_TOKEN

---

## Autenticação

Token pessoal ClickUp — ler SEMPRE do `~/.openclaw/.env`:

```python
import os
for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v
TOKEN = os.environ["CLICKUP_API_TOKEN"]
```

Header: `Authorization: $TOKEN` (sem "Bearer")

**NUNCA** hardcodar o token em código ou SKILL.md.

---

## IDs Conhecidos — Wolf Agency

| Recurso | ID | Nota |
|---------|-----|------|
| Team (Workspace) | 3076130 | Wolf Agency principal |
| List Produção DSGN | 901306028132 | Design — lista principal |
| List Núcleo Criativo | 901306028133 | Design — criativo |
| List Contas a Pagar | 901305981569 | Financeiro |
| List Contas a Receber | 901305981568 | Financeiro |
| Custom Field Design | b9b3676c-f119-48cf-851d-8ebd83e5011f | Designer responsável |

---

## Base URL

```
https://api.clickup.com/api/v2
```

---

## Endpoints Principais

### Workspace & Spaces

```bash
# Listar workspaces
GET /team

# Listar spaces de um workspace
GET /team/3076130/space

# Detalhes de um space
GET /space/{space_id}
```

### Folders & Lists

```bash
# Listar folders de um space
GET /space/{space_id}/folder

# Listar listas de um folder
GET /folder/{folder_id}/list

# Listar listas sem folder
GET /space/{space_id}/list
```

### Tasks (mais usado)

```bash
# Todas as tarefas de uma lista
GET /list/{list_id}/task?include_closed=false&subtasks=true

# Tarefas filtradas por time (todas as listas)
GET /team/3076130/task?include_closed=false&list_ids[]=901306028132&list_ids[]=901306028133

# Tarefa específica
GET /task/{task_id}

# Criar tarefa
POST /list/{list_id}/task
Body: {"name": "...", "description": "...", "assignees": [...], "priority": 2, "due_date": 1709251200000}

# Atualizar tarefa
PUT /task/{task_id}
Body: {"status": "em andamento", "priority": 1}

# Deletar tarefa
DELETE /task/{task_id}
```

### Query Parameters (Tasks)

| Param | Tipo | Descrição |
|-------|------|-----------|
| `include_closed` | bool | Incluir tarefas fechadas |
| `page` | int | Paginação (0-indexed, 100/página) |
| `subtasks` | bool | Incluir subtarefas |
| `statuses[]` | string | Filtrar por status |
| `assignees[]` | int | Filtrar por responsável |
| `due_date_gt` | int | Due date maior que (Unix ms) |
| `due_date_lt` | int | Due date menor que (Unix ms) |
| `date_updated_gt` | int | Atualizado após (Unix ms) |

### Users & Webhooks

```bash
# Usuário atual
GET /user

# Membros de uma lista
GET /list/{list_id}/member

# Webhooks
GET /team/3076130/webhook
POST /team/3076130/webhook
```

---

## Exemplos Python

### Buscar tarefas ativas

```python
import urllib.request, json, os

# Ler token do .env
for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k] = v

TOKEN = os.environ["CLICKUP_API_TOKEN"]
LIST_ID = "901306028132"

req = urllib.request.Request(
    f"https://api.clickup.com/api/v2/list/{LIST_ID}/task?include_closed=false",
    headers={"Authorization": TOKEN}
)
data = json.loads(urllib.request.urlopen(req, timeout=15).read())
for task in data.get("tasks", []):
    print(f"{task['status']['status']:20s} | {task['name'][:50]}")
```

### Criar tarefa

```python
import urllib.request, json, os

TOKEN = os.environ["CLICKUP_API_TOKEN"]
LIST_ID = "901306028132"

body = json.dumps({
    "name": "Nova tarefa",
    "description": "Descrição da tarefa",
    "priority": 3,
    "status": "para fazer"
}).encode()

req = urllib.request.Request(
    f"https://api.clickup.com/api/v2/list/{LIST_ID}/task",
    data=body, method="POST",
    headers={"Authorization": TOKEN, "Content-Type": "application/json"}
)
resp = json.loads(urllib.request.urlopen(req, timeout=15).read())
print(f"Criada: {resp['id']} — {resp['name']}")
```

---

## Notas

- Task IDs são strings
- Timestamps são Unix em **milissegundos**
- Priority: 1=urgente, 2=alta, 3=normal, 4=baixa, null=nenhuma
- Workspaces são chamados "teams" na API
- Status deve corresponder exatamente ao nome configurado na lista
- Respostas limitadas a 100 itens por página (`last_page: true` indica fim)
- Timezone: BRT (UTC-3) — converter timestamps antes de exibir

## Erros Comuns

| Status | Significado |
|--------|-------------|
| 400 | Requisição malformada |
| 401 | Token inválido — verificar CLICKUP_API_TOKEN no .env |
| 403 | Sem permissão |
| 404 | Recurso não encontrado |
| 429 | Rate limit — aguardar 60s |

---

## Segurança

- **Somente leitura** por padrão. Criar/mover/deletar tarefas requer aprovação do Netto.
- NUNCA expor o token em logs, mensagens ou relatórios.

---

*Skill: clickup-api | Agent: Atlas | Versão: 2.0 | Atualizado: 2026-03-18*
