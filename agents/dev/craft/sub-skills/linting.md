# linting.md — Craft Sub-Skill: Linting e Formatação
# Ativa quando: "lint", "ESLint", "Prettier", "formatação", "código sujo"

---

## Padrão Wolf: Configuração Completa

Código que passa no lint é código que pode ser revisado. Sem formatação manual — automático.

---

## ESLint — Config Padrão Wolf (TypeScript + Next.js)

```bash
# Instalar
npm install --save-dev \
  eslint \
  @typescript-eslint/eslint-plugin \
  @typescript-eslint/parser \
  eslint-config-next \
  eslint-plugin-import \
  eslint-import-resolver-typescript
```

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "plugin:@typescript-eslint/recommended-type-checked",
    "plugin:@typescript-eslint/stylistic-type-checked"
  ],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "project": true,
    "tsconfigRootDir": "."
  },
  "plugins": ["@typescript-eslint", "import"],
  "rules": {
    // TypeScript strict
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unused-vars": ["error", {
      "argsIgnorePattern": "^_",
      "varsIgnorePattern": "^_"
    }],
    "@typescript-eslint/consistent-type-imports": ["error", {
      "prefer": "type-imports"
    }],
    "@typescript-eslint/no-floating-promises": "error",
    "@typescript-eslint/no-misused-promises": "error",

    // Imports organizados
    "import/order": ["error", {
      "groups": [
        "builtin",
        "external",
        "internal",
        ["parent", "sibling"],
        "index",
        "type"
      ],
      "newlines-between": "always",
      "alphabetize": { "order": "asc", "caseInsensitive": true }
    }],
    "import/no-duplicates": "error",

    // Boas práticas
    "no-console": ["warn", { "allow": ["warn", "error"] }],
    "prefer-const": "error",
    "no-var": "error"
  },
  "ignorePatterns": [
    "node_modules/",
    ".next/",
    "dist/",
    "*.config.js",
    "*.config.mjs"
  ]
}
```

---

## Prettier — Config Wolf

```bash
npm install --save-dev prettier eslint-config-prettier
```

```json
// .prettierrc
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "bracketSpacing": true,
  "arrowParens": "always",
  "endOfLine": "lf",
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

```
// .prettierignore
node_modules
.next
dist
build
*.min.js
*.min.css
pnpm-lock.yaml
package-lock.json
```

```json
// .eslintrc.json — adicionar prettier no final dos extends
{
  "extends": [
    "next/core-web-vitals",
    "plugin:@typescript-eslint/recommended-type-checked",
    "prettier"  // sempre por último — desativa regras que conflitam com Prettier
  ]
}
```

---

## Biome — Alternativa All-in-One (Mais Rápido)

Para projetos novos sem necessidade de plugins ESLint específicos. 10-100x mais rápido que ESLint + Prettier.

```bash
npm install --save-dev @biomejs/biome
npx @biomejs/biome init
```

```json
// biome.json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "correctness": {
        "noUnusedVariables": "error",
        "noUnusedImports": "error"
      },
      "suspicious": {
        "noExplicitAny": "error",
        "noConsole": "warn"
      },
      "style": {
        "useConst": "error",
        "noVar": "error",
        "useTemplate": "error"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "formatWithErrors": false,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100,
    "lineEnding": "lf"
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingCommas": "all",
      "semicolons": "asNeeded"
    }
  },
  "files": {
    "ignore": ["node_modules", ".next", "dist", "build"]
  }
}
```

```json
// package.json com Biome
{
  "scripts": {
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write ."
  }
}
```

---

## Ruff — Para Python (Substitui flake8 + black + isort)

```bash
# Instalar
pip install ruff  # ou: uv add ruff --dev
```

```toml
# pyproject.toml
[tool.ruff]
target-version = "py312"
line-length = 100
exclude = [
    ".git",
    ".venv",
    "__pycache__",
    "migrations",
]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort (imports)
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "UP",   # pyupgrade (atualiza sintaxe antiga)
    "N",    # pep8-naming
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "ANN",  # flake8-annotations (type hints)
]
ignore = [
    "ANN101", # missing type annotation for self
    "ANN102", # missing type annotation for cls
]

[tool.ruff.lint.isort]
known-first-party = ["app"]
force-single-line = false

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
line-ending = "lf"
```

```bash
# Comandos ruff
ruff check .              # verifica erros
ruff check --fix .        # corrige automaticamente
ruff format .             # formata (substitui black)
ruff check --watch .      # modo watch
```

---

## Integração com VS Code

```json
// .vscode/settings.json — commitar no projeto
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "never"  // deixa o ESLint/Biome gerenciar
  },
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  },
  "eslint.validate": ["typescript", "typescriptreact", "javascript"],
  "typescript.tsdk": "node_modules/typescript/lib"
}

// .vscode/extensions.json — extensions recomendadas
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "charliermarsh.ruff",
    "bradlc.vscode-tailwindcss",
    "prisma.prisma"
  ]
}
```

---

## Auto-fix na Linha de Comando

```bash
# JavaScript / TypeScript
eslint --fix src/           # ESLint auto-fix
prettier --write src/       # Prettier format
npx biome check --write .   # Biome lint + format

# Python
ruff check --fix .          # lint fix
ruff format .               # format

# Rodar tudo de uma vez (npm script)
npm run lint:fix
```

---

## Checklist Linting Wolf

```
Setup
[ ] ESLint (ou Biome) configurado com TypeScript strict
[ ] Prettier (ou Biome) configurado com config Wolf
[ ] Ruff configurado para projetos Python
[ ] .eslintignore / biome.json ignore atualizado

VS Code
[ ] .vscode/settings.json commitado no repo
[ ] .vscode/extensions.json commitado no repo
[ ] Format on save ativado para todos os tipos de arquivo relevantes

CI
[ ] lint roda no CI antes de merge
[ ] type-check roda separado (tsc --noEmit)
[ ] CI falha se lint falhar (não apenas aviso)

Automação
[ ] Husky pre-commit roda lint-staged
[ ] Apenas arquivos modificados são lintados no pre-commit (performance)
[ ] Sem "eslint-disable" sem comentário justificando o motivo
```
