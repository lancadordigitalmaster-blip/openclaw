# Quality Gate — Wolf Mission Control v1.0
# Criado: 2026-03-05

---

## Como Alfred avalia um output

Cada output passa por **4 dimensões** (0–10 cada).
Score final = média ponderada normalizada para 0–1.

| Dimensão | Peso | Aprovado se | Reprovado se |
|----------|------|-------------|--------------|
| Completude | 25% | Responde ao objetivo declarado | Output genérico que poderia ser de qualquer missão |
| Especificidade | 25% | Contém números, datas, nomes, URLs | "Muito" "alguns" "vários" sem quantificar |
| Acionabilidade | 25% | Próximo passo claro, sem ambiguidade | "Analisar melhor" "considerar opções" |
| Qualidade | 25% | Nível de especialista no domínio | Resposta que um júnior poderia dar |

**Threshold:** 0.65 (aprovado) — abaixo disso → revisão automática
**Máx revisões:** 2. Na terceira falha → escala para Netto com os 3 outputs para decisão humana.

---

## Casos de Teste por Agente

### Gabi — Tráfego Pago

**Caso 1: Diagnóstico de CPA**

Input para missão:
```
Fazer diagnóstico da campanha de leads da Clínica Santos.
CPA atual: R$287. Meta definida: R$90.
Período: últimos 7 dias. Conta Meta: act_123456789.
Dataset disponível: CTR 0.6%, CVR 0.8%, Frequência 3.2.
```

Output esperado (aprovado ✅):
- Identificação do gargalo principal (CTR baixo → problema de criativo)
- Análise de frequência (3.2 → fadiga de criativo)
- Recomendação acionável com prioridade (ex: pausar conjunto X, criar 3 novos criativos com ângulo Y)
- Sinal `[SIGNALS]` para Luna com instrução de hook_fix

Output que reprova (❌):
- "O CPA está alto. Sugiro revisar a segmentação e os criativos."
- Sem dados específicos, sem priorização, sem handoff para Luna

---

**Caso 2: Estrutura de campanha**

Input:
```
Criar estrutura de campanha para lançamento do curso "Dark Script" em agosto.
Budget: R$15.000. Objetivo: leads qualificados. Duração: 7 dias de lançamento.
Público: empreendedores digitais, 25-45 anos, Brasil.
```

Output esperado (aprovado ✅):
- CBO com 3 conjuntos: frio (lookalike), morno (engajamento), quente (visitantes LP)
- Distribuição de budget por fase (pré-lançamento, lançamento, encerramento)
- Criativos necessários por conjunto (quantidade, formato, objetivo)
- KPIs de controle por dia (quanto gastar, CPC alvo, lead custo alvo)

---

### Luna — Copy e Conteúdo

**Caso 1: Hook para ad**

Input:
```
Gabi identificou CTR de 0.6% no conjunto lookalike 1% para Clínica Santos.
Hook atual: "Transforme sua saúde com nossos especialistas".
Público: mulheres 35-55, interesse em saúde preventiva.
Objetivo: leads para consulta gratuita.
```

Output esperado (aprovado ✅):
- 3+ opções de hook com ângulos distintos (contraintuitivo, dor, transformação)
- Justificativa de ângulo para cada opção
- Variação de formato (estático, vídeo 15s, carrossel)
- Checklist de humanização aplicado

Output que reprova (❌):
- "Você merece cuidar da sua saúde. Agende sua consulta gratuita!"
- Hook genérico que qualquer clínica do Brasil poderia usar

---

**Caso 2: Calendário editorial**

Input:
```
Criar calendário editorial de agosto para @marca_pessoal_joao.
João é coach de vendas B2B para SaaS. Tom: direto, sem floreio, provoca reflexão.
Meta: 20 posts no mês. Formatos: carrossel (60%), reels (30%), texto (10%).
Temas que performaram bem: processos de venda, objeções, contratos.
```

Output esperado (aprovado ✅):
- 20 posts com data, formato, tema específico, ângulo único por post
- Pelo menos 3 ângulos contraintuitivos
- Nenhum post com tema repetido
- Pilares de conteúdo identificados com distribuição
- Tom verificado contra SOUL.md

---

### Titan — Tech Lead

**Caso 1: Decisão de arquitetura**

Input:
```
Precisamos implementar sistema de queue para processar missões de forma assíncrona.
Volume esperado: 50-200 missões/dia. Stack atual: Supabase + Edge Functions.
Opções consideradas: pg_notify, external queue (BullMQ/SQS), polling via cron.
```

Output esperado (aprovado ✅):
- Análise das 3 opções com trade-offs documentados
- Recomendação com justificativa baseada no volume e stack atual
- Riscos da abordagem escolhida
- Diagrama de fluxo (pode ser texto/ASCII)
- Próximos passos para Forge implementar

---

**Caso 2: Code Review**

Input:
```
Revisar o seguinte código de Edge Function que processa handoffs:
[código colado]
```

Output esperado (aprovado ✅):
- Issues de segurança identificadas (se houver)
- Issues de performance (N+1, await desnecessário)
- Problemas de tratamento de erro
- Sugestões de refatoração com exemplo de código corrigido
- Classificação por severidade (critical/high/medium/low)

---

### Sage — SEO

**Caso 1: Keyword research**

Input:
```
Fazer keyword research para blog de agência digital.
Foco: serviços de tráfego pago. Público-alvo: PMEs brasileiras.
Concorrentes a analisar: [3 URLs fornecidas].
```

Output esperado (aprovado ✅):
- Tabela com 20+ keywords: keyword, volume/mês, dificuldade (0-100), intenção, prioridade
- Clusters temáticos organizados (pillar + spokes)
- 3+ oportunidades de cauda longa com baixa concorrência
- Gap de keywords em relação aos concorrentes
- Briefing de 3 artigos prioritários para Luna

---

## Benchmark de Agentes — SQL de Auditoria Semanal

```sql
-- Executar toda segunda-feira no Supabase SQL Editor
-- Identifica agentes abaixo do threshold
WITH metrics AS (
  SELECT
    a.name,
    a.emoji,
    COUNT(m.id) FILTER (WHERE m.status = 'done')    AS done,
    COUNT(m.id) FILTER (WHERE m.status = 'blocked') AS blocked,
    COUNT(m.id)                                      AS total,
    AVG(mo.quality)                                  AS avg_quality,
    AVG(EXTRACT(EPOCH FROM (m.completed_at - m.started_at))/60)
      FILTER (WHERE m.completed_at IS NOT NULL)      AS avg_min
  FROM agents a
  LEFT JOIN missions m ON m.agent_id = a.id
    AND m.created_at > NOW() - INTERVAL '7 days'
  LEFT JOIN mission_outputs mo ON mo.mission_id = m.id
    AND mo.agent_id = a.id
  GROUP BY a.id, a.name, a.emoji
)
SELECT
  name,
  emoji,
  done,
  blocked,
  ROUND((blocked::FLOAT / NULLIF(total,0) * 100)::NUMERIC, 1) AS taxa_bloqueio_pct,
  ROUND(avg_quality::NUMERIC, 2)                               AS qualidade,
  ROUND(avg_min::NUMERIC, 0)                                   AS tempo_medio_min,
  CASE
    WHEN avg_quality < 0.65        THEN '🔴 Qualidade baixa — revisar system prompt'
    WHEN blocked > done            THEN '🔴 Mais bloqueios que conclusões — verificar contexto'
    WHEN (blocked::FLOAT/NULLIF(total,0)) > 0.3 THEN '🟡 Taxa de bloqueio alta'
    WHEN avg_quality BETWEEN 0.65 AND 0.75 THEN '🟡 Qualidade aceitável — pode melhorar'
    ELSE '✅ Saudável'
  END AS status_saude
FROM metrics
WHERE total > 0
ORDER BY avg_quality ASC NULLS LAST;
```

---

## Thresholds por Agente

| Agente | Qualidade mínima | Tempo médio esperado | Taxa de bloqueio máxima |
|--------|-----------------|---------------------|------------------------|
| Alfred | 0.80 | — (orquestra, não executa) | < 5% |
| Gabi | 0.75 | < 45 min (audit) / < 20 min (estrutura) | < 15% |
| Luna | 0.78 | < 30 min (copy) / < 60 min (calendário) | < 10% |
| Sage | 0.72 | < 60 min (research) / < 90 min (audit) | < 20% |
| Nova | 0.70 | < 45 min | < 20% |
| Titan | 0.80 | < 30 min (review) / < 60 min (arquitetura) | < 10% |
| Pixel/Forge/Shield | 0.75 | Depende do escopo | < 20% |
| Atlas/Echo/Flux | 0.70 | < 15 min | < 15% |

---

## Quando Revisar o System Prompt de um Agente

Revisar quando **3 ou mais** dos seguintes são verdadeiros na última semana:

- Qualidade média < threshold definido acima
- 2+ outputs reprovados pelo quality gate
- Bloqueios frequentes pelo mesmo motivo
- Handoffs esperados não sendo emitidos
- Tempo médio > 2× o esperado

**Como revisar:**
1. Comparar output real vs output esperado nos casos de teste acima
2. Identificar gap específico
3. Adicionar instrução direcionada no system prompt (não reescrever tudo)
4. Rodar migration de UPDATE no Supabase
5. Testar com caso de teste específico

---

*Wolf Mission Control · Quality Gate v1.0 · 2026-03-05*
