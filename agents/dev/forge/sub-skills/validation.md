# validation.md — Forge Sub-Skill: Validation & Sanitization
# Ativa quando: "validação", "sanitização", "schema", "input"

## Padrão Wolf: Zod em Tudo

Zod é o validador padrão Wolf Agency. Typescript-first, runtime validation, inferência de tipos automática.

```bash
npm install zod
```

**Regra absoluta:** nenhum dado externo (body, params, query, headers, env vars, webhook payload) entra no sistema sem passar por um schema Zod.

## Middleware de Validação

```typescript
// src/middleware/validate.ts
import { Request, Response, NextFunction } from 'express'
import { ZodSchema, ZodError } from 'zod'

export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body)

    if (!result.success) {
      res.status(422).json(formatZodError(result.error))
      return
    }

    req.body = result.data // dados parseados e tipados
    next()
  }
}

export function validateQuery(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.query)

    if (!result.success) {
      res.status(422).json(formatZodError(result.error))
      return
    }

    req.query = result.data
    next()
  }
}

export function validateParams(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.params)

    if (!result.success) {
      res.status(422).json(formatZodError(result.error))
      return
    }

    req.params = result.data
    next()
  }
}

function formatZodError(error: ZodError) {
  return {
    error: {
      code: 'VALIDATION_ERROR',
      message: 'Invalid input.',
      details: error.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    },
  }
}
```

## Schemas Zod Complexos

### Criação de Campanha

```typescript
// src/schemas/campaign.schema.ts
import { z } from 'zod'

const DateStringSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use format YYYY-MM-DD')

export const CreateCampaignSchema = z.object({
  name: z
    .string()
    .min(1, 'Name is required.')
    .max(255, 'Name must be 255 characters or less.')
    .trim(),
  platform: z.enum(['meta', 'google', 'tiktok', 'linkedin']),
  objective: z.enum(['awareness', 'traffic', 'leads', 'conversions', 'sales']),
  budget: z.object({
    type: z.enum(['daily', 'lifetime']),
    amount: z.number().positive('Budget must be positive.').max(1_000_000),
    currency: z.string().length(3, 'Currency must be ISO 4217 (e.g., BRL, USD)').toUpperCase(),
  }),
  schedule: z
    .object({
      startDate: DateStringSchema,
      endDate: DateStringSchema.optional(),
    })
    .refine(
      (data) => {
        if (!data.endDate) return true
        return new Date(data.endDate) > new Date(data.startDate)
      },
      { message: 'End date must be after start date.', path: ['endDate'] }
    ),
  targetAudience: z
    .object({
      ageMin: z.number().int().min(18).max(65).optional(),
      ageMax: z.number().int().min(18).max(65).optional(),
      locations: z.array(z.string()).min(1, 'At least one location required.'),
      interests: z.array(z.string()).max(50).optional(),
    })
    .refine(
      (data) => {
        if (!data.ageMin || !data.ageMax) return true
        return data.ageMax > data.ageMin
      },
      { message: 'Age max must be greater than age min.', path: ['ageMax'] }
    ),
  tags: z.array(z.string().max(50)).max(20).default([]),
})

export const UpdateCampaignSchema = CreateCampaignSchema.partial()

export const CampaignQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  status: z.enum(['active', 'paused', 'completed', 'draft']).optional(),
  platform: z.enum(['meta', 'google', 'tiktok', 'linkedin']).optional(),
  search: z.string().max(100).optional(),
})

export type CreateCampaignInput = z.infer<typeof CreateCampaignSchema>
export type UpdateCampaignInput = z.infer<typeof UpdateCampaignSchema>
export type CampaignQuery = z.infer<typeof CampaignQuerySchema>
```

### Usuário com Senha

```typescript
// src/schemas/auth.schema.ts
import { z } from 'zod'

export const RegisterSchema = z
  .object({
    name: z.string().min(2).max(100).trim(),
    email: z.string().email('Invalid email address.').toLowerCase(),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters.')
      .regex(/[A-Z]/, 'Password must contain at least one uppercase letter.')
      .regex(/[0-9]/, 'Password must contain at least one number.'),
    confirmPassword: z.string(),
    organizationName: z.string().min(2).max(255).trim(),
    plan: z.enum(['starter', 'professional', 'enterprise']).default('starter'),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'Passwords do not match.',
    path: ['confirmPassword'],
  })

export const LoginSchema = z.object({
  email: z.string().email().toLowerCase(),
  password: z.string().min(1, 'Password is required.'),
})

export type RegisterInput = z.infer<typeof RegisterSchema>
export type LoginInput = z.infer<typeof LoginSchema>
```

### Webhook Payload

```typescript
// src/schemas/webhook.schema.ts
import { z } from 'zod'

// Meta Ads webhook
export const MetaWebhookSchema = z.object({
  object: z.literal('ad_account'),
  entry: z.array(
    z.object({
      id: z.string(),
      time: z.number(),
      changes: z.array(
        z.object({
          value: z.object({
            ad_id: z.string().optional(),
            campaign_id: z.string().optional(),
            event_type: z.string(),
          }),
          field: z.string(),
        })
      ),
    })
  ),
})

// Evolution API webhook
export const EvolutionWebhookSchema = z.discriminatedUnion('event', [
  z.object({
    event: z.literal('messages.upsert'),
    instance: z.string(),
    data: z.object({
      key: z.object({
        remoteJid: z.string(),
        fromMe: z.boolean(),
        id: z.string(),
      }),
      message: z.object({
        conversation: z.string().optional(),
        extendedTextMessage: z.object({ text: z.string() }).optional(),
      }),
    }),
  }),
  z.object({
    event: z.literal('connection.update'),
    instance: z.string(),
    data: z.object({
      state: z.enum(['open', 'close', 'connecting']),
    }),
  }),
])
```

## Validação de Variáveis de Ambiente

```typescript
// src/lib/env.ts — validar na inicialização, falhar rápido se inválido
import { z } from 'zod'

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters.'),
  JWT_REFRESH_SECRET: z.string().min(32),
  META_APP_SECRET: z.string().optional(),
  EVOLUTION_API_URL: z.string().url().optional(),
  EVOLUTION_API_KEY: z.string().optional(),
})

const result = EnvSchema.safeParse(process.env)

if (!result.success) {
  console.error('[ENV] Invalid environment variables:', result.error.flatten().fieldErrors)
  process.exit(1)
}

export const env = result.data
export type Env = z.infer<typeof EnvSchema>
```

## Sanitização de Dados Sensíveis

```typescript
// src/lib/sanitize.ts

const SENSITIVE_FIELDS = new Set([
  'password',
  'confirmPassword',
  'accessToken',
  'refreshToken',
  'apiKey',
  'secret',
  'token',
  'creditCard',
  'cvv',
])

export function sanitizeForLogging(data: Record<string, any>): Record<string, any> {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => {
      if (SENSITIVE_FIELDS.has(key)) return [key, '[REDACTED]']
      if (typeof value === 'object' && value !== null) return [key, sanitizeForLogging(value)]
      return [key, value]
    })
  )
}

// Uso:
console.info('[AUTH] Login attempt', sanitizeForLogging(req.body))
// Output: { email: 'user@example.com', password: '[REDACTED]' }

// Remover campos antes de retornar ao client
export function stripSensitiveFields<T extends Record<string, any>>(
  obj: T,
  fields: (keyof T)[]
): Omit<T, (typeof fields)[number]> {
  const result = { ...obj }
  for (const field of fields) {
    delete result[field]
  }
  return result
}

// Uso:
const user = await db.user.findUnique({ where: { id } })
return stripSensitiveFields(user, ['passwordHash', 'resetToken'])
```

## Uso no Router

```typescript
import { validateBody, validateQuery, validateParams } from '../middleware/validate'
import { CreateCampaignSchema, CampaignQuerySchema } from '../schemas/campaign.schema'
import { z } from 'zod'

const ParamsSchema = z.object({
  id: z.string().uuid('Invalid campaign ID.'),
})

router.get(
  '/',
  authenticate,
  validateQuery(CampaignQuerySchema),
  listCampaignsHandler
)

router.post(
  '/',
  authenticate,
  validateBody(CreateCampaignSchema),
  createCampaignHandler
)

router.patch(
  '/:id',
  authenticate,
  validateParams(ParamsSchema),
  validateBody(UpdateCampaignSchema),
  updateCampaignHandler
)
```

## Checklist de Validação

- [ ] Schema Zod definido antes de implementar o handler
- [ ] Todos os campos com mensagens de erro em inglês e descritivas
- [ ] Tipos TypeScript inferidos do schema (`z.infer<typeof Schema>`)
- [ ] Query params com `z.coerce` para conversão de string → número/boolean
- [ ] Dados sensíveis sanitizados antes de qualquer log
- [ ] Variáveis de ambiente validadas na inicialização da aplicação
- [ ] Schemas exportados e reutilizados (não duplicar)
- [ ] Erros retornados com status 422 e detalhes por campo
