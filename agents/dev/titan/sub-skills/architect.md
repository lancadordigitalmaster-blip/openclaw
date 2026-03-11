# architect.md — Titan Sub-Skill: Arquitetura
# Ativa quando: "como estruturar", "arquitetura", "novo sistema", "escalabilidade"

---

## PROTOCOLO DE DECISÃO ARQUITETURAL

```
PRINCÍPIOS QUE GUIAM TITAN:

  1. YAGNI — You Aren't Gonna Need It
     Não constrói para o futuro imaginado. Constrói para o presente real.

  2. KISS — Keep It Simple, Stupid
     A solução mais simples que funciona é geralmente a melhor.

  3. Wet before DRY
     Repete o código 2x antes de abstrair. Na terceira vez, abstrai.

  4. Fail Fast
     Valida inputs cedo. Lança erros descritivos. Nunca falha silenciosamente.

  5. Boundaries before Implementation
     Define as interfaces/contratos antes de implementar os detalhes.
```

---

## TEMPLATE DE ADR (Architecture Decision Record)

```markdown
# ADR-[N]: [Título da Decisão]
Data: [YYYY-MM-DD]
Status: [proposto | aceito | depreciado | substituído por ADR-X]

## Contexto
[O que está acontecendo que requer uma decisão?]

## Opções Consideradas

### Opção A: [Nome]
Prós: [lista]
Contras: [lista]

### Opção B: [Nome]
Prós: [lista]
Contras: [lista]

## Decisão
[Opção escolhida e por quê — específico para este contexto]

## Consequências
Positivas: [o que ganhamos]
Negativas: [o que perdemos ou aceitamos]
Neutras: [o que muda sem valor de juízo]

## Revisitar quando
[Condição que tornaria esta decisão obsoleta]
```

---

## PADRÕES ARQUITETURAIS WOLF

```yaml
para_apis_simples:
  recomendacao: Express ou Hono (Node.js) / FastAPI (Python)
  quando: MVP, API pequena, time pequeno
  evitar: NestJS ou arquitetura hexagonal para APIs com < 10 endpoints

para_sistemas_complexos:
  recomendacao: NestJS (Node.js) com injeção de dependência
  quando: múltiplos módulos, team > 3 devs, longa vida útil

para_dados_em_tempo_real:
  recomendacao: WebSocket (Socket.io) ou SSE para streaming
  quando: dashboard ao vivo, notificações, colaboração

para_jobs_background:
  recomendacao: BullMQ (Redis) para Node.js / Celery para Python
  quando: envio de email, processamento de imagem, sync de dados

para_multi_agente_ai:
  recomendacao: OpenClaw com SOUL.md + SKILL.md (já em uso)
  quando: orquestração de agentes Wolf
  evitar: LangChain para casos simples (over-engineering)
```
