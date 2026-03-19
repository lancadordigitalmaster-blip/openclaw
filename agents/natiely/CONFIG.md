# Configuração do Agente Natiely

## Status
✅ Agente operacional — integrado com ClickUp API real (2026-03-18)

## Estrutura
```
agents/natiely/
├── SKILL.md                          # Documentação principal
├── natiely.sh                        # Script executor (ClickUp integrado)
├── CONFIG.md                         # Este arquivo
└── references/
    ├── clickup-status.md             # Mapeamento de status
    ├── metricas-fluxo.md             # Fórmulas de KPIs
    └── templates-relatorio.md        # Templates de saída
```

## Requisitos

- `CLICKUP_API_TOKEN` definido em `~/.openclaw/.env`
- Team ID: 3076130
- Listas: 901306028132 (Produção DSGN), 901306028133 (Núcleo Criativo)

## Comandos

| Comando | Descrição | Status |
|---------|-----------|--------|
| `relatorio` | Relatório de demanda por designer (vs metas) | ✅ Operacional |
| `validar` | Validação de tarefas (campos obrigatórios) | ✅ Operacional |
| `alertas` | Alertas de SLA (deadlines, gargalos, bloqueios) | ✅ Operacional |
| `metricas` | KPIs de fluxo (WIP, throughput, aging) | ✅ Operacional |

## Uso

```bash
./agents/natiely/natiely.sh relatorio
./agents/natiely/natiely.sh alertas
./agents/natiely/natiely.sh validar
./agents/natiely/natiely.sh metricas
```

## Integração Telegram

Alfred detecta "Natiely" e ativa o agente automaticamente:
- "Natiely, relatório" → Gera relatório
- "Natiely, alertas" → Lista alertas
- "Natiely, métricas" → Mostra KPIs
