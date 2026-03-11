# prompt-engineering.md — FLUX Sub-Skill: Prompt Engineering
# Ativa quando: "prompt", "instrução", "system prompt", "melhora esse prompt"

---

## ANATOMIA DE PROMPT DE PRODUÇÃO

Todo prompt Wolf de produção tem 5 componentes obrigatórios:

```
[ROLE]       → Quem o modelo é e qual seu contexto de autoridade
[CONTEXT]    → Informação de background necessária para a tarefa
[TASK]       → O que exatamente deve ser feito (ação específica)
[FORMAT]     → Como a resposta deve ser estruturada
[CONSTRAINTS]→ O que não fazer, limites, restrições explícitas
```

### Template Base Wolf

```xml
<system>
You are [ROLE ESPECÍFICO] at Wolf Agency, a product studio that builds AI-powered products.

<context>
[INFORMAÇÃO DE BACKGROUND RELEVANTE]
[DADOS DO USUÁRIO SE APLICÁVEL]
</context>

<task>
[VERBO DE AÇÃO] + [OBJETO] + [CRITÉRIO DE SUCESSO]
</task>

<format>
Respond with [ESTRUTURA ESPERADA].
[EXEMPLO SE NECESSÁRIO]
</format>

<constraints>
- Do NOT [RESTRIÇÃO 1]
- Do NOT [RESTRIÇÃO 2]
- Always [REGRA OBRIGATÓRIA]
</constraints>
</system>
```

---

## TÉCNICAS AVANÇADAS

### 1. Chain of Thought (CoT)
Use quando o problema tem múltiplos passos lógicos ou a precisão é crítica.

```xml
<task>
Analyze the user's request and determine the best approach.
Think step by step before giving your final answer.
</task>
```

Variante com scratchpad explícito:
```xml
<task>
First, reason through the problem in <thinking> tags.
Then provide your final answer in <answer> tags.
</task>
```

### 2. Few-shot Examples
Use quando o formato de output é específico ou não-óbvio.

```xml
<examples>
<example>
<input>User wants to cancel subscription</input>
<output>{"intent": "cancel", "urgency": "high", "retention_offer": true}</output>
</example>
<example>
<input>User asking about pricing</input>
<output>{"intent": "pricing_inquiry", "urgency": "medium", "retention_offer": false}</output>
</example>
</examples>
```

Regra: mínimo 2 exemplos, máximo 5. Mais que 5 = aumenta tokens sem ganho proporcional.

### 3. XML Tags para Claude
Claude (Anthropic) processa XML estruturalmente. Use sempre para separar seções.

```xml
<!-- CORRETO: Claude entende hierarquia -->
<instructions>
  <primary>Classify the support ticket</primary>
  <secondary>Extract key entities</secondary>
</instructions>

<!-- ERRADO: Texto corrido sem estrutura -->
"Classify the support ticket and also extract key entities from it"
```

### 4. Structured Output
Quando precisar de JSON confiável, force o formato com precisão cirúrgica:

```xml
<format>
Respond ONLY with valid JSON. No markdown, no explanation, no preamble.
Schema:
{
  "action": "string (one of: approve, reject, escalate)",
  "confidence": "number (0.0 to 1.0)",
  "reason": "string (max 100 chars)"
}
</format>
```

Para Claude via Anthropic SDK, use `tool_use` como alternativa mais confiável ao JSON puro:
```typescript
const response = await anthropic.messages.create({
  model: "claude-opus-4-6",
  tools: [{
    name: "structured_output",
    description: "Return the analysis result",
    input_schema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["approve", "reject", "escalate"] },
        confidence: { type: "number" },
        reason: { type: "string" }
      },
      required: ["action", "confidence", "reason"]
    }
  }],
  tool_choice: { type: "tool", name: "structured_output" },
  messages: [{ role: "user", content: userInput }]
});
```

---

## ERROS COMUNS EM PROMPTS

### Erro 1: Prompt Vago
```
RUIM:  "Você é um assistente útil. Ajude o usuário."
BOM:   "You are a customer support agent for [PRODUTO]. Your goal is to resolve
        billing issues. You have access to order history. Be concise and solution-focused."
```

### Erro 2: Sem Formato Definido
```
RUIM:  "Analise o feedback do cliente."
BOM:   "Analyze the customer feedback. Return a JSON with:
        - sentiment: positive | negative | neutral
        - category: bug | feature_request | praise | billing
        - priority: 1-5 (5 = most urgent)
        - summary: max 50 chars"
```

### Erro 3: Sem Restrições
```
RUIM:  "Responda perguntas sobre nossos produtos."
BOM:   "Answer questions about our products using ONLY information from the
        provided context. If the answer is not in the context, say exactly:
        'I don't have that information. I'll escalate to our team.'
        Do NOT make up product details, pricing, or availability."
```

### Erro 4: Role Fraco
```
RUIM:  "Você é um especialista em finanças."
BOM:   "You are a CFO-level financial analyst with 15 years of experience in
        SaaS companies. You analyze unit economics, burn rate, and growth metrics.
        You speak in precise financial terms but can explain concepts clearly."
```

---

## EXEMPLOS WOLF: ANTES E DEPOIS

### Caso 1: Classificação de Lead

**Antes (ingênuo):**
```
Classifique esse lead como quente, morno ou frio.
Lead: {lead_data}
```

**Depois (produção):**
```xml
<system>
You are a sales qualification specialist at Wolf Agency.
You evaluate inbound leads for a product studio that builds AI-powered MVPs.

<context>
Ideal Customer Profile (ICP):
- B2B companies with 10-500 employees
- Has a specific business problem to solve with software
- Budget available (>R$50k project)
- Decision maker is engaging

Lead data:
{lead_data}
</context>

<task>
Classify this lead and determine next action.
</task>

<format>
Return JSON only:
{
  "temperature": "hot | warm | cold",
  "icp_match_score": 0-100,
  "disqualifiers": ["list of red flags if any"],
  "recommended_action": "schedule_call | send_nurture | disqualify",
  "reasoning": "2 sentences max"
}
</format>

<constraints>
- Base classification ONLY on provided data
- If critical info is missing, note it in disqualifiers
- Do NOT assume budget availability if not mentioned
</constraints>
</system>
```

### Caso 2: Geração de Conteúdo

**Antes:**
```
Escreva um post sobre IA para o LinkedIn da empresa.
```

**Depois:**
```xml
<system>
You are a content strategist writing for Wolf Agency's LinkedIn.
Wolf Agency is a product studio that builds AI-powered products for ambitious companies.
Voice: direct, confident, no buzzwords, shows expertise through specificity.

<context>
Topic: {topic}
Target audience: CTOs and product leaders at Brazilian scale-ups
Goal: Generate qualified leads and establish thought leadership
Recent high-performing post structure: hook → insight → concrete example → CTA
</context>

<task>
Write a LinkedIn post that educates and generates engagement.
</task>

<format>
- First line: scroll-stopping hook (no question marks, no "Você sabia que")
- Body: 3-4 short paragraphs
- Concrete example or data point required
- CTA: specific, low-friction
- Total length: 150-250 words
- Language: Portuguese (Brazil)
</format>

<constraints>
- No generic phrases: "no mundo atual", "cada vez mais", "transformação digital"
- No excessive exclamation marks
- No emoji spam (max 2 emojis total)
- Must include at least one specific number or metric
</constraints>
</system>
```

---

## COMO ITERAR EM PROMPTS SISTEMATICAMENTE

### Protocolo de Iteração Wolf

```
1. BASELINE
   → Escreva o prompt mínimo viável
   → Rode 5-10 inputs reais
   → Documente failures e successes

2. DIAGNÓSTICO
   → Failure type A: formato errado → adicionar/clarificar FORMAT
   → Failure type B: informação errada → melhorar CONTEXT ou CONSTRAINTS
   → Failure type C: tom errado → ajustar ROLE
   → Failure type D: output incompleto → clarificar TASK

3. HIPÓTESE
   → Mude UMA variável por vez
   → Documente o que mudou e por quê

4. TESTE
   → Rode nos mesmos inputs que falharam antes
   → Compare output anterior vs novo
   → Use evals/ para automação (ver sub-skill evals.md)

5. PRODUÇÃO
   → Versionamento: salve prompts como v1, v2, etc.
   → Nunca sobrescreva sem comparar métricas
```

### Checklist de Prompt Pronto para Produção

- [ ] Role definido com especificidade (não genérico)
- [ ] Contexto inclui toda informação que o modelo precisa
- [ ] Task usa verbo de ação específico
- [ ] Formato especifica estrutura de output esperada
- [ ] Constraints lista explicitamente o que não fazer
- [ ] Testado com inputs edge-case (vazios, ambíguos, maliciosos)
- [ ] Token count dentro do budget do projeto
- [ ] Versionado e documentado no repositório
