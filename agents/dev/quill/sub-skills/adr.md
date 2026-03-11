# adr.md — Quill Sub-Skill: Architecture Decision Records
# Ativa quando: "ADR", "decisão arquitetural", "por que fizemos assim"

## Propósito

ADR documenta decisões arquiteturais — não só o que foi decidido, mas o **contexto** e **trade-offs** que levaram àquela decisão. Seis meses depois, ninguém lembra por que escolheu PostgreSQL em vez de MongoDB. O ADR responde isso.

**O que não é ADR:** documentação de como o sistema funciona. ADR é sobre decisões de design, não descrições técnicas.

---

## Quando Escrever um ADR

Escreva quando a decisão:
- Vai durar mais de 6 meses ou é difícil de reverter
- Afeta mais de uma pessoa ou mais de um serviço
- Tem trade-offs não óbvios que foram considerados
- Alguém provavelmente vai perguntar "por que fazemos assim?" no futuro

**Não escreva ADR para:**
- Decisões triviais (qual biblioteca de datas usar)
- Preferências de estilo (tabs vs spaces → `.editorconfig` resolve)
- Decisões temporárias claramente marcadas como tal

---

## Template Wolf ADR

```markdown
# ADR-XXX: [Título Descritivo]

**Status:** [Proposto | Aceito | Depreciado | Substituído por ADR-YYY]
**Data:** YYYY-MM-DD
**Autores:** @nome, @nome
**Revisores:** @nome

---

## Contexto

Descreve a situação que força a tomada de decisão. Qual é o problema?
Quais são as forças em jogo (requisitos técnicos, requisitos de negócio,
limitações de equipe, restrições de custo)?

Exemplo:
> Precisamos sincronizar dados de campanhas Meta Ads para múltiplos clientes
> em tempo real. Atualmente fazemos polling a cada 5 minutos, causando dados
> desatualizados e excesso de chamadas à API (~50k chamadas/dia).

---

## Opções Consideradas

### Opção 1: Webhooks Meta Ads

**Descrição:** Assinar webhooks nativos da Meta Ads API para receber
notificações de mudança em tempo real.

**Prós:**
- Dados em tempo real (< 1 segundo de delay)
- Zero polling = economia de quota de API
- Escalável independente do número de clientes

**Contras:**
- Meta Ads webhooks são limitados a eventos de conta, não campanha
- Requer endpoint público com SSL válido
- Precisa implementar lógica de retry para webhooks falhos

---

### Opção 2: Polling Otimizado com Cache

**Descrição:** Manter polling mas com frequência adaptativa baseada em
horário e atividade da conta.

**Prós:**
- Simples de implementar (evolução do existente)
- Sem dependência de infraestrutura extra

**Contras:**
- Máximo de 1 minuto de delay (melhor que atual, mas não real-time)
- Quota de API ainda consumida
- Não escala com mais clientes

---

### Opção 3: Meta Ads → Pub/Sub → Event Streaming

**Descrição:** Integração via Google Pub/Sub para streaming de eventos
de mudança de campanha.

**Prós:**
- Dados em tempo real
- Alta confiabilidade com garantia de entrega
- Permite múltiplos consumidores

**Contras:**
- Custo adicional (Google Cloud)
- Complexidade operacional alta
- Overkill para escala atual (~200 contas)

---

## Decisão

**Escolhemos Opção 2: Polling Otimizado com Cache**

Reasoning: Webhooks Meta Ads não cobrem granularidade de campanha necessária.
Event streaming é custo e complexidade injustificados para 200 contas.
Polling otimizado (1 minuto em horário comercial, 10 minutos fora) atende
SLA de dados com mudança < 5% na quota de API.

Revisaremos esta decisão quando:
- Base de clientes ultrapassar 500 contas, OU
- Meta Ads lançar webhooks por campanha (monitorar changelog deles)

---

## Consequências

**Positivas:**
- Implementação em 1 sprint sem nova infraestrutura
- Redução de 70% nas chamadas à API via cache inteligente
- SLA de atualização: dados com no máximo 1 minuto de delay

**Negativas:**
- Não é real-time (delay de até 1 minuto)
- Precisa monitorar quota de API ativamente

**Ações necessárias:**
- [ ] Implementar scheduler com frequência adaptativa
- [ ] Adicionar cache Redis com TTL configurável por conta
- [ ] Alertas quando uso de quota ultrapassar 80%
- [ ] Criar ADR de revisão agendado para Q2 2025
```

---

## Diretório e Nomenclatura

```
workspace/docs/adr/
├── ADR-001-banco-de-dados-principal.md
├── ADR-002-autenticacao-jwt-vs-sessions.md
├── ADR-003-estrategia-sync-meta-ads.md
├── ADR-004-framework-de-testes.md
└── README.md   ← índice com todos os ADRs
```

**Nomenclatura:** `ADR-XXX-descricao-em-kebab-case.md`
**Numeração:** sequencial, nunca reutiliza números.

### README de índice dos ADRs

```markdown
# Architecture Decision Records

| ID | Título | Status | Data |
|----|--------|--------|------|
| [ADR-001](ADR-001-banco-de-dados.md) | Banco de dados principal: PostgreSQL | Aceito | 2024-01-15 |
| [ADR-002](ADR-002-autenticacao.md) | Autenticação: JWT stateless | Aceito | 2024-01-20 |
| [ADR-003](ADR-003-sync-meta-ads.md) | Sync Meta Ads: polling otimizado | Aceito | 2024-03-10 |
```

---

## Protocolo Wolf para ADRs

### Criação
1. Identificar decisão que merece registro (usa critério "vai durar > 6 meses")
2. Criar arquivo com próximo número sequencial
3. Preencher até "Opções Consideradas" e compartilhar para input da equipe
4. Decisão tomada em reunião ou thread assíncrona documentada
5. Completar seção "Decisão" e "Consequências"
6. Status = "Aceito"
7. Atualizar índice no README

### Atualização
- ADRs são imutáveis: não edita decisões passadas
- Se decisão mudar: cria novo ADR e marca o antigo como "Substituído por ADR-XXX"
- Adiciona link cruzado entre os dois

### Revisão
- ADR pode ter "Quando Revisitar" explícito (data ou condição)
- Quill lembra revisão na data ou quando condição for detectada

---

## Checklist de ADR Completo

- [ ] Número sequencial único
- [ ] Status definido (Proposto/Aceito/Depreciado/Substituído)
- [ ] Data e autores
- [ ] Contexto descreve o problema real, não a solução
- [ ] Mínimo 2 opções consideradas com prós e contras honestos
- [ ] Decisão explica o reasoning (não só o que, mas por quê)
- [ ] Consequências incluem tanto positivas quanto negativas
- [ ] Ações concretas listadas
- [ ] Critério de revisão definido (data ou condição)
- [ ] Adicionado ao índice de ADRs
