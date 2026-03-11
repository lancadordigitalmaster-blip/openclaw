# llm-performance.md — Turbo Sub-Skill: LLM Performance
# Ativa quando: "LLM lento", "tokens", "custo", "latência de IA"

---

## Métricas de LLM a Monitorar

| Métrica | O que é | Meta Wolf | Alerta |
|---------|---------|-----------|--------|
| TTFT | Time to First Token (usuário vê algo) | < 500ms | > 1s |
| Tokens/s | Velocidade de geração | > 30 tok/s | < 15 tok/s |
| Total latency | Tempo total até fim da resposta | < 5s | > 10s |
| Input tokens | Tokens no prompt | Minimizar | > 10k/request |
| Output tokens | Tokens gerados | Adequado à tarefa | — |
| Cache hit rate | % de prompts com cache hit | > 70% | < 40% |
| Cost per request | Custo médio por chamada | Definir baseline | 2x baseline |

---

## Estratégia 1: Streaming — Reduz Latência Percebida

O usuário começa a ler enquanto o modelo ainda gera. Impacto visual imediato.

```typescript
// Anthropic SDK — streaming com Next.js
import Anthropic from '@anthropic-ai/sdk'
import { StreamingTextResponse } from 'ai' // Vercel AI SDK

const client = new Anthropic()

// API Route — Next.js App Router
export async function POST(req: Request) {
  const { mensagem } = await req.json()

  const stream = await client.messages.stream({
    model: 'claude-haiku-4-5',
    max_tokens: 1024,
    messages: [{ role: 'user', content: mensagem }],
  })

  // Retorna stream direto para o cliente
  return new Response(stream.toReadableStream(), {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
}
```

```typescript
// Frontend — consumir stream
async function chatComStreaming(mensagem: string) {
  const response = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mensagem }),
  })

  const reader = response.body!.getReader()
  const decoder = new TextDecoder()
  let texto = ''

  while (true) {
    const { value, done } = await reader.read()
    if (done) break

    const chunk = decoder.decode(value)
    texto += chunk
    setTextoExibido(texto) // atualiza UI em tempo real
  }
}
```

---

## Estratégia 2: Modelo Certo para a Tarefa

Não use Opus para tudo. Custo e latência variam dramaticamente.

| Modelo | Custo Input | Custo Output | TTFT | Use Para |
|--------|-------------|--------------|------|----------|
| claude-haiku-4-5 | $0.80/Mtok | $4/Mtok | ~200ms | Classificação, extração simples, respostas curtas |
| claude-sonnet-4-5 | $3/Mtok | $15/Mtok | ~400ms | Maioria das tarefas, chat, análise média |
| claude-opus-4-5 | $15/Mtok | $75/Mtok | ~600ms | Raciocínio complexo, código difícil, análise profunda |

**Regra Wolf:** Haiku para triagem, Sonnet para execução, Opus para raciocínio que justifica o custo.

```typescript
// Roteamento de modelo por complexidade da tarefa
function selecionarModelo(tarefa: Tarefa): string {
  // Tarefas simples → Haiku (60x mais barato que Opus)
  if (tarefa.tipo === 'classificacao' || tarefa.tipo === 'extracao_simples') {
    return 'claude-haiku-4-5'
  }

  // Tarefas médias → Sonnet (padrão Wolf)
  if (tarefa.tipo === 'geracao_texto' || tarefa.tipo === 'analise') {
    return 'claude-sonnet-4-5'
  }

  // Tarefas que requerem raciocínio profundo → Opus
  if (tarefa.tipo === 'arquitetura' || tarefa.tipo === 'debug_complexo') {
    return 'claude-opus-4-5'
  }

  return 'claude-sonnet-4-5' // default seguro
}
```

---

## Estratégia 3: Prompt Cache da Anthropic

Reduz custo e latência quando o mesmo contexto é usado em múltiplas chamadas.

```typescript
// Prompt caching — marca partes do prompt para cache
const response = await client.messages.create({
  model: 'claude-sonnet-4-5',
  max_tokens: 1024,
  system: [
    {
      type: 'text',
      text: `Você é um assistente especializado em suporte técnico da Wolf Agency.

Contexto do produto (atualizado semanalmente):
${documentacaoExtensa}  // 5000 tokens de contexto

Regras de atendimento:
${regrasDeAtendimento}  // 2000 tokens de regras
`,
      cache_control: { type: 'ephemeral' }, // cache por 5 minutos
    },
  ],
  messages: [
    { role: 'user', content: perguntaDoUsuario }, // varia por request
  ],
})

// Primeira chamada: paga input tokens completos
// Chamadas seguintes (dentro de 5min): paga apenas 10% do custo

// Verificar se cache foi usado
const uso = response.usage
console.log({
  inputTokens: uso.input_tokens,
  cacheCreationTokens: uso.cache_creation_input_tokens,  // tokens que foram cacheados
  cacheReadTokens: uso.cache_read_input_tokens,          // tokens lidos do cache
})
```

```typescript
// Padrão Wolf: cache para contexto estático + variável por user
async function responderComCache(pergunta: string, contextoEstatico: string) {
  return client.messages.create({
    model: 'claude-haiku-4-5',
    max_tokens: 512,
    system: [
      {
        type: 'text',
        text: contextoEstatico,
        cache_control: { type: 'ephemeral' },
      },
    ],
    messages: [{ role: 'user', content: pergunta }],
  })
}
```

---

## Estratégia 4: Batch API para Processamentos Não-Urgentes

50% de desconto no custo. Ideal para: processamento de documentos, análise em lote, classificação em massa.

```typescript
// Anthropic Batch API
const batch = await client.messages.batches.create({
  requests: documentos.map((doc, i) => ({
    custom_id: `doc-${doc.id}`, // para identificar no resultado
    params: {
      model: 'claude-haiku-4-5',
      max_tokens: 256,
      messages: [
        {
          role: 'user',
          content: `Classifique este documento em uma categoria: ${doc.texto}`,
        },
      ],
    },
  })),
})

console.log(`Batch criado: ${batch.id}`)

// Verificar status (SLA: até 24h, geralmente minutos)
async function aguardarBatch(batchId: string) {
  while (true) {
    const status = await client.messages.batches.retrieve(batchId)
    if (status.processing_status === 'ended') {
      break
    }
    await new Promise(r => setTimeout(r, 30_000)) // verifica a cada 30s
  }

  // Processar resultados
  for await (const result of await client.messages.batches.results(batchId)) {
    if (result.result.type === 'succeeded') {
      await salvarResultado(result.custom_id, result.result.message)
    }
  }
}
```

---

## Estratégia 5: Paralelismo de Chamadas

```typescript
// ERRADO — sequencial (soma das latências)
async function processarDocumentos(docs: Documento[]) {
  const resultados = []
  for (const doc of docs) {
    const resultado = await analisarComLLM(doc) // espera cada um
    resultados.push(resultado)
  }
  return resultados
}
// 10 docs × 2s = 20s total

// CORRETO — paralelo com limite de concorrência
import pLimit from 'p-limit'

async function processarDocumentos(docs: Documento[]) {
  const limit = pLimit(5) // máximo 5 chamadas simultâneas (evita rate limit)

  const resultados = await Promise.all(
    docs.map(doc => limit(() => analisarComLLM(doc)))
  )
  return resultados
}
// 10 docs ÷ 5 paralelos × 2s = 4s total (5x mais rápido)
```

```typescript
// Promise.all para chamadas independentes
async function analisarTexto(texto: string) {
  // Roda em paralelo — ambas as chamadas disparam ao mesmo tempo
  const [resumo, sentimento, categorias] = await Promise.all([
    gerarResumo(texto),        // ~1s
    analisarSentimento(texto), // ~0.5s
    extrairCategorias(texto),  // ~0.7s
  ])
  // Total: ~1s (o mais lento), não 2.2s (sequencial)

  return { resumo, sentimento, categorias }
}
```

---

## Otimização de Prompts — Reduzir Tokens

```typescript
// Medir tokens antes de enviar
const tokenizer = await import('@anthropic-ai/tokenizer')

function estimarTokens(texto: string): number {
  return tokenizer.countTokens(texto)
}

// Técnicas de redução de tokens no prompt

// 1. Contexto conciso — cortar o que o modelo não precisa
// ANTES (800 tokens):
const systemPromptVerboso = `
  Você é um assistente de suporte ao cliente muito prestativo e profissional
  da empresa Wolf Agency. Sua missão é ajudar os clientes a resolver seus
  problemas de forma eficiente e empática. Sempre seja cordial...
  [parágrafo após parágrafo de contexto]
`

// DEPOIS (120 tokens):
const systemPromptConciso = `
  Suporte Wolf Agency. Responda em PT-BR. Seja direto e resolve o problema.
  Se não souber, diga: "Vou verificar e retorno em breve."
`

// 2. Exemplos only quando necessário
// Few-shot aumenta qualidade mas custa tokens
// Use apenas para tarefas onde o modelo erra sem exemplos

// 3. Instruções de formato curtas
// ANTES: "Por favor, formate sua resposta como um objeto JSON com as
//         seguintes chaves: titulo, descricao, categoria, tags"
// DEPOIS: "Responda em JSON: {titulo, descricao, categoria, tags[]}"
```

---

## Monitoramento de Custos e Performance

```typescript
// Wrapper de monitoramento Wolf
interface LLMMetrics {
  modelo: string
  inputTokens: number
  outputTokens: number
  cacheHit: boolean
  latenciaMs: number
  custo: number
  tarefa: string
}

const PRECOS = {
  'claude-haiku-4-5': { input: 0.0008, output: 0.004 },
  'claude-sonnet-4-5': { input: 0.003, output: 0.015 },
  'claude-opus-4-5': { input: 0.015, output: 0.075 },
} // por 1k tokens

async function chamarLLM(params: MessageCreateParams, tarefa: string) {
  const inicio = Date.now()
  const response = await client.messages.create(params)
  const latencia = Date.now() - inicio

  const preco = PRECOS[params.model as keyof typeof PRECOS]
  const custo =
    (response.usage.input_tokens * preco.input +
      response.usage.output_tokens * preco.output) / 1000

  const metrics: LLMMetrics = {
    modelo: params.model,
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    cacheHit: (response.usage as any).cache_read_input_tokens > 0,
    latenciaMs: latencia,
    custo,
    tarefa,
  }

  // Enviar para seu sistema de observabilidade
  await enviarMetrica('llm.request', metrics)

  if (custo > 0.10) {
    console.warn(`Chamada cara: $${custo.toFixed(4)} para tarefa "${tarefa}"`)
  }

  return response
}
```

---

## Checklist LLM Performance Wolf

```
Latência
[ ] Streaming implementado para respostas ao usuário
[ ] TTFT monitorado (meta: < 500ms)
[ ] Chamadas independentes em paralelo (Promise.all)

Custo
[ ] Modelo adequado à complexidade da tarefa (não Opus para tudo)
[ ] Prompt cache para contexto estático > 1000 tokens
[ ] Batch API para processamentos não-urgentes
[ ] Custo por request monitorado com alerta

Qualidade de Prompt
[ ] Tokens do prompt medidos antes de ir para prod
[ ] Context janela não desperdiçada com texto desnecessário
[ ] max_tokens configurado adequado à tarefa (não 4096 para tudo)

Observabilidade
[ ] Todas as chamadas monitoradas (modelo, tokens, latência, custo)
[ ] Cache hit rate > 70% para prompts que usam cache
[ ] Dashboard de custo diário/mensal
[ ] Alerta para anomalias de custo (2x baseline)
```
