# docker.md — Ops Sub-Skill: Docker & Containers
# Ativa quando: "docker", "container", "compose", "imagem"

## Dockerfile Multi-Stage — Node.js

```dockerfile
# Dockerfile
# Stage 1: Dependências
FROM node:22-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile

# Stage 2: Build
FROM node:22-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Stage 3: Runner (imagem final mínima)
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Usuário não-root obrigatório
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 appuser

# Apenas artefatos necessários
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
COPY --from=builder --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /app/package.json ./package.json

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
```

## Dockerfile Multi-Stage — Python

```dockerfile
# Dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runner
FROM python:3.12-slim AS runner
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.12/site-packages"

# Usuário não-root
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --gid 1001 appuser

COPY --from=builder /install /install
COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## docker-compose.dev.yml

```yaml
# docker-compose.dev.yml
version: "3.9"

services:
  api:
    build:
      context: .
      target: deps          # para no stage de deps, sem build
    command: npm run dev
    volumes:
      - .:/app
      - /app/node_modules   # preservar node_modules do container
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    env_file:
      - .env.local
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: wolfapp_dev
      POSTGRES_USER: wolf
      POSTGRES_PASSWORD: wolf_dev_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U wolf -d wolfapp_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

## docker-compose.prod.yml

```yaml
# docker-compose.prod.yml
version: "3.9"

services:
  api:
    image: ${REGISTRY}/wolfapp-api:${IMAGE_TAG:-latest}
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"   # bind apenas no loopback — Nginx faz o proxy
    environment:
      - NODE_ENV=production
    env_file:
      - .env.prod
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  workers:
    image: ${REGISTRY}/wolfapp-api:${IMAGE_TAG:-latest}
    command: node dist/workers/index.js
    restart: unless-stopped
    env_file:
      - .env.prod
    depends_on:
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

## .dockerignore

```
node_modules
dist
.git
.env*
*.log
coverage
.nyc_output
README.md
docker-compose*.yml
.github
```

## Boas Práticas Wolf

**Usuário não-root:** sempre criar e usar usuário de aplicação, nunca rodar como root.

**Imagens mínimas:** usar `-alpine` ou `-slim`. Menos camadas, menos superfície de ataque.

**Healthcheck:** obrigatório em todos os serviços. O compose usa para `depends_on`.

**Resource limits:** definir `deploy.resources.limits` em produção. Sem limite, um serviço pode consumir toda a memória do servidor.

**Bind no loopback:** em produção, portar serviços apenas em `127.0.0.1`. Nginx faz o proxy público.

## Comandos Úteis

```bash
# Build com tag
docker build -t wolfapp-api:1.0.0 .

# Build sem cache (quando suspeitar de cache corrompido)
docker build --no-cache -t wolfapp-api:latest .

# Ver tamanho das imagens
docker images wolfapp-api

# Subir dev
docker compose -f docker-compose.dev.yml up

# Subir prod com rebuild
docker compose -f docker-compose.prod.yml up -d --build

# Ver logs de um serviço
docker compose logs -f api

# Executar comando em container rodando
docker compose exec api sh

# Inspecionar resource usage
docker stats

# Limpar tudo (cuidado em produção)
docker system prune -af --volumes

# Ver layers da imagem
docker history wolfapp-api:latest

# Copiar arquivo de/para container
docker compose cp api:/app/dist ./dist-backup
```
