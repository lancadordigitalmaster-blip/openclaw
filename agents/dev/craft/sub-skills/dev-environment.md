# dev-environment.md — Craft Sub-Skill: Ambiente de Desenvolvimento
# Ativa quando: "ambiente", "dev container", "Docker dev", "setup local"

---

## Filosofia Wolf: Ambiente Reproduzível

"Funciona na minha máquina" não é aceitável. Todo dev deve conseguir rodar o projeto com os mesmos comandos, no mesmo ambiente.

**Meta:** Clone → `make setup` → `make dev` → pronto em < 5 minutos.

---

## Dev Containers — Ambiente Totalmente Reproduzível

Desenvolvimento dentro de container Docker. VS Code abre direto no container.

```json
// .devcontainer/devcontainer.json
{
  "name": "Wolf Dev Environment",
  "dockerComposeFile": ["../docker-compose.dev.yml", "docker-compose.yml"],
  "service": "app",
  "workspaceFolder": "/workspace",

  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20",
      "nvmVersion": "latest"
    },
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss",
        "prisma.prisma",
        "ms-azuretools.vscode-docker"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "terminal.integrated.shell.linux": "/bin/bash"
      }
    }
  },

  "postCreateCommand": "make setup",
  "forwardPorts": [3000, 5432, 6379],
  "portsAttributes": {
    "3000": { "label": "App Web" },
    "5432": { "label": "PostgreSQL" },
    "6379": { "label": "Redis" }
  },

  "remoteUser": "node"
}
```

```yaml
# .devcontainer/docker-compose.yml (override para dev container)
version: '3.8'
services:
  app:
    volumes:
      - ..:/workspace:cached
      - /workspace/node_modules  # anônimo — node_modules no container
    command: sleep infinity      # mantém container vivo
```

---

## docker-compose.dev.yml — Serviços de Desenvolvimento

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  # Banco de dados PostgreSQL
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: wolf
      POSTGRES_PASSWORD: wolf_dev_pass
      POSTGRES_DB: wolf_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U wolf -d wolf_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Redis
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  # Mailhog — SMTP fake para dev (captura emails)
  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # UI web (http://localhost:8025)

  # MinIO — S3 local para desenvolvimento
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"  # API S3
      - "9001:9001"  # Console web
    volumes:
      - minio_data:/data

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

```bash
# Comandos comuns
docker compose -f docker-compose.dev.yml up -d          # inicia serviços
docker compose -f docker-compose.dev.yml down            # para serviços
docker compose -f docker-compose.dev.yml down -v         # para e remove volumes
docker compose -f docker-compose.dev.yml logs -f postgres # logs do banco
```

---

## Variáveis de Ambiente — direnv

direnv carrega automaticamente o .env quando você entra no diretório.

```bash
# Instalar direnv
brew install direnv  # macOS
# ou: apt install direnv

# Adicionar ao shell (.zshrc ou .bashrc)
eval "$(direnv hook zsh)"  # ou bash

# Na raiz do projeto
echo 'dotenv .env.local' > .envrc
direnv allow .

# Agora ao entrar no diretório, .env.local é carregado automaticamente
# Não precisa de source .env antes de rodar comandos
```

```bash
# .env.local — template para desenvolvimento
DATABASE_URL="postgresql://wolf:wolf_dev_pass@localhost:5432/wolf_dev"
REDIS_URL="redis://localhost:6379"

# Auth
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="dev-secret-apenas-local-nao-use-em-prod"

# Storage
AWS_S3_ENDPOINT="http://localhost:9000"
AWS_S3_BUCKET="wolf-dev"
AWS_ACCESS_KEY_ID="minioadmin"
AWS_SECRET_ACCESS_KEY="minioadmin"

# Email (Mailhog local)
SMTP_HOST="localhost"
SMTP_PORT="1025"
SMTP_SECURE="false"

# Opcional: ativa features de dev
DEBUG="true"
LOG_LEVEL="debug"
```

---

## Gerenciamento de Versão de Node — nvm e volta

### nvm (mais comum)
```bash
# Instalar nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# .nvmrc na raiz do projeto (comitar)
echo "20.11.0" > .nvmrc

# Usar a versão correta
nvm use           # lê .nvmrc automaticamente
nvm install       # instala se não tiver

# Auto-switch ao entrar no diretório (.zshrc)
autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
```

### volta (alternativa mais rápida, sem shell hook)
```bash
# Instalar volta
curl https://get.volta.sh | bash

# Fixar versão no projeto (salva no package.json)
volta pin node@20
volta pin pnpm@9

# package.json
{
  "volta": {
    "node": "20.11.0",
    "pnpm": "9.0.0"
  }
}

# Volta troca automaticamente ao entrar no diretório — sem config extra
```

---

## Gerenciamento de Python — pyenv + uv

```bash
# pyenv — gerencia versões do Python
brew install pyenv

# .python-version na raiz do projeto (comitar)
echo "3.12.2" > .python-version

# pyenv instala e usa automaticamente
pyenv install 3.12.2
pyenv local 3.12.2  # cria/atualiza .python-version

# uv — gerenciamento de dependências (muito mais rápido que pip)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Criar ambiente virtual com uv
uv venv
source .venv/bin/activate

# Instalar dependências
uv pip install -r requirements.txt
# ou com pyproject.toml
uv pip install -e ".[dev]"

# Adicionar dependência
uv pip install fastapi
uv pip freeze > requirements.txt
```

---

## Checklist de Ambiente Funcionando

Execute esta verificação ao configurar ambiente ou quando algo der errado:

```bash
#!/bin/bash
# scripts/check-dev-env.sh

VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${VERDE}✓${NC} $1"; }
fail() { echo -e "${VERMELHO}✗${NC} $1"; FALHOU=1; }
warn() { echo -e "${AMARELO}!${NC} $1"; }

FALHOU=0
echo "Verificando ambiente de desenvolvimento..."
echo

# Node.js
REQUIRED_NODE=20
CURRENT_NODE=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -z "$CURRENT_NODE" ]; then
  fail "Node.js não encontrado"
elif [ "$CURRENT_NODE" -lt "$REQUIRED_NODE" ]; then
  fail "Node.js $REQUIRED_NODE+ necessário. Atual: $(node --version)"
else
  ok "Node.js $(node --version)"
fi

# pnpm
if command -v pnpm &>/dev/null; then
  ok "pnpm $(pnpm --version)"
else
  warn "pnpm não encontrado (npm install -g pnpm)"
fi

# Docker
if docker info &>/dev/null; then
  ok "Docker $(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
else
  warn "Docker não está rodando (serviços locais não disponíveis)"
fi

# Banco de dados
if pg_isready -h localhost -p 5432 &>/dev/null; then
  ok "PostgreSQL disponível em localhost:5432"
else
  warn "PostgreSQL não disponível (rode: docker compose -f docker-compose.dev.yml up -d postgres)"
fi

# Redis
if redis-cli -h localhost ping &>/dev/null; then
  ok "Redis disponível"
else
  warn "Redis não disponível (rode: docker compose -f docker-compose.dev.yml up -d redis)"
fi

# .env.local
if [ -f ".env.local" ]; then
  ok ".env.local existe"
else
  fail ".env.local não encontrado (copie de .env.example)"
fi

# node_modules
if [ -d "node_modules" ]; then
  ok "node_modules instalado"
else
  fail "node_modules ausente (rode: pnpm install)"
fi

echo
if [ "$FALHOU" -eq 1 ]; then
  echo -e "${VERMELHO}Ambiente com problemas. Corrija os erros acima.${NC}"
  exit 1
else
  echo -e "${VERDE}Ambiente OK!${NC}"
fi
```

---

## Checklist Dev Environment Wolf

```
Configuração Inicial (por projeto)
[ ] .nvmrc ou volta configurado no package.json
[ ] .python-version se projeto Python
[ ] docker-compose.dev.yml com todos os serviços necessários
[ ] .env.example com TODOS os campos (sem valores reais)
[ ] make setup funciona do zero em máquina limpa
[ ] .devcontainer/ configurado para VS Code (projetos de time)

Por Desenvolvedor
[ ] nvm/volta instalado e .nvmrc lido automaticamente
[ ] direnv instalado e .envrc configurado
[ ] Docker rodando
[ ] VS Code com extensions recomendadas (.vscode/extensions.json)
[ ] make dev sobe o servidor em < 30s

Documentação
[ ] README tem seção "Como rodar localmente" atualizada
[ ] Variáveis de ambiente documentadas no .env.example
[ ] Dependências externas documentadas (banco, Redis, serviços de terceiro)
[ ] Passo a passo para obter credenciais de dev (APIs externas)
```
