# LISTENING — LUNA · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
monitoramento de marca, social listening, menções, reputação online, o que estão falando, brand monitoring, sentiment

## PROTOCOLO
1. Carregar termos de monitoramento do cliente em clients.yaml: nome da marca, @handles, hashtags oficiais, nomes de produtos, CEO/fundador (se público)
2. Buscar menções nas plataformas configuradas: Instagram, Twitter/X, TikTok, LinkedIn, YouTube (comentários), Google reviews
3. Para cada menção coletada: registrar plataforma, autor, alcance estimado, data/hora, texto completo
4. Classificar sentimento de cada menção: Positivo / Neutro / Negativo / URGENTE (crise ou ataque viral)
5. Priorizar por score de urgência: (alcance × impacto_negativo) — menções URGENTE sobem ao topo automaticamente
6. Para menções negativas de alto alcance: redigir rascunho de resposta empática e não-defensiva
7. Para menções positivas de alto alcance: sinalizar como oportunidade de repost/engajamento
8. Identificar padrões: existe reclamação recorrente que indica problema operacional real?
9. Gerar alerta imediato se: menção com > 500 interações negativas OU palavra-chave de crise detectada
10. Registrar todas as menções coletadas em activity.log com classificação e ação recomendada

## OUTPUT
```
SOCIAL LISTENING REPORT — [CLIENTE] — [DATA HH:MM]

RESUMO: [X] menções | Positivas: X | Neutras: X | Negativas: X | URGENTES: X

URGENTES (ação imediata)
- @usuario (X seguidores): "[trecho]" — Rascunho de resposta: [texto]

NEGATIVAS A MONITORAR
- [lista com autor, alcance, texto, ação sugerida]

OPORTUNIDADES (positivas de alto alcance)
- [lista com sugestão de engajamento]

PADRÃO IDENTIFICADO: [se houver]
```

## NUNCA
- Nunca responder publicamente sem aprovação do operador ou cliente
- Nunca classificar menção ambígua como negativa sem contexto suficiente
- Nunca ignorar menções URGENTE, mesmo fora do horário de monitoramento regular

---
*Sub-skill de: LUNA | Versão: 2.0 | Atualizado: 2026-03-04*
