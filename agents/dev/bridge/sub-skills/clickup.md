# clickup.md — Bridge Sub-Skill: ClickUp API
# Ativa quando: "ClickUp", "tarefa", "projeto", "automação ClickUp"

## Propósito

Automatizar criação e gestão de tasks no ClickUp a partir de eventos Wolf: alertas de campanha, pendências detectadas por agentes, mudanças de status, relatórios. Bridge mantém ClickUp sincronizado com o que acontece nos sistemas.

---

## Configuração

```typescript
import axios from 'axios';

const clickup = axios.create({
  baseURL: 'https://api.clickup.com/api/v2',
  headers: {
    Authorization: process.env.CLICKUP_API_TOKEN,
    'Content-Type': 'application/json',
  },
  timeout: 10000,
});

// IDs Wolf (configurar em variáveis de ambiente)
const WOLF_WORKSPACE = {
  teamId: process.env.CLICKUP_TEAM_ID,
  spaces: {
    engineering: process.env.CLICKUP_SPACE_ENGINEERING,
    operations: process.env.CLICKUP_SPACE_OPERATIONS,
    clients: process.env.CLICKUP_SPACE_CLIENTS,
  },
  lists: {
    bugs: process.env.CLICKUP_LIST_BUGS,
    alerts: process.env.CLICKUP_LIST_ALERTS,
    backlog: process.env.CLICKUP_LIST_BACKLOG,
  },
};
```

---

## Estrutura ClickUp API v2

```
Team (Workspace Wolf)
└── Space (Engenharia, Operações, Clientes)
    └── Folder (opcional — agrupa listas)
        └── List (Backlog, In Progress, Bugs, Alerts)
            └── Task
                ├── Subtasks
                ├── Comments
                ├── Attachments
                └── Custom Fields
```

### Obter IDs necessários

```bash
# Listar spaces do workspace
curl -s "https://api.clickup.com/api/v2/team/${TEAM_ID}/space" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" | jq '.spaces[] | {id, name}'

# Listar listas de um space
curl -s "https://api.clickup.com/api/v2/space/${SPACE_ID}/list" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" | jq '.lists[] | {id, name}'
```

---

## Criação de Tasks

### Task básica

```typescript
interface CreateTaskParams {
  listId: string;
  name: string;
  description?: string;
  priority?: 1 | 2 | 3 | 4; // 1=urgent, 2=high, 3=normal, 4=low
  assignees?: number[];      // User IDs do ClickUp
  dueDate?: number;          // Unix timestamp em ms
  tags?: string[];
  customFields?: Array<{
    id: string;
    value: string | number | boolean;
  }>;
}

async function createTask(params: CreateTaskParams) {
  const { data } = await clickup.post(`/list/${params.listId}/task`, {
    name: params.name,
    description: params.description,
    priority: params.priority,
    assignees: params.assignees,
    due_date: params.dueDate,
    tags: params.tags,
    custom_fields: params.customFields,
  });
  return data;
}
```

### Task com markdown

```typescript
async function createAlertTask(alert: {
  type: string;
  campaignName: string;
  details: string;
  accountId: string;
  severity: 'critical' | 'warning' | 'info';
}) {
  const priorityMap = { critical: 1, warning: 2, info: 3 } as const;

  const description = `
## Alerta Detectado

**Tipo:** ${alert.type}
**Campanha:** ${alert.campaignName}
**Conta:** ${alert.accountId}
**Severidade:** ${alert.severity}

### Detalhes
${alert.details}

### Ações Recomendadas
- Revisar métricas da campanha no painel Meta Ads
- Verificar se há mudança significativa no target ou criativos
- Documentar ação tomada como comentário nesta task

---
*Task criada automaticamente por Bridge em ${new Date().toISOString()}*
  `.trim();

  return createTask({
    listId: WOLF_WORKSPACE.lists.alerts,
    name: `[${alert.severity.toUpperCase()}] ${alert.type} — ${alert.campaignName}`,
    description,
    priority: priorityMap[alert.severity],
    tags: ['auto-gerado', 'alerta', alert.type.toLowerCase()],
    customFields: [
      { id: process.env.CF_ACCOUNT_ID, value: alert.accountId },
      { id: process.env.CF_SOURCE, value: 'bridge-agent' },
    ],
  });
}
```

---

## Atualização de Status

```typescript
// Status padrão Wolf (IDs variam por lista)
type TaskStatus = 'to do' | 'in progress' | 'review' | 'done' | 'closed';

async function updateTaskStatus(taskId: string, status: TaskStatus) {
  const { data } = await clickup.put(`/task/${taskId}`, { status });
  return data;
}

// Fechar task com comentário
async function closeTaskWithComment(taskId: string, resolution: string) {
  await addTaskComment(taskId, `**Resolução:** ${resolution}`);
  await updateTaskStatus(taskId, 'closed');
}

// Adicionar comentário
async function addTaskComment(taskId: string, comment: string) {
  const { data } = await clickup.post(`/task/${taskId}/comment`, {
    comment_text: comment,
    notify_all: false,
  });
  return data;
}
```

---

## Busca e Deduplicação

```typescript
// Buscar tasks existentes antes de criar (evita duplicatas)
async function findExistingAlert(listId: string, alertType: string, campaignId: string) {
  const { data } = await clickup.get(`/list/${listId}/task`, {
    params: {
      statuses: ['to do', 'in progress'],
      custom_fields: JSON.stringify([
        { field_id: process.env.CF_SOURCE, operator: '=', value: 'bridge-agent' },
      ]),
      include_closed: false,
    },
  });

  return data.tasks.find(
    (task: any) =>
      task.name.includes(alertType) &&
      task.custom_fields?.find(
        (f: any) => f.id === process.env.CF_ACCOUNT_ID && f.value === campaignId
      )
  );
}

// Criar ou atualizar task (idempotente)
async function upsertAlertTask(alert: AlertData) {
  const existing = await findExistingAlert(
    WOLF_WORKSPACE.lists.alerts,
    alert.type,
    alert.accountId,
  );

  if (existing) {
    await addTaskComment(
      existing.id,
      `**Update ${new Date().toISOString()}:** ${alert.details}`
    );
    return existing;
  }

  return createAlertTask(alert);
}
```

---

## Webhooks ClickUp → Wolf

```typescript
// Registrar webhook
async function registerClickUpWebhook(endpoint: string) {
  const { data } = await clickup.post(`/team/${WOLF_WORKSPACE.teamId}/webhook`, {
    endpoint,
    events: [
      'taskStatusUpdated',
      'taskAssigneeUpdated',
      'taskCommentPosted',
      'taskCreated',
    ],
  });
  return data;
}

// Handler de eventos ClickUp
app.post('/webhooks/clickup', async (req, res) => {
  res.status(200).send('ok');

  const { event, task_id } = req.body;

  switch (event) {
    case 'taskStatusUpdated':
      await handleTaskStatusChange(task_id, req.body);
      break;
    case 'taskCommentPosted':
      await handleTaskComment(task_id, req.body);
      break;
  }
});

// Notificar canal Slack quando task crítica é atualizada
async function handleTaskStatusChange(taskId: string, event: any) {
  const task = await clickup.get(`/task/${taskId}`);
  const isCritical = task.data.tags?.includes('alerta') && task.data.priority === 1;

  if (isCritical && event.status === 'closed') {
    await notifySlack(`#eng-ops`, `Task crítica resolvida: ${task.data.name}`);
  }
}
```

---

## Custom Fields Wolf

Campos customizados padrão para tasks automáticas:

| Campo | Tipo | Uso |
|-------|------|-----|
| `CF_SOURCE` | texto | 'bridge-agent', 'quill', 'manual' |
| `CF_ACCOUNT_ID` | texto | ID da conta Meta/Google |
| `CF_CAMPAIGN_ID` | texto | ID da campanha |
| `CF_SEVERITY` | dropdown | critical, warning, info |
| `CF_AUTO_RESOLVED` | checkbox | Task resolvida automaticamente |

```typescript
// Criar task com custom fields
const task = await createTask({
  listId: WOLF_WORKSPACE.lists.alerts,
  name: 'CPA acima do target — Black Friday',
  customFields: [
    { id: process.env.CF_SOURCE, value: 'bridge-agent' },
    { id: process.env.CF_ACCOUNT_ID, value: 'act_123456' },
    { id: process.env.CF_SEVERITY, value: 'warning' },
  ],
});
```

---

## Checklist de Integração ClickUp

- [ ] CLICKUP_API_TOKEN em variável de ambiente
- [ ] IDs de spaces e listas mapeados em variáveis de ambiente
- [ ] Custom fields para source e account_id configurados
- [ ] Deduplicação implementada antes de criar tasks
- [ ] Comentários adicionados em tasks existentes (não cria duplicata)
- [ ] Webhook configurado para receber atualizações de status
- [ ] Prioridade mapeada corretamente (critical=1, warning=2, info=3)
- [ ] Tasks automáticas marcadas com tag 'auto-gerado'
- [ ] Timeout de 10s nas chamadas
- [ ] Logs com task_id para rastreamento
