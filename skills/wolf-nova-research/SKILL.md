# SKILL.md — Wolf Nova Research · Pesquisa Profunda com Múltiplas Fontes
# Wolf Agency AI System | Versão: 1.0 | Criado: 2026-03-05
# Baseado no conceito "Deep Research Pro" — adaptado para macOS + Wolf Agency

> Pesquisa aprofundada com múltiplas fontes web, síntese estruturada e
> citações rastreáveis. Usa ferramentas nativas do OpenClaw (web_search + web_fetch).
> Salva relatórios em `workspace/shared/memory/research/` para reutilização.

---

## Agent

**Nova** (primário) — estratégia e inteligência de mercado.
**Alfred** pode acionar como orquestrador quando outros agentes precisarem de contexto.
**Gabi, Luna, Sage** podem solicitar via handoff para enriquecer missões.

---

## Triggers

```
"pesquisa" | "pesquise" | "research" | "deep dive"
"benchmarks de" | "benchmark"
"tendências de" | "tendência"
"concorrentes de" | "análise de concorrente"
"o que está rolando com" | "o que está acontecendo com"
"me dá um panorama de" | "panorama do mercado"
"levanta dados sobre" | "levanta informações sobre"
"quais são os CPAs médios" | "qual é o ROAS médio"
"o que está performando" | "criativos que estão funcionando"
"inteligência de mercado" | "market research"
"análise de" + [nicho/empresa/tema]
```

---

## Fluxo de Pesquisa — 5 Passos

### PASSO 1 — Entender o objetivo (30 segundos)

Antes de pesquisar, confirmar mentalmente (ou perguntar ao usuário se ambíguo):
- **Objetivo:** aprender, tomar decisão, criar conteúdo, ou embasar proposta?
- **Profundidade:** visão geral rápida (3-5 fontes) ou análise profunda (15-25 fontes)?
- **Recência:** dados dos últimos 3 meses? 12 meses? Histórico?
- **Ângulo específico:** foco em algum segmento geográfico, nicho ou métrica?

Se o usuário disser apenas "pesquisa X" → usar profundidade padrão (10-15 fontes), recência 12 meses.

---

### PASSO 2 — Planejar as sub-perguntas

Dividir o tema em 3 a 5 sub-perguntas antes de começar qualquer busca.

**Exemplo — Tema:** "CPAs médios de lead gen para clínicas estéticas"
```
Sub-perguntas:
1. Qual é o CPA benchmark para geração de leads em clínicas estéticas no Brasil?
2. Quais plataformas (Meta vs Google) têm melhor resultado nesse nicho?
3. Que tipos de criativos/ofertas convertem melhor?
4. Quais são as sazonalidades e momentos de maior custo?
5. O que os concorrentes da área estão fazendo?
```

Registrar as sub-perguntas antes de executar — isso garante cobertura completa.

---

### PASSO 3 — Executar buscas web (ferramenta nativa)

Para cada sub-pergunta, usar a ferramenta nativa de busca web disponível no OpenClaw.
Usar 2-3 variações de termos por sub-pergunta para maximizar cobertura.

#### Como buscar

Usar diretamente a ferramenta `web_search` com a query em linguagem natural ou como string de busca.
Não é necessário curl nem scripts — o sistema já tem busca integrada (provider: kimi).

**Exemplos de queries para marketing digital:**

```
# Benchmarks
"CPA médio clínica estética Meta Ads Brasil 2026"
"benchmark lead gen saúde estética Facebook Ads"
"custo por lead clínica beleza tráfego pago"

# Tendências
"tendências criativos Meta Ads 2026"
"o que está performando Instagram Ads Brasil"
"melhores hooks vídeo ads saúde estética"

# Concorrentes / mercado
"agências tráfego pago clínicas estéticas Brasil"
"como anunciam clínicas estéticas Facebook"
"case study lead gen estética ROAS 2025 2026"
```

#### Processo por sub-pergunta

1. Executar busca com query principal → anotar título, URL e snippet de cada resultado
2. Se os snippets forem vagos → executar busca com query alternativa
3. Registrar todos os URLs únicos encontrados (evitar duplicatas)
4. Ao fim das N sub-perguntas, ter lista consolidada de URLs com relevância estimada

**Meta de buscas:** 15 a 25 URLs únicos coletados no total.

---

### PASSO 4 — Leitura profunda das melhores fontes

Após coletar os snippets, selecionar as 4-6 URLs mais promissoras e ler o conteúdo completo
usando a ferramenta nativa `web_fetch`.

**Não usar curl** — usar `web_fetch` diretamente com a URL.

**Critérios para priorizar uma URL:**
- Fonte especializada (relatório de agência, artigo acadêmico, case study)
- Dados numéricos visíveis no snippet (CPAs, taxas, percentuais)
- Recente (últimos 12 meses preferível)
- Relevância direta para a sub-pergunta

**Se a URL retornar erro ou conteúdo vazio:** pular e usar a próxima da lista.
Não insistir mais de 1 tentativa por URL.

---

### PASSO 5 — Sintetizar e gerar o relatório

Após coletar dados de todas as fontes, gerar o relatório usando o template abaixo.

**Regras de qualidade (obrigatórias):**
1. Toda afirmação de fato precisa de `(Fonte: [nome](url))`
2. Se apenas 1 fonte confirma → marcar como `⚠️ não verificado`
3. Se não encontrou dados para uma sub-pergunta → escrever "Dados insuficientes encontrados"
4. Não inventar números. Se não encontrou benchmark, dizer isso explicitamente.
5. Priorizar fontes dos últimos 12 meses sobre fontes mais antigas

---

## Template do Relatório

```markdown
# [TEMA]: Relatório de Pesquisa Profunda
*Gerado em: [DD/MM/YYYY HH:MM] | Fontes consultadas: [N] | Confiança geral: Alta/Média/Baixa*

---

## Resumo Executivo
[3-5 frases cobrindo as principais descobertas. O que é mais importante saber imediatamente.]

---

## 1. [Primeira Sub-pergunta respondida]

[Achados principais com citações inline]

- Dado específico com número ([Nome da Fonte](url))
- Outro achado relevante ([Nome da Fonte](url))
- ⚠️ [Afirmação com apenas 1 fonte — não verificada] ([Fonte única](url))

---

## 2. [Segunda Sub-pergunta]

[Idem]

---

## 3. [Terceira Sub-pergunta]

[Idem]

---

## Insights para a Wolf Agency

### Para Gabi (Tráfego Pago):
- [Implicação direta para campanhas]

### Para Luna (Copy/Criativos):
- [O que está funcionando em criativos/copy]

### Para Sage (SEO/Conteúdo):
- [Keywords, tendências de conteúdo]

### Para Netto (Estratégia):
- [Oportunidades de negócio ou posicionamento]

---

## Principais Conclusões

- [Insight acionável 1]
- [Insight acionável 2]
- [Insight acionável 3]

---

## Lacunas Identificadas
[O que não foi possível encontrar / onde os dados são fracos]

---

## Fontes Consultadas
1. [Título](url) — breve descrição de 1 linha
2. [Título](url) — breve descrição de 1 linha
...

---

## Metodologia
Buscas executadas: [N] | Fontes analisadas: [N] | Leituras completas: [N]
Sub-perguntas investigadas: [lista]
Período de recência preferencial: [últimos X meses]

---
*Wolf Agency · Nova Research v1.0 · [data]*
```

---

## Salvar o relatório

```bash
# Criar slug a partir do tema (ex: "cpa-clinicas-esteticas-2026")
SLUG="[slug-do-tema]"
RESEARCH_DIR="/Users/thomasgirotto/.openclaw/workspace/shared/memory/research/${SLUG}"
mkdir -p "$RESEARCH_DIR"

# Salvar o relatório completo
# Escrever o conteúdo markdown em: $RESEARCH_DIR/report.md

# Atualizar índice de pesquisas
echo "- [$(date +%Y-%m-%d)] [TEMA](${SLUG}/report.md)" >> \
  /Users/thomasgirotto/.openclaw/workspace/shared/memory/research/INDEX.md
```

---

## Resposta no chat / Telegram

### Pesquisa curta (< 3 sub-perguntas ou solicitação rápida):
Entregar o relatório completo no chat.

### Pesquisa profunda (4+ sub-perguntas ou relatório longo):
Entregar no chat:
1. O **Resumo Executivo**
2. Os **Principais Conclusões** em bullets
3. Informar: "Relatório completo salvo em `research/[slug]/report.md`"

### Via Telegram (quando acionado por cron ou comando):
```
✅ *Pesquisa concluída: [TEMA]*

📊 *Resumo Executivo*
[3-5 frases]

💡 *Principais insights:*
• [insight 1]
• [insight 2]
• [insight 3]

📁 Relatório completo: `research/[slug]/report.md`
🔍 Fontes: [N] | Confiança: [Alta/Média/Baixa]
```

---

## Quando outros agentes acionam Nova Research

### Gabi precisa de benchmarks antes de configurar campanha:
```
[GABI→NOVA] Preciso de benchmarks de CPA para [NICHO] antes de estruturar a campanha.
Urgência: alta. Profundidade: rápida (5-8 fontes).
```

### Luna precisa de referências de criativos:
```
[LUNA→NOVA] Pesquisa criativos performando para [NICHO/PRODUTO] em [PLATAFORMA].
Foco em: hooks, formatos, ângulos de copy.
```

### Sage precisa de tendências de conteúdo:
```
[SAGE→NOVA] Research tendências de conteúdo e keywords emergentes para [TEMA].
Foco em: volume de busca, intenção, oportunidades de cauda longa.
```

Quando receber esses handoffs, executar com a profundidade solicitada e retornar resultado via `[NOVA→GABI]` etc.

---

## Profundidades disponíveis

| Modo | Buscas | Fontes lidas | Tempo est. | Quando usar |
|------|--------|--------------|-----------|-------------|
| **Rápido** | 5-8 | 2-3 leituras completas | ~3 min | Pergunta específica, Gabi precisa de 1 benchmark |
| **Padrão** | 10-15 | 3-5 leituras completas | ~8 min | Pesquisa normal, antes de proposta |
| **Profundo** | 20-30 | 6-8 leituras completas | ~15 min | Análise de mercado completa, novo cliente, setor desconhecido |

---

## Activity Log

```
[TIMESTAMP] [NovaResearch] TEMA: [tema] | MODO: [rápido/padrão/profundo] | FONTES: [N] | SALVO: [slug] | STATUS: ok/erro
```

---

*Skill: wolf-nova-research | Versão: 1.0 | Criado: 2026-03-05*
*Inspirado em: deep-research-pro by @parags (adaptado para Wolf Agency macOS)*
