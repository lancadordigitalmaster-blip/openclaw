# readme.md — Quill Sub-Skill: README de Projeto
# Ativa quando: "README", "documenta projeto", "visão geral"

## Propósito

Gerar e manter READMEs que um dev novo consiga usar em menos de 10 minutos. README ruim = tempo perdido de toda a equipe. README bom = onboarding rápido, menos perguntas repetidas.

---

## Template README Padrão Wolf

```markdown
# Nome do Projeto

> Tagline de uma linha: o que faz e por que importa.

## O que é

Parágrafo direto. Qual problema resolve, para quem, como. Sem jargão desnecessário.

## Pré-requisitos

- Node.js >= 20.x
- pnpm >= 9.x
- Docker >= 24.x
- Acesso à VPN Wolf (solicitar ao @infra)

## Instalação

```bash
git clone git@github.com:wolf-agency/nome-do-projeto.git
cd nome-do-projeto
pnpm install
cp .env.example .env
# Editar .env com os valores corretos (ver seção Variáveis de Ambiente)
pnpm db:migrate
pnpm dev
```

## Variáveis de Ambiente

| Variável               | Obrigatória | Descrição                          | Exemplo                        |
|------------------------|-------------|-------------------------------------|-------------------------------|
| `DATABASE_URL`         | Sim         | Connection string PostgreSQL        | `postgresql://user:pass@host` |
| `REDIS_URL`            | Sim         | Connection string Redis             | `redis://localhost:6379`      |
| `META_ADS_TOKEN`       | Condicional | Token Meta Ads (somente em prod)    | `EAAxxxxx`                    |
| `JWT_SECRET`           | Sim         | Segredo para assinar JWTs           | string aleatória >= 32 chars  |

> Valores reais no 1Password, vault `Wolf Engineering`.

## Como Usar

### Desenvolvimento

```bash
pnpm dev          # inicia em modo watch
pnpm test         # roda todos os testes
pnpm test:watch   # testes em modo watch
pnpm lint         # ESLint + Prettier
pnpm typecheck    # TypeScript sem emitir
```

### Build

```bash
pnpm build        # build de produção
pnpm start        # inicia o build
```

## Arquitetura

```
src/
├── api/          # Controllers e rotas HTTP
├── services/     # Lógica de negócio
├── repositories/ # Camada de dados
├── jobs/         # Background jobs
├── lib/          # Utilitários e helpers
└── types/        # Tipos TypeScript globais
```

Diagrama de arquitetura: [docs/architecture.md](docs/architecture.md)

## Desenvolvimento

- Branch padrão: `main`
- Feature branches: `feat/descricao-curta`
- Fixes: `fix/descricao-curta`
- PRs requerem aprovação de 1 reviewer
- CI deve passar antes do merge

## Deploy

```bash
# Staging (automático via CI no push para main)
# Produção (manual via pipeline):
pnpm run deploy:prod
```

Detalhes: [docs/deployment.md](docs/deployment.md)

## Contribuindo

1. Crie branch a partir de `main`
2. Faça suas alterações
3. `pnpm test && pnpm lint && pnpm typecheck`
4. Abra PR com descrição clara do que muda e por quê
5. Adicione entrada no CHANGELOG.md

## Suporte

- Issues: GitHub Issues deste repositório
- Urgente: canal `#eng-suporte` no Slack Wolf
- Owner técnico: @nome-do-owner
```

---

## Princípios Wolf para README

**Exemplos concretos > teoria**
Mostre o comando exato, não "instale as dependências". Mostre `pnpm install`, não "instale com seu gerenciador de pacotes preferido".

**Comandos exatos > descrições**
Se precisa rodar algo, escreve o comando. Se tem flags específicas, inclui. Se tem uma ordem, documenta a ordem.

**README = contrato**
Se o README diz que `pnpm dev` funciona, tem que funcionar. README desatualizado é pior que README inexistente — engana.

**Um arquivo, um README**
Não fragmenta informações entre 5 arquivos quando pode estar em um. Links para detalhes, mas o essencial fica no README.

---

## Checklist de README Completo

### Estrutura
- [ ] Nome e tagline na primeira linha
- [ ] Seção "O que é" com 1-3 parágrafos
- [ ] Pré-requisitos com versões específicas
- [ ] Instalação com comandos passo a passo
- [ ] Tabela de variáveis de ambiente completa
- [ ] Seção "Como usar" com exemplos reais
- [ ] Descrição da arquitetura de pastas
- [ ] Instruções de desenvolvimento
- [ ] Instruções de deploy
- [ ] Como contribuir

### Qualidade
- [ ] Todos os comandos testados e funcionando
- [ ] Links internos não estão quebrados
- [ ] Variáveis de ambiente têm exemplos (não valores reais)
- [ ] Versões dos pré-requisitos especificadas
- [ ] Seção de suporte com contato real

### Manutenção
- [ ] Data de última atualização visível
- [ ] Owner identificado
- [ ] Processo para reportar README desatualizado

---

## Protocolo Quill: Revisão de README

1. Ler o README do zero, como se fosse novo no projeto
2. Seguir cada passo de instalação em máquina limpa (ou container)
3. Verificar se todos os comandos executam sem erro
4. Confirmar que variáveis de ambiente na tabela batem com `.env.example`
5. Verificar links internos e externos
6. Atualizar data de última revisão

**Frequência de revisão:** A cada release major ou quando onboarding reportar problema.
