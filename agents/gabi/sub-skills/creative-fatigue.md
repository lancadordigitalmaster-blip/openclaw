# CREATIVE-FATIGUE — GABI · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
fadiga de criativo, creative fatigue, frequência alta, CTR caindo, criativo cansado, renovar criativos

## PROTOCOLO
1. Puxar métricas dos últimos 14 dias por criativo ativo: frequência, CTR, CPA, impressões
2. Identificar criativos em fadiga por critério A: frequência > 3.5 (audience fria) ou > 5.0 (remarketing)
3. Identificar criativos em fadiga por critério B: queda de CTR > 20% comparando semana atual vs semana anterior
4. Identificar criativos em fadiga por critério C: CPA aumentou > 30% WoW com volume estatístico (min. 50 cliques)
5. Cruzar critérios: 1 critério = monitorar | 2 critérios = alerta | 3 critérios = pausar imediatamente
6. Para os criativos que convertiam bem antes da fadiga: extrair padrões (formato, ângulo, CTA, duração, thumbnail)
7. Sugerir 3-5 categorias de novos criativos baseadas nesses padrões com briefs resumidos
8. Listar criativos candidatos a pausa com justificativa por critério
9. Estimar impacto em CPA/ROAS se fadiga não for corrigida em 7 dias
10. Registrar em activity.log com data de detecção

## OUTPUT
```
RELATÓRIO DE FADIGA — [CLIENTE] — [DATA]

CRIATIVOS EM FADIGA
| ID | Nome | Frequência | CTR Atual | CTR -7d | Score Fadiga | Ação |
|----|------|------------|-----------|---------|--------------|------|

CANDIDATOS A PAUSA IMEDIATA
- [ID]: 3/3 critérios atingidos

SUGESTÕES DE NOVOS CRIATIVOS (baseado nos top performers pré-fadiga)
1. Formato: Reels 15s | Ângulo: [X] | CTA: [Y]
2. ...
```

## NUNCA
- Nunca recomendar pausa de criativo com menos de 1.000 impressões na semana
- Nunca ignorar sazonalidade ao comparar CTR semana a semana
- Nunca pausar sem identificar substitutos disponíveis ou em produção

---
*Sub-skill de: GABI | Versão: 2.0 | Atualizado: 2026-03-04*
