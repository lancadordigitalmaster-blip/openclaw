# wolf-system.md — Titan Sub-Skill: Sistema Wolf
# Ativa quando: "alfred", "openclaw", "skill", "mcp", "agente wolf", "heartbeat"

---

## MAPA DO SISTEMA WOLF

```
SOUL.md                         ← Identidade global do Alfred, princípios, memória
    │
    ├── AGENTS.md               ← Regras operacionais: o que pode/não pode fazer
    │
    ├── ORCHESTRATOR.md         ← Lógica de roteamento: qual agente trata cada tarefa
    │
    ├── agents/
    │   ├── traffic/            ← Gabi (Meta Ads, Google Ads, ROAS)
    │   │   ├── SKILL.md
    │   │   └── sub-skills/     ← audit, budget-monitor, creative-fatigue, report-builder
    │   ├── social/             ← Luna (conteúdo, calendário, publicação)
    │   │   ├── SKILL.md
    │   │   └── sub-skills/     ← content-waterfall, calendar, listening, competitor-watch
    │   ├── seo/                ← Sage (rankings, keywords, audit técnico)
    │   │   ├── SKILL.md
    │   │   └── sub-skills/     ← content-gap, rank-monitor, keyword-research
    │   ├── strategy/           ← Nova (pesquisa, concorrentes, tendências)
    │   │   ├── SKILL.md
    │   │   └── sub-skills/     ← advisory-board, deep-research, competitor-360
    │   └── dev/
    │       ├── titan/          ← Tech Lead (debug, arquitetura, code review)
    │       │   ├── SKILL.md
    │       │   └── sub-skills/ ← debug, code-review, refactor, architect, infra, security, build, docs, wolf-system
    │       └── pixel/          ← Frontend (React, Next.js, UI/UX, performance)
    │           ├── SKILL.md
    │           └── sub-skills/ ← component, performance, responsive, a11y, animation, forms, state
    │
    ├── skills/                 ← Skills avulsas do Alfred (não de agente específico)
    │   ├── wolf-reminders/
    │   ├── wolf-meeting-summary/
    │   ├── wolf-caption-gen/
    │   └── ...
    │
    ├── shared/
    │   ├── memory/             ← activity.log, alerts.yaml, clients.yaml
    │   ├── templates/          ← report-client, alert-message, brief-creative
    │   └── outputs/            ← arquivos gerados pelos agentes
    │
    └── memory/
        ├── MEMORY.md           ← Índice de memória de longo prazo
        ├── projects.md         ← Projetos ativos
        ├── decisions.md        ← Decisões permanentes
        ├── lessons.md          ← Lições aprendidas
        ├── people.md           ← Contatos
        └── YYYY-MM-DD.md       ← Notas diárias
```

---

## ARQUITETURA DE UM AGENTE WOLF

```yaml
estrutura_agente:
  SKILL.md:
    - Identidade e personalidade do agente
    - Stack e domínio de conhecimento
    - MCPs necessários (filesystem, bash, github, etc.)
    - Heartbeat: frequência e checklist de monitoramento
    - Modos de operação (Firefighter, Engineer, Auditor...)
    - Sub-skills com roteamento por keywords
    - Protocolo de output padrão
    - Activity log template

  sub-skills/:
    - Arquivos .md com protocolos específicos
    - Carregados dinamicamente quando keyword ativa
    - Contêm: checklist, templates, exemplos de código
    - Não duplicam o que está no SKILL.md principal

mcps_comuns:
  filesystem:   lê/escreve arquivos do workspace
  bash:         executa comandos, testes, builds
  github:       cria PRs, lê commits, cria branches
  telegram:     notifica alertas críticos
  browser:      testa UIs, captura screenshots
```

---

## PROTOCOLO DE DIAGNÓSTICO DO SISTEMA WOLF

### Quando um agente está com problema

```
PASSO 1 — IDENTIFICA O SUBSISTEMA
  □ Qual agente está com problema? (Alfred, Gabi, Luna, Titan, Pixel...)
  □ É o agente em si ou um MCP que ele usa?
  □ É um problema de configuração ou de lógica no SKILL.md?

PASSO 2 — LÊ OS ARQUIVOS RELEVANTES
  □ SKILL.md do agente com problema
  □ Sub-skill específica se o problema é em funcionalidade específica
  □ AGENTS.md se for questão de permissões ou regras operacionais
  □ SOUL.md se for questão de identidade/princípios globais

PASSO 3 — DIAGNÓSTICO COM CONTEXTO DO SISTEMA
  Perguntas:
  → O agente tem as instruções corretas para o comportamento esperado?
  → O MCP necessário está configurado e funcionando?
  → Há conflito entre o SKILL.md e o SOUL.md?
  → A sub-skill está no caminho correto e sendo carregada?

PASSO 4 — FIX QUE NÃO QUEBRA A INTEGRAÇÃO
  Antes de alterar qualquer arquivo do sistema Wolf:
  □ Verifica impacto nos outros agentes (mudança em SOUL.md afeta todos)
  □ Prefere adicionar/clarificar a remover
  □ Testa localmente antes de salvar (simulação mental do fluxo)
  □ Se mudança estrutural: cria backup antes (./backup-system.sh)

PASSO 5 — DOCUMENTA A MUDANÇA
  □ Atualiza o arquivo modificado com data no rodapé
  □ Registra no activity log o que foi alterado e por quê
  □ Se for mudança de arquitetura: considera ADR
```

---

## COMANDOS ESPECIAIS WOLF

### "audita o sistema wolf"

```
PROTOCOLO DE AUDITORIA COMPLETA:

  1. SOUL.md
     □ Identidade do Alfred está clara e consistente?
     □ Lista de agentes está atualizada?
     □ Princípios operacionais refletem o comportamento atual?
     □ Estrutura de arquivos documentada está correta?

  2. AGENTS.md
     □ Regras de permissão estão claras e aplicáveis?
     □ Heartbeat schedule está configurado?
     □ Hierarquia de modelos está definida?

  3. ORCHESTRATOR.md
     □ Tabela de roteamento cobre todos os casos comuns?
     □ Modo multi-agente está documentado?
     □ Comandos globais estão atualizados?

  4. SKILL.md de cada agente ativo
     □ MCPs necessários estão listados?
     □ Heartbeat tem checklist acionável?
     □ Sub-skills têm roteamento por keywords?
     □ Output padrão está definido?

  5. Sub-skills
     □ Todos os arquivos referenciados existem?
     □ Nenhuma sub-skill está desatualizada ou contraditória?

  ENTREGA:
  → Relatório priorizado:
    🔴 GAPS CRÍTICOS (funcionalidade importante sem cobertura)
    🟡 INCONSISTÊNCIAS (conflitos entre arquivos)
    🟢 MELHORIAS (oportunidades de melhoria não urgentes)
```

### "o agente [NOME] está com problema"

```
PROTOCOLO DE DEBUG DE AGENTE:

  1. Identifica o agente: Gabi / Luna / Sage / Nova / Titan / Pixel / Alfred

  2. Carrega o contexto:
     → agents/[squad]/[nome]/SKILL.md
     → Sub-skills relevantes para o problema reportado

  3. Diagnóstico específico:
     □ O comportamento esperado está descrito no SKILL.md?
     □ O MCP necessário para esta funcionalidade está listado?
     □ Há ambiguidade nas instruções que pode causar comportamento errado?
     □ O roteamento de sub-skills está correto?

  4. Fix e verificação:
     → Propõe mudança específica com justificativa
     → Mostra antes/depois das alterações
     → Define como testar que o problema foi resolvido
```

### "melhora o sistema wolf"

```
PROTOCOLO DE MELHORIA DO SISTEMA:

  1. ANÁLISE DE COBERTURA
     Para cada agente: quais casos de uso não têm sub-skill dedicada?
     Quais tarefas comuns exigem improvisação do agente?

  2. ANÁLISE DE CONSISTÊNCIA
     Os padrões de output são consistentes entre agentes?
     As regras globais do SOUL.md estão sendo respeitadas?
     Os heartbeats têm formato padronizado?

  3. ANÁLISE DE INTEGRAÇÕES
     Quais colaborações entre agentes estão documentadas mas não testadas?
     Quais MCPs estão sendo usados mas não documentados?

  4. PROPOSTA DE ROADMAP
     Formato de entrega:

     ## Melhorias Priorizadas — Sistema Wolf

     ### P0 — Crítico (resolve agora)
     - [Melhoria]: [justificativa] | Esforço: [P/M/G]

     ### P1 — Alta (próxima semana)
     - [Melhoria]: [justificativa] | Esforço: [P/M/G]

     ### P2 — Médio (próximo mês)
     - [Melhoria]: [justificativa] | Esforço: [P/M/G]
```

---

## ESTRUTURA DE ARQUIVOS ESPERADA

```yaml
arquivos_obrigatorios:
  raiz:
    - SOUL.md          ← identidade e princípios do Alfred
    - AGENTS.md        ← regras operacionais
    - BOOT.md          ← contexto de inicialização
    - MEMORY.md        ← índice de memória longa
    - TOOLS.md         ← ferramentas e MCPs disponíveis

  orchestrator:
    - ORCHESTRATOR.md  ← lógica de roteamento

  memory:
    - MEMORY.md        ← consolidado de memória
    - projects.md      ← projetos ativos e status
    - decisions.md     ← decisões permanentes
    - lessons.md       ← lições aprendidas
    - people.md        ← contatos e perfis
    - pending.md       ← tarefas aguardando input
    - YYYY-MM-DD.md    ← notas da sessão (gerado dinamicamente)

  por_agente:
    - SKILL.md                     ← obrigatório
    - sub-skills/[nome].md         ← um por funcionalidade major

convenções_de_nomenclatura:
  SKILL.md:      "SKILL.md" (sempre maiúsculo)
  sub-skills:    "kebab-case.md" (sempre minúsculo com hífen)
  memory:        "YYYY-MM-DD.md" para notas diárias
  backups:       "YYYY-MM-DD-HHMMSS/" timestamp completo
```

---

## PADRÕES DE MCP NO SISTEMA WOLF

```yaml
mcps_core:
  filesystem:
    uso: "lê/escreve qualquer arquivo do workspace"
    configuracao: nativo no OpenClaw
    comando: "read_file, write_file, list_directory"

  bash:
    uso: "executa comandos no terminal"
    configuracao: nativo no OpenClaw
    riscos: "sempre confirma antes de comandos destrutivos"

mcps_opcionais_comuns:
  github:
    uso: "cria PRs, lê commits, verifica CI"
    instala: "openclaw plugins install github-mcp"
    agentes_que_usam: [Titan, Craft, Vega]

  telegram:
    uso: "notificações e alertas para Netto"
    agentes_que_usam: [Alfred, Gabi, Luna, Titan]
    regra: "apenas ID autorizado: 789352357"

  browser-automation:
    uso: "testa UIs, captura screenshots, verifica endpoints"
    agentes_que_usam: [Pixel, Vega, Titan]

diagnostico_mcp:
  verificar_status: "openclaw plugins status"
  reiniciar: "openclaw plugins restart [nome]"
  listar_disponiveis: "openclaw plugins list"
  verificar_logs: "openclaw plugins logs [nome]"
```

---

## CHECKLIST DE SAÚDE DO SISTEMA

```
VERIFICAÇÃO RÁPIDA (< 5 minutos):
  □ SOUL.md carrega sem erro?
  □ AGENTS.md tem regras claras de permissão?
  □ ORCHESTRATOR.md tem tabela de roteamento atualizada?
  □ Todos os SKILL.md dos agentes ativos existem?
  □ MCPs críticos estão respondendo?
  □ Activity log está sendo escrito?
  □ Backups recentes existem?

VERIFICAÇÃO COMPLETA (auditoria):
  □ Todos os arquivos referenciados existem?
  □ Não há contradições entre SOUL.md e SKILL.md dos agentes?
  □ Sub-skills estão nos caminhos corretos?
  □ Heartbeats têm agendamento definido?
  □ Credenciais em .env estão atualizadas?
  □ Backup-system.sh está funcional?
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Titan] AÇÃO: wolf-system [auditoria/diagnóstico/melhoria] | SISTEMA: [componente] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: wolf-system.md | Agente: Titan | Atualizado: 2026-03-04*
