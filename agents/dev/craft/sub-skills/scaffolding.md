# scaffolding.md — Craft Sub-Skill: Project Scaffolding
# Ativa quando: "cria projeto", "scaffold", "novo projeto", "estrutura"

---

## Meta Wolf: < 5 Minutos do Zero ao Dev Server Rodando

Zero configuração manual. Template pré-configurado com tudo que o projeto precisa.

---

## Templates Wolf Disponíveis

| Template | Stack | Quando Usar |
|----------|-------|-------------|
| `wolf-nextjs` | Next.js 15, TypeScript strict, Tailwind, Vitest | Apps web, dashboards, landing pages |
| `wolf-fastapi` | FastAPI, Python 3.12, uv, Pydantic v2, pytest | APIs Python, microserviços, ML backends |
| `wolf-openclaw-skill` | Node.js, TypeScript, estrutura de skill OpenClaw | Novas skills para o sistema Wolf |
| `wolf-api-node` | Node.js, Fastify, TypeScript strict, Drizzle ORM | APIs Node.js standalone |

---

## Como Criar Projeto com degit

```bash
# degit — clona template sem histórico git (limpo, rápido)
npx degit wolf-agency/wolf-nextjs meu-projeto
cd meu-projeto

# Inicializar git limpo
git init
git add .
git commit -m "feat: scaffold inicial Wolf Next.js"

# Instalar dependências
npm install  # ou pnpm install (preferido)

# Configurar variáveis de ambiente
cp .env.example .env.local
# Editar .env.local com valores reais

# Dev server
npm run dev
```

```bash
# Com pnpm (padrão Wolf para projetos novos)
npx degit wolf-agency/wolf-fastapi minha-api
cd minha-api

# Python com uv (padrão Wolf Python)
uv venv
source .venv/bin/activate  # Linux/Mac
# ou: .venv\Scripts\activate  # Windows

uv pip install -r requirements.txt
cp .env.example .env

uvicorn main:app --reload
```

---

## Estrutura de Diretórios Padrão Wolf

### Next.js Wolf
```
meu-projeto/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml          # type-check, lint, test, build
│   │   └── preview.yml     # deploy de preview por PR
│   └── pull_request_template.md
├── .husky/
│   ├── pre-commit          # lint-staged
│   └── commit-msg          # commitlint
├── app/                    # App Router (Next.js 13+)
│   ├── (auth)/             # grupo: rotas autenticadas
│   │   ├── dashboard/
│   │   │   └── page.tsx
│   │   └── layout.tsx
│   ├── api/                # API Routes
│   │   └── [...]/
│   ├── globals.css
│   ├── layout.tsx          # root layout
│   └── page.tsx            # home
├── components/
│   ├── ui/                 # componentes base (shadcn)
│   └── features/           # componentes de domínio
├── lib/
│   ├── db.ts               # instância do banco
│   ├── auth.ts             # configuração de auth
│   └── utils.ts            # utilitários gerais
├── hooks/                  # React hooks customizados
├── types/                  # TypeScript types globais
├── tests/
│   ├── unit/               # testes unitários
│   ├── integration/        # testes de integração
│   └── e2e/                # Playwright (se necessário)
├── public/                 # assets estáticos
├── .env.example            # template de variáveis (comita)
├── .env.local              # valores reais (NÃO comita)
├── .gitignore
├── .eslintrc.json
├── .prettierrc
├── commitlint.config.js
├── next.config.js
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

### FastAPI Wolf
```
minha-api/
├── .github/workflows/
│   └── ci.yml
├── app/
│   ├── __init__.py
│   ├── main.py             # instância FastAPI, middlewares, routers
│   ├── config.py           # settings com Pydantic BaseSettings
│   ├── dependencies.py     # DI: banco, auth, rate limit
│   ├── routers/            # endpoints por domínio
│   │   ├── usuarios.py
│   │   └── produtos.py
│   ├── models/             # SQLAlchemy models
│   ├── schemas/            # Pydantic schemas (input/output)
│   ├── services/           # lógica de negócio
│   └── utils/
├── tests/
│   ├── conftest.py         # fixtures
│   ├── unit/
│   └── integration/
├── migrations/             # Alembic
├── .env.example
├── .gitignore
├── pyproject.toml          # deps com uv
├── Makefile                # comandos padronizados
└── Dockerfile
```

---

## Checklist de Projeto Novo Wolf

```
Dia 0 — Setup Inicial
[ ] Projeto criado com template Wolf (não from scratch)
[ ] Git inicializado com commit inicial
[ ] .env.example preenchido com todos os campos necessários
[ ] .gitignore configurado (node_modules, .env, .next, dist, __pycache__)
[ ] README.md com: o que é, como rodar, variáveis necessárias

Qualidade de Código
[ ] ESLint ou Ruff configurado e funcionando
[ ] Prettier ou Black configurado
[ ] TypeScript strict mode ativado (noImplicitAny, strictNullChecks)
[ ] Husky instalado (pre-commit roda lint)
[ ] commitlint instalado (valida mensagens de commit)

Testes
[ ] Framework de teste configurado (Vitest ou pytest)
[ ] Teste de exemplo funcionando (npm test passa)
[ ] Cobertura mínima definida (Wolf default: 80%)

CI/CD
[ ] GitHub Actions configurado (type-check, lint, test, build)
[ ] Branch protection configurado (main exige PR + CI verde)
[ ] Deploy automático para staging configurado

Dev Experience
[ ] Dev server sobe em < 30s
[ ] Hot reload funcionando
[ ] Variáveis de ambiente documentadas no .env.example
[ ] Makefile ou scripts npm para comandos comuns
```

---

## Script de Verificação de Ambiente

```bash
#!/bin/bash
# scripts/check-env.sh — roda antes do dev server

set -e

echo "Verificando ambiente..."

# Node version
REQUIRED_NODE="20"
CURRENT_NODE=$(node --version | cut -d. -f1 | tr -d 'v')
if [ "$CURRENT_NODE" -lt "$REQUIRED_NODE" ]; then
  echo "ERRO: Node.js $REQUIRED_NODE+ necessário. Atual: $(node --version)"
  exit 1
fi
echo "✓ Node.js $(node --version)"

# .env.local existe
if [ ! -f ".env.local" ]; then
  echo "AVISO: .env.local não encontrado. Copiando de .env.example..."
  cp .env.example .env.local
  echo "AÇÃO NECESSÁRIA: Preencha as variáveis em .env.local"
fi
echo "✓ Variáveis de ambiente"

# Dependências instaladas
if [ ! -d "node_modules" ]; then
  echo "Instalando dependências..."
  npm install
fi
echo "✓ Dependências"

echo "Ambiente OK. Iniciando dev server..."
```

```json
// package.json — scripts padronizados Wolf
{
  "scripts": {
    "dev": "node scripts/check-env.js && next dev",
    "build": "next build",
    "start": "next start",
    "test": "vitest",
    "test:ci": "vitest run --coverage",
    "lint": "next lint && tsc --noEmit",
    "lint:fix": "next lint --fix && prettier --write .",
    "type-check": "tsc --noEmit",
    "prepare": "husky"
  }
}
```
