# error-handling.md — Forge Sub-Skill: Error Handling
# Ativa quando: "erro", "tratamento", "exception", "middleware"

## Classes de Erro Customizadas

```typescript
// src/errors/index.ts
export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details: Array<{ field?: string; message: string }> = []
  ) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor)
  }
}

export class ValidationError extends AppError {
  constructor(details: Array<{ field: string; message: string }>) {
    super(422, 'VALIDATION_ERROR', 'Invalid input.', details)
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found.') {
    super(404, 'RESOURCE_NOT_FOUND', message)
  }
}

export class AuthError extends AppError {
  constructor(code = 'UNAUTHENTICATED', message = 'Authentication required.') {
    super(401, code, message)
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions.') {
    super(403, 'FORBIDDEN', message)
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(409, 'CONFLICT', message)
  }
}

export class RateLimitError extends AppError {
  constructor(message = 'Too many requests. Try again later.') {
    super(429, 'RATE_LIMIT_EXCEEDED', message)
  }
}

export class ExternalServiceError extends AppError {
  constructor(service: string, message?: string) {
    super(502, 'EXTERNAL_SERVICE_ERROR', message ?? `External service error: ${service}`)
  }
}
```

## Error Handler Global — Express

```typescript
// src/middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express'
import { ZodError } from 'zod'
import { Prisma } from '@prisma/client'
import { AppError, ValidationError, ConflictError, NotFoundError } from '../errors'
import { logger } from '../lib/logger'

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction // eslint-disable-line @typescript-eslint/no-unused-vars
): void {
  // 1. Erro de validação Zod (não tratado pelo middleware validate)
  if (err instanceof ZodError) {
    const validationError = new ValidationError(
      err.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      }))
    )
    res.status(422).json(formatError(validationError))
    return
  }

  // 2. Erros do Prisma — mapear para erros de negócio
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    const mapped = mapPrismaError(err)
    logger.warn('[ERROR_HANDLER] Prisma error', {
      code: err.code,
      meta: err.meta,
      url: req.url,
    })
    res.status(mapped.statusCode).json(formatError(mapped))
    return
  }

  // 3. Erros da aplicação (AppError e subclasses)
  if (err instanceof AppError) {
    const level = err.statusCode >= 500 ? 'error' : 'warn'
    logger[level](`[ERROR_HANDLER] ${err.code}`, {
      message: err.message,
      statusCode: err.statusCode,
      url: req.url,
      method: req.method,
      userId: req.user?.id,
    })
    res.status(err.statusCode).json(formatError(err))
    return
  }

  // 4. Erro inesperado — logar stack trace, nunca expor em produção
  logger.error('[ERROR_HANDLER] Unhandled error', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    userId: req.user?.id,
  })

  res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message:
        process.env.NODE_ENV === 'production'
          ? 'An internal error occurred.'
          : err.message,
      details: [],
    },
  })
}

function formatError(err: AppError) {
  return {
    error: {
      code: err.code,
      message: err.message,
      details: err.details,
    },
  }
}

function mapPrismaError(err: Prisma.PrismaClientKnownRequestError): AppError {
  switch (err.code) {
    case 'P2002': {
      const fields = (err.meta?.target as string[]) ?? []
      return new ConflictError(`${fields.join(', ')} already exists.`)
    }
    case 'P2025':
      return new NotFoundError('Record not found.')
    case 'P2003':
      return new AppError(400, 'FOREIGN_KEY_VIOLATION', 'Referenced record does not exist.')
    default:
      return new AppError(500, 'DATABASE_ERROR', 'Database operation failed.')
  }
}
```

## Error Handler Global — Fastify

```typescript
// src/plugins/error-handler.ts (Fastify)
import { FastifyInstance, FastifyError } from 'fastify'
import { ZodError } from 'zod'
import { AppError } from '../errors'
import { logger } from '../lib/logger'

export async function errorHandlerPlugin(app: FastifyInstance): Promise<void> {
  app.setErrorHandler((err, request, reply) => {
    if (err instanceof ZodError) {
      return reply.status(422).send({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid input.',
          details: err.errors.map((e) => ({
            field: e.path.join('.'),
            message: e.message,
          })),
        },
      })
    }

    if (err instanceof AppError) {
      return reply.status(err.statusCode).send({
        error: { code: err.code, message: err.message, details: err.details },
      })
    }

    logger.error('[ERROR_HANDLER] Unhandled', {
      error: err.message,
      stack: err.stack,
      url: request.url,
    })

    return reply.status(500).send({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: process.env.NODE_ENV === 'production' ? 'An internal error occurred.' : err.message,
        details: [],
      },
    })
  })
}
```

## Logger Estruturado

```typescript
// src/lib/logger.ts
type LogLevel = 'debug' | 'info' | 'warn' | 'error'

interface LogEntry {
  level: LogLevel
  message: string
  timestamp: string
  [key: string]: any
}

function log(level: LogLevel, message: string, context?: Record<string, any>): void {
  const entry: LogEntry = {
    level,
    message,
    timestamp: new Date().toISOString(),
    env: process.env.NODE_ENV,
    ...context,
  }

  // NUNCA logar stack trace em produção
  if (process.env.NODE_ENV === 'production' && entry.stack) {
    delete entry.stack
  }

  const output = JSON.stringify(entry)

  if (level === 'error') {
    process.stderr.write(output + '\n')
  } else {
    process.stdout.write(output + '\n')
  }
}

export const logger = {
  debug: (message: string, context?: Record<string, any>) => log('debug', message, context),
  info: (message: string, context?: Record<string, any>) => log('info', message, context),
  warn: (message: string, context?: Record<string, any>) => log('warn', message, context),
  error: (message: string, context?: Record<string, any>) => log('error', message, context),
}
```

## Registro do Error Handler

```typescript
// src/app.ts
import express from 'express'
import { errorHandler } from './middleware/error-handler'

const app = express()

app.use(express.json())
app.use('/api/v1/campaigns', campaignRoutes)
app.use('/api/v1/auth', authRoutes)

// DEVE ser o último middleware registrado
app.use(errorHandler)

export default app
```

## Tratamento Assíncrono — Wrapper

```typescript
// src/lib/async-handler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express'

// Evitar try/catch repetido em cada handler
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
): RequestHandler {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}

// Uso:
router.get(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const campaign = await CampaignService.findById(req.params.id)
    if (!campaign) throw new NotFoundError('Campaign not found.')
    res.json({ data: campaign })
  })
)
```

## Regras Absolutas — Error Handling

```
NUNCA expor stack trace em produção
NUNCA retornar mensagens de erro do banco de dados diretamente
NUNCA silenciar erros com catch vazio: catch(e) {}
NUNCA usar console.log para erros — usar logger.error com contexto
SEMPRE registrar o error handler como ÚLTIMO middleware no Express
SEMPRE mapear erros de bibliotecas externas para AppError antes de relançar
SEMPRE logar userId, método e URL junto com o erro para facilitar debug
```

## Checklist de Error Handling

- [ ] Error handler global registrado como último middleware
- [ ] Classes de erro customizadas cobrindo casos de negócio
- [ ] Erros do Prisma/banco mapeados para erros de negócio
- [ ] Stack trace nunca exposto em produção
- [ ] Logs estruturados com contexto (userId, url, method)
- [ ] `asyncHandler` wrapper em todos os handlers async
- [ ] Erros de validação retornando 422 com detalhes por campo
- [ ] Erros 5xx alertando via sistema de monitoramento
