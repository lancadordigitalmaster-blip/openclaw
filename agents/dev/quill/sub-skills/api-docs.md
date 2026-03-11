# api-docs.md — Quill Sub-Skill: Documentação de API
# Ativa quando: "API", "OpenAPI", "Swagger", "endpoints documentados"

## Propósito

API não documentada é API inutilizável por outros times. Documentação de API tem que ser precisa (bate com o código real) e útil (exemplos de request/response reais, não genéricos).

---

## OpenAPI 3.1 — Spec Padrão Wolf

```yaml
openapi: 3.1.0
info:
  title: Nome do Serviço API
  description: |
    Descrição do que essa API faz.
    Inclui casos de uso principais e público-alvo.
  version: 1.0.0
  contact:
    name: Wolf Engineering
    email: eng@wolf.agency

servers:
  - url: https://api.wolf.agency/v1
    description: Produção
  - url: https://api-staging.wolf.agency/v1
    description: Staging
  - url: http://localhost:3000/v1
    description: Local

security:
  - bearerAuth: []

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    Error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
          example: "VALIDATION_ERROR"
        message:
          type: string
          example: "Campo 'email' é obrigatório"
        details:
          type: array
          items:
            type: object

paths:
  /campaigns:
    get:
      summary: Lista campanhas
      description: |
        Retorna lista paginada de campanhas do account ativo.
        Filtragem por status e período disponível via query params.
      tags: [Campaigns]
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [ACTIVE, PAUSED, ARCHIVED]
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        '200':
          description: Lista de campanhas
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Campaign'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
              example:
                data:
                  - id: "camp_123"
                    name: "Black Friday 2024"
                    status: "ACTIVE"
                    budget: 5000.00
                pagination:
                  page: 1
                  limit: 20
                  total: 47
        '401':
          description: Token inválido ou expirado
          content:
            application/json:
              example:
                code: "UNAUTHORIZED"
                message: "Token expirado"
        '500':
          description: Erro interno
```

---

## Geração Automática de Docs

### Express + swagger-jsdoc

```bash
pnpm add swagger-jsdoc swagger-ui-express
```

```typescript
// src/lib/swagger.ts
import swaggerJsdoc from 'swagger-jsdoc';

const options = {
  definition: {
    openapi: '3.1.0',
    info: {
      title: 'Nome da API',
      version: '1.0.0',
    },
  },
  apis: ['./src/api/**/*.ts'], // arquivos com anotações JSDoc
};

export const swaggerSpec = swaggerJsdoc(options);
```

```typescript
// src/api/campaigns/campaigns.controller.ts

/**
 * @swagger
 * /campaigns:
 *   get:
 *     summary: Lista campanhas
 *     tags: [Campaigns]
 *     responses:
 *       200:
 *         description: Lista de campanhas
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/CampaignList'
 */
export async function listCampaigns(req: Request, res: Response) {
  // ...
}
```

```typescript
// src/app.ts — montar rota de docs
import { swaggerSpec } from './lib/swagger';

// Scalar UI (melhor que Swagger UI)
app.get('/api-docs/spec', (req, res) => res.json(swaggerSpec));
app.use('/api-docs', apiReference({ spec: { url: '/api-docs/spec' } }));
```

### FastAPI (automático)

FastAPI gera OpenAPI automaticamente. Sem configuração extra. Endpoint padrão: `/docs` (Swagger UI) e `/redoc`.

```python
# Customização mínima
from fastapi import FastAPI

app = FastAPI(
    title="Nome do Serviço",
    description="Descrição clara do serviço",
    version="1.0.0",
    docs_url="/api-docs",
    redoc_url=None,  # desabilita redoc se usar Scalar
)

@app.get("/campaigns", response_model=list[Campaign])
async def list_campaigns(
    status: CampaignStatus | None = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
):
    """
    Lista campanhas do account ativo.

    Suporta filtragem por status e paginação.
    Retorna no máximo 100 itens por página.
    """
    # ...
```

---

## Scalar UI — Visualização Wolf Padrão

Scalar é preferível ao Swagger UI: mais limpo, melhor UX, suporte a dark mode.

```bash
pnpm add @scalar/express-api-reference
```

```typescript
import { apiReference } from '@scalar/express-api-reference';

app.use('/docs', apiReference({
  spec: { url: '/api-spec.json' },
  theme: 'default',
  defaultHttpClient: {
    targetKey: 'javascript',
    clientKey: 'fetch',
  },
}));
```

---

## Campos Obrigatórios por Endpoint

Todo endpoint documentado precisa ter:

| Campo | Obrigatório | Exemplo |
|-------|-------------|---------|
| `summary` | Sim | "Cria campanha" |
| `description` | Sim | Comportamento, edge cases, limites |
| `tags` | Sim | Agrupamento lógico |
| `parameters` | Sim (se houver) | Descrição + tipo + exemplo |
| `requestBody` com schema | Sim (se POST/PUT) | Schema completo com exemplos |
| `responses.200` com exemplo | Sim | Response real, não placeholder |
| `responses.400` | Sim (se valida input) | Formato do erro |
| `responses.401` | Sim (se autenticado) | Token inválido/expirado |
| `responses.500` | Sim | Erro interno genérico |

---

## Manter Sincronizado com o Código

**Problema:** docs desatualizadas que mentem sobre o comportamento real da API.

**Protocolo Wolf:**

1. Schema da documentação = schema de validação (use `zod-to-openapi` ou `typebox`)
2. Testes de contrato validam que a API responde como documentado
3. CI falha se spec OpenAPI tiver erros de validação
4. Review de PR inclui verificar se mudança de endpoint atualizou a doc

```typescript
// Abordagem Wolf: schema único, valida e documenta
import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

const CreateCampaignSchema = z.object({
  name: z.string().min(1).max(255).openapi({ example: 'Black Friday 2024' }),
  budget: z.number().positive().openapi({ example: 5000.00 }),
  status: z.enum(['ACTIVE', 'PAUSED']).openapi({ example: 'ACTIVE' }),
}).openapi('CreateCampaign');

// Mesma schema para validação de request E para gerar OpenAPI spec
```

---

## Checklist de API Docs Completa

- [ ] Spec OpenAPI 3.1 válida (sem erros de lint)
- [ ] Todos os endpoints cobertos
- [ ] Cada endpoint tem summary + description
- [ ] Todos os campos de request documentados com tipos e exemplos
- [ ] Todos os response codes documentados
- [ ] Exemplos de response com dados reais (não "string", "number")
- [ ] Autenticação documentada em `components/securitySchemes`
- [ ] Scalar UI acessível em `/docs` (dev e staging)
- [ ] Spec disponível como JSON em `/api-spec.json`
- [ ] Schemas reutilizáveis em `components/schemas` (sem repetição)
- [ ] Erros padronizados usando schema `Error` compartilhado
