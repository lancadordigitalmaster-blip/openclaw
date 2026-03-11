# TREND-MONITOR — NOVA · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
tendências, trend monitor, o que está em alta, trends do setor, novidades do mercado, monitorar tendências

## PROTOCOLO
1. Carregar nichos de todos os clientes ativos em clients.yaml
2. **Google Trends**: verificar volume de busca dos últimos 90 dias para termos-chave de cada nicho; identificar curva de crescimento (explosiva, gradual, estável, em queda)
3. **Twitter/X**: verificar trending topics relacionados a cada nicho; puxar top 5 posts virais do nicho nas últimas 48h
4. **Reddit**: verificar hot posts nos subreddits relevantes a cada nicho (últimos 7 dias); anotar os temas com mais upvotes e comentários
5. Classificar cada tendência identificada por maturidade:
   - Emergente (< 3 meses de crescimento): alto risco, alto potencial
   - Consolidada (3-12 meses): menor risco, ainda relevante
   - Em declínio (queda nos últimos 60 dias): evitar investimento
6. Para cada tendência: avaliar relevância para cada cliente ativo (alta/média/baixa/irrelevante)
7. Calcular janela de oportunidade: tendências emergentes têm janela de 2-8 semanas antes de saturar
8. Recomendar ação por tendência e por cliente: Aproveitar agora / Monitorar / Ignorar
9. Para tendências com recomendação "Aproveitar": gerar ideia de conteúdo ou campanha específica
10. Registrar em activity.log com timestamp para comparação futura

## OUTPUT
```
TREND MONITOR — [DATA] — Clientes analisados: X

TENDÊNCIAS EMERGENTES (agir em até 2 semanas)
[Tendência]: Volume Google +X% em 30d | Relevante para: [Clientes]
Ação: Aproveitar | Ideia: [conteúdo/campanha específica]

TENDÊNCIAS CONSOLIDADAS (janela ainda aberta)
[Tendência]: [análise] | Ação: [Aproveitar/Monitorar]

TENDÊNCIAS EM DECLÍNIO (evitar)
[Tendência]: [queda observada] | Ação: Ignorar

MATRIZ CLIENTE × TENDÊNCIA
| Cliente | Tendência | Relevância | Ação |
```

## NUNCA
- Nunca recomendar "Aproveitar" para tendência em declínio apenas porque é popular historicamente
- Nunca ignorar tendências negativas do setor (crises regulatórias, shifts de comportamento) — são tão importantes quanto as positivas
- Nunca gerar análise sem especificar janela de oportunidade estimada para tendências emergentes

---
*Sub-skill de: NOVA | Versão: 2.0 | Atualizado: 2026-03-04*
