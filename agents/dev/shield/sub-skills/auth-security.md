# auth-security.md — SHIELD Sub-Skill: Authentication Security
# Ativa quando: "autenticação", "JWT", "OAuth", "sessão", "token"

---

## JWT — Implementação Segura

### Algoritmo: HS256 vs RS256

| | HS256 | RS256 |
|-|-------|-------|
| Chave | Uma chave secreta compartilhada | Par de chaves pública/privada |
| Uso | Aplicações monolíticas, sem serviços terceiros | Microserviços, múltiplos consumers |
| Risco | Se a chave vaza, tudo está comprometido | Chave privada isolada, pública pode ser distribuída |
| Wolf default | Monolito simples | Microserviços / integrações externas |

### Configuração Segura de JWT

```typescript
import jwt from 'jsonwebtoken';

const JWT_CONFIG = {
  algorithm: 'HS256' as const,
  accessTokenExpiry: '15m',    // Curto — minimiza janela de comprometimento
  refreshTokenExpiry: '7d',    // Longo — mas rotacionado
};

// Geração de tokens
function generateTokens(userId: string, organizationId: string) {
  const payload = { userId, organizationId };

  const accessToken = jwt.sign(payload, process.env.JWT_SECRET!, {
    expiresIn: JWT_CONFIG.accessTokenExpiry,
    algorithm: JWT_CONFIG.algorithm,
    issuer: 'wolf-agency',
    audience: 'wolf-app',
  });

  const refreshToken = jwt.sign(
    { ...payload, tokenType: 'refresh' },
    process.env.JWT_REFRESH_SECRET!,
    {
      expiresIn: JWT_CONFIG.refreshTokenExpiry,
      algorithm: JWT_CONFIG.algorithm,
    }
  );

  return { accessToken, refreshToken };
}

// Validação com verificação completa
function verifyAccessToken(token: string): jwt.JwtPayload {
  return jwt.verify(token, process.env.JWT_SECRET!, {
    algorithms: [JWT_CONFIG.algorithm],
    issuer: 'wolf-agency',
    audience: 'wolf-app',
  }) as jwt.JwtPayload;
}
```

### Refresh Token Rotation

```typescript
// Banco de dados de refresh tokens válidos
interface RefreshTokenRecord {
  tokenHash: string;      // Nunca armazenar o token em plain text
  userId: string;
  expiresAt: Date;
  usedAt: Date | null;    // Detecta reutilização
}

import crypto from 'crypto';

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function rotateRefreshToken(oldRefreshToken: string) {
  const tokenHash = hashToken(oldRefreshToken);
  const record = await db.refreshTokens.findOne({ tokenHash });

  if (!record) {
    throw new Error('Refresh token inválido');
  }

  // Token reusado = possível comprometimento
  if (record.usedAt !== null) {
    // Invalidar TODOS os tokens do usuário (família comprometida)
    await db.refreshTokens.deleteMany({ userId: record.userId });
    throw new Error('Reuse detected — all sessions invalidated');
  }

  if (record.expiresAt < new Date()) {
    throw new Error('Refresh token expirado');
  }

  // Marcar como usado
  await db.refreshTokens.update({ tokenHash }, { usedAt: new Date() });

  // Gerar novo par de tokens
  const { accessToken, refreshToken } = generateTokens(record.userId, record.organizationId);

  // Salvar novo refresh token
  await db.refreshTokens.create({
    tokenHash: hashToken(refreshToken),
    userId: record.userId,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    usedAt: null,
  });

  return { accessToken, refreshToken };
}
```

---

## Armazenamento Seguro de Tokens

### httpOnly Cookie vs localStorage

| | httpOnly Cookie | localStorage |
|-|----------------|-------------|
| Acesso via JS | Não (imune a XSS) | Sim (vulnerável a XSS) |
| CSRF | Vulnerável (mitigar com SameSite + CSRF token) | Imune |
| Subdomínios | Controlável via domain | Isolado por origem |
| Wolf padrão | **Usar para tokens** | Nunca para tokens sensíveis |

```typescript
// Configuração de cookie seguro
res.cookie('accessToken', accessToken, {
  httpOnly: true,           // JavaScript não acessa
  secure: true,             // Apenas HTTPS
  sameSite: 'strict',       // Proteção contra CSRF
  maxAge: 15 * 60 * 1000,  // 15 minutos (em ms)
  path: '/',
});

res.cookie('refreshToken', refreshToken, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  maxAge: 7 * 24 * 60 * 60 * 1000,  // 7 dias
  path: '/auth/refresh',             // Escopo limitado
});
```

---

## OAuth 2.0 Flow

### Authorization Code Flow (mais seguro)

```
1. App → Redirect para: /oauth/authorize?client_id=X&redirect_uri=Y&scope=Z&state=RANDOM
2. Usuário autentica e aprova
3. Provedor → Redirect para: /callback?code=AUTH_CODE&state=RANDOM
4. App verifica state (anti-CSRF)
5. App → POST /oauth/token com code → recebe access_token + refresh_token
6. App usa access_token para chamadas de API
```

```typescript
import crypto from 'crypto';

// Gerar state único para proteção CSRF no OAuth
function generateOAuthState(): string {
  return crypto.randomBytes(32).toString('hex');
}

// Iniciar flow OAuth
app.get('/auth/google', (req, res) => {
  const state = generateOAuthState();
  req.session.oauthState = state;  // Armazenar na sessão

  const params = new URLSearchParams({
    client_id: process.env.GOOGLE_CLIENT_ID!,
    redirect_uri: process.env.GOOGLE_REDIRECT_URI!,
    scope: 'openid email profile',
    response_type: 'code',
    state,
    access_type: 'offline',    // Para receber refresh_token
    prompt: 'consent',
  });

  res.redirect(`https://accounts.google.com/o/oauth2/auth?${params}`);
});

// Callback OAuth
app.get('/auth/google/callback', async (req, res) => {
  const { code, state } = req.query;

  // Verificar state — proteção CSRF
  if (state !== req.session.oauthState) {
    return res.status(400).json({ error: 'State mismatch — possible CSRF' });
  }

  // Trocar code por tokens
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      code: code as string,
      client_id: process.env.GOOGLE_CLIENT_ID!,
      client_secret: process.env.GOOGLE_CLIENT_SECRET!,
      redirect_uri: process.env.GOOGLE_REDIRECT_URI!,
      grant_type: 'authorization_code',
    }),
  });

  const tokens = await tokenResponse.json();
  // ... processar tokens e criar sessão
});
```

---

## Rate Limiting em Auth

```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';

// Login — por IP
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutos
  max: 5,
  store: new RedisStore({ client: redisClient }),
  keyGenerator: (req) => req.ip,
  message: { error: 'Muitas tentativas de login. Aguarde 15 minutos.' },
  standardHeaders: true,
});

// Login — por e-mail (evita distributed brute force)
const loginByEmailLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hora
  max: 10,
  keyGenerator: (req) => req.body.email?.toLowerCase() || req.ip,
});

// Password reset — muito restrito
const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hora
  max: 3,
  keyGenerator: (req) => req.body.email?.toLowerCase() || req.ip,
});

app.post('/auth/login', loginLimiter, loginByEmailLimiter, handleLogin);
app.post('/auth/reset-password', passwordResetLimiter, handlePasswordReset);
```

---

## Logout que Realmente Invalida Token

```typescript
// Problema: JWT stateless — revogar é impossível sem blacklist

// Solução 1: Blacklist de tokens (Redis)
const BLACKLIST_PREFIX = 'jwt_blacklist:';

async function logout(req: Request, res: Response) {
  const token = req.cookies.accessToken;

  if (token) {
    // Decodificar para pegar expiração
    const decoded = jwt.decode(token) as jwt.JwtPayload;
    const ttl = (decoded.exp || 0) - Math.floor(Date.now() / 1000);

    if (ttl > 0) {
      // Adicionar ao blacklist até expirar
      await redis.setex(`${BLACKLIST_PREFIX}${hashToken(token)}`, ttl, '1');
    }
  }

  // Invalidar refresh tokens no banco
  await db.refreshTokens.deleteMany({ userId: req.user.userId });

  // Limpar cookies
  res.clearCookie('accessToken');
  res.clearCookie('refreshToken');

  res.json({ message: 'Logout realizado' });
}

// Middleware que verifica blacklist
async function checkBlacklist(req: Request, res: Response, next: NextFunction) {
  const token = req.cookies.accessToken;
  if (!token) return next();

  const isBlacklisted = await redis.exists(`${BLACKLIST_PREFIX}${hashToken(token)}`);
  if (isBlacklisted) {
    return res.status(401).json({ error: 'Token inválido' });
  }

  next();
}
```

---

## Checklist Auth Security

- [ ] JWT com expiração curta (access token max 15-30min)
- [ ] Refresh token rotation implementado com detecção de reutilização
- [ ] Tokens armazenados em httpOnly cookies (não localStorage)
- [ ] Cookies com flags Secure, SameSite=Strict
- [ ] Rate limiting em login (por IP e por e-mail)
- [ ] OAuth state validado no callback (anti-CSRF)
- [ ] Logout invalida tokens no servidor (blacklist ou DB)
- [ ] Passwords hasheados com bcrypt (rounds >= 12)
- [ ] MFA disponível para contas com acesso a dados de clientes
- [ ] Tokens de serviço com escopo mínimo e rotação periódica
