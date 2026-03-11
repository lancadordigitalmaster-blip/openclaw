# auth.md — Forge Sub-Skill: Authentication & Authorization
# Ativa quando: "autenticação", "auth", "JWT", "login", "sessão"

## JWT vs Session — Quando Usar

| Critério              | JWT (Stateless)                          | Session (Stateful)                        |
|-----------------------|------------------------------------------|-------------------------------------------|
| Escalabilidade        | Horizontal sem compartilhar estado       | Requer store compartilhado (Redis)        |
| Revogação imediata    | Difícil (requer blacklist)               | Simples (deletar sessão)                  |
| Performance           | Sem hit no banco por request             | Hit no Redis/banco por request            |
| Tamanho do token      | Maior (payload embedded)                 | Menor (apenas session ID)                 |
| Uso Wolf padrão       | APIs REST, microsserviços, mobile        | Apps server-side com logout crítico       |

**Decisão Wolf:** JWT com refresh token para APIs. Sessions para apps que precisam de revogação imediata.

## Providers Suportados

### Clerk (recomendado para SaaS rápido)
```typescript
import { clerkMiddleware, getAuth } from '@clerk/express'

app.use(clerkMiddleware())

app.get('/protected', (req, res) => {
  const { userId } = getAuth(req)
  if (!userId) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Not authenticated.' } })
  res.json({ data: { userId } })
})
```

### Auth.js / NextAuth (Next.js)
```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import GitHub from 'next-auth/providers/github'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [GitHub],
  callbacks: {
    async session({ session, token }) {
      session.user.id = token.sub!
      return session
    },
  },
})
```

### Supabase Auth
```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!)

// Verificar token no middleware
const { data: { user }, error } = await supabase.auth.getUser(token)
if (error || !user) {
  return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Invalid token.' } })
}
```

## Middleware authenticate() — Padrão Wolf

```typescript
// src/middleware/authenticate.ts
import { Request, Response, NextFunction } from 'express'
import jwt from 'jsonwebtoken'

export interface AuthenticatedUser {
  id: string
  email: string
  organizationId: string
  role: 'owner' | 'admin' | 'member'
}

declare global {
  namespace Express {
    interface Request {
      user: AuthenticatedUser
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      error: {
        code: 'UNAUTHENTICATED',
        message: 'Authentication required.',
      },
    })
    return
  }

  const token = authHeader.split(' ')[1]

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as AuthenticatedUser
    req.user = payload
    next()
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'Token has expired.',
        },
      })
      return
    }

    res.status(401).json({
      error: {
        code: 'INVALID_TOKEN',
        message: 'Invalid token.',
      },
    })
  }
}

// Middleware de autorização por role
export function authorize(...roles: AuthenticatedUser['role'][]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!roles.includes(req.user.role)) {
      res.status(403).json({
        error: {
          code: 'FORBIDDEN',
          message: 'Insufficient permissions.',
        },
      })
      return
    }
    next()
  }
}
```

## Refresh Tokens

```typescript
// src/services/auth.service.ts
import jwt from 'jsonwebtoken'
import { db } from '../lib/db'

const ACCESS_TOKEN_TTL = '15m'
const REFRESH_TOKEN_TTL = '30d'

export function generateTokens(user: AuthenticatedUser) {
  const accessToken = jwt.sign(
    { id: user.id, email: user.email, organizationId: user.organizationId, role: user.role },
    process.env.JWT_SECRET!,
    { expiresIn: ACCESS_TOKEN_TTL }
  )

  const refreshToken = jwt.sign(
    { id: user.id, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET!,
    { expiresIn: REFRESH_TOKEN_TTL }
  )

  return { accessToken, refreshToken }
}

export async function refreshAccessToken(refreshToken: string) {
  let payload: any

  try {
    payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!)
  } catch {
    throw new Error('INVALID_REFRESH_TOKEN')
  }

  // Verificar se refresh token não foi revogado
  const stored = await db.refreshToken.findUnique({ where: { token: refreshToken } })
  if (!stored || stored.revokedAt) {
    throw new Error('REVOKED_REFRESH_TOKEN')
  }

  const user = await db.user.findUnique({ where: { id: payload.id } })
  if (!user) throw new Error('USER_NOT_FOUND')

  return generateTokens(user)
}

// POST /auth/refresh
router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body
    if (!refreshToken) {
      return res.status(400).json({ error: { code: 'MISSING_TOKEN', message: 'Refresh token required.' } })
    }

    const tokens = await refreshAccessToken(refreshToken)
    res.json({ data: tokens })
  } catch (err: any) {
    res.status(401).json({ error: { code: err.message, message: 'Token refresh failed.' } })
  }
})
```

## Proteção de Rotas

```typescript
// Rota pública
router.post('/auth/login', loginHandler)
router.post('/auth/register', registerHandler)

// Rota autenticada
router.get('/profile', authenticate, profileHandler)

// Rota com role específico
router.delete('/users/:id', authenticate, authorize('owner', 'admin'), deleteUserHandler)

// Grupo de rotas protegidas
const protectedRouter = Router()
protectedRouter.use(authenticate)
protectedRouter.get('/dashboard', dashboardHandler)
protectedRouter.get('/analytics', analyticsHandler)
app.use('/api/v1', protectedRouter)
```

## Checklist de Implementação Auth

- [ ] JWT_SECRET e JWT_REFRESH_SECRET em variáveis de ambiente (mínimo 256 bits)
- [ ] Access token com TTL curto (15min)
- [ ] Refresh token armazenado no banco com possibilidade de revogação
- [ ] Middleware authenticate() aplicado em todas as rotas protegidas
- [ ] Middleware authorize() para controle de role
- [ ] Senhas hasheadas com bcrypt (salt rounds >= 12) ou argon2
- [ ] Rate limiting em endpoints de login/register
- [ ] Tokens não expostos em logs
- [ ] HTTPS obrigatório em produção
- [ ] Refresh token rotacionado a cada uso (evita replay attacks)

## Segurança — Regras Absolutas

```
NUNCA armazenar JWT em localStorage → usar httpOnly cookie ou memoria
NUNCA logar tokens em qualquer nível
NUNCA retornar hash de senha na resposta
NUNCA usar JWT_SECRET fraco (ex: "secret", "123456")
SEMPRE validar o payload do token antes de confiar nos dados
```
