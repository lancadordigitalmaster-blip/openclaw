# RANK-TRACKER — SAGE · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
rank tracker, monitorar posições, posições do Google, ranking de keywords, onde estou no Google, variação de posições

## PROTOCOLO
1. Carregar lista de keywords monitoradas do cliente (em clients.yaml ou planilha de keywords do cliente)
2. Puxar posições atuais via DataForSEO (SERP Checker) para cada keyword monitorada
3. Comparar posições em 4 janelas temporais: hoje vs ontem, hoje vs 7 dias atrás, hoje vs 30 dias atrás
4. Calcular variação absoluta (posições ganhas/perdidas) e variação percentual para cada janela
5. Identificar e classificar movimentações:
   - Maiores ganhos: keywords que subiram mais de 5 posições no período
   - Maiores quedas: keywords que caíram mais de 5 posições no período
   - Entradas no top 10: keywords que entraram pela primeira vez ou voltaram ao top 10
   - Saídas do top 10: keywords que caíram abaixo da posição 10
6. Calcular tráfego orgânico estimado por keyword usando CTR médio por posição:
   - Pos 1: 31.7% | Pos 2: 24.7% | Pos 3: 18.7% | Pos 4: 13.6% | Pos 5-10: decrescente
7. Calcular impacto total em tráfego estimado: comparar tráfego estimado atual vs 30 dias atrás
8. Verificar threshold de alerta definido em clients.yaml — se variação > threshold: gerar alerta imediato
9. Identificar possível causa de quedas expressivas (mudança de algoritmo, concorrente novo, problema técnico)
10. Registrar snapshot completo em activity.log com data e hora

## OUTPUT
```
RANK TRACKER — [CLIENTE] — [DATA]
Keywords monitoradas: XX | Tráfego estimado: X.XXX/mês (Δ +/-X% vs 30d)

MAIORES GANHOS (últimos 7 dias)
| Keyword           | Posição Atual | Posição -7d | Δ    | Tráfego Est. |
|-------------------|---------------|-------------|------|--------------|
| [keyword]         | 3             | 11          | +8   | ~XXX         |

MAIORES QUEDAS (últimos 7 dias)
[mesma estrutura]

ENTRADAS NO TOP 10: [lista]
SAÍDAS DO TOP 10: [lista]

ALERTAS
[ALERTA] [keyword]: queda de X posições em 24h — Verificar [causa provável]
```

## NUNCA
- Nunca reportar variação de 1-2 posições como "queda expressiva" — flutuação normal do Google
- Nunca ignorar padrão de múltiplas quedas simultâneas sem investigar possível atualização de algoritmo
- Nunca calcular tráfego estimado sem aplicar CTR por posição — posição sem CTR é métrica de vaidade

---
*Sub-skill de: SAGE | Versão: 2.0 | Atualizado: 2026-03-04*
