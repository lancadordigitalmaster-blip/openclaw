# COMPETITOR-GAP — SAGE · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
gap de keywords, competitor gap, keywords dos concorrentes, o que concorrente rankeia que eu não rankeo, oportunidades de keywords, keywords roubáveis

## PROTOCOLO
1. Receber: URL do cliente + URLs dos concorrentes a analisar (máximo 3 concorrentes)
2. Puxar via DataForSEO: keywords em que cada concorrente rankeia no top 20
3. Identificar keywords de gap: concorrente rankeia (top 20) + cliente NÃO rankeia (top 20) + keyword tem volume > 200/mês
4. Remover keywords irrelevantes para o negócio do cliente (navegacionais de marca concorrente, termos de nicho diferente)
5. Para cada keyword de gap: registrar volume, KD, CPC, intenção de busca, posição do concorrente
6. Filtrar por intenção de compra: priorizar intenção Transacional e Comercial
7. Calcular oportunidade de tráfego estimado: volume × CTR esperado (baseado em posição alvo realista dado o KD vs DR do cliente)
8. Priorizar keywords por matriz: impacto_potencial (volume × intenção) / dificuldade_de_rankeamento (KD vs DR cliente)
9. Para as top 10 keywords priorizadas: definir plano de ataque (criar nova landing page, otimizar página existente, criar artigo de cluster)
10. Entregar lista de "keywords roubáveis" com plano de ataque específico por keyword

## OUTPUT
```
COMPETITOR GAP — [CLIENTE] vs [Concorrentes] — [DATA]

KEYWORDS DE GAP IDENTIFICADAS: XXX total | Após filtros: XX relevantes

TOP KEYWORDS ROUBÁVEIS (priorizadas por impacto/dificuldade)
| Keyword              | Volume | KD  | Intenção    | Concorrente (pos) | Oportunidade | Ataque |
|----------------------|--------|-----|-------------|-------------------|--------------|--------|
| [keyword]            | X.XXX  | XX  | Transacional| [concorrente] (#X)| ~XXX vis/mês | Nova LP|

QUICK WINS (KD < 30, volume > 200, intenção comercial/transacional)
[lista com ação imediata]

PLANO DE ATAQUE — PRÓXIMOS 60 DIAS
1. Semana 1-2: criar/otimizar [página] para [keyword] — estimativa: [X] visitas/mês
2. Semana 3-4: ...

IMPACTO POTENCIAL TOTAL: ~X.XXX visitas/mês adicionais se top 10 keywords conquistadas
```

## NUNCA
- Nunca incluir keywords de marca do concorrente na lista de "roubáveis" — intenção navegacional não converte
- Nunca recomendar atacar keyword com KD > 60 sem plano de link building explícito
- Nunca omitir o plano de ataque — lista sem ação não gera resultado

---
*Sub-skill de: SAGE | Versão: 2.0 | Atualizado: 2026-03-04*
