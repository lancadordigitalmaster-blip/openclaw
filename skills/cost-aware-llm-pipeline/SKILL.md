---
name: cost-aware-llm-pipeline
description: Padrões de otimização de custo para uso de LLM — roteamento por complexidade, budget tracking, retry logic, e prompt caching. Use ao construir sistemas que chamam APIs de LLM, processar batches, ou quando precisa reduzir custo sem perder qualidade. Versão Wolf Agency do ECC.
origin: ECC (adapted for Wolf Agency)
---

# Cost-Aware LLM Pipeline — Wolf Agency

Padrões para controlar custos de API de LLM mantendo qualidade.

## Quando Ativar

- Construir sistemas que chamam APIs Claude, OpenAI, etc.
- Processar batches de itens com complexidade variada
- Precisar ficar dentro de um budget de API
- Otimizar custo sem sacrificar qualidade em tarefas complexas

## Regra de Roteamento — Alfred

| Tarefa | Modelo | Motivo |
|--------|--------|--------|
| Crons, heartbeats, monitoring | Haiku 4.5 | ~4x mais barato |
| Interação Telegram (Netto) | Sonnet 4.6 | Qualidade primária |
| Análise complexa, código | Sonnet 4.6 | Necessidade real |
| Raciocínio arquitetural profundo | Opus 4.6 | Reservar para casos críticos |

## Thresholds de Roteamento

```
texto > 10.000 chars → Sonnet
itens > 30 → Sonnet
simples/rotina → Haiku
```

## Preços de Referência (2025-2026)

| Modelo | Input ($/1M tokens) | Output ($/1M tokens) | Custo relativo |
|--------|---------------------|----------------------|----------------|
| Haiku 4.5 | $0.80 | $4.00 | 1x |
| Sonnet 4.6 | $3.00 | $15.00 | ~4x |
| Opus 4.6 | $15.00 | $75.00 | ~19x |

## Retry Logic — Regras

Fazer retry APENAS em erros transitórios:
- `APIConnectionError` ✅
- `RateLimitError` ✅ (com backoff exponencial)
- `InternalServerError` ✅

Falhar rápido sem retry:
- `AuthenticationError` ❌
- `BadRequestError` ❌

Backoff: 2^tentativa segundos (1s, 2s, 4s). Máximo 3 tentativas.

## Prompt Caching

Para system prompts longos (>1024 tokens), usar cache:
- Economiza custo e latência em chamadas repetidas
- `cache_control: {type: "ephemeral"}` na parte estática do prompt

## Anti-padrões a Evitar

- ❌ Usar Sonnet/Opus para todas as tarefas independente da complexidade
- ❌ Fazer retry em erros permanentes (desperdiça budget)
- ❌ Hardcodar nomes de modelo espalhados no código
- ❌ Ignorar prompt caching em system prompts repetitivos
- ❌ Não monitorar custo acumulado

## Melhores Práticas

- **Começar com o modelo mais barato**, escalar só quando necessário
- **Definir budget limits** antes de rodar batches
- **Logar decisões de roteamento** para tunar thresholds com dados reais
- **Usar prompt caching** para system prompts acima de 1024 tokens
- **Nunca fazer retry** em erros de autenticação ou validação

## Aplicação na Wolf

Arquitetura Anthropic-first do Alfred:
- Primário (Telegram): `anthropic/claude-sonnet-4-6`
- Crons/Automações: `anthropic/claude-haiku-4-5-20251001`
- Fallback 1: `anthropic/claude-haiku-4-5-20251001`
- Fallback 2: `openrouter/anthropic/claude-haiku-4-5`
- Fallback 3: `openrouter/google/gemini-2.5-flash`
