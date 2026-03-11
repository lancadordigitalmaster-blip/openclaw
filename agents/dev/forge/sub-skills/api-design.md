# api-design.md — Forge Sub-Skill: API Design
# Ativa quando: "endpoint", "rota", "API", "REST", "route"

## Princípios REST Wolf Agency

**Recursos, não ações.** A URL identifica o recurso. O verbo HTTP define a ação.

```
ERRADO:  POST /createUser
CORRETO: POST /users

ERRADO:  GET /getUserById/123
CORRETO: GET /users/123

ERRADO:  POST /sendMessage
CORRETO: POST /conversations/:id/messages
```

**Hierarquia de recursos:**
```
/campaigns                        → coleção
/campaigns/:id                    → recurso único
/campaigns/:id/ads                → sub-recurso
/campaigns/:id/ads/:adId          → sub-recurso único
```

## HTTP Verbs Corretos

| Verbo    | Uso                                      | Body | Idempotente |
|----------|------------------------------------------|------|-------------|
| GET      | Ler recurso(s)                           | Não  | Sim         |
| POST     | Criar recurso                            | Sim  | Não         |
| PUT      | Substituir recurso inteiro               | Sim  | Sim         |
| PATCH    | Atualizar campos específicos             | Sim  | Não         |
| DELETE   | Remover recurso                          | Não  | Sim         |

## Padrão de Resposta Wolf

**Sucesso:**
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2026-03-04T12:00:00Z",
    "version": "1.0"
  }
}
```

**Sucesso com paginação:**
```json
{
  "data": [ ... ],
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 142,
      "pages": 8
    },
    "timestamp": "2026-03-04T12:00:00Z"
  }
}
```

**Erro:**
```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Campaign not found.",
    "details": []
  }
}
```

**Erro de validação (422):**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input.",
    "details": [
      { "field": "name", "message": "Name is required." },
      { "field": "budget", "message": "Budget must be a positive number." }
    ]
  }
}
```

## Status Codes Wolf

| Code | Quando usar                                                    |
|------|----------------------------------------------------------------|
| 200  | Leitura ou update bem-sucedido                                 |
| 201  | Criação bem-sucedida (POST)                                    |
| 204  | Delete bem-sucedido (sem body)                                 |
| 400  | Request malformada (JSON inválido, parâmetro faltando)         |
| 401  | Não autenticado (token ausente ou inválido)                    |
| 403  | Autenticado mas sem permissão                                  |
| 404  | Recurso não encontrado                                         |
| 409  | Conflito (email duplicado, estado inválido para operação)      |
| 422  | Dados semanticamente inválidos (falhou validação de negócio)   |
| 429  | Rate limit excedido                                            |
| 500  | Erro interno do servidor                                       |

## Checklist de Novo Endpoint

- [ ] URL segue padrão de recurso (não ação)
- [ ] Verbo HTTP correto para a operação
- [ ] Autenticação/autorização aplicada
- [ ] Validação de input com Zod
- [ ] Status code correto no retorno
- [ ] Resposta no formato Wolf `{ data, meta }` ou `{ error }`
- [ ] Paginação implementada se retorna lista
- [ ] Rate limiting configurado se exposto publicamente
- [ ] Testes de happy path e erros escritos
- [ ] Documentado no Swagger/OpenAPI ou README de rotas

## Exemplo Completo — Express/Hono

### Express (TypeScript)

```typescript
import { Router, Request, Response, NextFunction } from 'express'
import { z } from 'zod'
import { authenticate } from '../middleware/authenticate'
import { validateBody } from '../middleware/validate'
import { CampaignService } from '../services/campaign.service'
import { NotFoundError } from '../errors'

const router = Router()

const CreateCampaignSchema = z.object({
  name: z.string().min(1).max(255),
  budget: z.number().positive(),
  startDate: z.string().datetime(),
  platform: z.enum(['meta', 'google', 'tiktok']),
})

// GET /campaigns
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = Number(req.query.page) || 1
    const limit = Math.min(Number(req.query.limit) || 20, 100)

    const { campaigns, total } = await CampaignService.list({
      organizationId: req.user.organizationId,
      page,
      limit,
    })

    res.status(200).json({
      data: campaigns,
      meta: {
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
        timestamp: new Date().toISOString(),
      },
    })
  } catch (err) {
    next(err)
  }
})

// GET /campaigns/:id
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const campaign = await CampaignService.findById(req.params.id, req.user.organizationId)

    if (!campaign) {
      throw new NotFoundError('Campaign not found.')
    }

    res.status(200).json({
      data: campaign,
      meta: { timestamp: new Date().toISOString() },
    })
  } catch (err) {
    next(err)
  }
})

// POST /campaigns
router.post(
  '/',
  authenticate,
  validateBody(CreateCampaignSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const campaign = await CampaignService.create({
        ...req.body,
        organizationId: req.user.organizationId,
      })

      res.status(201).json({
        data: campaign,
        meta: { timestamp: new Date().toISOString() },
      })
    } catch (err) {
      next(err)
    }
  }
)

// PATCH /campaigns/:id
router.patch('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const campaign = await CampaignService.update(req.params.id, req.user.organizationId, req.body)

    if (!campaign) {
      throw new NotFoundError('Campaign not found.')
    }

    res.status(200).json({
      data: campaign,
      meta: { timestamp: new Date().toISOString() },
    })
  } catch (err) {
    next(err)
  }
})

// DELETE /campaigns/:id
router.delete('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    await CampaignService.delete(req.params.id, req.user.organizationId)
    res.status(204).send()
  } catch (err) {
    next(err)
  }
})

export default router
```

### Hono (TypeScript — Edge/Cloudflare Workers)

```typescript
import { Hono } from 'hono'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

const CreateCampaignSchema = z.object({
  name: z.string().min(1),
  budget: z.number().positive(),
  platform: z.enum(['meta', 'google', 'tiktok']),
})

app.get('/campaigns', async (c) => {
  const campaigns = await CampaignService.list()
  return c.json({ data: campaigns, meta: { timestamp: new Date().toISOString() } })
})

app.post(
  '/campaigns',
  zValidator('json', CreateCampaignSchema),
  async (c) => {
    const body = c.req.valid('json')
    const campaign = await CampaignService.create(body)
    return c.json({ data: campaign, meta: { timestamp: new Date().toISOString() } }, 201)
  }
)

export default app
```

## Convenções Adicionais

- Sempre versionar a API: `/api/v1/...`
- Nomes de recursos em **plural** e **kebab-case**: `/ad-accounts`, `/campaign-groups`
- Query params para filtros e paginação: `?status=active&page=2&limit=20`
- Nunca colocar informações sensíveis na URL (tokens, senhas)
- Headers de resposta: sempre incluir `Content-Type: application/json`
