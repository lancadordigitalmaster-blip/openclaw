# monorepo.md — Craft Sub-Skill: Monorepo
# Ativa quando: "monorepo", "workspace", "compartilha código", "pnpm"

---

## Quando Monorepo Faz Sentido

```
USE MONOREPO QUANDO:
✓ Múltiplos apps que compartilham código (ex: web + mobile + dashboard)
✓ Biblioteca interna usada por vários projetos
✓ Time único desenvolve todos os apps
✓ Deploys precisam ser coordenados (breaking change em shared/)
✓ Quer evitar duplicação de configuração (ESLint, TypeScript, etc.)

NÃO USE MONOREPO QUANDO:
✗ Um único app sem previsão de reutilização de código
✗ Times completamente separados sem colaboração
✗ Apps em stacks completamente diferentes (Node + Rust + Go)
✗ Projeto pequeno (< 3 devs, 1-2 apps)
✗ CI já demora muito — monorepo pode piorar sem caching
```

---

## pnpm Workspaces — Padrão Wolf

```yaml
# pnpm-workspace.yaml — na raiz do monorepo
packages:
  - 'apps/*'      # aplicações
  - 'packages/*'  # bibliotecas internas compartilhadas
  - 'shared/*'    # código compartilhado não publicado
```

### Estrutura Wolf

```
meu-monorepo/
├── apps/
│   ├── web/                    # Next.js principal
│   │   ├── package.json        # "name": "@wolf/web"
│   │   └── ...
│   ├── admin/                  # Dashboard administrativo
│   │   ├── package.json        # "name": "@wolf/admin"
│   │   └── ...
│   └── api/                    # FastAPI ou Node.js API
│       └── ...
├── packages/
│   ├── ui/                     # Componentes React compartilhados
│   │   ├── src/
│   │   │   ├── components/
│   │   │   └── index.ts        # barrel export
│   │   ├── package.json        # "name": "@wolf/ui"
│   │   └── tsconfig.json
│   ├── types/                  # TypeScript types compartilhados
│   │   ├── src/
│   │   │   └── index.ts
│   │   └── package.json        # "name": "@wolf/types"
│   └── utils/                  # Utilitários compartilhados
│       ├── src/
│       └── package.json        # "name": "@wolf/utils"
├── shared/
│   └── config/                 # Configs compartilhadas (ESLint, TS, etc.)
│       ├── eslint-base.json
│       ├── tsconfig.base.json
│       └── package.json        # "name": "@wolf/config"
├── package.json                # root — scripts globais
├── pnpm-workspace.yaml
├── turbo.json
└── .gitignore
```

---

## Configuração Inicial

```bash
# Criar estrutura
mkdir meu-monorepo && cd meu-monorepo
git init

# package.json root
cat > package.json << 'EOF'
{
  "name": "meu-monorepo",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "test": "turbo test",
    "lint": "turbo lint",
    "type-check": "turbo type-check",
    "clean": "turbo clean"
  },
  "devDependencies": {
    "turbo": "latest"
  }
}
EOF

# pnpm-workspace.yaml
cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
  - 'shared/*'
EOF

# Instalar Turborepo
pnpm install

# Criar estrutura de diretórios
mkdir -p apps/web apps/admin packages/ui packages/types packages/utils
```

---

## Turborepo — Caching de Builds

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],      // aguarda build das dependências
      "outputs": [".next/**", "dist/**", "build/**"],
      "cache": true
    },
    "dev": {
      "cache": false,               // dev nunca usa cache
      "persistent": true            // mantém rodando
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"],
      "cache": true
    },
    "lint": {
      "outputs": [],
      "cache": true
    },
    "type-check": {
      "dependsOn": ["^build"],
      "cache": true
    },
    "clean": {
      "cache": false
    }
  }
}
```

```bash
# Comandos Turborepo
turbo dev                          # roda dev em todos os apps em paralelo
turbo build                        # build apenas o que mudou (cache inteligente)
turbo build --filter=@wolf/web     # build só de um app específico
turbo build --filter=@wolf/web...  # build do web e suas dependências
turbo test --filter=[HEAD^1]       # testa só o que mudou desde o último commit
```

---

## Packages/ui — Componente Compartilhado

```json
// packages/ui/package.json
{
  "name": "@wolf/ui",
  "version": "0.1.0",
  "private": true,
  "main": "./dist/index.js",
  "module": "./dist/index.mjs",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "dev": "tsup src/index.ts --format cjs,esm --dts --watch",
    "lint": "eslint src",
    "type-check": "tsc --noEmit"
  },
  "peerDependencies": {
    "react": ">=18",
    "react-dom": ">=18"
  },
  "devDependencies": {
    "tsup": "^8.0.0",
    "typescript": "^5.0.0",
    "@wolf/config": "workspace:*"
  }
}
```

```typescript
// packages/ui/src/components/Button.tsx
import type { ButtonHTMLAttributes } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
}

export function Button({
  variant = 'primary',
  size = 'md',
  className = '',
  ...props
}: ButtonProps) {
  const variants = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700',
    secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    ghost: 'bg-transparent hover:bg-gray-100',
  }
  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2',
    lg: 'px-6 py-3 text-lg',
  }

  return (
    <button
      className={`rounded-md font-medium transition-colors ${variants[variant]} ${sizes[size]} ${className}`}
      {...props}
    />
  )
}
```

```typescript
// packages/ui/src/index.ts — barrel export
export { Button } from './components/Button'
export { Input } from './components/Input'
export { Modal } from './components/Modal'
// exportar tudo que é parte da UI library
```

---

## Usando Packages Internos

```json
// apps/web/package.json
{
  "name": "@wolf/web",
  "dependencies": {
    "@wolf/ui": "workspace:*",
    "@wolf/types": "workspace:*",
    "@wolf/utils": "workspace:*"
  }
}
```

```typescript
// apps/web/src/app/page.tsx
import { Button } from '@wolf/ui'
import type { User } from '@wolf/types'
import { formatDate } from '@wolf/utils'
```

---

## Configuração TypeScript Compartilhada

```json
// shared/config/tsconfig.base.json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noUncheckedIndexedAccess": true,
    "skipLibCheck": true,
    "esModuleInterop": true
  }
}
```

```json
// packages/ui/tsconfig.json — extends a base
{
  "extends": "@wolf/config/tsconfig.base.json",
  "compilerOptions": {
    "jsx": "react-jsx",
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["dist", "node_modules"]
}
```

---

## Trade-offs do Monorepo

```
VANTAGENS:
✓ Compartilhamento de código sem publicar pacotes
✓ Refactoring atômico (muda interface em packages/ → TypeScript indica onde atualizar)
✓ CI pode testar apenas o que mudou (Turborepo)
✓ Configuração centralizada (ESLint, TypeScript, Prettier)
✓ Uma única PR pode alterar múltiplos apps relacionados

DESVANTAGENS:
✗ Setup mais complexo inicial
✗ Git clone maior (todo o histórico de todos os apps)
✗ CI mais lento sem caching configurado corretamente
✗ Curva de aprendizado para devs novos
✗ Conflitos de dependência entre apps (versões diferentes)

MITIGAÇÕES:
- Turborepo para caching inteligente de CI
- pnpm para instalação eficiente com hard links
- GitHub Actions matrix para paralelizar CI por app
- Documenta bem a estrutura no README raiz
```

---

## Checklist Monorepo Wolf

```
Estrutura
[ ] pnpm-workspace.yaml configurado
[ ] Diretórios apps/, packages/, shared/ criados
[ ] Nomes de packages com escopo (@wolf/nome)
[ ] tsconfig.base.json compartilhado e extendido

Turborepo
[ ] turbo.json com tasks configuradas
[ ] Cache ativado para build, test, lint
[ ] dependsOn correto (packages buildam antes dos apps)
[ ] Remote cache configurado (Vercel ou self-hosted)

Packages Internos
[ ] Build dos packages gera tipos (.d.ts)
[ ] exports no package.json configurado corretamente
[ ] workspace:* como versão de dependências internas

CI
[ ] Pipeline roda turbo build/test (aproveita cache)
[ ] Publica mudanças apenas nos apps afetados
[ ] Cache do Turborepo persistido entre runs (CI)
```
