# AUDIT — GABI · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
audit, health check, auditoria de conta, verificar conta, diagnóstico de ads, saúde da conta

## PROTOCOLO
1. Mapear estrutura completa: campanhas > adsets > anúncios ativos/pausados/arquivados
2. Verificar campanhas ativas sem conversão registrada nos últimos 7+ dias
3. Checar adsets com overlap de público > 20% entre si na mesma campanha
4. Analisar criativos: CTR abaixo de 0.8% (Feed), CPM acima do benchmark do nicho
5. Verificar configurações de otimização: evento de conversão, janela de atribuição, estratégia de lance
6. Identificar gastos sem retorno: adsets com CPA > 3x meta definida em clients.yaml
7. Checar frequência: adsets com frequência > 3.5 em campanhas de topo de funil
8. Calcular score de saúde (0-10): -1 por campanha sem conversão, -0.5 por overlap, -1 por criativo em fadiga
9. Compilar lista dos top 5 problemas priorizados por impacto estimado em receita
10. Registrar resultado em activity.log com timestamp e score

## OUTPUT
```
AUDIT REPORT — [CLIENTE] — [DATA]
Score de Saúde: X/10

ESTRUTURA
- Campanhas ativas: X | Adsets ativos: X | Anúncios ativos: X

TOP 5 PROBLEMAS (por impacto)
1. [Problema] — Impacto: [Alto/Médio/Baixo] — Ação: [o que fazer]
2. ...

PRÓXIMOS PASSOS IMEDIATOS
- [ ] Ação 1
- [ ] Ação 2
```

## NUNCA
- Nunca pausar campanhas sem confirmação explícita do operador
- Nunca comparar métricas de nichos diferentes sem ajuste de benchmark
- Nunca gerar score sem analisar ao menos 7 dias de dados

---
*Sub-skill de: GABI | Versão: 2.0 | Atualizado: 2026-03-04*
