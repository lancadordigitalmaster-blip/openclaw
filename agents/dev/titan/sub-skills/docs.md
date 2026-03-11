# docs.md — Titan Sub-Skill: Documentação Técnica
# Ativa quando: "documenta", "README", "explica como funciona", "runbook"

---

## PROTOCOLO DE DOCUMENTAÇÃO TÉCNICA

```
PRINCÍPIO FUNDAMENTAL: Documentação que ninguém lê não existe.
Escreve para o dev que vai manter isso às 23h numa sexta-feira.

ANTES DE ESCREVER:
  □ Quem vai ler isso? (dev novo? dev sênior? ops? cliente?)
  □ Qual decisão ou ação essa documentação vai habilitar?
  □ O documento mais curto que cumpre o objetivo é o melhor

REGRAS DE ESCRITA TÉCNICA WOLF:
  1. Concrete first — exemplos antes de abstrações
  2. Passive voice kills clarity — "o sistema faz X", não "X é feito"
  3. Uma ideia por parágrafo — não agrupa conceitos sem necessidade
  4. Code blocks para tudo que é código — nunca inline junto com texto longo
  5. Headers navegáveis — alguém que leu uma vez volta para achar algo específico
```

---

## TIPOS DE DOCUMENTAÇÃO

### README — Porta de Entrada do Projeto

```
ESTRUTURA OBRIGATÓRIA:
  1. O que é (1-2 linhas) — sem jargão
  2. Por que existe / o que resolve
  3. Como rodar em 5 minutos (Quick Start)
  4. Referência completa (configuração, variáveis, endpoints)
  5. Como contribuir / como fazer deploy

CHECKLIST DE README:
  □ Roda os comandos do Quick Start do zero numa máquina limpa?
  □ Todas as variáveis de ambiente documentadas com exemplo?
  □ Comportamento de erro documentado (o que acontece quando X falha)?
  □ Quem manter: quem é dono, como reportar bug?
  □ Versão atual e data de última atualização?
```

### ADR — Architecture Decision Record

```
QUANDO ESCREVER UM ADR:
  → Quando escolhe tecnologia que vai ser difícil de mudar
  → Quando descarta uma opção óbvia por razão não óbvia
  → Quando a decisão vai ser questionada em 6 meses
  → Quando o contexto que motivou a decisão pode ser esquecido

NÃO PRECISA DE ADR:
  → Escolhas de estilo (use eslint/prettier para isso)
  → Decisões triviais reversíveis
  → Padrões já estabelecidos no projeto
```

### RUNBOOK — Operação em Produção

```
ESTRUTURA DO RUNBOOK:
  1. Nome do sistema e responsável
  2. Dependências críticas (o que precisa estar ok para funcionar)
  3. Health check: como verificar que está saudável
  4. Procedimentos de rotina (restart, deploy, backup)
  5. Troubleshooting: sintoma → causa → solução
  6. Contatos de escalação

CRITÉRIO DE QUALIDADE:
  Um novo membro da equipe consegue resolver um incidente
  usando só este runbook, sem perguntar para ninguém.
```

### COMENTÁRIO INLINE — Código com Contexto

```
QUANDO COMENTAR:
  ✓ Lógica não óbvia — "por que" não "o que"
  ✓ Workarounds e hacks — explica a causa do problema
  ✓ Edge cases importantes — "este valor pode ser null se X"
  ✓ Links para issue/PR que motivou a mudança
  ✓ Limites conhecidos — "isso quebra para arrays > 10k itens"

QUANDO NÃO COMENTAR:
  ✗ O que o código claramente já mostra
  ✗ Comentários de seção desnecessários (// autenticação)
  ✗ Código morto — deleta, não comenta
  ✗ Comentários de TODO sem dono e data
```

---

## TEMPLATES

### Template README Wolf

```markdown
# [Nome do Projeto]

> [Uma linha: o que faz e por que existe]

## Quick Start

```bash
# Pré-requisitos: Node 18+, Docker
git clone [repo]
cd [projeto]
cp .env.example .env  # preenche as variáveis obrigatórias
npm install
npm run dev
```

Acessa: http://localhost:3000

## O que este projeto faz

[2-3 parágrafos explicando o problema resolvido e como]

## Configuração

### Variáveis de Ambiente

| Variável | Obrigatória | Descrição | Exemplo |
|----------|-------------|-----------|---------|
| DATABASE_URL | sim | URL do PostgreSQL | postgresql://user:pass@host/db |
| API_KEY | sim | Chave da API X | sk-... |
| LOG_LEVEL | não | Nível de log (default: info) | debug |

### Dependências Externas

- **PostgreSQL 15+** — banco principal
- **Redis 7+** — cache e filas (opcional para desenvolvimento)
- **[Serviço X]** — [para quê é usado]

## Scripts

```bash
npm run dev        # desenvolvimento com hot reload
npm run build      # build de produção
npm test           # roda todos os testes
npm run lint       # verifica estilo de código
npm run migrate    # roda migrations pendentes
```

## Deploy

[Link para runbook ou instruções resumidas]

## Arquitetura

[Diagrama simples ou link para ADR principal]

## Troubleshooting

| Sintoma | Causa Provável | Solução |
|---------|----------------|---------|
| [Erro X] | [Causa] | [Solução] |

## Dono e Contato

**Squad:** Dev Wolf
**Manutenção:** [nome]
**Última atualização:** [data]
```

---

### Template ADR Wolf

```markdown
# ADR-[N]: [Título — decisão em forma de afirmação]

**Data:** [YYYY-MM-DD]
**Status:** proposto | aceito | depreciado | substituído por ADR-[N]
**Autor:** [Titan / nome]
**Contexto do projeto:** [nome do projeto]

## Contexto

[Situação atual que exige decisão. Seja específico: tecnologia existente,
volume esperado, restrições de prazo ou equipe. 3-5 linhas.]

## Problema

[O que precisa ser decidido, em uma linha clara.]

## Opções Consideradas

### Opção A: [Nome]
**Descrição:** [O que é]
**Prós:**
- [Vantagem específica para este contexto]
**Contras:**
- [Desvantagem específica para este contexto]
**Esforço estimado:** [P/M/G]

### Opção B: [Nome]
[idem]

## Decisão

**Escolha: Opção [X]**

[Justificativa em 2-4 linhas, específica para o contexto. Não genérica.
Por que essa opção é a melhor AQUI e AGORA.]

## Consequências

**Positivas:**
- [O que ganhamos]

**Negativas / Tradeoffs aceitos:**
- [O que abrimos mão ou aceitamos como custo]

**Neutras:**
- [O que muda sem julgamento de valor]

## Revisitar quando

[Condição concreta que tornaria esta decisão obsoleta.
Ex: "Volume de requests ultrapassar 10k/min" ou "Time crescer para 5+ devs"]

## Referências

- [Link para issue, PR, discussão que embasou esta decisão]
```

---

### Template Runbook Wolf

```markdown
# Runbook: [Nome do Sistema]

**Sistema:** [nome]
**Dono:** [quem é responsável]
**Criticidade:** [crítico / alto / médio / baixo]
**Última revisão:** [YYYY-MM-DD]

---

## Health Check

Como verificar que o sistema está saudável:

```bash
# Verifica endpoint de saúde
curl -s https://[sistema].wolf.com/health | jq .

# Esperado:
# { "status": "ok", "uptime": 99.9 }
```

**Sinais de saúde:**
- [ ] HTTP 200 em /health
- [ ] Tempo de resposta < 500ms
- [ ] Sem erros nos últimos 5 minutos

---

## Dependências

| Dependência | Como verificar | O que fazer se falhar |
|-------------|----------------|----------------------|
| PostgreSQL | [comando] | [ação] |
| Redis | [comando] | [ação] |

---

## Procedimentos de Rotina

### Restart do serviço
```bash
# Railway
railway restart [service-name]

# Docker
docker compose restart app

# Verifica que voltou
curl -s https://[url]/health
```

### Deploy de nova versão
[Link para pipeline de CI/CD ou passos manuais]

---

## Troubleshooting

### [Sintoma 1]
**Sintoma:** [O que o usuário vê ou o que aparece no log]
**Causa:** [Por que acontece]
**Solução:**
```bash
[comandos para resolver]
```

### [Sintoma 2]
[idem]

---

## Escalação

| Situação | Contato | Canal |
|----------|---------|-------|
| Sistema down em produção | Netto | Telegram |
| Bug crítico afetando usuários | [nome] | [canal] |
```

---

## CHECKLIST PRÉ-ENTREGA DE DOCUMENTAÇÃO

```
README:
  □ Quick Start testado do zero (não só "funciona na minha máquina")
  □ Todas as env vars listadas com exemplos reais (valores fake)
  □ Erros comuns documentados com solução
  □ Data de última atualização presente

ADR:
  □ Contexto explica POR QUE a decisão foi necessária
  □ Pelo menos 2 opções comparadas com critérios concretos
  □ Tradeoffs declarados explicitamente (não só prós)
  □ Condição de revisão definida

Runbook:
  □ Novo membro consegue fazer health check sem perguntar para ninguém
  □ Todos os sintomas comuns têm solução documentada
  □ Contatos de escalação atualizados
  □ Comandos testados (não copiados de memória)

Comentários inline:
  □ Explica "por que", não "o que"
  □ TODOs têm dono e issue referenciada
  □ Sem código morto comentado
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Titan] AÇÃO: documentação [tipo: README/ADR/runbook] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: docs.md | Agente: Titan | Atualizado: 2026-03-04*
