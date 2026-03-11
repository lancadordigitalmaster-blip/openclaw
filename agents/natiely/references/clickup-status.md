# ClickUp Status Mapping

## Status da Lista de Design

| Status | Cor | Significado | SLA | Ação Esperada |
|--------|-----|-------------|-----|---------------|
| **apontamentos** | 🔴 | Erro na demanda, precisa de correção | Imediato | Atendimento corrige e move para "para fazer" |
| **para fazer** | ⚪ | Nova demanda, aguardando início | 24-48h | Designer pega quando disponível |
| **produzindo** | 🔵 | Em andamento, designer trabalhando | 2h | Designer atualiza progresso |
| **em alteração** | 🟡 | Ajuste solicitado pelo cliente | Mesmo dia | Designer aplica alterações |
| **conferência interna** | 🟠 | Revisão interna do atendimento | 1h | Atendimento revisa e aprova/rejeita |
| **enviado ao cliente** | 🟣 | Aguardando aprovação do cliente | 1 dia | Cliente aprova ou solicita ajuste |
| **aprovado** | 🟢 | Cliente aprovou, finalizado | — | Arquivar com evidência |
| **arquivado** | ⚫ | Concluído e arquivado | — | Referência futura |

## Fluxo de Trabalho

```
apontamentos → para fazer → produzindo → conferência interna → enviado ao cliente → aprovado → arquivado
                    ↑________________________↓
                              em alteração
```

## Alertas de Status

### 🔴 Crítico (Ação Imediata)
- Tarefa em "apontamentos" há > 4h
- Tarefa em "conferência interna" há > 2h
- Tarefa em "enviado ao cliente" há > 2 dias sem resposta

### 🟡 Atenção (Ação em 24h)
- Tarefa em "para fazer" há > 48h
- Tarefa em "produzindo" há > 3 dias (aging)
- Tarefa em "em alteração" há > 24h

### 🟢 Normal
- Demais status dentro do SLA
