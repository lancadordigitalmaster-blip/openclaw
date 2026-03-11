# Mapeamento de Status ClickUp

## Status e Significados

| Status | Significado | SLA | Ação se Estourar |
|--------|-------------|-----|------------------|
| **apontamentos** | Erro na demanda — falta informação | **Imediato** | 🔴 Corrigir agora |
| **para fazer** | Designer não começou | 24-48h | Verificar data |
| **produzindo** | Designer trabalhando | 2h | Verificar complexidade |
| **em alteração** | Ajuste do cliente | Mesmo dia / 24h | Entregar hoje |
| **conferência interna** | Atendimento revisando | 1h | Cobrar atendimento |
| **enviado ao cliente** | Aguardando aprovação | 1 dia | Cobrar cliente |
| **finalizada** | Entregue e aprovada | — | — |

## Status de Bloqueio

| Status | Significado | Ação |
|--------|-------------|------|
| **pausado / bloqueado** | Impedimento externo | Identificar blocker |
| **aguardando cliente** | Feedback pendente | Cobrar cliente |
| **backlog congelado** | Prioridade suspensa | Reavaliar com PM |

## Status de Qualidade

| Status | Significado | Ação |
|--------|-------------|------|
| **material reprovado** | Cliente não aprovou | Refazer |
| **ajuste** | Pequena correção | Entregar rápido |

## Regras de Transição

1. **apontamentos** → **para fazer**: Só quando erro for corrigido
2. **para fazer** → **produzindo**: Designer iniciou
3. **produzindo** → **conferência interna**: Entregue para revisão
4. **conferência interna** → **enviado ao cliente**: Aprovado interno
5. **enviado ao cliente** → **finalizada**: Cliente aprovou
6. Qualquer → **em alteração**: Cliente pediu mudança

## Cores dos Status

- 🟢 **Verde**: para fazer, finalizada
- 🔴 **Vermelho**: em alteração, material reprovado
- 🟡 **Amarelo**: formatos, enviado ao cliente
- 🔵 **Azul**: conferência interna, aguardando cliente
- ⚫ **Preto/Cinza**: apontamentos, backlog congelado, pausado
