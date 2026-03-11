# infra.md — Titan Sub-Skill: Infraestrutura e Deploy
# Ativa quando: "deploy", "servidor", "docker", "ssl", "domínio", "hosting"

---

## CONHECIMENTO DE INFRA DO SISTEMA WOLF

```yaml
stack_infra_wolf:
  hosting_preferido: [Railway, Render, DigitalOcean App Platform]
  containers: Docker + docker-compose para desenvolvimento local
  proxy: Nginx para produção self-hosted
  ssl: Certbot (Let's Encrypt) ou Cloudflare Proxy
  banco: Supabase (PostgreSQL hosted) ou PostgreSQL no Docker
  cache: Redis (Upstash para serverless ou Redis no Docker)
  storage: Supabase Storage ou Cloudflare R2
  ci_cd: GitHub Actions

deploy_checklist:
  pre_deploy:
    - Testes passando localmente
    - .env.example atualizado (sem valores reais)
    - Sem console.log de debug no código
    - Sem secrets no código (grep -r "sk-" . --include="*.js")
    - Migrations de banco prontas (se houver mudança de schema)

  deploy:
    - Deploy em staging primeiro (se existir)
    - Smoke test em staging
    - Deploy em produção
    - Smoke test em produção (endpoints críticos)

  pos_deploy:
    - Monitora logs por 10 minutos
    - Verifica métricas de erro
    - Rollback plan pronto (como reverter em < 5 minutos)
```

---

## DOCKER COMPOSE WOLF — TEMPLATE BASE

```yaml
version: "3.8"
services:
  app:
    build: .
    ports: ["3000:3000"]
    env_file: .env
    depends_on: [redis, postgres]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: wolf
      POSTGRES_USER: wolf
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes: [postgres_data:/var/lib/postgresql/data]
    restart: unless-stopped

volumes:
  postgres_data:
```

---

## NGINX — CONFIG PADRÃO WOLF

```nginx
server {
    listen 80;
    server_name meu-projeto.wolf.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name meu-projeto.wolf.com;

    ssl_certificate /etc/letsencrypt/live/meu-projeto.wolf.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/meu-projeto.wolf.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## ROLLBACK — PROTOCOLO WOLF

```
QUANDO DEPLOY FALHA:

  1. Identifica: frontend, backend ou banco?
  2. Reverte aplicação:
     Railway/Render: botão "rollback" no dashboard
     Docker: docker compose up -d --no-deps app (imagem anterior ainda local)
     Git: git revert HEAD + push

  3. Verifica que voltou ao normal (smoke test)
  4. Investiga causa raiz antes do próximo deploy
  5. Documenta o incidente no activity.log
```
