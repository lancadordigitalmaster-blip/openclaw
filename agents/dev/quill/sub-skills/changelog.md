# changelog.md — Quill Sub-Skill: CHANGELOG e Release Notes
# Ativa quando: "CHANGELOG", "release notes", "o que mudou", "versão"

## Propósito

CHANGELOG comunica o que mudou entre versões para usuários, devs e stakeholders. Seguimos [Keep a Changelog](https://keepachangelog.com) + [Semantic Versioning](https://semver.org).

**Regra Wolf:** toda PR mergeada em main = entrada no CHANGELOG antes do merge.

---

## Formato Padrão Wolf

```markdown
# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
Versionamento: [Semantic Versioning](https://semver.org/lang/pt-BR/)

## [Unreleased]

### Adicionado
- Integração com Google Analytics 4 para rastreamento de conversões

### Modificado
- Performance de consulta de campanhas melhorada (índice adicionado)

---

## [2.4.0] - 2024-12-01

### Adicionado
- Endpoint `POST /campaigns/bulk` para criação em lote de até 50 campanhas
- Suporte a webhook de eventos de campanha (ver docs/webhooks.md)
- Campo `attribution_window` em AdSet (valores: 1d, 7d, 28d)

### Modificado
- `GET /campaigns` agora retorna campo `spend_ytd` por padrão
- Limite de paginação aumentado de 50 para 100 itens

### Corrigido
- Bug onde campanhas arquivadas apareciam em listagem padrão (#234)
- Timeout em sincronização Meta Ads para contas com > 10k campanhas

---

## [2.3.1] - 2024-11-20

### Corrigido
- Erro 500 ao criar campanha com budget em formato string (#289)
- Race condition em processamento de webhooks duplicados

### Segurança
- Atualização de dependência: `jsonwebtoken` 8.x → 9.x (CVE-2022-23529)

---

## [2.3.0] - 2024-11-10

### Adicionado
- Dashboard de métricas em tempo real
- Exportação de relatórios em formato CSV e XLSX

### Removido
- Endpoint deprecated `GET /campaigns/legacy` (removido após 6 meses de aviso)
- Suporte a autenticação via API Key na query string (usar header Authorization)

[Unreleased]: https://github.com/wolf-agency/projeto/compare/v2.4.0...HEAD
[2.4.0]: https://github.com/wolf-agency/projeto/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/wolf-agency/projeto/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/wolf-agency/projeto/compare/v2.2.0...v2.3.0
```

---

## Semantic Versioning — Regras Wolf

| Tipo de Mudança | Versão | Exemplo |
|-----------------|--------|---------|
| Breaking change (API incompatível, remove campo, altera contrato) | MAJOR (X.0.0) | 2.0.0 → 3.0.0 |
| Nova funcionalidade backward-compatible | MINOR (x.Y.0) | 2.3.0 → 2.4.0 |
| Bug fix backward-compatible | PATCH (x.y.Z) | 2.4.0 → 2.4.1 |
| Security fix (mesmo que minor) | PATCH ou MINOR | Depende do impacto |

**Dúvida sobre breaking change?** Se cliente precisa mudar código pra continuar funcionando = breaking = MAJOR.

---

## Categorias do CHANGELOG

| Categoria | Quando Usar |
|-----------|-------------|
| **Adicionado** | Funcionalidade nova |
| **Modificado** | Mudança em funcionalidade existente (não quebra) |
| **Depreciado** | Será removido em versão futura |
| **Removido** | Funcionalidade removida (normalmente = breaking) |
| **Corrigido** | Bug fix |
| **Segurança** | Vulnerabilidade corrigida, dependência atualizada por CVE |

---

## Automação com Conventional Commits

### Formato de Commit Wolf

```
tipo(escopo): descrição curta

corpo opcional com mais detalhes

BREAKING CHANGE: descrição da breaking change (se aplicável)
```

**Tipos:**
- `feat`: nova funcionalidade → bump MINOR
- `fix`: bug fix → bump PATCH
- `feat!` ou `BREAKING CHANGE:` → bump MAJOR
- `docs`, `chore`, `refactor`, `test`, `style`, `ci` → sem bump

**Exemplos:**
```bash
git commit -m "feat(campaigns): adiciona endpoint de bulk creation"
git commit -m "fix(webhooks): corrige race condition em duplicatas"
git commit -m "feat!: remove endpoint /campaigns/legacy"
```

### Gerar CHANGELOG Automático

```bash
# Instalar conventional-changelog
pnpm add -D conventional-changelog-cli

# Gerar desde última tag
pnpm conventional-changelog -p angular -i CHANGELOG.md -s

# Configurar no package.json
```

```json
{
  "scripts": {
    "changelog": "conventional-changelog -p angular -i CHANGELOG.md -s",
    "version:patch": "npm version patch && pnpm changelog",
    "version:minor": "npm version minor && pnpm changelog",
    "version:major": "npm version major && pnpm changelog"
  }
}
```

### Com release-it (mais completo)

```bash
pnpm add -D release-it @release-it/conventional-changelog
```

```json
// .release-it.json
{
  "plugins": {
    "@release-it/conventional-changelog": {
      "preset": "angular",
      "infile": "CHANGELOG.md"
    }
  },
  "git": {
    "commitMessage": "chore: release v${version}",
    "tagName": "v${version}"
  },
  "github": {
    "release": true
  }
}
```

```bash
# Fazer release
pnpm release-it        # interativo
pnpm release-it patch  # forçar patch
pnpm release-it minor  # forçar minor
```

---

## Processo Wolf: PR → CHANGELOG

1. Dev abre PR com mudança
2. Na descrição da PR, inclui qual entrada vai no CHANGELOG
3. Quill valida: PR que muda comportamento externo sem entrada no CHANGELOG = **bloqueado**
4. Antes do merge: revisor confirma entrada no CHANGELOG
5. Após merge: se é release, fazer bump de versão e publicar

**Script de validação no CI:**

```bash
#!/bin/bash
# Verifica se CHANGELOG.md foi modificado em PRs que alteram src/
SRC_CHANGED=$(git diff --name-only origin/main...HEAD | grep "^src/" | wc -l)
CHANGELOG_CHANGED=$(git diff --name-only origin/main...HEAD | grep "^CHANGELOG.md" | wc -l)

if [ "$SRC_CHANGED" -gt 0 ] && [ "$CHANGELOG_CHANGED" -eq 0 ]; then
  echo "ERRO: Mudanças em src/ sem atualização no CHANGELOG.md"
  exit 1
fi
```

---

## Checklist de CHANGELOG

- [ ] Arquivo `CHANGELOG.md` na raiz do repositório
- [ ] Seção `[Unreleased]` no topo para acúmulo de mudanças
- [ ] Cada release tem data no formato YYYY-MM-DD
- [ ] Breaking changes claramente sinalizadas
- [ ] Links de diff entre versões no rodapé
- [ ] Conventional commits configurado no repositório
- [ ] Script de geração automática no `package.json`
- [ ] CI valida presença de entrada no CHANGELOG em PRs relevantes
- [ ] Process documentado no CONTRIBUTING.md
