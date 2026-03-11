# REPORT-BUILDER — GABI · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
relatório, report, performance de ads, consolidar dados, resultado do mês, resumo de campanha

## PROTOCOLO
1. Definir período: semanal (seg–dom) ou mensal (1–último dia) ou customizado
2. Puxar dados Meta Ads: investimento, impressões, cliques, CTR, CPM, conversões, receita atribuída
3. Puxar dados Google Ads: investimento, cliques, conversões, ROAS, CPA por campanha
4. Puxar dados GA4: sessões, taxa de conversão, receita, canal de origem
5. Consolidar métricas-chave: ROAS total, CPA blended, CTR médio, CPM médio, frequência
6. Calcular variação vs período anterior: Δ% para cada métrica principal
7. Identificar top 3 performers (campanhas/adsets/criativos com melhor ROAS)
8. Identificar bottom 3 performers (maior gasto proporcional, menor retorno)
9. Gerar seção de recomendações: 3-5 ações priorizadas para o próximo período
10. Formatar relatório no template Wolf e registrar em activity.log

## OUTPUT
```
RELATÓRIO DE PERFORMANCE — [CLIENTE] — [PERÍODO]

VISÃO GERAL
| Métrica    | Período atual | Período anterior | Δ%    |
|------------|---------------|------------------|-------|
| ROAS       | X.X           | X.X              | +X%   |
| CPA        | R$ XX         | R$ XX            | -X%   |
| Investimento | R$ X.000    | R$ X.000         | +X%   |

TOP PERFORMERS | BOTTOM PERFORMERS

RECOMENDAÇÕES PARA O PRÓXIMO PERÍODO
1. [Ação] — Impacto estimado: [Alto/Médio]
```

## NUNCA
- Nunca misturar janelas de atribuição diferentes sem normalizar os dados
- Nunca gerar relatório sem ao menos 2 fontes de dados confirmadas
- Nunca omitir métricas negativas — transparência total com o cliente

---
*Sub-skill de: GABI | Versão: 2.0 | Atualizado: 2026-03-04*
