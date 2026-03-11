# git-workflow.md — Craft Sub-Skill: Git Workflow
# Ativa quando: "git", "commit", "hook", "husky", "pre-commit", "conventional"

---

## Conventional Commits Wolf

Formato: `tipo(escopo): descrição curta`

| Tipo | Quando Usar | Exemplo |
|------|-------------|---------|
| `feat` | Nova funcionalidade | `feat(auth): adiciona login com Google` |
| `fix` | Correção de bug | `fix(checkout): corrige cálculo de frete` |
| `perf` | Melhoria de performance | `perf(query): adiciona índice na tabela pedidos` |
| `refactor` | Refatoração sem nova feature ou fix | `refactor(auth): extrai lógica de token para serviço` |
| `test` | Adiciona ou corrige testes | `test(usuarios): adiciona testes de integração` |
| `docs` | Documentação | `docs(api): atualiza exemplos de autenticação` |
| `ci` | CI/CD | `ci: adiciona step de bundle size check` |
| `chore` | Manutenção (deps, config) | `chore: atualiza next.js para 15.1` |
| `revert` | Reverte commit anterior | `revert: feat(auth): adiciona login com Google` |

**Regra Wolf:** Mensagem no imperativo, em português ou inglês consistente, sem ponto final.

```
BONS COMMITS:
feat(produtos): implementa busca com filtros avançados
fix(pagamento): corrige loop infinito no retry de PIX
perf(dashboard): reduz queries de 12 para 3 com eager loading
chore(deps): atualiza prisma para 5.18

RUINS:
"ajustes"
"corrigindo bugs"
"WIP"
"fixes #123"  ← referência sem contexto
"feat: várias coisas novas"  ← muito amplo
```

---

## Husky + lint-staged

```bash
# Instalação
npm install --save-dev husky lint-staged

# Inicializar husky
npx husky init
```

```bash
# .husky/pre-commit
#!/bin/sh
npx lint-staged
```

```bash
# .husky/commit-msg
#!/bin/sh
npx --no -- commitlint --edit $1
```

```json
// package.json — lint-staged config
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{js,jsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ],
    "*.py": [
      "ruff check --fix",
      "ruff format"
    ]
  }
}
```

```bash
# Garantir que hooks são executáveis após clone
# package.json
{
  "scripts": {
    "prepare": "husky"  // roda automaticamente após npm install
  }
}
```

---

## commitlint — Valida Mensagens de Commit

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
```

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Tipos permitidos Wolf
    'type-enum': [
      2, // nível: error
      'always',
      ['feat', 'fix', 'perf', 'refactor', 'test', 'docs', 'ci', 'chore', 'revert'],
    ],
    // Corpo da mensagem: opcional mas sem limite de tamanho
    'body-max-line-length': [0, 'always'],
    // Subject: máximo 100 caracteres
    'subject-max-length': [2, 'always', 100],
    // Sem ponto final
    'subject-full-stop': [2, 'never', '.'],
    // Case: sem forçar lowercase (permite palavras específicas maiúsculas)
    'subject-case': [0],
  },
}
```

---

## Branch Naming Wolf

```bash
# Formato: tipo/descricao-kebab-case

feat/login-google
feat/checkout-pix
fix/calculo-frete-nulo
fix/loop-infinito-pagamento
chore/update-nextjs-15
perf/indices-tabela-pedidos
docs/api-autenticacao
ci/bundle-size-check

# Regras:
# - Sempre em lowercase
# - Hifens entre palavras (não underscore)
# - Curto mas descritivo (max 40 chars após o tipo/)
# - Começa com o tipo (igual ao commit type)
```

```bash
# Criar branch com padrão
git checkout -b feat/minha-feature

# Ou com script helper (adicionar ao .bashrc / .zshrc)
gcb() {
  git checkout -b "$1"
  echo "Branch criada: $(git branch --show-current)"
}
# uso: gcb feat/nova-feature
```

---

## PR Template Wolf

```markdown
<!-- .github/pull_request_template.md -->

## O que foi feito

<!-- Descreva o que foi implementado ou corrigido. Uma linha clara. -->

## Por que foi feito

<!-- Contexto: qual problema resolve? link para issue se existir -->
Closes #

## Tipo de mudança

- [ ] feat: nova funcionalidade
- [ ] fix: correção de bug
- [ ] perf: melhoria de performance
- [ ] refactor: refatoração sem mudança de comportamento
- [ ] chore: manutenção, dependências
- [ ] docs: documentação

## Checklist

- [ ] Código passa no lint (`npm run lint`)
- [ ] Testes passam (`npm test`)
- [ ] Testes adicionados para novo comportamento
- [ ] Sem `console.log` esquecido
- [ ] Sem `.env` ou credenciais no código
- [ ] Breaking changes documentados abaixo (se houver)

## Screenshots (se mudança visual)

<!-- Antes / Depois se relevante -->

## Breaking Changes

<!-- Se existirem, detalhar aqui -->
```

---

## Git Flow Wolf — Simplificado

```
ESTRUTURA DE BRANCHES:
======================
main          → produção (sempre deployável)
staging       → ambiente de homologação
feat/*        → features em desenvolvimento
fix/*         → bugs urgentes
chore/*       → manutenção

FLUXO PADRÃO:
=============
1. Cria branch a partir de main
   git checkout main && git pull
   git checkout -b feat/minha-feature

2. Desenvolve com commits convencionais
   git commit -m "feat(auth): implementa JWT refresh token"

3. Push e abre PR para main
   git push -u origin feat/minha-feature
   gh pr create --title "feat(auth): JWT refresh token" --body "..."

4. CI roda (type-check, lint, test, build)

5. Review e merge (squash merge para histórico limpo)

6. Branch deletada automaticamente após merge

PARA HOTFIXES:
==============
git checkout main
git checkout -b fix/bug-critico
# corrige
git push
gh pr create --label "hotfix" --title "fix: ..."
# review rápido, merge, deploy imediato
```

---

## Comandos Git Úteis Wolf

```bash
# Ver log limpo e compacto
git log --oneline --graph --decorate --all | head -20

# Stash com nome descritivo
git stash push -m "WIP: implementando filtros de produto"
git stash list
git stash pop stash@{0}

# Amend no último commit (antes de push)
git add .
git commit --amend --no-edit  # mantém a mensagem
git commit --amend -m "fix(auth): nova mensagem"  # troca a mensagem

# Reset suave (desfaz commit, mantém mudanças staged)
git reset --soft HEAD~1

# Ver o que mudou no PR vs main
git diff main...HEAD --stat

# Cherry-pick (aplicar commit específico em outra branch)
git cherry-pick abc1234

# Limpar branches locais já mergeadas
git branch --merged main | grep -v "^[ *]*main$" | xargs git branch -d
```

---

## Configuração Global Wolf (Uma Vez por Máquina)

```bash
# Identidade
git config --global user.name "Seu Nome"
git config --global user.email "seu@wolfagency.com.br"

# Editor para mensagens de commit
git config --global core.editor "code --wait"  # VS Code

# Default branch
git config --global init.defaultBranch main

# Pull rebase (evita merge commits desnecessários)
git config --global pull.rebase true

# Auto-stash ao fazer rebase
git config --global rebase.autoStash true

# Aliases úteis
git config --global alias.st "status -sb"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.undo "reset --soft HEAD~1"
```

---

## Checklist Git Workflow Wolf

```
Setup do Projeto
[ ] Husky instalado e hooks configurados (pre-commit, commit-msg)
[ ] lint-staged configurado (só lint arquivos modificados)
[ ] commitlint instalado e validando tipos Wolf
[ ] PR template configurado em .github/pull_request_template.md
[ ] Branch protection em main (requer PR + CI verde + 1 review)

Por Commit
[ ] Mensagem no formato tipo(escopo): descrição
[ ] Commit atômico (uma coisa por commit)
[ ] Sem arquivos de debug, console.log, ou .env commitados

Por PR
[ ] Branch com nome no padrão (feat/, fix/, etc.)
[ ] PR title segue Conventional Commits
[ ] Checklist do PR template preenchido
[ ] CI verde antes de solicitar review

Higiene
[ ] Branches locais limpas após merge
[ ] Main sempre em estado deployável
[ ] Sem commits diretos em main (force push bloqueado)
```
