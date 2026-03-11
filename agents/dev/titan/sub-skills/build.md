# build.md — Titan Sub-Skill: Implementação de Feature
# Ativa quando: "cria", "implementa", "constrói", "adiciona", "faz um"

---

## PROTOCOLO ENGINEER MODE

```
REGRA #1: Não começa a codar sem entender o que vai ser construído.
REGRA #2: O design mais simples que funciona é o correto.
REGRA #3: Testes não são opcionais — fazem parte da definição de "pronto".

PROCESSO COMPLETO:
  1. ENTENDIMENTO  — o que precisa fazer e por que
  2. DESIGN        — como vai funcionar antes de escrever código
  3. IMPLEMENTAÇÃO — código limpo em pequenos passos verificáveis
  4. TESTE         — unitário, integração e smoke test manual
  5. DEPLOY        — checklist pré-deploy, deploy, verificação pós-deploy
```

---

## FASE 1 — ENTENDIMENTO (nunca pula)

```
PERGUNTAS OBRIGATÓRIAS ANTES DE COMEÇAR:

  Sobre o requisito:
  □ O que exatamente precisa fazer? (comportamento, não tecnologia)
  □ O que NÃO precisa fazer? (escopo negativo é tão importante quanto o positivo)
  □ Quem vai usar e como? (tipo de usuário, volume esperado, frequência)
  □ Qual o critério de sucesso? (como saber que está pronto?)

  Sobre edge cases:
  □ O que acontece se o input for vazio / null / inválido?
  □ O que acontece se uma dependência externa estiver fora do ar?
  □ O que acontece com volume 10x maior que o esperado?
  □ O que acontece se o usuário repetir a ação duas vezes?

  Sobre o contexto técnico:
  □ Tem código existente para integrar ou é do zero?
  □ Quais dependências e APIs já estão disponíveis?
  □ Tem prazo? Qual o MVP mínimo aceitável?
  □ Vai ser mantido por quem?

SE ALGUMA RESPOSTA FOR "não sei": para aqui, pergunta antes de continuar.
```

---

## FASE 2 — DESIGN (escreve antes de codar)

```
OUTPUT DO DESIGN (em texto, não código ainda):

  ESTRUTURA DE DADOS:
    → Quais tipos/interfaces vão ser criados ou modificados?
    → Qual o shape dos dados de entrada e saída?

  FLUXO PRINCIPAL:
    → Passo a passo do happy path (o que acontece quando tudo funciona)

  FLUXO DE ERRO:
    → O que pode dar errado em cada passo?
    → Como cada erro vai ser tratado?

  COMPONENTES/MÓDULOS:
    → Quais funções/classes/módulos vão ser criados?
    → Responsabilidade de cada um (uma frase)
    → Ordem de implementação (o que depende do que?)

  DECISÕES TÉCNICAS:
    → Há alguma decisão arquitetural não trivial? Documenta como ADR se sim.
    → Alguma alternativa foi descartada? Por quê?
```

---

## FASE 3 — IMPLEMENTAÇÃO

### Ordem de Construção

```
REGRA: Implementa de dentro para fora.
  1. Tipos/interfaces primeiro (contrato)
  2. Lógica de negócio pura (sem side effects)
  3. Persistência/banco (models, queries)
  4. Integrações externas (APIs, serviços)
  5. Camada HTTP/UI (endpoints, componentes)
  6. Testes para cada camada
```

### Padrões Wolf TypeScript

```typescript
// ========================
// TIPOS — definem o contrato
// ========================

// ✅ BOM — tipos explícitos, sem 'any'
interface CreateCampaignInput {
  name: string
  budget: number
  startDate: Date
  targetAudience: AudienceSegment
}

interface CreateCampaignResult {
  id: string
  status: 'active' | 'paused' | 'error'
  createdAt: Date
}

// ❌ RUIM — 'any' esconde bugs, 'data' não diz nada
async function createCampaign(data: any): Promise<any> { ... }

// ========================
// FUNÇÕES — responsabilidade única
// ========================

// ✅ BOM — nome descreve o que faz, parâmetros tipados, erros explícitos
async function createCampaign(
  input: CreateCampaignInput
): Promise<Result<CreateCampaignResult, CampaignError>> {
  // Validação no início — fail fast
  const validation = validateCampaignInput(input)
  if (!validation.ok) {
    return { ok: false, error: validation.error }
  }

  // Lógica de negócio isolada
  const campaign = mapInputToCampaign(input)

  // Side effect separado e testável
  const saved = await campaignRepository.create(campaign)

  return { ok: true, data: saved }
}

// ❌ RUIM — mistura validação, lógica, banco, email numa função só
async function doStuff(x, y, z) {
  if (x && y) {
    const r = await db.query(`INSERT INTO campaigns VALUES (${x}, ${y})`)
    await sendEmail(z, 'feito')
    return r
  }
}

// ========================
// TRATAMENTO DE ERROS
// ========================

// ✅ BOM — erros tipados, não swallowados
type CampaignError =
  | { type: 'validation'; field: string; message: string }
  | { type: 'duplicate'; existingId: string }
  | { type: 'quota_exceeded'; limit: number }

// Padrão Result Wolf (alternativa ao throw)
type Result<T, E> = { ok: true; data: T } | { ok: false; error: E }

// ❌ RUIM — erro silenciado
try {
  await doSomething()
} catch (e) {
  console.log(e) // e segue em frente sem tratar
}

// ========================
// ASYNC/AWAIT
// ========================

// ✅ BOM — paralelo quando independente
const [user, campaigns, metrics] = await Promise.all([
  userRepo.findById(userId),
  campaignRepo.findByUser(userId),
  metricsService.getForUser(userId),
])

// ❌ RUIM — serial desnecessário (3x mais lento)
const user = await userRepo.findById(userId)
const campaigns = await campaignRepo.findByUser(userId)
const metrics = await metricsService.getForUser(userId)
```

### Padrões Wolf Python

```python
# ========================
# TIPOS — usa dataclasses ou Pydantic
# ========================

# ✅ BOM — tipado, validado, documentado
from pydantic import BaseModel, Field
from typing import Literal
from datetime import datetime

class CreateCampaignInput(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    budget: float = Field(..., gt=0)
    start_date: datetime
    status: Literal['active', 'paused'] = 'active'

# ========================
# FUNÇÕES — princípio único
# ========================

# ✅ BOM — nome descritivo, type hints, docstring se não óbvio
async def create_campaign(
    input_data: CreateCampaignInput,
    repo: CampaignRepository,
) -> Campaign:
    """
    Cria uma nova campanha no sistema.
    Lança CampaignValidationError se os dados forem inválidos.
    """
    existing = await repo.find_by_name(input_data.name)
    if existing:
        raise CampaignAlreadyExistsError(name=input_data.name)

    campaign = Campaign.from_input(input_data)
    return await repo.save(campaign)

# ❌ RUIM — sem tipos, nome genérico, sem tratamento de erro
def do_stuff(x, y):
    r = db.execute(f"INSERT INTO campaigns VALUES ('{x}', {y})")
    return r
```

---

## FASE 4 — TESTE

### Estratégia de Teste Wolf

```
PIRÂMIDE DE TESTES:
  70% — Unitário  (lógica de negócio isolada, rápido, sem IO)
  20% — Integração (banco real, cache, serviços externos mockados)
  10% — E2E / Smoke (fluxo crítico end-to-end)

O QUE TESTAR SEMPRE:
  □ Happy path — funciona com inputs válidos normais
  □ Edge cases mapeados no design
  □ Erro de input inválido retorna mensagem clara
  □ Falha de dependência externa é tratada graciosamente
  □ Idempotência onde necessário (dupla requisição não quebra)
```

```typescript
// Estrutura de teste Wolf (Vitest ou Jest)
describe('createCampaign', () => {
  // Arrange — contexto claro
  const validInput: CreateCampaignInput = {
    name: 'Campanha Verão 2026',
    budget: 5000,
    startDate: new Date('2026-03-10'),
    targetAudience: mockAudience,
  }

  it('cria campanha com dados válidos', async () => {
    // Act
    const result = await createCampaign(validInput)

    // Assert — verifica comportamento, não implementação
    expect(result.ok).toBe(true)
    if (result.ok) {
      expect(result.data.status).toBe('active')
      expect(result.data.id).toBeDefined()
    }
  })

  it('rejeita orçamento negativo', async () => {
    const result = await createCampaign({ ...validInput, budget: -100 })
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.error.type).toBe('validation')
      expect(result.error.field).toBe('budget')
    }
  })

  it('retorna erro se campanha com mesmo nome já existe', async () => {
    await createCampaign(validInput) // primeira vez — ok
    const result = await createCampaign(validInput) // segunda vez — deve falhar
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.error.type).toBe('duplicate')
    }
  })
})
```

---

## FASE 5 — DEPLOY

### Checklist Pré-Deploy

```
CÓDIGO:
  □ Testes passando (npm test / pytest)
  □ Lint sem erros (npm run lint)
  □ Sem console.log de debug no código
  □ Sem secrets/tokens hardcoded (grep -r "sk-\|api_key" src/)
  □ .env.example atualizado se novas variáveis foram adicionadas

BANCO (se houver migration):
  □ Migration escrita e testada em dev
  □ Migration é reversível (tem down() definido)
  □ Impacto em dados existentes avaliado

REVIEW:
  □ PR description preenchida com contexto
  □ Diff revisado pelo próprio autor antes de pedir review
  □ Breaking changes identificados e comunicados

PRÉ-VERIFICAÇÃO:
  □ Deploy em staging primeiro (se existir)
  □ Smoke test em staging aprovado
  □ Plano de rollback definido (como reverter em < 5 min)
```

### Template de PR Description

```markdown
## O que esta PR faz

[2-3 linhas: comportamento adicionado/modificado]

## Por que

[Contexto: qual problema resolve, link para issue/ticket]

## Como testar

1. [Passo 1]
2. [Passo 2]
3. Esperado: [resultado]

## Checklist

- [ ] Testes passando
- [ ] Sem console.log
- [ ] .env.example atualizado (se necessário)
- [ ] Migration reversível (se houver)
- [ ] Breaking changes documentados (se houver)

## Screenshots (se mudança visual)

[Antes / Depois]

## Riscos e Tradeoffs

[O que pode afetar? O que foi descartado e por quê?]
```

---

## CHECKLIST FINAL DE ENTREGA

```
FUNCIONALIDADE:
  □ Happy path funciona end-to-end
  □ Todos os edge cases mapeados são tratados
  □ Mensagens de erro são úteis (não genéricas)
  □ Logs suficientes para debugar em produção

QUALIDADE:
  □ Testes cobrem os casos críticos
  □ Código legível por alguém que não escreveu
  □ Nenhuma função com mais de 50 linhas (se sim: refatora)
  □ Nenhuma abstração prematura (YAGNI)

OPERAÇÃO:
  □ Como monitorar se está funcionando em produção?
  □ Como debugar se der problema?
  □ Como reverter se necessário?
  □ O que precisa de documentação ou atualização de runbook?
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Titan] AÇÃO: implementação [feature] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: build.md | Agente: Titan | Atualizado: 2026-03-04*
