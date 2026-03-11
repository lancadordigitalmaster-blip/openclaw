# mcp-development.md — FLUX Sub-Skill: MCP Development
# Ativa quando: "MCP", "ferramenta", "tool", "integração de IA"

---

## O QUE É UM MCP SERVER

MCP (Model Context Protocol) é o padrão Anthropic para conectar LLMs a ferramentas externas. Um MCP server expõe `tools` que o modelo pode chamar para executar ações no mundo real — buscar dados, criar registros, chamar APIs.

**Fluxo básico:**
```
LLM → decide usar tool → MCP server executa → retorna resultado → LLM continua
```

---

## ESTRUTURA DE MCP SERVER

### Arquitetura de Arquivos

```
mcp-[nome]/
├── src/
│   ├── index.ts          # Entry point, server setup
│   ├── tools/
│   │   ├── index.ts      # Exporta todas as tools
│   │   ├── tool-a.ts     # Definição + handler de cada tool
│   │   └── tool-b.ts
│   └── utils/
│       ├── client.ts     # Cliente da API externa
│       └── validators.ts # Validação de inputs
├── .env.example          # Template de variáveis
├── package.json
└── tsconfig.json
```

### Schema de Tool Definition

```typescript
// src/tools/create-task.ts
import { Tool } from "@modelcontextprotocol/sdk/types.js";

export const createTaskTool: Tool = {
  name: "create_task",
  description: `Creates a new task in the project management system.
    Use this when the user wants to add a task, to-do, or action item.
    Returns the created task ID and confirmation.`,
  inputSchema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "The task title. Be concise and action-oriented."
      },
      description: {
        type: "string",
        description: "Detailed description of what needs to be done. Optional."
      },
      assignee_email: {
        type: "string",
        description: "Email of the person responsible. Optional."
      },
      due_date: {
        type: "string",
        description: "Due date in ISO 8601 format (YYYY-MM-DD). Optional."
      },
      priority: {
        type: "string",
        enum: ["low", "medium", "high", "urgent"],
        description: "Task priority level. Defaults to medium if not specified."
      }
    },
    required: ["title"]
  }
};
```

### Handler de Tool

```typescript
// src/tools/create-task.ts (continuação)
import { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { getProjectClient } from "../utils/client.js";

export async function handleCreateTask(
  input: Record<string, unknown>
): Promise<CallToolResult> {
  const { title, description, assignee_email, due_date, priority } = input as {
    title: string;
    description?: string;
    assignee_email?: string;
    due_date?: string;
    priority?: string;
  };

  try {
    const client = getProjectClient();
    const task = await client.tasks.create({
      title,
      description: description ?? "",
      assigneeEmail: assignee_email,
      dueDate: due_date ? new Date(due_date) : undefined,
      priority: priority ?? "medium"
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            success: true,
            task_id: task.id,
            title: task.title,
            url: task.url,
            message: `Task "${task.title}" created successfully.`
          }, null, 2)
        }
      ]
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            success: false,
            error: message,
            hint: "Check if the assignee email exists in the system."
          }, null, 2)
        }
      ],
      isError: true
    };
  }
}
```

### Entry Point (index.ts)

```typescript
// src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema
} from "@modelcontextprotocol/sdk/types.js";

import { createTaskTool, handleCreateTask } from "./tools/create-task.js";
import { listTasksTool, handleListTasks } from "./tools/list-tasks.js";

const server = new Server(
  {
    name: "mcp-project-manager",
    version: "1.0.0"
  },
  {
    capabilities: { tools: {} }
  }
);

// Registra tools disponíveis
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [createTaskTool, listTasksTool]
}));

// Roteador de handlers
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "create_task":
      return handleCreateTask(args ?? {});
    case "list_tasks":
      return handleListTasks(args ?? {});
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("MCP server running on stdio");
```

### package.json

```json
{
  "name": "mcp-project-manager",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.0.0"
  }
}
```

---

## CHECKLIST DE NOVO MCP

### Antes de Escrever Código
- [ ] A tool resolve um problema específico e não-trivial para o LLM?
- [ ] A API externa tem rate limits documentados?
- [ ] As credenciais estão mapeadas (nomes de env vars definidos)?

### Durante o Desenvolvimento
- [ ] **Description clara**: descreve QUANDO usar a tool (não apenas o que ela faz)
- [ ] **Schema completo**: todos os campos com `description` preenchida
- [ ] **Required correto**: apenas campos verdadeiramente obrigatórios em `required`
- [ ] **Erros descritivos**: `isError: true` + mensagem que ajuda o LLM a corrigir
- [ ] **Rate limiting**: implementado para não explodir quotas de API
- [ ] **Credenciais via .env**: zero hardcode de secrets no código
- [ ] **.env.example**: arquivo template commitado no repositório

### Antes de Integrar
- [ ] Testado isolado (sem LLM) com inputs válidos
- [ ] Testado com inputs inválidos (erros retornam graciosamente)
- [ ] Testado com edge cases (strings vazias, null, campos extras)
- [ ] Documentado no SKILL.md do agente que vai usar

---

## GERENCIAMENTO DE CREDENCIAIS

```typescript
// src/utils/client.ts
import { config } from "dotenv";
config();

function getRequiredEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${key}. ` +
      `Check .env.example for required variables.`
    );
  }
  return value;
}

export function getProjectClient() {
  const apiKey = getRequiredEnv("PROJECT_API_KEY");
  const baseUrl = getRequiredEnv("PROJECT_BASE_URL");
  // return new ProjectClient({ apiKey, baseUrl });
}
```

```bash
# .env.example
PROJECT_API_KEY=your_api_key_here
PROJECT_BASE_URL=https://api.example.com/v1
RATE_LIMIT_PER_MINUTE=60
```

---

## RATE LIMITING

```typescript
// src/utils/rate-limiter.ts
export class RateLimiter {
  private requests: number[] = [];
  private readonly maxRequests: number;
  private readonly windowMs: number;

  constructor(maxRequests = 60, windowMs = 60_000) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  async throttle(): Promise<void> {
    const now = Date.now();
    this.requests = this.requests.filter(t => now - t < this.windowMs);

    if (this.requests.length >= this.maxRequests) {
      const oldestRequest = this.requests[0];
      const waitMs = this.windowMs - (now - oldestRequest) + 100;
      await new Promise(resolve => setTimeout(resolve, waitMs));
    }

    this.requests.push(Date.now());
  }
}

// Singleton
export const rateLimiter = new RateLimiter(
  parseInt(process.env.RATE_LIMIT_PER_MINUTE ?? "60"),
  60_000
);
```

---

## COMO TESTAR MCP ISOLADO DO LLM

### Teste Direto via Node.js

```typescript
// test/test-tool.ts
import { handleCreateTask } from "../src/tools/create-task.js";

async function runTests() {
  console.log("=== Testing create_task ===\n");

  // Teste 1: Input válido
  console.log("Test 1: Valid input");
  const result1 = await handleCreateTask({
    title: "Review design mockups",
    priority: "high",
    due_date: "2026-03-15"
  });
  console.log(JSON.stringify(result1, null, 2));

  // Teste 2: Apenas required
  console.log("\nTest 2: Only required fields");
  const result2 = await handleCreateTask({ title: "Quick task" });
  console.log(JSON.stringify(result2, null, 2));

  // Teste 3: Input inválido
  console.log("\nTest 3: Invalid assignee");
  const result3 = await handleCreateTask({
    title: "Task with bad assignee",
    assignee_email: "notanemail"
  });
  console.log(JSON.stringify(result3, null, 2));
}

runTests().catch(console.error);
```

```bash
# Rodar teste
npx tsx test/test-tool.ts
```

### Teste via MCP Inspector (Anthropic)

```bash
# Instalar inspector
npx @modelcontextprotocol/inspector dist/index.js

# Abre UI no browser para testar tools interativamente
# URL: http://localhost:5173
```

### Configuração no Claude Desktop (validação final)

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "project-manager": {
      "command": "node",
      "args": ["/path/to/mcp-project-manager/dist/index.js"],
      "env": {
        "PROJECT_API_KEY": "your_key_here",
        "PROJECT_BASE_URL": "https://api.example.com/v1"
      }
    }
  }
}
```

---

## PADRÃO DE DESCRIPTION PARA TOOLS

A `description` é o que o LLM lê para decidir quando usar a tool. Siga este padrão:

```
[O que faz] + [quando usar] + [o que retorna]
```

**Ruim:**
```
"description": "Creates a task"
```

**Bom:**
```
"description": "Creates a new task in Linear. Use this when the user asks to add,
create, or track a task, action item, or to-do. Returns the task ID and URL.
If unsure about assignee or due date, create the task without them."
```
