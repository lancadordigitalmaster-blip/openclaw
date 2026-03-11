# wiki.md — Quill Sub-Skill: Wiki e Base de Conhecimento
# Ativa quando: "wiki", "confluence", "notion", "base de conhecimento"

## Propósito

Wiki é onde conhecimento que não pertence a um repositório específico vive. Processos, decisões de negócio, contexto de clientes, guias operacionais. O princípio central: **single source of truth** — não duplica, referencia.

---

## Estrutura de Wiki Wolf

Organização por **domínio**, não por time. Times mudam; domínios são estáveis.

```
Wolf Knowledge Base
│
├── 01. Engenharia
│   ├── Arquitetura Geral (diagrama do sistema Wolf)
│   ├── Padrões e Convenções (coding standards, naming, etc.)
│   ├── Infraestrutura (servidores, domínios, credenciais — links)
│   ├── MCPs Disponíveis (referência para MCP-GUIDE.md)
│   └── Onboarding de Devs (link para onboarding por projeto)
│
├── 02. Operações
│   ├── Runbooks (links para runbooks em cada repositório)
│   ├── Planos de On-Call (quem acionar, quando, como)
│   ├── Postmortems (análises de incidentes)
│   └── SLAs e SLOs Definidos
│
├── 03. Clientes
│   ├── [Nome do Cliente]
│   │   ├── Contexto de Negócio (o que fazem, KPIs, público)
│   │   ├── Stack Técnica Deles (se integração)
│   │   ├── Contatos Técnicos
│   │   └── Integrações Ativas (com links para docs técnicas)
│   └── Template de Novo Cliente
│
├── 04. Agentes Wolf
│   ├── Catálogo de Agentes (SKILL.md de cada agente — links)
│   ├── Como Criar Novo Agente
│   ├── Protocolos de Comunicação entre Agentes
│   └── Histórico de Decisões (links para ADRs relevantes)
│
├── 05. Processos
│   ├── Processo de Deploy (referencia runbooks)
│   ├── Processo de Code Review
│   ├── Gestão de Incidentes
│   └── Processo de Release
│
└── 06. Referência Rápida
    ├── Comandos Frequentes (cheatsheet)
    ├── Contatos de Emergência
    ├── Links Rápidos (dashboards, painéis, monitoring)
    └── Glossário Wolf (termos específicos do contexto)
```

---

## GitHub Wiki vs Notion vs Docs-as-Code

### Docs-as-Code (recomendado Wolf para eng)

```
workspace/docs/           # dentro do repositório
├── adr/                  # Architecture Decision Records
├── runbooks/             # Procedimentos operacionais
├── api/                  # OpenAPI specs
└── architecture/         # Diagramas e decisões de arquitetura
```

**Vantagens:** versionado com o código, PRs para mudanças, blame para rastrear origem, sem acesso separado.

**Quando usar:** documentação técnica diretamente ligada ao código (ADRs, runbooks, API docs, arquitetura).

---

### GitHub Wiki

**Vantagens:** integrado ao repositório, fácil de editar, markdown nativo.
**Desvantagens:** sem histórico de revisão robusto, sem review process, não é versionado junto com o código.

**Quando usar Wolf:** documentação de projeto que não é técnica pura (contexto de produto, decisões de negócio do repositório).

---

### Notion (padrão Wolf para não-eng)

**Vantagens:** amigável para não-devs, rich text, databases, vistas múltiplas.
**Desvantagens:** não versionado, pode divergir do código real, acesso depende de licença.

**Quando usar Wolf:**
- Processos de negócio e operações
- Documentação de clientes
- Templates e checklists operacionais
- Conhecimento que CS/Marketing também acessa

---

## Princípio de Single Source of Truth

**Nunca duplicar.** Se a informação vive em um lugar, a wiki referencia — não copia.

```markdown
<!-- ERRADO: copiar o conteúdo do README aqui -->
## Como instalar o projeto X
1. git clone...
2. pnpm install...

<!-- CERTO: referenciar -->
## Projeto X
- Repositório: github.com/wolf-agency/projeto-x
- Instalação e setup: [README do projeto](link)
- Arquitetura: [docs/architecture.md no repositório](link)
- Runbooks: [docs/runbooks/ no repositório](link)
```

**Por que importa:** se duplicar, uma versão ficará desatualizada. Nunca se sabe qual está certa.

---

## Como Manter a Wiki Viva

### Regras de Manutenção Wolf

1. **Dono definido por seção** — sem dono = página órfã = vai ficar desatualizada
2. **Data de última revisão** em toda página
3. **Processo de revisão trimestral** — Quill agenda revisão das páginas mais acessadas
4. **Feedback loop** — canal `#wiki-feedback` para reportar informação errada

### Estrutura de Cabeçalho Wolf (toda página de wiki)

```markdown
# Título da Página

**Owner:** @nome-responsavel
**Última atualização:** YYYY-MM-DD
**Próxima revisão:** YYYY-MM-DD
**Status:** [Atual | Revisão Pendente | Desatualizado]

---

[conteúdo da página]

---

*Encontrou algo errado? Reporte em #wiki-feedback ou edite diretamente.*
```

### Processo de Revisão Trimestral

```
Quill (toda primeira segunda do trimestre):
1. Listar páginas com "Próxima revisão" no mês
2. Notificar owners: "Página X vence revisão em 7 dias"
3. Se após 14 dias não atualizado: marcar como "Revisão Pendente"
4. Se após 30 dias: escalar para tech-lead
```

---

## Categorias Essenciais para Agência Wolf

Toda wiki de agência precisa cobrir pelo menos:

| Categoria | Conteúdo Mínimo | Owner Típico |
|-----------|-----------------|--------------|
| Clientes | Contexto, contatos, integrações ativas | CS + Eng |
| Infraestrutura | Servidores, domínios, acesso, custos | Infra |
| Agentes Wolf | Catálogo, skills, como usar | Tech Lead |
| Processos | Deploy, review, release, incidentes | Eng Lead |
| Postmortems | Análises de incidentes com lições | Eng |
| Glossário | Termos Wolf e do negócio | Todos |
| Onboarding | Primeiros dias na Wolf, cultura, ferramentas | People + Eng |

---

## Checklist de Wiki Saudável

- [ ] Estrutura por domínio (não por time)
- [ ] Toda página tem owner e data de revisão
- [ ] Nenhuma informação duplicada (referencia, não copia)
- [ ] Single source of truth para cada tipo de informação
- [ ] Processo de revisão trimestral agendado
- [ ] Canal de feedback definido (#wiki-feedback)
- [ ] Onboarding referencia a wiki
- [ ] Links internos checados mensalmente (sem 404)
- [ ] Postmortems documentados após incidentes
- [ ] Glossário atualizado com termos Wolf
