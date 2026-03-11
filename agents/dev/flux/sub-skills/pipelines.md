# pipelines.md — FLUX Sub-Skill: AI Pipelines & Orquestração
# Ativa quando: "pipeline", "orquestração", "multi-agente", "fluxo de IA"

---

## PADRÕES DE ORQUESTRAÇÃO

### 1. Sequential (Cadeia Linear)

Cada step recebe o output do anterior. Use para workflows onde cada etapa depende da anterior.

```
Input → [Step A] → [Step B] → [Step C] → Output
```

```typescript
// Exemplo: pipeline de análise de contrato
async function analyzeContract(contractText: string) {
  // Step 1: Extrair cláusulas
  const clauses = await extractClauses(contractText);

  // Step 2: Analisar risco de cada cláusula
  const riskAnalysis = await analyzeRisks(clauses);

  // Step 3: Gerar sumário executivo
  const summary = await generateSummary(riskAnalysis);

  return { clauses, riskAnalysis, summary };
}
```

**Quando usar:** processamento de documentos, pipelines ETL de IA, transformações em cascata.

---

### 2. Parallel (Execução Paralela)

Múltiplos steps independentes rodando simultaneamente. Reduz latência total.

```
             ┌→ [Step A] ─┐
Input ───────┼→ [Step B] ─┼→ Merge → Output
             └→ [Step C] ─┘
```

```typescript
// Exemplo: análise multi-dimensão de feedback de usuário
async function analyzeFeedback(feedback: string) {
  const [sentiment, category, urgency, entities] = await Promise.all([
    classifySentiment(feedback),
    classifyCategory(feedback),
    assessUrgency(feedback),
    extractEntities(feedback)
  ]);

  return { sentiment, category, urgency, entities };
}
```

**Quando usar:** análises independentes do mesmo input, enriquecimento de dados com múltiplas fontes.

**Cuidado:** se um step falha, `Promise.all` cancela tudo. Use `Promise.allSettled` para resiliência:

```typescript
const results = await Promise.allSettled([
  classifySentiment(feedback),
  classifyCategory(feedback)
]);

const sentiment = results[0].status === "fulfilled"
  ? results[0].value
  : "unknown";
```

---

### 3. Branching (Roteamento Condicional)

O roteador decide qual caminho seguir com base no input. Use para sistemas com múltiplos tipos de request.

```
         ┌─ [Handler A] (se tipo = billing)
Input → [Router] ─┼─ [Handler B] (se tipo = technical)
         └─ [Handler C] (se tipo = general)
```

```typescript
type RequestType = "billing" | "technical" | "general";

async function routeRequest(userMessage: string) {
  // Step 1: Classificar intenção
  const requestType = await classifyIntent(userMessage) as RequestType;

  // Step 2: Rotear para handler especializado
  const handlers: Record<RequestType, (msg: string) => Promise<string>> = {
    billing: handleBillingRequest,
    technical: handleTechnicalSupport,
    general: handleGeneralInquiry
  };

  const handler = handlers[requestType];
  if (!handler) {
    return handleGeneralInquiry(userMessage); // fallback
  }

  return handler(userMessage);
}
```

---

### 4. Human-in-the-Loop (HITL)

O pipeline pausa e aguarda aprovação/input humano antes de continuar. Crítico para ações irreversíveis.

```
[Step A] → [Step B] → PAUSE (human review) → [Step C - ação irreversível]
```

```typescript
// Exemplo: pipeline de publicação de conteúdo
interface PipelineState {
  id: string;
  status: "pending" | "awaiting_approval" | "approved" | "rejected" | "done";
  draft: string;
  reviewerNotes?: string;
}

async function contentPublicationPipeline(topic: string): Promise<void> {
  // Step 1: Gerar draft
  const draft = await generateDraft(topic);

  // Step 2: Salvar estado e notificar revisor
  const state: PipelineState = {
    id: crypto.randomUUID(),
    status: "awaiting_approval",
    draft
  };
  await saveState(state);
  await notifyReviewer(state.id, draft);

  // Pipeline pausa aqui.
  // Retoma quando webhook /pipeline/:id/approve ou /reject é chamado.
}

// Endpoint de aprovação (chamado pelo revisor)
async function approvePipeline(stateId: string, notes: string): Promise<void> {
  const state = await loadState(stateId);
  state.status = "approved";
  state.reviewerNotes = notes;
  await saveState(state);

  // Continua pipeline
  await publishContent(state.draft);
  state.status = "done";
  await saveState(state);
}
```

---

## OPENCLAW COMO ORQUESTRADOR WOLF

OpenClaw coordena agentes especializados. Cada agente tem um domínio e capacidades definidas no SKILL.md.

### Padrão de Delegação

```typescript
// O orquestrador decide qual agente acionar
async function orchestrate(task: string): Promise<string> {
  // 1. Classificar o tipo de tarefa
  const taskType = await classifyTask(task);

  // 2. Selecionar agente especializado
  const agentMap: Record<string, string> = {
    "mobile_dev": "ECHO",
    "ai_engineering": "FLUX",
    "backend_dev": "FORGE",
    "frontend_dev": "CRAFT",
    "data_analysis": "ATLAS",
    "infrastructure": "TITAN"
  };

  const targetAgent = agentMap[taskType] ?? "FLUX"; // FLUX como fallback técnico

  // 3. Passar contexto completo para o agente
  return await delegateToAgent(targetAgent, task);
}
```

---

## QUANDO USAR LANGCHAIN VS IMPLEMENTAÇÃO PRÓPRIA

### Use LangChain quando:
- Você precisa de RAG complexo com múltiplos retrievers rapidamente
- Projeto experimental/protótipo onde velocidade de desenvolvimento > controle
- Você precisa de integrações prontas (Pinecone, Weaviate, etc.)

### Use implementação própria (padrão Wolf) quando:
- Pipeline está em produção e precisa de controle total
- Performance é crítica (LangChain tem overhead de abstrações)
- O pipeline é simples — não justifica dependência pesada
- Você precisa de debugging claro (LangChain dificulta observabilidade)

**Regra Wolf:** comece sem LangChain. Adicione se a complexidade justificar.

---

## TRATAMENTO DE ERROS EM PIPELINES DE IA

### Padrão de Retry com Backoff Exponencial

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxRetries?: number;
    initialDelay?: number;
    maxDelay?: number;
    retryOn?: (error: unknown) => boolean;
  } = {}
): Promise<T> {
  const {
    maxRetries = 3,
    initialDelay = 1000,
    maxDelay = 10000,
    retryOn = () => true
  } = options;

  let lastError: unknown;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (attempt === maxRetries || !retryOn(error)) {
        throw error;
      }

      const delay = Math.min(
        initialDelay * Math.pow(2, attempt),
        maxDelay
      );
      console.error(`Attempt ${attempt + 1} failed. Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// Uso no pipeline
const result = await withRetry(
  () => callLLM(prompt),
  {
    maxRetries: 3,
    retryOn: (err) => {
      // Retry apenas em rate limit ou timeout, não em erros de autenticação
      const message = err instanceof Error ? err.message : "";
      return message.includes("rate_limit") || message.includes("timeout");
    }
  }
);
```

### Fallback Gracioso

```typescript
async function callLLMWithFallback(
  prompt: string,
  primaryModel: string,
  fallbackModel: string
): Promise<string> {
  try {
    return await callLLM(prompt, primaryModel);
  } catch (error) {
    console.error(`Primary model ${primaryModel} failed:`, error);
    console.log(`Falling back to ${fallbackModel}`);
    return await callLLM(prompt, fallbackModel);
  }
}

// Exemplo: opus como primário, sonnet como fallback
const response = await callLLMWithFallback(
  prompt,
  "claude-opus-4-6",
  "claude-sonnet-4-6"
);
```

---

## ESTADO PERSISTENTE ENTRE STEPS

### Padrão Wolf: State Object + Supabase

```typescript
// src/pipeline/state.ts
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

interface PipelineRun {
  id: string;
  created_at: string;
  status: "running" | "paused" | "completed" | "failed";
  input: Record<string, unknown>;
  steps: Record<string, StepResult>;
  current_step: string;
  error?: string;
}

interface StepResult {
  status: "pending" | "completed" | "failed";
  output?: unknown;
  completed_at?: string;
  error?: string;
}

export async function createPipelineRun(
  input: Record<string, unknown>
): Promise<PipelineRun> {
  const run: Omit<PipelineRun, "created_at"> = {
    id: crypto.randomUUID(),
    status: "running",
    input,
    steps: {},
    current_step: "init"
  };

  const { data, error } = await supabase
    .from("pipeline_runs")
    .insert(run)
    .select()
    .single();

  if (error) throw new Error(`Failed to create pipeline run: ${error.message}`);
  return data;
}

export async function updateStep(
  runId: string,
  stepName: string,
  result: StepResult
): Promise<void> {
  const { error } = await supabase
    .from("pipeline_runs")
    .update({
      steps: supabase.rpc("jsonb_set_nested", {
        // Atualiza apenas o step específico no objeto steps
        target: "steps",
        path: stepName,
        value: result
      }),
      current_step: stepName
    })
    .eq("id", runId);

  if (error) throw new Error(`Failed to update step: ${error.message}`);
}
```

### SQL para tabela de state

```sql
create table pipeline_runs (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz default now(),
  status       text not null default 'running',
  input        jsonb not null default '{}',
  steps        jsonb not null default '{}',
  current_step text not null default 'init',
  error        text,
  completed_at timestamptz
);

-- Index para consulta por status
create index on pipeline_runs (status, created_at desc);
```

---

## CHECKLIST DE PIPELINE PRONTO PARA PRODUÇÃO

- [ ] Cada step tem timeout definido (evita pipeline travado)
- [ ] Retry com backoff implementado para chamadas LLM
- [ ] State salvo no banco (pipeline pode ser retomado se cair)
- [ ] Erros são logados com contexto suficiente para debug
- [ ] HITL implementado para ações irreversíveis (envio de email, pagamentos)
- [ ] Fallback de modelo configurado (primário + backup)
- [ ] Custo estimado por execução de pipeline documentado
- [ ] Monitoramento de execuções com alerta em caso de falha em cascata
