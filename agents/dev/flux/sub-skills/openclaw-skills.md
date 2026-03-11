# openclaw-skills.md — FLUX Sub-Skill: OpenClaw Skills & Agentes Wolf
# Ativa quando: "skill openclaw", "agente wolf", "SOUL", "SKILL.md", "novo agente"

---

## ESTRUTURA DE SKILL.md WOLF

Todo agente Wolf tem um `SKILL.md` com estas seções obrigatórias:

```markdown
# SKILL.md — [Nome] · [Título do Agente]
# Wolf Agency AI System | Versão: X.0
# "[Frase de identidade — como o agente pensa]"

---

## IDENTIDADE
[Quem é o agente. Domínio de atuação. Como ele pensa.]

## STACK COMPLETA
[YAML com tecnologias organizadas por categoria]

## MCPs NECESSÁRIOS
[Lista de MCP servers que o agente precisa para funcionar]

## HEARTBEAT
[Frequência e checklist de monitoramento autônomo]

## SUB-SKILLS
[Lista de sub-skills com keyword de ativação]

## PROTOCOLOS
[Regras de como o agente age em situações específicas]

## OUTPUT PADRÃO
[Formato esperado das respostas do agente]
```

---

## TEMPLATE COMPLETO DE SKILL.md

```markdown
# SKILL.md — [NOME] · [Título]
# Wolf Agency AI System | Versão: 1.0
# "[Frase que define a filosofia do agente]"

---

## IDENTIDADE

Você é **[Nome]** — [descrição do papel] da Wolf Agency.
Você pensa em [domínio principal].
Você [princípio de qualidade que guia as decisões].

**Domínio:** [lista de especialidades]

---

## STACK COMPLETA

\`\`\`yaml
[categoria_1]:
  [tecnologia_a]: [quando usar]
  [tecnologia_b]: [quando usar]

[categoria_2]:
  [tecnologia_c]: [quando usar]
\`\`\`

---

## MCPs NECESSÁRIOS

\`\`\`yaml
mcps:
  - filesystem: [o que faz para esse agente]
  - bash: [o que faz para esse agente]
  - [mcp_especifico]: [função]
\`\`\`

---

## HEARTBEAT — [Nome] Monitor
**Frequência:** [Diariamente às Xh | Semanalmente às Y]

\`\`\`
CHECKLIST_HEARTBEAT_[NOME]:
□ [Verificação 1]
□ [Verificação 2]
□ [Verificação 3]
\`\`\`

---

## SUB-SKILLS

| Sub-Skill        | Ativa quando                    | Arquivo                  |
|------------------|---------------------------------|--------------------------|
| [nome]           | "[keywords]"                    | sub-skills/[arquivo].md  |

---

## PROTOCOLOS

### Protocolo: [Situação]
Quando [condição]:
1. [Ação 1]
2. [Ação 2]
3. [Ação 3]

---

## OUTPUT PADRÃO

Toda resposta inclui:
1. [Elemento obrigatório 1]
2. [Elemento obrigatório 2]
3. [Elemento obrigatório 3]
```

---

## PADRÃO DE SUB-SKILL

```markdown
# [arquivo].md — [Agente] Sub-Skill: [Título]
# Ativa quando: "[keyword1]", "[keyword2]", "[keyword3]"

---

## [SEÇÃO PRINCIPAL]

[Conteúdo técnico direto]

### [Subseção com Protocolo]

\`\`\`typescript
// Exemplo de código Wolf
\`\`\`

---

## CHECKLIST

- [ ] [Item verificável]
- [ ] [Item verificável]
```

**Regras de sub-skill:**
- Arquivo único, focado em um domínio
- Ativa por keywords específicas no contexto da conversa
- Conteúdo deve ser acionável (protocolos, código, checklists)
- Sem introdução genérica — vai direto ao ponto
- Sem ACTIVITY LOG

---

## COMO CRIAR NOVO AGENTE DO ZERO

### Passo 1: Definir Identidade

Responda antes de escrever uma linha:
- Qual problema específico esse agente resolve?
- Que tecnologias ele precisa dominar?
- Como ele difere dos agentes existentes?
- Qual frase define sua filosofia de trabalho?

Se você não consegue responder isso com precisão, o agente não está pronto para existir.

### Passo 2: Criar Estrutura de Diretórios

```bash
# Na raiz do workspace
AGENT_NAME="[nome em minúsculo]"
AGENT_DIR="agents/dev/$AGENT_NAME"

mkdir -p "$AGENT_DIR/sub-skills"
touch "$AGENT_DIR/SKILL.md"
```

### Passo 3: Escrever SKILL.md

Use o template acima. Foque em:
- Identidade única e clara (não duplicar domínio de agente existente)
- Stack tecnológica específica e justificada
- MCPs mínimos necessários (não listar tudo, listar o que realmente precisa)
- Heartbeat relevante para o domínio do agente

### Passo 4: Criar Sub-Skills Prioritárias

```bash
# Identificar os 3-5 contextos mais comuns de uso do agente
# Criar sub-skill para cada um
touch "$AGENT_DIR/sub-skills/[contexto-1].md"
touch "$AGENT_DIR/sub-skills/[contexto-2].md"
```

### Passo 5: Registrar no ORCHESTRATOR

Adicionar o agente na tabela do `ORCHESTRATOR.md`:

```markdown
| [NOME]   | [Título]        | [Especialidade]              | agents/dev/[nome]/SKILL.md |
```

---

## COMO INTEGRAR AGENTE NO ORCHESTRATOR.md

O `ORCHESTRATOR.md` é o documento central que define como os agentes são roteados.

### Localização
```
/Users/thomasgirotto/.openclaw/workspace/ORCHESTRATOR.md
```

### Formato de entrada na tabela de agentes

```markdown
## AGENTES DISPONÍVEIS

| Agente    | Papel               | Domínio Principal                         | SKILL.md                           |
|-----------|---------------------|-------------------------------------------|------------------------------------|
| FLUX      | AI Engineer         | LLMs, prompts, MCPs, RAG, pipelines       | agents/dev/flux/SKILL.md           |
| [NOVO]    | [Título]            | [Especialidade 1], [Especialidade 2]      | agents/dev/[nome]/SKILL.md         |
```

### Adicionar padrão de roteamento

```markdown
## REGRAS DE ROTEAMENTO

- Task envolve [domínio do novo agente] → DELEGA para [NOME]
```

---

## CHECKLIST DE AGENTE NOVO ANTES DE ATIVAR

### Estrutura
- [ ] Diretório criado: `agents/dev/[nome]/`
- [ ] SKILL.md criado com todas as seções obrigatórias
- [ ] Pelo menos 2 sub-skills criadas
- [ ] Registrado no ORCHESTRATOR.md

### Identidade
- [ ] Domínio único (não duplica outro agente existente)
- [ ] Stack tecnológica documentada com precisão
- [ ] Frase de identidade define filosofia, não é genérica
- [ ] MCPs necessários identificados e disponíveis

### Qualidade
- [ ] Heartbeat definido com checklist relevante para o domínio
- [ ] Protocolos escritos para situações previsíveis do domínio
- [ ] Output padrão definido (o que toda resposta deve conter)
- [ ] Tom é direto, Wolf Agency — sem verbosidade desnecessária

### Integração
- [ ] ORCHESTRATOR.md atualizado com o novo agente
- [ ] Regras de roteamento adicionadas
- [ ] Testado com 3 tasks representativas do domínio do agente

---

## AGENTES WOLF EXISTENTES (REFERÊNCIA)

| Agente  | Especialidade Principal                        |
|---------|------------------------------------------------|
| FLUX    | AI Engineering (LLMs, prompts, MCPs, RAG)      |
| ECHO    | Mobile / React Native / PWA                    |
| FORGE   | Backend / APIs / Banco de dados                |
| CRAFT   | Frontend / React / Next.js                     |
| ATLAS   | Data / Analytics / BI                         |
| PIXEL   | Design / UI-UX / Figma                         |
| QUILL   | Copy / Conteúdo / Marketing                    |
| SHIELD  | Segurança / DevSecOps                          |
| TITAN   | Infraestrutura / DevOps / Cloud                |
| OPS     | Operações / Processos / Gestão                 |
| VEGA    | Produto / Estratégia / Roadmap                 |
| BRIDGE  | Integrações / Conectores / APIs externas       |
| IRIS    | Research / Competitive Intelligence            |
| TURBO   | Performance / Otimização geral                 |
