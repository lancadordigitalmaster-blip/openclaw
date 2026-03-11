# oauth.md — Bridge Sub-Skill: OAuth 2.0 e Autorização
# Ativa quando: "OAuth", "autorização", "login com Google", "token"

## Propósito

Implementar OAuth 2.0 corretamente para integrações Wolf com Google (Drive, Sheets, Ads), Meta (Ads API) e outros providers. Token mal armazenado = brecha de segurança. Flow errado = autenticação quebrada.

---

## OAuth 2.0 Flows — Quando Usar Qual

| Situação | Flow | Por quê |
|----------|------|---------|
| Web app com backend (server-side) | Authorization Code | Seguro: troca código por token no backend |
| SPA React / Mobile app | PKCE | Sem client_secret exposto; proof key valida a troca |
| Server-to-server (sem usuário) | Client Credentials | Machine-to-machine direto |
| Acesso a dados do próprio app | Service Account | Google específico; sem consentimento de usuário |

---

## Authorization Code Flow (Web Apps Wolf)

```typescript
// 1. Redirecionar usuário para provider
const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
authUrl.searchParams.set('client_id', process.env.GOOGLE_CLIENT_ID);
authUrl.searchParams.set('redirect_uri', process.env.GOOGLE_REDIRECT_URI);
authUrl.searchParams.set('response_type', 'code');
authUrl.searchParams.set('scope', 'https://www.googleapis.com/auth/adwords openid email');
authUrl.searchParams.set('access_type', 'offline');  // Recebe refresh_token
authUrl.searchParams.set('prompt', 'consent');        // Força reexibição para refresh_token
authUrl.searchParams.set('state', generateSecureState(userId)); // CSRF protection

res.redirect(authUrl.toString());

// 2. Callback: trocar código por tokens (no BACKEND)
async function handleOAuthCallback(code: string, state: string) {
  // Validar state antes de qualquer coisa (CSRF protection)
  const userId = validateAndConsumeState(state);
  if (!userId) throw new Error('Invalid OAuth state');

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.GOOGLE_CLIENT_SECRET,
      redirect_uri: process.env.GOOGLE_REDIRECT_URI,
      grant_type: 'authorization_code',
    }),
  });

  const tokens = await tokenResponse.json();
  // tokens.access_token  — expira em 1 hora
  // tokens.refresh_token — longa duração (armazenar encriptado)
  // tokens.expires_in    — segundos até expirar

  await storeTokens(userId, tokens);
}
```

---

## PKCE Flow (SPAs e Mobile)

```typescript
// 1. Gerar code_verifier e code_challenge
import { createHash, randomBytes } from 'crypto';

function generatePKCE() {
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256')
    .update(verifier)
    .digest('base64url');
  return { verifier, challenge };
}

// No frontend (SPA)
const { verifier, challenge } = generatePKCE();
sessionStorage.setItem('pkce_verifier', verifier); // temporário, só para a troca

const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
authUrl.searchParams.set('code_challenge', challenge);
authUrl.searchParams.set('code_challenge_method', 'S256');
// ... outros params

// 2. No callback: usar verifier para trocar código
const verifier = sessionStorage.getItem('pkce_verifier');
sessionStorage.removeItem('pkce_verifier');

// Trocar código no backend (passar verifier para o backend via POST seguro)
await api.post('/auth/callback', { code, verifier });
```

---

## Google OAuth Wolf — Configuração por Produto

### Google Ads API

```typescript
const GOOGLE_ADS_SCOPES = [
  'https://www.googleapis.com/auth/adwords',
];

// Requer: Developer Token (obtido no Google Ads UI)
// Headers obrigatórios em toda chamada:
const headers = {
  'Authorization': `Bearer ${accessToken}`,
  'developer-token': process.env.GOOGLE_ADS_DEVELOPER_TOKEN,
  'login-customer-id': managerId, // MCC account ID
};
```

### Google Sheets / Drive

```typescript
const GOOGLE_SHEETS_SCOPES = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.file', // só arquivos criados pelo app
];
```

### GA4 / Search Console (leitura)

```typescript
const GOOGLE_ANALYTICS_SCOPES = [
  'https://www.googleapis.com/auth/analytics.readonly',
  'https://www.googleapis.com/auth/webmasters.readonly',
];
```

---

## Meta OAuth (Ads API)

```typescript
// 1. Token de curta duração (1-2 horas)
// Obtido via login button ou Graph API Explorer

// 2. Trocar por token de longa duração (60 dias)
const response = await fetch(
  `https://graph.facebook.com/v19.0/oauth/access_token?` +
  `grant_type=fb_exchange_token&` +
  `client_id=${process.env.META_APP_ID}&` +
  `client_secret=${process.env.META_APP_SECRET}&` +
  `fb_exchange_token=${shortLivedToken}`
);
const { access_token, expires_in } = await response.json();

// 3. Scopes necessários para Ads API
const META_ADS_SCOPES = [
  'ads_read',           // Ler dados de campanhas
  'ads_management',     // Criar/editar campanhas
  'business_management', // Gerenciar Business Manager
  'read_insights',      // Acessar insights
];
```

---

## Token Storage — Regras Wolf

| Token | Onde Guardar | Por quê |
|-------|-------------|---------|
| `access_token` | Memória (servidor) ou cookie httpOnly | Nunca localStorage |
| `refresh_token` | Banco encriptado (AES-256) | Alta sensibilidade |
| `state` OAuth | Session server-side ou Redis (TTL 10min) | Anti-CSRF, descartado após uso |

```typescript
// Armazenar refresh_token encriptado
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ENCRYPTION_KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY, 'hex'); // 32 bytes

function encryptToken(token: string): string {
  const iv = randomBytes(16);
  const cipher = createCipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted.toString('hex')}`;
}

function decryptToken(encryptedToken: string): string {
  const [ivHex, authTagHex, encryptedHex] = encryptedToken.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  const encrypted = Buffer.from(encryptedHex, 'hex');
  const decipher = createDecipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
  decipher.setAuthTag(authTag);
  return decipher.update(encrypted) + decipher.final('utf8');
}
```

---

## Refresh Token Rotation

```typescript
async function getValidAccessToken(userId: string): Promise<string> {
  const tokenRecord = await db.oauthTokens.findOne({ userId, provider: 'google' });

  // Token ainda válido (com margem de 5 minutos)
  if (tokenRecord.expiresAt > Date.now() + 5 * 60 * 1000) {
    return decryptToken(tokenRecord.encryptedAccessToken);
  }

  // Renovar via refresh token
  const refreshToken = decryptToken(tokenRecord.encryptedRefreshToken);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.GOOGLE_CLIENT_SECRET,
    }),
  });

  if (!response.ok) {
    // Refresh token expirado ou revogado — usuário precisa re-autenticar
    await db.oauthTokens.update({ userId }, { status: 'requires_reauth' });
    throw new OAuthReauthRequiredError(userId);
  }

  const newTokens = await response.json();

  // Atualizar no banco
  await db.oauthTokens.update({ userId, provider: 'google' }, {
    encryptedAccessToken: encryptToken(newTokens.access_token),
    expiresAt: Date.now() + newTokens.expires_in * 1000,
    // Se Google retornou novo refresh_token (rotation), atualizar
    ...(newTokens.refresh_token && {
      encryptedRefreshToken: encryptToken(newTokens.refresh_token),
    }),
  });

  return newTokens.access_token;
}
```

---

## Revogação de Token

```typescript
// Revogar quando usuário desconecta integração
async function revokeGoogleToken(userId: string) {
  const tokenRecord = await db.oauthTokens.findOne({ userId, provider: 'google' });
  const refreshToken = decryptToken(tokenRecord.encryptedRefreshToken);

  // Revogar no Google
  await fetch(`https://oauth2.googleapis.com/revoke?token=${refreshToken}`, {
    method: 'POST',
  });

  // Remover do banco
  await db.oauthTokens.delete({ userId, provider: 'google' });
}
```

---

## Checklist de OAuth

- [ ] Flow correto para o tipo de app (Authorization Code / PKCE / Service Account)
- [ ] State parameter implementado (anti-CSRF)
- [ ] Tokens trocados no backend, nunca no frontend
- [ ] access_token nunca em localStorage
- [ ] refresh_token encriptado no banco
- [ ] Refresh automático com margem de 5 minutos antes da expiração
- [ ] Tratamento de refresh_token expirado (re-auth flow)
- [ ] Revogação implementada quando usuário desconecta
- [ ] Scopes mínimos necessários (princípio do menor privilégio)
- [ ] GOOGLE_CLIENT_SECRET nunca exposto no frontend
