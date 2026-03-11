# cicd.md — Ops Sub-Skill: CI/CD & GitHub Actions
# Ativa quando: "deploy", "pipeline", "CI/CD", "GitHub Actions"

## Pipeline Padrão Wolf

Fluxo: `push` → `test` → `build` → `deploy`

Ambientes:
- `develop` → deploy automático em **staging**
- `main` → deploy automático em **production**
- Pull Requests → apenas test + build (sem deploy)

## GitHub Actions — Pipeline Completo

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  NODE_VERSION: "22"
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: wolfapp_test
          POSTGRES_USER: wolf
          POSTGRES_PASSWORD: wolf_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run type check
        run: npm run typecheck

      - name: Run tests
        run: npm run test:coverage
        env:
          DATABASE_URL: postgresql://wolf:wolf_test@localhost:5432/wolfapp_test
          REDIS_URL: redis://localhost:6379
          JWT_SECRET: test_secret_that_is_long_enough_for_testing
          JWT_REFRESH_SECRET: test_refresh_secret_that_is_long_enough

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage
          path: coverage/

  build:
    name: Build & Push Image
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push'
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment:
      name: staging
      url: https://staging.wolfapp.com

    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/wolfapp-staging
            export IMAGE_TAG=develop-${{ github.sha }}
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d --no-build
            docker compose -f docker-compose.prod.yml exec -T api npm run db:migrate
            echo "Deployed $IMAGE_TAG to staging"

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://app.wolfapp.com

    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/wolfapp
            export IMAGE_TAG=main-${{ github.sha }}
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d --no-build
            docker compose -f docker-compose.prod.yml exec -T api npm run db:migrate
            echo "Deployed $IMAGE_TAG to production"
```

## Pipeline Simplificado (sem Docker — Railway/Render/Fly.io)

```yaml
# .github/workflows/deploy-simple.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  test-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"

      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test

      - name: Deploy to Railway
        uses: bervProject/railway-deploy@v1.0.0
        with:
          railway_token: ${{ secrets.RAILWAY_TOKEN }}
          service: wolfapp-api
```

## Cache de Dependências

```yaml
# Cache npm — já incluso no setup-node com cache: "npm"
# Cache Docker layers — já incluso no build-push-action com cache-from/cache-to

# Cache para projetos com Prisma (gera client no npm ci)
- name: Cache Prisma client
  uses: actions/cache@v4
  with:
    path: node_modules/.prisma
    key: prisma-${{ hashFiles('prisma/schema.prisma') }}
```

## Secrets no GitHub

Onde configurar: `Settings → Secrets and variables → Actions`

| Secret             | Uso                                         |
|--------------------|---------------------------------------------|
| `PROD_HOST`        | IP ou hostname do servidor de produção      |
| `PROD_USER`        | Usuário SSH (ex: deploy)                    |
| `PROD_SSH_KEY`     | Chave privada SSH (sem passphrase)          |
| `STAGING_HOST`     | IP ou hostname do servidor de staging       |
| `STAGING_USER`     | Usuário SSH staging                         |
| `STAGING_SSH_KEY`  | Chave privada SSH staging                   |
| `RAILWAY_TOKEN`    | Token da Railway (se usar)                  |
| `SLACK_WEBHOOK`    | URL do webhook para notificações            |

**Gerar chave SSH para deploy:**
```bash
ssh-keygen -t ed25519 -C "deploy@wolfapp" -f ~/.ssh/wolfapp_deploy -N ""
# Adicionar conteúdo de wolfapp_deploy.pub ao authorized_keys do servidor
# Adicionar conteúdo de wolfapp_deploy (privada) ao secret PROD_SSH_KEY
```

## Notificação no Slack/Telegram

```yaml
# Adicionar ao final do job deploy-production
- name: Notify deployment
  if: always()
  uses: slackapi/slack-github-action@v1.27.0
  with:
    payload: |
      {
        "text": "${{ job.status == 'success' && 'Deployed to production' || 'Deploy FAILED' }}: `${{ github.sha }}` by ${{ github.actor }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Estratégia de Ambientes

| Branch    | Ambiente   | Deploy      | Aprovação manual |
|-----------|------------|-------------|------------------|
| `feature/*` | -        | Apenas CI   | -                |
| `develop`  | Staging   | Automático  | Não              |
| `main`     | Production| Automático  | Opcional (environment protection) |

**Environment protection rules (recomendado para produção):**
- `Settings → Environments → production → Required reviewers`
- Adicionar tech lead como revisor obrigatório

## Checklist de Pipeline

- [ ] Testes rodam antes do build
- [ ] Build apenas em push (não em PRs)
- [ ] Secrets configurados no GitHub (não no código)
- [ ] Cache de dependências configurado
- [ ] Health check após deploy
- [ ] Rollback documentado se deploy falhar
- [ ] Variáveis de ambiente de produção nunca no repositório
- [ ] Notificação de deploy bem-sucedido ou falha
