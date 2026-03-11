# COMPETITOR-WATCH — LUNA · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
concorrentes, competitor watch, monitorar concorrentes, o que concorrente postou, benchmark social, espionar concorrente

## PROTOCOLO
1. Carregar lista de concorrentes do cliente em clients.yaml (máximo 5 perfis por execução)
2. Para cada concorrente: puxar as últimas 5 publicações (feed + reels) de cada plataforma monitorada
3. Para cada post coletado: registrar data, formato, legenda (primeiras 150 chars), métricas de engajamento (likes, comentários, compartilhamentos, visualizações se vídeo)
4. Calcular taxa de engajamento de cada concorrente: (likes+comentários+shares) / seguidores × 100
5. Identificar posts com engajamento acima da média histórica do concorrente (desvio > 1.5x a média)
6. Para os posts de alto desempenho: analisar em profundidade — formato, ângulo de comunicação, CTA, horário de publicação, uso de trend ou áudio viral
7. Verificar se algum concorrente lançou campanha ou promoção recente
8. Identificar gap de conteúdo: o que os concorrentes não estão fazendo que o cliente poderia explorar
9. Extrair 1 aprendizado acionável principal: específico, baseado em evidência, aplicável imediatamente
10. Registrar achados em activity.log com data de coleta

## OUTPUT
```
COMPETITOR WATCH — [CLIENTE] — [DATA]

CONCORRENTES ANALISADOS: [lista]

POST DE MAIOR ENGAJAMENTO (da semana)
Concorrente: [nome] | Plataforma: [X] | Engajamento: X% (Δ+X% vs média)
Formato: [X] | Ângulo: [X] | CTA: [X] | Horário: [X]

ACHADOS POR CONCORRENTE
[Concorrente A]: [resumo dos 5 posts + destaque]

GAP IDENTIFICADO: [o que nenhum está fazendo]

APRENDIZADO ACIONÁVEL:
"[1 insight específico e aplicável ao cliente]"
```

## NUNCA
- Nunca copiar ou sugerir replicação direta de conteúdo de concorrentes
- Nunca analisar menos de 5 posts por concorrente sem justificativa (perfil muito novo, etc.)
- Nunca omitir o gap identificado — é o output de maior valor desta sub-skill

---
*Sub-skill de: LUNA | Versão: 2.0 | Atualizado: 2026-03-04*
