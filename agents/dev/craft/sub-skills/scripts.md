# scripts.md — Craft Sub-Skill: Scripts e Automação
# Ativa quando: "Makefile", "script", "automatiza", "comando", "task runner"

---

## Makefile Padrão Wolf

O Makefile como interface única de comandos. Todo projeto Wolf tem um.

```makefile
# Makefile
.DEFAULT_GOAL := help
.PHONY: help setup dev test build clean deploy-staging deploy-prod lint type-check

# Cores para output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

## — Help ————————————————————————————————————

help: ## Mostra este menu de ajuda
	@echo ''
	@echo 'Uso:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) { \
			printf "  ${YELLOW}%-20s${RESET} %s\n", $$1, $$2 \
		} else if (/^## /) { \
			printf "\n${GREEN}%s${RESET}\n", substr($$0, 4) \
		} \
	}' $(MAKEFILE_LIST)

## — Setup ———————————————————————————————————

setup: ## Configura o ambiente de desenvolvimento do zero
	@echo "Verificando dependências..."
	@which node || (echo "ERRO: Node.js não encontrado" && exit 1)
	@which pnpm || npm install -g pnpm
	pnpm install
	cp -n .env.example .env.local || true
	@echo "Setup concluído. Configure .env.local e rode 'make dev'"

setup-python: ## Configura ambiente Python com uv
	@which uv || (echo "Instalando uv..." && curl -LsSf https://astral.sh/uv/install.sh | sh)
	uv venv
	uv pip install -r requirements.txt
	cp -n .env.example .env || true
	@echo "Ambiente Python pronto. Ative: source .venv/bin/activate"

## — Desenvolvimento —————————————————————————

dev: ## Inicia o servidor de desenvolvimento
	pnpm dev

dev-python: ## Inicia o servidor FastAPI com hot reload
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

## — Qualidade ———————————————————————————————

lint: ## Roda linting e formatação
	pnpm lint

lint-fix: ## Corrige erros de lint automaticamente
	pnpm lint:fix

type-check: ## Verifica tipos TypeScript
	pnpm type-check

## — Testes ——————————————————————————————————

test: ## Roda testes unitários
	pnpm test

test-watch: ## Roda testes em modo watch
	pnpm test:watch

test-coverage: ## Roda testes com relatório de cobertura
	pnpm test:ci
	@echo "Cobertura: abre coverage/index.html para ver o relatório"

test-e2e: ## Roda testes E2E com Playwright
	pnpm playwright test

## — Build ———————————————————————————————————

build: ## Build de produção
	pnpm build

build-docker: ## Build da imagem Docker
	docker build -t $(APP_NAME):latest .

## — Database ————————————————————————————————

db-migrate: ## Roda migrações pendentes
	pnpm db:migrate

db-migrate-create: ## Cria nova migração (uso: make db-migrate-create name=nome)
	pnpm db:migrate:create $(name)

db-reset: ## CUIDADO: Reseta o banco de desenvolvimento
	@echo "${YELLOW}ATENÇÃO: Isso vai apagar todos os dados do banco de dev${RESET}"
	@read -p "Confirmar? [y/N] " confirm && [ "$$confirm" = "y" ]
	pnpm db:reset

db-seed: ## Popula o banco com dados de seed
	pnpm db:seed

## — Clean ———————————————————————————————————

clean: ## Remove artefatos de build e cache
	rm -rf .next dist build coverage node_modules/.cache
	@echo "Limpeza concluída"

clean-all: ## Remove TUDO incluindo node_modules (reinstala depois)
	rm -rf .next dist build coverage node_modules .pnpm-store
	@echo "Limpeza total concluída. Rode 'make setup' para reinstalar"

## — Deploy ——————————————————————————————————

deploy-staging: ## Deploy para ambiente de staging
	@echo "Deployando para staging..."
	./scripts/deploy.sh staging

deploy-prod: ## Deploy para produção (requer confirmação)
	@echo "${YELLOW}DEPLOY PARA PRODUÇÃO${RESET}"
	@read -p "Branch atual: $$(git branch --show-current). Confirmar? [y/N] " confirm && [ "$$confirm" = "y" ]
	./scripts/deploy.sh production

## — Utilities ———————————————————————————————

logs: ## Mostra logs do servidor (produção)
	ssh deploy@$(PROD_HOST) "journalctl -u $(APP_NAME) -f"

tunnel: ## Cria túnel SSH para banco de produção (read-only)
	ssh -L 5433:localhost:5432 deploy@$(PROD_HOST) -N

format: ## Formata todos os arquivos
	prettier --write "src/**/*.{ts,tsx,js,json}"

check-all: type-check lint test ## Roda todas as verificações (CI local)
	@echo "${GREEN}Tudo OK!${RESET}"
```

---

## Scripts npm — package.json

```json
{
  "scripts": {
    "dev": "next dev --turbo",
    "build": "next build",
    "start": "next start",
    "preview": "next build && next start",

    "test": "vitest",
    "test:watch": "vitest --watch",
    "test:ci": "vitest run --coverage --reporter=verbose",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",

    "lint": "next lint && tsc --noEmit",
    "lint:fix": "next lint --fix && prettier --write .",
    "type-check": "tsc --noEmit",
    "format": "prettier --write .",
    "format:check": "prettier --check .",

    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio",
    "db:seed": "tsx scripts/seed.ts",

    "analyze": "ANALYZE=true next build",
    "check-all": "tsc --noEmit && next lint && vitest run",
    "prepare": "husky"
  }
}
```

---

## Shell Scripts de Automação Wolf

### deploy.sh
```bash
#!/bin/bash
# scripts/deploy.sh [staging|production]
set -euo pipefail  # para em qualquer erro, undefined var, pipe falha

ENVIRONMENT="${1:-staging}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APP_NAME="minha-app"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# Verificações pré-deploy
log "Iniciando deploy para: ${ENVIRONMENT}"

# 1. Verificar que está na branch correta
CURRENT_BRANCH=$(git branch --show-current)
if [ "$ENVIRONMENT" = "production" ] && [ "$CURRENT_BRANCH" != "main" ]; then
  error "Deploy de produção só pode ser feito a partir de main. Branch atual: $CURRENT_BRANCH"
fi

# 2. Verificar que não há mudanças não commitadas
if ! git diff-index --quiet HEAD --; then
  error "Existem mudanças não commitadas. Commit ou stash antes de deployar."
fi

# 3. Testes passando
log "Rodando verificações..."
npm run type-check || error "Type check falhou"
npm run lint || error "Lint falhou"
npm run test:ci || error "Testes falharam"

# 4. Build
log "Building..."
npm run build || error "Build falhou"

# 5. Deploy (adapte para sua infra)
log "Deployando para ${ENVIRONMENT}..."
if [ "$ENVIRONMENT" = "staging" ]; then
  # Exemplo: Fly.io
  fly deploy --config fly.staging.toml
elif [ "$ENVIRONMENT" = "production" ]; then
  # Tag de versão para rastreabilidade
  git tag "deploy-prod-${TIMESTAMP}"
  git push origin "deploy-prod-${TIMESTAMP}"
  fly deploy --config fly.production.toml
fi

log "Deploy concluído: ${ENVIRONMENT} — ${TIMESTAMP}"
```

### backup.sh
```bash
#!/bin/bash
# scripts/backup.sh — backup do banco de dados
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups"
DB_NAME="${POSTGRES_DB:-minha_app}"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

log() { echo "[$(date +'%H:%M:%S')] $1"; }

log "Iniciando backup do banco: ${DB_NAME}"

# Dump comprimido
pg_dump "$DATABASE_URL" \
  --format=custom \
  --compress=9 \
  --file="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump" | cut -f1)
log "Backup criado: ${DB_NAME}_${TIMESTAMP}.dump (${BACKUP_SIZE})"

# Upload para S3 (se configurado)
if [ -n "${AWS_S3_BACKUP_BUCKET:-}" ]; then
  aws s3 cp \
    "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump" \
    "s3://${AWS_S3_BACKUP_BUCKET}/backups/${DB_NAME}_${TIMESTAMP}.dump"
  log "Backup enviado para S3"
fi

# Remover backups antigos
find "$BACKUP_DIR" -name "*.dump" -mtime "+${RETENTION_DAYS}" -delete
log "Backups com mais de ${RETENTION_DAYS} dias removidos"

log "Backup concluído"
```

---

## Boas Práticas de Scripts Wolf

```bash
#!/bin/bash

# 1. Sempre começar com
set -euo pipefail
# -e: para no primeiro erro
# -u: trata variáveis undefined como erro
# -o pipefail: pipe falha se qualquer comando falhar

# 2. Verificar dependências no início
check_deps() {
  local deps=("node" "docker" "aws")
  for dep in "${deps[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || {
      echo "ERRO: $dep não encontrado. Instale antes de continuar."
      exit 1
    }
  done
}

# 3. Mensagens de progresso claras
log() { echo "[$(date +'%H:%M:%S')] $1"; }
error() { echo "[ERRO] $1" >&2; exit 1; }
warn() { echo "[AVISO] $1" >&2; }

# 4. Cleanup em caso de interrupção
cleanup() {
  log "Limpando recursos temporários..."
  rm -f /tmp/trabalho_temp_$$
}
trap cleanup EXIT INT TERM

# 5. Confirmação para operações destrutivas
confirmar() {
  local mensagem="$1"
  read -r -p "$mensagem [y/N] " resposta
  [[ "$resposta" =~ ^[Yy]$ ]] || exit 0
}

# 6. Variáveis com defaults documentados
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
ENVIRONMENT="${1:-development}"  # primeiro argumento com default
```

---

## Checklist Scripts Wolf

```
Qualidade de Script
[ ] set -euo pipefail no início de todo script bash
[ ] Verificação de dependências necessárias
[ ] Mensagens de progresso com timestamp
[ ] Operações destrutivas com confirmação manual
[ ] Cleanup de recursos temporários com trap

Makefile
[ ] make help funciona e documenta todos os targets
[ ] Targets com ## são documentados (aparecem no help)
[ ] .PHONY declarado para targets que não geram arquivos
[ ] Confirmação antes de deploy-prod

Scripts de Deploy
[ ] Verificação de branch correta antes de deploy
[ ] Testes rodando antes do build
[ ] Build verificado antes do deploy
[ ] Rollback documentado ou automatizado
[ ] Logs de deploy com timestamp para rastreabilidade

Automação
[ ] Scripts idempotentes (pode rodar múltiplas vezes sem problema)
[ ] Variáveis de ambiente com defaults documentados
[ ] Sem hardcoded secrets ou IPs de servidor
```
