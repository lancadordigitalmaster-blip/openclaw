# refactor.md — Titan Sub-Skill: Refatoração
# Ativa quando: "refatora", "está lento", "está confuso", "melhora"

---

## PROTOCOLO DE REFATORAÇÃO

```
REGRA FUNDAMENTAL: Não quebre o que funciona.
Refatoração = mesmo comportamento externo, código interno melhor.

ANTES DE REFATORAR:
  1. Existe teste cobrindo esse código? (se não: escreve primeiro)
  2. Qual é o problema real? (lento? difícil de manter? bugado?)
  3. Qual o risco? (código crítico de produção? isolado?)

TIPOS DE REFATORAÇÃO:

  EXTRACT FUNCTION (código repetido ou muito longo)
    → Identifica bloco coeso que pode ser função
    → Nomeia baseado no que ele faz, não no como
    → Testa que comportamento é idêntico

  RENAME (nomes que não descrevem)
    → Renomeia variável/função/classe para o que ela realmente é
    → x, data, info, temp = nomes ruins
    → userEmail, campaignBudget, parseAdMetrics = nomes bons

  SIMPLIFY CONDITIONALS
    → if/else aninhado > 3 níveis: extrair em função ou early return
    → Negações duplas: if (!isNotValid) → if (isValid)
    → Switch grande com lógica: considerar Map/objeto de estratégias

  PERFORMANCE REFACTOR
    → N+1 queries: identifica e resolve com JOIN ou batch
    → Loop desnecessário: .find() em vez de filter()[0]
    → Await em série quando poderia ser Promise.all() em paralelo
    → Cache de operação cara que repete com mesmo input

OUTPUT:
  Mostra: antes vs depois com comentário explicando a melhoria
  Declara: "comportamento preservado" ou "mudança intencional: [X]"
```

---

## PADRÕES DE REFATORAÇÃO WOLF

```typescript
// ❌ ANTES — código confuso
async function f(x, y, z) {
  let r = await db.query('SELECT * FROM users WHERE id = ' + x)
  if (r && r.length > 0) {
    let u = r[0]
    if (u.role == 'admin') {
      if (z == true) {
        await sendMsg(u.email, y)
      }
    }
  }
}

// ✅ DEPOIS — legível, seguro, testável
async function notifyAdminUser(
  userId: string,
  message: string,
  shouldNotify: boolean
): Promise<void> {
  if (!shouldNotify) return

  const user = await userRepository.findById(userId)
  if (!user || user.role !== 'admin') return

  await emailService.send(user.email, message)
}
```
