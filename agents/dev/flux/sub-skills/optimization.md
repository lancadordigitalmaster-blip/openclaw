# optimization.md — FLUX Sub-Skill: Otimização de Custo e Performance
# Ativa quando: "custo", "tokens", "otimiza", "mais barato", "mais rápido"

---

## CÁLCULO DE CUSTO

### Fórmula Base

```
Custo por request = (input_tokens × preço_input) + (output_tokens × preço_output)
Custo mensal      = custo_por_request × requests_por_mês
```

### Tabela de Preços Wolf (Março 2026)

| Modelo                  | Input (por 1M tokens) | Output (por 1M tokens) | Uso Ideal                         |
|-------------------------|----------------------|------------------------|-----------------------------------|
| claude-opus-4-6         | $15.00               | $75.00                 | Tarefas complexas, raciocínio     |
| claude-sonnet-4-6       | $3.00                | $15.00                 | Produção geral, custo-benefício   |
| claude-haiku-3-5        | $0.80                | $4.00                  | Classificação, tarefas simples    |
| gpt-4o                  | $2.50                | $10.00                 | Alternativa quando necessário     |
| gpt-4o-mini             | $0.15                | $0.60                  | Tasks triviais, alta volume       |
| text-embedding-3-small  | $0.02                | —                      | Embeddings (RAG)                  |
| text-embedding-3-large  | $0.13                | —                      | Embeddings alta precisão          |

*Verifique preços atuais em anthropic.com/pricing e openai.com/pricing — valores mudam.*

### Calculadora Rápida

```typescript
function estimateMonthlyCost(
  requestsPerDay: number,
  avgInputTokens: number,
  avgOutputTokens: number,
  model: "opus" | "sonnet" | "haiku"
): number {
  const pricing = {
    opus:   { input: 15.00, output: 75.00 },
    sonnet: { input: 3.00,  output: 15.00 },
    haiku:  { input: 0.80,  output: 4.00  }
  };

  const { input, output } = pricing[model];
  const costPerRequest =
    (avgInputTokens / 1_000_000) * input +
    (avgOutputTokens / 1_000_000) * output;

  return costPerRequest * requestsPerDay * 30;
}

// Exemplo: 1000 requests/dia, 2000 tokens input, 500 tokens output
console.log(estimateMonthlyCost(1000, 2000, 500, "sonnet")); // ~$4.50/mês
console.log(estimateMonthlyCost(1000, 2000, 500, "opus"));   // ~$28.50/mês
```

---

## ESTRATÉGIAS DE REDUÇÃO DE CUSTO

### 1. Escolha de Modelo Adequado (maior impacto)

Matriz de decisão:

```
Tarefa de classificação/roteamento simples  → Haiku (10-20x mais barato que Opus)
Geração de conteúdo, code review, análise   → Sonnet (5x mais barato que Opus)
Raciocínio complexo, planejamento, research → Opus (quando a qualidade justifica)
```

Exemplo prático — sistema de suporte:
```typescript
async function processTicket(ticket: string): Promise<void> {
  // Classificação: Haiku é suficiente
  const category = await classifyWithHaiku(ticket);

  if (category === "simple_faq") {
    // FAQ: Haiku responde
    return answerWithHaiku(ticket);
  }

  if (category === "technical") {
    // Técnico: Sonnet tem qualidade adequada
    return answerWithSonnet(ticket);
  }

  // Escalação complexa: Opus só quando necessário
  return answerWithOpus(ticket);
}
```

---

### 2. Redução de Tokens no Prompt

**Identifique token waste:**
```typescript
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic();

// Contar tokens antes de enviar
async function countPromptTokens(messages: Anthropic.MessageParam[]): Promise<number> {
  const response = await anthropic.messages.countTokens({
    model: "claude-sonnet-4-6",
    messages
  });
  return response.input_tokens;
}
```

**Técnicas de compressão:**
```
ANTES: "Por favor, analise o texto a seguir e me diga qual é o sentimento
        expresso, se é positivo, negativo ou neutro. Responda de forma clara."
        → ~40 tokens

DEPOIS: "Classify sentiment: positive | negative | neutral\nText: {text}"
        → ~12 tokens (70% menor)
```

**Remova exemplos redundantes do few-shot:**
```
Regra: se o modelo acerta sem o exemplo, remova o exemplo.
Teste: retira um exemplo por vez, mede acurácia, mantém o mínimo necessário.
```

---

### 3. Prompt Caching (Anthropic)

Cache economiza custo quando o mesmo system prompt é reutilizado. Cache hit = 90% mais barato no input.

```typescript
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic();

// System prompt longo (documentação, base de conhecimento)
const LARGE_SYSTEM_PROMPT = `...conteúdo extenso que não muda entre requests...`;

async function queryWithCaching(userMessage: string): Promise<string> {
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: [
      {
        type: "text",
        text: LARGE_SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" } // Ativa cache
      }
    ],
    messages: [{ role: "user", content: userMessage }]
  });

  // Verificar uso do cache
  const usage = response.usage;
  console.log({
    input_tokens: usage.input_tokens,
    cache_creation_input_tokens: (usage as any).cache_creation_input_tokens,
    cache_read_input_tokens: (usage as any).cache_read_input_tokens
  });

  return response.content[0].type === "text" ? response.content[0].text : "";
}
```

**Quando vale o cache:**
- System prompt > 1024 tokens
- Mesmo prompt usado em > 5 requests seguidos
- Use caso: chatbot com documentação grande, RAG com context fixo

**Custo do cache:**
- Cache creation: 25% mais caro que input normal (paga uma vez)
- Cache hit: 90% mais barato que input normal (paga toda vez que reutiliza)
- Break even: ~1.4 cache hits por token cacheado

---

### 4. Batch Processing

Para processamento em lote (não precisa de resposta imediata), use Batch API da Anthropic — 50% mais barato.

```typescript
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic();

async function batchProcessDocuments(documents: string[]): Promise<string> {
  const requests = documents.map((doc, i) => ({
    custom_id: `doc-${i}`,
    params: {
      model: "claude-haiku-3-5" as const,
      max_tokens: 512,
      messages: [
        {
          role: "user" as const,
          content: `Summarize in 2 sentences: ${doc}`
        }
      ]
    }
  }));

  const batch = await anthropic.messages.batches.create({ requests });
  console.log(`Batch created: ${batch.id}`);
  console.log("Processing... check results at /batches/:id/results");

  return batch.id;
}

// Verificar resultado (polling ou webhook)
async function getBatchResults(batchId: string) {
  const batch = await anthropic.messages.batches.retrieve(batchId);

  if (batch.processing_status !== "ended") {
    console.log(`Status: ${batch.processing_status}. Check again later.`);
    return null;
  }

  const results = [];
  for await (const result of await anthropic.messages.batches.results(batchId)) {
    if (result.result.type === "succeeded") {
      results.push({
        id: result.custom_id,
        output: result.result.message.content[0]
      });
    }
  }
  return results;
}
```

**Use Batch quando:** relatórios noturnos, processamento de histórico, análise de datasets, geração de conteúdo em bulk.

**Não use Batch quando:** resposta em tempo real necessária, latência < 5 minutos importa.

---

### 5. Streaming para Melhorar UX de Latência

Streaming não reduz custo, mas melhora percepção de velocidade significativamente. Usuário vê tokens chegando em vez de esperar a resposta completa.

```typescript
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic();

// API Route (Next.js / Express)
async function streamingResponse(
  prompt: string,
  res: Response // HTTP Response object
): Promise<void> {
  // Headers para SSE
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  const stream = anthropic.messages.stream({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }]
  });

  for await (const event of stream) {
    if (
      event.type === "content_block_delta" &&
      event.delta.type === "text_delta"
    ) {
      // Envia cada chunk para o cliente
      res.write(`data: ${JSON.stringify({ text: event.delta.text })}\n\n`);
    }
  }

  res.write("data: [DONE]\n\n");
  res.end();
}
```

**Frontend (React) consumindo stream:**
```typescript
async function streamChat(message: string, onChunk: (text: string) => void) {
  const response = await fetch("/api/chat", {
    method: "POST",
    body: JSON.stringify({ message }),
    headers: { "Content-Type": "application/json" }
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split("\n").filter(l => l.startsWith("data: "));

    for (const line of lines) {
      const data = line.slice(6); // Remove "data: "
      if (data === "[DONE]") return;

      try {
        const { text } = JSON.parse(data);
        onChunk(text);
      } catch {}
    }
  }
}
```

---

## CHECKLIST DE OTIMIZAÇÃO

### Antes de entrar em produção:
- [ ] Modelo correto para a complexidade da tarefa (não usar Opus onde Haiku basta)
- [ ] Tokens do prompt contados e documentados
- [ ] System prompt longo (> 1024 tokens) com cache habilitado
- [ ] Output tokens limitado com `max_tokens` adequado (não deixar sem limite)
- [ ] Estimativa de custo mensal calculada e aprovada

### Quando o custo subir:
1. Log de tokens por endpoint (identificar qual rota gasta mais)
2. Verificar se cache está sendo hit (ratio de cache hits deve ser > 70%)
3. Revisar se o modelo está superdimensionado para a tarefa
4. Considerar Batch API para processamento não-urgente
5. Revisar tamanho do system prompt — remover contexto desnecessário
