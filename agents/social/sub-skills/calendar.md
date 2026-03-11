# CALENDAR — LUNA · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
calendário editorial, calendar, plano de conteúdo, programação de posts, grade de conteúdo, planejamento semanal, planejamento mensal

## PROTOCOLO
1. Receber: cliente, período (semana/quinzena/mês) e frequência de postagem
2. Verificar em clients.yaml: frequência configurada, pilares de conteúdo, plataformas ativas, restrições de marca
3. Mapear datas comemorativas e tendências relevantes para o nicho do cliente no período
4. Verificar datas já bloqueadas ou lançamentos previstos informados pelo cliente
5. Distribuir posts respeitando frequência configurada, evitando concentração em um único dia
6. Balancear pilares de conteúdo por distribuição recomendada:
   - Educativo: 40% | Institucional/Marca: 20% | Entretenimento: 25% | Conversão: 15%
7. Para cada post: definir data, horário sugerido (baseado em métricas de engajamento do cliente), plataforma, formato, pilar, tema/ideia central
8. Sinalizar datas comemorativas aproveitadas com tag [SAZONAL]
9. Reservar 2-3 slots como "espaço para conteúdo reativo" (tendências da semana)
10. Entregar tabela e registrar em activity.log

## OUTPUT
```
CALENDÁRIO EDITORIAL — [CLIENTE] — [PERÍODO]

| Data       | Horário | Plataforma | Formato    | Pilar         | Tema                | Status    |
|------------|---------|------------|------------|---------------|---------------------|-----------|
| 05/03 Qui  | 18h     | Instagram  | Carrossel  | Educativo     | [Tema]              | A produzir |
| 06/03 Sex  | 12h     | TikTok     | Reels 30s  | Entretenimento| [Tema] [SAZONAL]    | A produzir |

SLOTS REATIVOS: [data], [data], [data]
```

## NUNCA
- Nunca ignorar frequência configurada em clients.yaml em favor de volume maior
- Nunca planejar mais de 2 posts de conversão seguidos sem conteúdo de valor entre eles
- Nunca confirmar calendário sem verificar conflito com datas de lançamento do cliente

---
*Sub-skill de: LUNA | Versão: 2.0 | Atualizado: 2026-03-04*
