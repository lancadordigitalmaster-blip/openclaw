# BUDGET-MONITOR — GABI · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
budget, pacing, gasto, orçamento, overspend, underpacing, projeção de gasto, ritmo de investimento

## PROTOCOLO
1. Puxar gasto acumulado do dia e do mês (Meta Ads API + Google Ads API)
2. Calcular budget esperado para o dia: (budget_mensal / dias_no_mês) × dia_atual
3. Calcular pacing ratio: gasto_real / budget_esperado
   - < 0.85 = underpacing | 0.85–1.15 = no ritmo | > 1.15 = overspend
4. Identificar campanhas individuais com overspend acima de 20% do budget diário delas
5. Projetar gasto do mês: (gasto_acumulado / dia_atual) × total_dias_no_mês
6. Comparar projeção vs budget mensal contratado (em clients.yaml)
7. Se projeção > budget + 10%: emitir alerta CRÍTICO com valor em risco
8. Se projeção < budget - 15%: emitir alerta de underpacing com oportunidade perdida estimada
9. Recomendar ajuste de budget diário por campanha para normalizar pacing
10. Registrar snapshot em activity.log

## OUTPUT
```
BUDGET MONITOR — [CLIENTE] — [DATA HH:MM]

RESUMO
- Budget mensal: R$ X.000 | Gasto até hoje: R$ X.000
- Pacing ratio: X.XX (STATUS: OVERSPEND / NO RITMO / UNDERPACING)
- Projeção do mês: R$ X.000 (Δ +X% vs budget)

ALERTAS
[CRÍTICO] Campanha "X": R$ XXX gastos vs R$ XXX esperado hoje
[ATENÇÃO] ...

RECOMENDAÇÃO
- Reduzir budget diário da campanha X de R$ XX para R$ XX
```

## NUNCA
- Nunca alterar budgets diretamente sem aprovação do operador
- Nunca usar dados de apenas 1 dia para calcular projeção mensal (mínimo 3 dias)
- Nunca ignorar sazonalidades na comparação de pacing

---
*Sub-skill de: GABI | Versão: 2.0 | Atualizado: 2026-03-04*
