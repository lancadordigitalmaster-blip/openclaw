# wolf-docs.md — Quill Sub-Skill: Documentação de Agentes Wolf
# Ativa quando: "skill", "MCP", "documenta agente", "SKILL.md"

## Propósito

Todo agente Wolf precisa de documentação que permita a qualquer membro da equipe (humano ou outro agente) entender o que ele faz, como ativá-lo, e quais são seus limites. Quill é responsável por auditar e manter essa documentação.

**Auditoria:** Quill revisa todos os SKILL.md toda sexta-feira. Agente sem SKILL.md completo = agente não-operacional.

---

## Estrutura SKILL.md Obrigatória

```markdown
# SKILL.md — [Nome do Agente]

## Identidade

**Nome:** Nome do agente
**Papel:** Descrição de uma linha do propósito
**Owner:** @nome-responsavel
**Versão:** X.Y.Z
**Status:** [Ativo | Beta | Depreciado]

---

## Stack

- **Runtime:** Node.js 20 / Python 3.12 / etc.
- **Framework:** Express / FastAPI / etc.
- **Banco:** PostgreSQL / Redis / etc.
- **Infraestrutura:** Docker / Kubernetes / etc.

---

## MCPs Registrados

| MCP | Versão | Propósito |
|-----|--------|-----------|
| `mcp-evolution` | 1.2.0 | WhatsApp via Evolution API |
| `mcp-meta-ads` | 2.1.0 | Meta Ads insights e gestão |
| `mcp-clickup` | 1.0.0 | Criação e atualização de tasks |

---

## Heartbeat

**Frequência:** A cada 5 minutos
**Endpoint:** `GET /health`
**Resposta esperada:**
```json
{
  "status": "healthy",
  "version": "2.3.1",
  "uptime": 86400,
  "checks": {
    "database": "ok",
    "redis": "ok",
    "meta_ads_api": "ok"
  }
}
```
**Alertas:** Grafana → canal `#alerts-[nome-agente]` se health fail por > 2 minutos

---

## Sub-Skills

| Sub-Skill | Arquivo | Ativa Quando |
|-----------|---------|--------------|
| Nome da skill | `sub-skills/arquivo.md` | "keyword1", "keyword2" |

---

## Protocolos

### Input Padrão

```typescript
interface AgentInput {
  task: string;          // Descrição da tarefa
  context?: object;      // Contexto adicional
  priority?: 'low' | 'medium' | 'high';
  requestId: string;     // UUID para rastreamento
}
```

### Output Padrão

```typescript
interface AgentOutput {
  success: boolean;
  result?: any;
  error?: {
    code: string;
    message: string;
    retryable: boolean;
  };
  metadata: {
    requestId: string;
    duration: number;   // ms
    version: string;
  };
}
```

### Comportamento em Falha

- Timeout de task: 30 segundos (configurável)
- Retry automático: 3x com exponential backoff
- Dead letter: tasks não processadas após retries vão para `queue:dead-letter`
- Alerta: qualquer falha é logada com requestId para rastreamento

---

## Configuração

```env
# Variáveis obrigatórias
AGENT_NAME=nome-do-agente
AGENT_VERSION=2.3.1

# Conexões
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# MCPs
MCP_EVOLUTION_URL=http://evolution:8080
MCP_META_ADS_TOKEN=EAAxxxxx
```

---

## Dependências entre Agentes

- **Depende de:** [AgentX] para autenticação, [AgentY] para notificações
- **É consumido por:** [AgentZ] para processamento downstream

---

## Limitações Conhecidas

- Não processa mais de 100 tasks simultâneas (configurável com CONCURRENCY)
- Rate limit Meta Ads: respeita 200 req/hora por conta
- Sem suporte a tasks com payload > 10MB

---

## Histórico de Versões

| Versão | Data | Principais Mudanças |
|--------|------|---------------------|
| 2.3.1 | 2024-12-01 | Fix: timeout em sync de contas grandes |
| 2.3.0 | 2024-11-10 | Feature: suporte a bulk operations |
| 2.0.0 | 2024-09-01 | Breaking: novo formato de output padrão |
```

---

## Como Documentar uma Sub-Skill

Cada arquivo em `sub-skills/` segue esta estrutura:

```markdown
# nome-arquivo.md — [Agente] Sub-Skill: [Título]
# Ativa quando: "keyword1", "keyword2", "keyword3"

## Propósito

Uma linha descrevendo o que esta sub-skill resolve.

---

## Protocolo

Passos concretos de execução. O que o agente faz quando ativado.

1. Passo concreto com ação específica
2. Próximo passo
3. Verificação de resultado

## Exemplos

### Exemplo 1: [Caso de Uso]

**Input:**
```
Descrição de input típico
```

**O que Quill faz:**
1. Identifica o tipo de documento necessário
2. Aplica template correspondente
3. ...

**Output:**
```
Resultado esperado
```

## Checklist

- [ ] Item de verificação 1
- [ ] Item de verificação 2
```

---

## Protocolo Quill: Auditoria Semanal de SKILL.md

**Toda sexta-feira, Quill executa:**

1. Listar todos os agentes em `workspace/agents/`
2. Para cada agente, verificar presença de `SKILL.md`
3. Para cada SKILL.md, validar seções obrigatórias:
   - Identidade completa (nome, papel, owner, versão, status)
   - MCPs listados com versões
   - Heartbeat documentado
   - Sub-skills com mapeamento de keywords
   - Protocolos de input/output
4. Comparar versão documentada com versão em execução
5. Reportar discrepâncias no canal `#wolf-docs`

**Formato do relatório:**

```
=== Auditoria SKILL.md — [data] ===

✓ bridge — SKILL.md completo (v2.3.1)
✓ quill — SKILL.md completo (v1.5.0)
⚠ atlas — SKILL.md desatualizado (doc: v1.0.0 / running: v1.2.0)
✗ novo-agente — SKILL.md ausente

Ações pendentes:
- @owner-atlas: atualizar SKILL.md para v1.2.0
- @owner-novo: criar SKILL.md antes de sexta próxima
```

---

## Checklist de Agente Documentado

### SKILL.md
- [ ] Identidade completa (nome, papel, owner, versão, status)
- [ ] Stack detalhada
- [ ] MCPs listados com versões
- [ ] Heartbeat com endpoint e formato de resposta
- [ ] Sub-skills com tabela de mapeamento
- [ ] Protocolos de input/output com TypeScript interfaces
- [ ] Comportamento em falha documentado
- [ ] Variáveis de ambiente listadas
- [ ] Dependências entre agentes
- [ ] Limitações conhecidas
- [ ] Histórico de versões

### Sub-Skills
- [ ] Cada sub-skill tem arquivo próprio em `sub-skills/`
- [ ] Cabeçalho com keywords de ativação
- [ ] Protocolo com passos concretos
- [ ] Pelo menos 1 exemplo prático
- [ ] Checklist de verificação

### Manutenção
- [ ] SKILL.md atualizado a cada release
- [ ] Sub-skills revisadas quando comportamento muda
- [ ] Owner identificado e disponível
