# rag.md — FLUX Sub-Skill: RAG (Retrieval-Augmented Generation)
# Ativa quando: "RAG", "embeddings", "busca semântica", "base de conhecimento"

---

## QUANDO RAG RESOLVE VS QUANDO É OVER-ENGINEERING

### Use RAG quando:
- Base de conhecimento > 50k tokens (não cabe no context window)
- Conteúdo muda frequentemente (documentos, FAQs, produtos)
- Precisão factual é crítica (não pode alucinar)
- Você precisa citar fontes específicas
- Múltiplos usuários com bases de conhecimento distintas

### NÃO use RAG quando:
- A informação cabe no system prompt (< 20k tokens, estático)
- Você tem apenas 10-20 documentos — só coloque no context
- O projeto tem budget limitado e prazo curto — RAG tem overhead de 2-3 semanas
- A pergunta não é sobre fatos — para raciocínio, RAG não ajuda

---

## ARQUITETURA RAG WOLF

```
INGESTION PIPELINE                    QUERY PIPELINE
─────────────────                    ───────────────
Documentos/Texto                      User Query
     ↓                                    ↓
Chunking (split)                      Embed query
     ↓                                    ↓
Embed chunks                          Vector search (pgvector)
     ↓                                    ↓
Upsert no Supabase                    Top-K chunks retrieved
(pgvector)                                ↓
                                      Inject no prompt + LLM
                                          ↓
                                      Resposta com contexto
```

---

## STACK WOLF PARA RAG

| Componente    | Tecnologia                          |
|---------------|-------------------------------------|
| Vector Store  | Supabase + pgvector                 |
| Embeddings    | OpenAI text-embedding-3-small       |
| LLM           | Claude claude-opus-4-6 / claude-sonnet-4-6      |
| Framework     | TypeScript puro (sem LangChain)     |
| Chunking      | Implementação própria (veja abaixo) |

---

## SUPABASE PGVECTOR SETUP

### Criação da tabela

```sql
-- Enable pgvector extension
create extension if not exists vector;

-- Tabela de chunks
create table documents (
  id          uuid primary key default gen_random_uuid(),
  source      text not null,           -- arquivo ou URL de origem
  chunk_index integer not null,        -- posição do chunk no documento
  content     text not null,           -- texto do chunk
  metadata    jsonb default '{}',      -- tags, autor, data, etc.
  embedding   vector(1536),            -- text-embedding-3-small = 1536 dims
  created_at  timestamptz default now()
);

-- Index para busca por similaridade (cosine)
create index on documents
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);
```

### Função de busca semântica

```sql
create or replace function match_documents(
  query_embedding vector(1536),
  match_threshold float default 0.7,
  match_count     int    default 5
)
returns table (
  id       uuid,
  source   text,
  content  text,
  metadata jsonb,
  similarity float
)
language sql stable
as $$
  select
    id,
    source,
    content,
    metadata,
    1 - (embedding <=> query_embedding) as similarity
  from documents
  where 1 - (embedding <=> query_embedding) > match_threshold
  order by embedding <=> query_embedding
  limit match_count;
$$;
```

---

## CHUNKING STRATEGY

### Regras Wolf

```
Tamanho de chunk:  400-600 tokens (~300-450 palavras)
Overlap:           10-15% do tamanho (50-80 tokens)
Separadores:       Parágrafos > frases > palavras (nessa ordem)
```

### Por que esse tamanho?
- Muito pequeno (< 100 tokens): perde contexto, chunks sem sentido completo
- Muito grande (> 1000 tokens): ruído no retrieval, mistura tópicos
- 400-600 é o sweet spot para documentos técnicos e de negócio

### Implementação

```typescript
// src/utils/chunker.ts
interface Chunk {
  content: string;
  index: number;
  tokenCount: number;
}

function estimateTokens(text: string): number {
  // Aproximação: ~1.3 tokens por palavra em inglês/português
  return Math.ceil(text.split(/\s+/).length * 1.3);
}

export function chunkText(
  text: string,
  maxTokens = 500,
  overlapTokens = 60
): Chunk[] {
  const paragraphs = text.split(/\n\n+/).filter(p => p.trim().length > 0);
  const chunks: Chunk[] = [];
  let currentChunk = "";
  let currentTokens = 0;
  let chunkIndex = 0;

  for (const paragraph of paragraphs) {
    const paraTokens = estimateTokens(paragraph);

    if (currentTokens + paraTokens > maxTokens && currentChunk.length > 0) {
      // Salva chunk atual
      chunks.push({
        content: currentChunk.trim(),
        index: chunkIndex++,
        tokenCount: currentTokens
      });

      // Overlap: pega últimas palavras do chunk anterior
      const words = currentChunk.split(/\s+/);
      const overlapWords = words.slice(-Math.floor(overlapTokens / 1.3));
      currentChunk = overlapWords.join(" ") + "\n\n" + paragraph;
      currentTokens = estimateTokens(currentChunk);
    } else {
      currentChunk += (currentChunk ? "\n\n" : "") + paragraph;
      currentTokens += paraTokens;
    }
  }

  if (currentChunk.trim()) {
    chunks.push({
      content: currentChunk.trim(),
      index: chunkIndex,
      tokenCount: currentTokens
    });
  }

  return chunks;
}
```

---

## PIPELINE DE INGESTION

```typescript
// src/ingestion/ingest.ts
import OpenAI from "openai";
import { createClient } from "@supabase/supabase-js";
import { chunkText } from "../utils/chunker.js";
import { readFileSync } from "fs";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

async function embedTexts(texts: string[]): Promise<number[][]> {
  const response = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: texts
  });
  return response.data.map(d => d.embedding);
}

export async function ingestDocument(
  filePath: string,
  metadata: Record<string, unknown> = {}
): Promise<void> {
  console.log(`Ingesting: ${filePath}`);

  const text = readFileSync(filePath, "utf-8");
  const chunks = chunkText(text);

  console.log(`  ${chunks.length} chunks created`);

  // Batch embed (max 100 por request na OpenAI)
  const batchSize = 100;
  for (let i = 0; i < chunks.length; i += batchSize) {
    const batch = chunks.slice(i, i + batchSize);
    const embeddings = await embedTexts(batch.map(c => c.content));

    const rows = batch.map((chunk, idx) => ({
      source: filePath,
      chunk_index: chunk.index,
      content: chunk.content,
      metadata: { ...metadata, token_count: chunk.tokenCount },
      embedding: embeddings[idx]
    }));

    const { error } = await supabase.from("documents").upsert(rows, {
      onConflict: "source,chunk_index"
    });

    if (error) throw new Error(`Supabase upsert failed: ${error.message}`);
    console.log(`  Batch ${Math.floor(i / batchSize) + 1} upserted`);
  }

  console.log(`Done: ${filePath}`);
}
```

---

## PIPELINE DE QUERY (RETRIEVAL + GENERATION)

```typescript
// src/rag/query.ts
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { createClient } from "@supabase/supabase-js";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

interface RetrievedChunk {
  id: string;
  source: string;
  content: string;
  similarity: number;
}

async function retrieveRelevantChunks(
  query: string,
  topK = 5,
  threshold = 0.7
): Promise<RetrievedChunk[]> {
  const embeddingResponse = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: query
  });
  const queryEmbedding = embeddingResponse.data[0].embedding;

  const { data, error } = await supabase.rpc("match_documents", {
    query_embedding: queryEmbedding,
    match_threshold: threshold,
    match_count: topK
  });

  if (error) throw new Error(`Retrieval failed: ${error.message}`);
  return data ?? [];
}

export async function ragQuery(userQuestion: string): Promise<string> {
  // 1. Retrieve
  const chunks = await retrieveRelevantChunks(userQuestion);

  if (chunks.length === 0) {
    return "Não encontrei informação relevante na base de conhecimento para responder essa pergunta.";
  }

  // 2. Build context
  const context = chunks
    .map((c, i) => `[${i + 1}] (source: ${c.source})\n${c.content}`)
    .join("\n\n---\n\n");

  // 3. Generate
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: `You are a helpful assistant. Answer questions based ONLY on the provided context.
If the answer is not in the context, say so clearly. Do not make up information.
Always cite which source(s) you used by referencing [1], [2], etc.`,
    messages: [
      {
        role: "user",
        content: `Context:\n${context}\n\nQuestion: ${userQuestion}`
      }
    ]
  });

  return response.content[0].type === "text" ? response.content[0].text : "";
}
```

---

## CHECKLIST DE RAG PRONTO PARA PRODUÇÃO

### Ingestion
- [ ] Chunking testado com documentos reais do projeto
- [ ] Tamanho médio de chunk verificado (400-600 tokens)
- [ ] Overlap implementado para não perder contexto entre chunks
- [ ] Metadados incluem: source, data de atualização, categoria
- [ ] Upsert com `onConflict` para reprocessar sem duplicar

### Retrieval
- [ ] Threshold de similaridade calibrado (começar com 0.7, ajustar)
- [ ] Top-K definido por caso de uso (5 para FAQ, 10 para documentação técnica)
- [ ] Testado com queries que NÃO têm resposta (deve retornar vazio graciosamente)

### Generation
- [ ] Prompt instrui explicitamente a não alucinar fora do contexto
- [ ] Citação de fontes implementada
- [ ] Fallback quando retrieval retorna vazio

### Monitoramento
- [ ] Log de queries para análise de gaps na base de conhecimento
- [ ] Similaridade média logada por query
- [ ] Alert se threshold médio cair (base de conhecimento desatualizada)
