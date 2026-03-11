# Configuração do Agente Natiely

## Status
✅ Agente criado e configurado
⚠️ Integração ClickUp pendente

## Estrutura Criada
```
agents/natiely/
├── SKILL.md                          # Documentação principal
├── natiely.sh                        # Script executor
└── references/
    ├── clickup-status.md             # Mapeamento de status
    ├── metricas-fluxo.md             # Fórmulas de KPIs
    └── templates-relatorio.md        # Templates de saída
```

## Próximos Passos

### 1. Configurar ClickUp API
Criar arquivo `.env` na raiz do workspace:
```
CLICKUP_API_KEY=pk_seu_token_aqui
CLICKUP_LIST_ID=123456789
CLICKUP_TEAM_ID=987654321
```

### 2. Definir Designers e Metas
Criar arquivo `agents/natiely/config/designers.yaml`:
```yaml
designers:
  - nome: "Designer 1"
    meta_diaria: 3
    clickup_id: "user_id_1"
  - nome: "Designer 2"
    meta_diaria: 3
    clickup_id: "user_id_2"
```

### 3. Testar Integração
```bash
./agents/natiely/natiely.sh relatorio
```

## Comandos Disponíveis

| Comando | Descrição | Status |
|---------|-----------|--------|
| `relatorio` | Relatório de demanda | ✅ Simulação |
| `validar` | Validação de tarefas | ✅ Simulação |
| `alertas` | Alertas de SLA | ✅ Simulação |
| `metricas` | KPIs de fluxo | ✅ Simulação |

## Integração Telegram

Quando alguém mencionar no grupo:
- "Natiely, relatório" → Gera relatório
- "Natiely, alertas" → Lista alertas
- "Natiely, métricas" → Mostra KPIs

Alfred detecta "Natiely" e ativa o agente automaticamente.
