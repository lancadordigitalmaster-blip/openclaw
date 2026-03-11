# automation.md — Bridge Sub-Skill: Automação com n8n / Make / Zapier
# Ativa quando: "n8n", "Make", "Zapier", "workflow", "automação"

## Propósito

n8n é o orquestrador padrão de automações Wolf. Conecta sistemas externos, transforma dados e aciona ações sem escrever código para cada fluxo. Saber quando usar n8n vs código customizado economiza tempo e mantém manutenibilidade.

---

## Quando Usar Cada Ferramenta

| Ferramenta | Usar quando | Evitar quando |
|------------|-------------|---------------|
| **n8n** | Integração entre sistemas, transformação de dados, workflows com condicionais | Lógica de negócio complexa, processamento de dados em escala |
| **Código customizado** | Lógica complexa, performance crítica, transformações avançadas | Simples triggers → ações que n8n resolve em 10 minutos |
| **Make** | Cliente não-técnico precisa manter, sem servidor próprio | Automações críticas que precisam de SLA alto |
| **Zapier** | Última opção — protótipo rápido apenas | Produção (caro, limitado, difícil de debugar) |

---

## n8n — Configuração Wolf

### Self-hosted com Docker

```yaml
# docker-compose.yml
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    environment:
      N8N_HOST: n8n.wolf.agency
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://n8n.wolf.agency/
      GENERIC_TIMEZONE: America/Sao_Paulo
      N8N_BASIC_AUTH_ACTIVE: true
      N8N_BASIC_AUTH_USER: ${N8N_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_PASSWORD}
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: ${DB_USER}
      DB_POSTGRESDB_PASSWORD: ${DB_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
```

---

## Patterns de Workflow n8n

### Pattern 1: Trigger → Transform → Action

```
Trigger (Webhook / Cron / Event)
  ↓
Transform (Set / Function / Code Node)
  ↓
Condition (IF node)
  ↓ Yes          ↓ No
Action A      Action B
```

**Exemplo Wolf: Alert Meta Ads → ClickUp + WhatsApp**

```
[Webhook Trigger]
Recebe alerta de CPA alto da Bridge
  ↓
[Set Node]
Mapeia campos:
- campaignName: {{ $json.campaign_name }}
- currentCPA: {{ $json.cpa_current }}
- targetCPA: {{ $json.cpa_target }}
- accountId: {{ $json.account_id }}
  ↓
[IF Node]
currentCPA > targetCPA * 1.3 → Crítico
currentCPA > targetCPA * 1.1 → Aviso
  ↓ Crítico
[HTTP Request — ClickUp]
POST /api/v2/list/{listId}/task
Cria task priority=1 (urgent)
  ↓
[HTTP Request — Evolution]
POST /message/sendText/{instance}
Envia WhatsApp para analista responsável
```

### Pattern 2: Cron → Aggregation → Report

```
[Cron Trigger]
Todo segunda-feira às 9h
  ↓
[HTTP Request — Meta Ads]
Busca insights da semana
  ↓
[HTTP Request — Google Ads]
Busca insights da semana
  ↓
[Code Node]
Consolida e calcula KPIs
  ↓
[HTTP Request — Google Sheets]
Atualiza planilha de relatório
  ↓
[Send Email / WhatsApp]
Notifica cliente
```

### Pattern 3: Error Handler

```
[Qualquer node]
  ↓ (em caso de erro)
[Error Trigger]
  ↓
[Set Node]
Formata mensagem de erro
  ↓
[Slack / WhatsApp]
Notifica canal #eng-alerts
  ↓
[ClickUp]
Cria task de investigação
```

---

## Tratamento de Erro em Workflows

```javascript
// Code Node para tratamento robusto
const items = $input.all();
const results = [];
const errors = [];

for (const item of items) {
  try {
    const processed = processItem(item.json);
    results.push({ json: processed });
  } catch (error) {
    errors.push({
      json: {
        error: error.message,
        item: item.json,
        timestamp: new Date().toISOString(),
      }
    });
  }
}

// Retorna tanto resultados quanto erros para próximos nodes tratarem
return [...results, ...errors];
```

**Configuração de retry em nodes HTTP:**
- Max Tries: 3
- Wait Between Tries: 1000ms (com tipo "Exponential Backoff")
- Continue on Fail: depende do workflow

---

## Convenções Wolf para n8n

### Nomenclatura de Workflows

```
[Sistema] Nome Descritivo
Ex:
- [Meta Ads] Sync Insights Diário
- [Evolution] Notificação de Alerta
- [ClickUp] Criar Task de Bug Automático
- [Clientes] Relatório Semanal — {NomeCliente}
```

### Organização

```
n8n/
├── Alertas e Monitoramento/
│   ├── [Meta Ads] CPA Alto → ClickUp + WhatsApp
│   └── [Sistema] Health Check → Alerta
├── Relatórios/
│   ├── [Clientes] Relatório Semanal Automático
│   └── [Interno] Dashboard Semanal Wolf
└── Integrações/
    ├── [ClickUp] Sync Tasks → Notion
    └── [Slack] Comandos → Bridge
```

### Credenciais

- Nunca hardcoda tokens em workflows
- Usa "Credentials" do n8n (criptografadas no banco)
- Nome padrão: `[Provider] Wolf Agency` (ex: `Meta Ads Wolf Agency`)

---

## Alternativas: Make para Não-Devs

### Quando indicar Make ao invés de n8n

- Automação precisa ser mantida por CS ou PM (não dev)
- Integração simples entre dois SaaS (ex: Form → CRM)
- Cliente quer gerenciar a própria automação

### Limitações Make vs n8n

| Aspecto | n8n (self-hosted) | Make |
|---------|-------------------|------|
| Controle de dados | Total | Dados passam pela cloud Make |
| Custo (alto volume) | Fixo (servidor) | Por operação (pode escalar caro) |
| Complexidade máxima | Alta (código custom) | Média |
| Debug | Completo | Limitado |
| SLA | Controlado | Depende da Make |

---

## Zapier — Apenas Prototipagem

```
REGRA WOLF: Zapier não vai para produção.

- OK para: demonstrar conceito para cliente, prototipo de 1 dia
- Não OK para: automações de negócio, acesso a dados sensíveis, produção
```

---

## Checklist de Workflow n8n

- [ ] Workflow nomeado com convenção `[Sistema] Descrição`
- [ ] Credenciais usando sistema de credentials do n8n (não hardcoded)
- [ ] Error Handler configurado (notifica em falha)
- [ ] Retry configurado em nodes HTTP externos
- [ ] Workflow testado com dados reais antes de ativar
- [ ] Documentação no Description do workflow (primeiro node)
- [ ] Webhook URLs documentadas (se usa webhook trigger)
- [ ] Logs de execução revisados após ativação
- [ ] Alertas configurados para falhas repetidas
- [ ] Owner identificado (quem mantém este workflow)
