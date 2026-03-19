---
name: strategic-compact
description: Gerencia compactação estratégica de contexto em pontos lógicos do workflow. Use quando a sessão se aproxima de limites de contexto, ao alternar entre fases de tarefas, ou após completar um milestone. Previne interrupção de operações complexas por auto-compactação arbitrária.
origin: ECC (adapted for Wolf Agency)
---

# Strategic Compact — Wolf Agency

Sugere compactação manual em pontos estratégicos, em vez de depender de auto-compactação arbitrária.

## Quando Ativar

- Sessões longas se aproximando de limites de contexto (1MB+)
- Trabalho em multi-fases (pesquisa → plano → implementação → teste)
- Alternando entre tarefas não relacionadas na mesma sessão
- Após completar um milestone importante e iniciar trabalho novo
- Quando respostas ficam mais lentas ou menos coerentes (pressão de contexto)
- Never-Forget Protocol em ORANGE ou RED

## Por Que Compactação Estratégica?

Auto-compactação dispara em pontos arbitrários:
- Frequentemente no meio de tarefas, perdendo contexto importante
- Sem consciência de fronteiras lógicas de tarefas
- Pode interromper operações complexas multi-etapa

Compactação estratégica em fronteiras lógicas:
- **Após exploração, antes de execução** — Compactar contexto de pesquisa, manter plano de implementação
- **Após completar um milestone** — Início limpo para próxima fase
- **Antes de mudanças de contexto** — Limpar contexto de exploração antes de tarefa diferente

## Guia de Decisão de Compactação

| Transição de Fase | Compactar? | Por Quê |
|------------------|------------|---------|
| Pesquisa → Planejamento | ✅ Sim | Contexto de pesquisa é volumoso; plano é o output destilado |
| Planejamento → Implementação | ✅ Sim | Plano já está em arquivo; liberar contexto para código |
| Implementação → Teste | ⚠️ Talvez | Manter se testes referenciam código recente |
| Debug → Próxima feature | ✅ Sim | Traces de debug poluem contexto para trabalho não relacionado |
| Meio da implementação | ❌ Não | Perder variáveis, paths e estado parcial é custoso |
| Após abordagem falhada | ✅ Sim | Limpar raciocínio de beco sem saída antes de tentar nova abordagem |

## O Que Sobrevive à Compactação

| Persiste | Perdido |
|----------|---------|
| Arquivos SOUL.md, AGENTS.md | Raciocínio intermediário e análise |
| memory/*.md (arquivos no disco) | Conteúdo de arquivos lidos anteriormente |
| Estado git (commits, branches) | Histórico de tool calls |
| Crons e configurações | Preferências expressas verbalmente |

## Melhores Práticas

1. **Compactar após planejamento** — Uma vez finalizado o plano, compactar para começar fresco
2. **Compactar após debugging** — Limpar contexto de resolução de erros antes de continuar
3. **Não compactar no meio da implementação** — Preservar contexto para mudanças relacionadas
4. **Salvar antes de compactar** — Gravar contexto importante em arquivos memory/ antes de compactar
5. **Usar `/compact` com resumo** — Adicionar mensagem: "Focus em implementar X em seguida"

## Estratégias de Otimização de Contexto

### Carregamento Lazy de Skills
Em vez de carregar todo o conteúdo de skills no início, usar tabela de triggers:

| Trigger | Skill | Carregar Quando |
|---------|-------|-----------------| 
| "conteúdo", "post", "legenda" | content-engine | Contexto de social media |
| "campanha", "ads", "tráfego" | meta-ads / google-ads | Contexto de tráfego pago |
| "SEO", "keywords" | google-trends / content-creator | Contexto de SEO |
| "financeiro", "DRE", "fluxo" | cfo-wolf | Contexto financeiro |

### Fontes de Consumo de Contexto
- **SOUL.md + AGENTS.md** — Sempre carregados, manter enxutos
- **Skills carregadas** — Cada skill adiciona 1-5K tokens
- **Histórico de conversa** — Cresce a cada exchange
- **Resultados de ferramentas** — Leituras de arquivo e buscas adicionam volume

## Protocolo Wolf para Contexto Crítico

Quando Never-Forget Protocol ativa ORANGE ou RED:
1. Salvar estado em `memory/last-context.md` imediatamente
2. Completar resposta atual de forma concisa
3. Sugerir compactação para Netto
4. Após compactação, retomar via `memory/last-context.md`
