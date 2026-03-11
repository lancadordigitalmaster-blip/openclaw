# onboarding.md — Quill Sub-Skill: Onboarding de Devs
# Ativa quando: "onboarding", "novo dev", "como começar", "setup"

## Propósito

Meta objetiva: novo dev rodando o projeto localmente em menos de 15 minutos. Se passa disso, o onboarding está quebrado. Quill mantém esse SLA e testa mensalmente.

---

## Template de Onboarding Wolf

```markdown
# Onboarding — [Nome do Projeto]

**Meta:** Você estará rodando isso em < 15 minutos.
**Dificuldades?** Canal `#eng-onboarding` no Slack ou @nome-do-owner.

---

## Pré-requisitos

Instale antes de começar:

| Ferramenta | Versão | Instalação |
|-----------|--------|------------|
| Node.js | >= 20.x | `nvm install 20` |
| pnpm | >= 9.x | `npm install -g pnpm@9` |
| Docker Desktop | >= 24.x | https://docker.com/download |
| Git | qualquer | já instalado no Mac |

**Acessos necessários** (solicite ao seu manager antes de começar):
- [ ] GitHub: organização `wolf-agency`
- [ ] 1Password: vault `Wolf Engineering`
- [ ] VPN Wolf (instruções no Notion: Wolf/Infra/VPN)

---

## Setup (passo a passo)

### 1. Clone o repositório

```bash
git clone git@github.com:wolf-agency/nome-do-projeto.git
cd nome-do-projeto
```

Se der erro de permissão SSH: [configure sua chave SSH](https://docs.github.com/pt/authentication/connecting-to-github-with-ssh).

### 2. Instale dependências

```bash
pnpm install
```

Tempo esperado: 1-2 minutos.

### 3. Configure variáveis de ambiente

```bash
cp .env.example .env
```

Abra o 1Password, vault `Wolf Engineering`, item `[Nome do Projeto] - Dev`. Copie os valores para `.env`.

**Variáveis que VOCÊ precisa personalizar:**
- `DATABASE_URL`: não muda (aponta para Docker local)
- `META_ADS_TOKEN`: pegar no painel pessoal Meta Business (opcional para dev)

### 4. Inicie serviços de infraestrutura

```bash
docker compose up -d
```

**Saída esperada:**
```
✔ Container postgres-local    Started
✔ Container redis-local       Started
```

### 5. Rode as migrations

```bash
pnpm db:migrate
```

### 6. Popule dados iniciais

```bash
pnpm db:seed
```

Isso cria:
- Usuário admin: `admin@wolf.test` / `wolf123`
- 3 clientes de exemplo com campanhas

### 7. Inicie o servidor

```bash
pnpm dev
```

**Acesse:** http://localhost:3000

Login com `admin@wolf.test` / `wolf123`. Se aparecer o dashboard, está funcionando.

---

## Onde Está o Quê

```
src/
├── api/          # Rotas e controllers HTTP
│   └── [recurso]/
│       ├── [recurso].routes.ts      # Definição de rotas
│       ├── [recurso].controller.ts  # Handler das requisições
│       └── [recurso].schema.ts      # Validação de input (Zod)
├── services/     # Lógica de negócio (sem dependência de HTTP)
├── repositories/ # Queries ao banco de dados (Prisma)
├── jobs/         # Background jobs (BullMQ)
├── lib/          # Utilitários: logger, http client, cache
└── types/        # Tipos TypeScript compartilhados

prisma/
├── schema.prisma # Schema do banco de dados
└── migrations/   # Histórico de migrations

docs/
├── adr/          # Architecture Decision Records
├── runbooks/     # Runbooks operacionais
└── api/          # Documentação OpenAPI
```

---

## Como Contribuir

1. Pegar task no ClickUp (coluna `Backlog`)
2. Criar branch: `feat/descricao-curta` ou `fix/descricao-curta`
3. Desenvolver
4. Antes do PR: `pnpm test && pnpm lint && pnpm typecheck`
5. Abrir PR com descrição clara
6. Adicionar entrada no `CHANGELOG.md`
7. Solicitar review de 1 pessoa do time

**Convenção de commits:** `feat:`, `fix:`, `chore:`, `docs:` ([Conventional Commits](https://conventionalcommits.org))

---

## Quem Perguntar

| Área | Pessoa | Contato |
|------|--------|---------|
| Dúvidas de negócio | @product-owner | Slack DM |
| Infra/DevOps | @eng-infra | Canal #eng-infra |
| Arquitetura | @tech-lead | Canal #eng-arquitetura |
| Onboarding | @owner-do-projeto | Canal #eng-onboarding |

---

## Primeiro Dia — O que Explorar

1. Ler [docs/adr/](docs/adr/) — entender decisões principais do projeto
2. Rodar os testes: `pnpm test`
3. Explorar o banco de dados: `pnpm prisma studio`
4. Fazer uma pequena mudança e ver o hot reload funcionar
5. Ler o CHANGELOG para entender evolução recente
```

---

## Checklist de Onboarding Completo

### Conteúdo
- [ ] Pré-requisitos com versões exatas e links de instalação
- [ ] Passo a passo com comandos numerados
- [ ] Saída esperada para comandos críticos
- [ ] Instrução de obtenção de credenciais (1Password, etc.)
- [ ] Mapa do repositório (onde está o quê)
- [ ] Guia de contribuição (branch naming, commit convention)
- [ ] Quem perguntar (com área e canal específico)
- [ ] Sugestões para o primeiro dia

### Qualidade
- [ ] Testado em máquina limpa (sem cache pré-existente)
- [ ] Testado por alguém que NÃO conhece o projeto
- [ ] Tempo real de setup cronometrado (meta: < 15 min)
- [ ] Todos os links funcionando

### Manutenção
- [ ] Owner definido para manutenção
- [ ] Data de última atualização registrada
- [ ] Processo para reportar onboarding quebrado (canal Slack)

---

## Como Manter o Onboarding Atualizado

**Teste mensal (Quill executa ou delega):**

```bash
# Script de validação de onboarding
#!/bin/bash
echo "=== Teste de Onboarding Wolf ==="
echo "Iniciado em: $(date)"

# Criar ambiente limpo
rm -rf /tmp/onboarding-test
mkdir /tmp/onboarding-test
cd /tmp/onboarding-test

# Simular passos
git clone git@github.com:wolf-agency/nome-do-projeto.git test-repo
cd test-repo
time pnpm install
cp .env.example .env
docker compose up -d
pnpm db:migrate
pnpm db:seed
timeout 30 pnpm dev &
sleep 15
curl -f http://localhost:3000/health || echo "FALHA: servidor não respondeu"

echo "Finalizado em: $(date)"
```

**Quando atualizar obrigatoriamente:**
- Quando versão de Node.js/pnpm mudar
- Quando adicionar/remover variável de ambiente obrigatória
- Quando estrutura de pastas mudar significativamente
- Quando processo de contribuição mudar
- Quando novo dev reportar problema durante onboarding
