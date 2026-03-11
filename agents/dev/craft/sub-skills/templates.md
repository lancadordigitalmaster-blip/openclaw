# templates.md — Craft Sub-Skill: Templates e Boilerplates
# Ativa quando: "template", "boilerplate", "padroniza", "Wolf template"

---

## Templates Wolf — Inventário

| Nome | Stack | Repositório | Última atualização |
|------|-------|------------|-------------------|
| `wolf-nextjs` | Next.js 15, TypeScript strict, Tailwind, Vitest, Drizzle | `wolf-agency/wolf-nextjs` | Mensal |
| `wolf-fastapi` | FastAPI, Python 3.12, uv, Pydantic v2, pytest, Alembic | `wolf-agency/wolf-fastapi` | Mensal |
| `wolf-api-node` | Fastify, TypeScript, Drizzle, Zod, Vitest | `wolf-agency/wolf-api-node` | Mensal |
| `wolf-openclaw-skill` | Node.js, TypeScript, estrutura OpenClaw | `wolf-agency/wolf-openclaw-skill` | Quinzenal |
| `wolf-landing` | Next.js, Tailwind, sem banco (sites estáticos) | `wolf-agency/wolf-landing` | Bimestral |

---

## Como Usar Templates — degit

```bash
# degit: clona template sem histórico git
# Mais limpo que git clone, sem .git/ do template

# Next.js Wolf
npx degit wolf-agency/wolf-nextjs meu-projeto
cd meu-projeto
git init
pnpm install
cp .env.example .env.local

# FastAPI Wolf
npx degit wolf-agency/wolf-fastapi minha-api
cd minha-api
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt
cp .env.example .env

# Com branch específica (para versões de preview)
npx degit wolf-agency/wolf-nextjs#canary meu-projeto-canary

# Com subdiretório (monorepo com múltiplos templates)
npx degit wolf-agency/templates/apps/next-wolf meu-projeto
```

---

## O Que Vai em Todo Template Wolf

Todo template Wolf nasce com isso configurado e funcionando:

### Qualidade de Código
```
ESLint          → TypeScript strict, Next.js rules (ou equivalente)
Prettier        → config Wolf (.prettierrc)
TypeScript      → strict mode: noImplicitAny, strictNullChecks, noUnusedLocals
Biome           → alternativa all-in-one onde ESLint não é necessário
```

### Git
```
Husky           → hooks pre-commit e commit-msg
lint-staged     → lint apenas arquivos modificados
commitlint      → valida Conventional Commits Wolf
.gitignore      → node_modules, .env*, dist, .next, __pycache__
```

### Testes
```
Vitest          → testes unitários (JavaScript/TypeScript)
pytest          → testes (Python)
coverage        → threshold mínimo: 80%
Playwright      → E2E (apenas templates web completos)
```

### CI/CD
```
GitHub Actions  → type-check → lint → test → build → bundle size
branch-protection → main requer PR + CI verde
Dependabot      → updates automáticos de dependências
```

### Arquivos Essenciais
```
.env.example    → todas as variáveis necessárias documentadas
README.md       → o que é, como rodar, variáveis, estrutura
Makefile        → comandos padronizados (setup, dev, test, build, deploy)
Dockerfile      → produção (multi-stage, non-root user)
docker-compose.dev.yml → desenvolvimento local com hot reload
```

---

## Como Criar Novo Template Wolf

### Com degit (recomendado para templates simples)
```bash
# 1. Cria projeto de referência que vai virar template
mkdir wolf-meu-template
cd wolf-meu-template
git init

# 2. Desenvolve a estrutura ideal
# - Configura tudo: ESLint, TypeScript, Husky, CI, etc.
# - Usa placeholders onde necessário

# 3. Substitui nomes específicos por placeholders
# O degit usa arquivos como estão — não há sistema de variáveis nativo
# Convenção Wolf: usar "wolf-template-app" como nome placeholder

# 4. Adiciona .degit.json para instruções pós-clone (opcional)
cat > .degit.json << 'EOF'
{
  "actions": [
    {
      "action": "remove",
      "files": [".git"]
    }
  ]
}
EOF

# 5. Documenta no README o que o usuário deve fazer após clone
# (trocar nome, preencher .env, etc.)

# 6. Publica no GitHub como repositório wolf-agency/wolf-meu-template
# 7. Adiciona à tabela de inventário acima
```

### Com cookiecutter (para templates com variáveis — projetos Python)
```bash
# Estrutura de diretório cookiecutter
wolf-fastapi-template/
├── cookiecutter.json          # variáveis e defaults
├── {{cookiecutter.project_slug}}/
│   ├── app/
│   │   ├── main.py
│   │   └── config.py
│   ├── pyproject.toml
│   ├── README.md
│   └── Makefile
└── hooks/
    └── post_gen_project.py    # script pós-geração

# cookiecutter.json
{
  "project_name": "Meu Projeto FastAPI",
  "project_slug": "{{ cookiecutter.project_name.lower().replace(' ', '-') }}",
  "python_version": "3.12",
  "use_postgres": ["yes", "no"],
  "use_redis": ["yes", "no"],
  "author": "Wolf Agency"
}

# Usar
cookiecutter gh:wolf-agency/wolf-fastapi-template
```

---

## Versionamento de Templates

```
ESTRATÉGIA WOLF DE VERSIONAMENTO:
==================================

Branches:
- main    → versão estável atual (todos os projetos novos)
- canary  → próxima versão (features em teste)
- v1, v2  → versões antigas mantidas para referência (read-only)

Tags semânticas:
- v1.0.0 → release major (breaking changes)
- v1.1.0 → release minor (novas features)
- v1.1.1 → release patch (fixes no template)

CHANGELOG do template:
- Documenta o que mudou em cada versão
- Indica se é breaking change
- Facilita atualização em projetos existentes
```

---

## Como Propagar Mudanças para Projetos Existentes

Templates evoluem. Projetos criados de templates antigos ficam desatualizados.

```bash
# Estratégia 1: diff manual + cherry-pick
# Gera patch da mudança no template
cd wolf-nextjs/
git diff v1.2.0..v1.3.0 -- .eslintrc.json > /tmp/eslint-update.patch

# Aplica no projeto existente
cd meu-projeto-existente/
git apply /tmp/eslint-update.patch
```

```bash
# Estratégia 2: script de migração (para mudanças grandes)
# Wolf cria scripts de migração para changes significativas

# scripts/migrations/migrate-to-v2.sh
#!/bin/bash
# Migração: adiciona Biome, remove ESLint + Prettier
set -euo pipefail

echo "Migrando para template Wolf v2..."

# Remove deps antigas
pnpm remove eslint prettier eslint-config-next @typescript-eslint/eslint-plugin

# Instala Biome
pnpm add -D @biomejs/biome

# Copia nova configuração
curl -sL https://raw.githubusercontent.com/wolf-agency/wolf-nextjs/main/biome.json \
  > biome.json

# Remove configs antigas
rm -f .eslintrc.json .prettierrc

# Atualiza scripts no package.json
node -e "
const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'))
pkg.scripts.lint = 'biome check .'
pkg.scripts['lint:fix'] = 'biome check --write .'
require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2))
"

echo "Migração concluída. Revise as mudanças antes de commitar."
```

```javascript
// Estratégia 3: comparar com template atual (script de auditoria)
// scripts/audit-template.js
const { execSync } = require('child_process')
const fs = require('fs')

const TEMPLATE_FILES = [
  '.eslintrc.json',
  '.prettierrc',
  'tsconfig.json',
  '.github/workflows/ci.yml',
  'vitest.config.ts',
]

for (const file of TEMPLATE_FILES) {
  try {
    const local = fs.readFileSync(file, 'utf8')
    const template = execSync(
      `curl -sL https://raw.githubusercontent.com/wolf-agency/wolf-nextjs/main/${file}`
    ).toString()

    if (local !== template) {
      console.log(`DESATUALIZADO: ${file}`)
    } else {
      console.log(`OK: ${file}`)
    }
  } catch {
    console.log(`AUSENTE: ${file}`)
  }
}
```

---

## Checklist Template Wolf

```
Criação de Novo Template
[ ] Começa de template Wolf existente (não do zero)
[ ] ESLint/Biome configurado e passando
[ ] TypeScript strict configurado
[ ] Husky + lint-staged + commitlint instalados
[ ] Vitest com coverage configurado
[ ] GitHub Actions CI funcionando (push para branch de teste)
[ ] .env.example com todos os campos necessários
[ ] README com: o que é, como usar, estrutura de diretórios
[ ] Makefile com targets padrão Wolf
[ ] Adicionado ao inventário de templates

Uso de Template
[ ] Criado com degit (não git clone)
[ ] Nome do projeto substituído (busca e substitui "wolf-template-app")
[ ] .env.example copiado e configurado
[ ] Git inicializado com commit inicial
[ ] CI rodando no repositório novo

Manutenção
[ ] Template tem versão semântica
[ ] CHANGELOG atualizado a cada release
[ ] Scripts de migração criados para breaking changes
[ ] Projetos existentes notificados de updates relevantes (segurança)
```
