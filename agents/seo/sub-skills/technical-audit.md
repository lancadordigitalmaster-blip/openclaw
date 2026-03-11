# TECHNICAL-AUDIT — SAGE · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
auditoria técnica, technical audit, SEO técnico, problemas técnicos de SEO, velocidade do site, Core Web Vitals, indexação

## PROTOCOLO
1. Receber URL do domínio do cliente
2. **Indexação**: verificar robots.txt (bloqueios indevidos?), sitemap.xml (existe, está no GSC, atualizado?), cobertura no Google Search Console (páginas excluídas, erros de indexação)
3. **Core Web Vitals** (via PageSpeed Insights API): LCP (meta < 2.5s), CLS (meta < 0.1), INP (meta < 200ms); verificar para mobile e desktop separadamente
4. **Estrutura de URLs**: verificar consistência (trailing slash, www vs non-www), URLs com parâmetros desnecessários, profundidade de URLs (ideal < 3 níveis)
5. **Redirects**: mapear cadeia de redirects (max 1 hop), identificar redirect loops, páginas 404 com backlinks
6. **Canonical tags**: páginas duplicadas sem canonical, canonical apontando para URL errada, self-canonicals corretos
7. **Schema markup**: verificar presença (Organization, LocalBusiness, Article, Product conforme tipo de site); validar via Rich Results Test
8. **Mobile-friendliness**: teste via Google Mobile-Friendly Tool; verificar viewport meta tag, tap targets, texto legível sem zoom
9. Calcular score técnico (0-100): base 100, descontar por cada problema encontrado conforme severidade (crítico -15, importante -8, menor -3)
10. Compilar lista priorizada de correções ordenada por impacto × facilidade de implementação

## OUTPUT
```
TECHNICAL AUDIT — [CLIENTE / URL] — [DATA]
Score Técnico: XX/100

CORE WEB VITALS
| Métrica | Mobile | Desktop | Status |
| LCP     | X.Xs   | X.Xs    | PASSA / FALHA |
| CLS     | X.XX   | X.XX    | PASSA / FALHA |
| INP     | XXXms  | XXXms   | PASSA / FALHA |

PROBLEMAS ENCONTRADOS (priorizados)
[CRÍTICO] [Categoria]: [descrição do problema] — Correção: [o que fazer]
[IMPORTANTE] ...
[MENOR] ...

QUICK WINS (alto impacto, baixa complexidade)
1. [ação] — Impacto estimado: [X pontos no score]
```

## NUNCA
- Nunca gerar score sem verificar ao menos as 6 categorias do protocolo
- Nunca recomendar correção de schema sem validar o markup atual primeiro
- Nunca omitir problemas de indexação mesmo que o cliente não os tenha mencionado — são críticos

---
*Sub-skill de: SAGE | Versão: 2.0 | Atualizado: 2026-03-04*
