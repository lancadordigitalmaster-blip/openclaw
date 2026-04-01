---
name: "ai-humanizer"
description: "When the user wants to humanize text, remove AI patterns, make writing sound more natural, or score text for AI detection. Triggers: 'humaniza esse texto', 'remove padrão de IA', 'deixa mais natural', 'parece muito IA', 'reescreve de forma humana', 'humanize', 'tira o tom de robô', 'score de IA', 'detecta IA no texto'."
---

# AI Humanizer — Wolf Agency

Detecta e remove padrões de escrita de IA, reescrevendo o texto para soar natural e humano. Essencial para qualquer copy gerada pelo Alfred antes de ir para o cliente.

## O que detecta (24 padrões)

### Conteúdo
- **Inflação de significado** — "revolucionário", "transformador", "sem precedentes"
- **Atribuições vagas** — "estudos mostram", "especialistas dizem", sem citar fonte
- **Linguagem promocional** — superlativo gratuito, hype sem substância

### Linguagem
- **Vocabulário de IA** — delve, tapestry, vibrant, unleash, game-changer, paradigm shift
  - Em português: "mergulhar em", "tecer", "robusto", "alavancar", "ecossistema"
- **Evitar cópula** — frases que nunca usam "é/são" naturalmente
- **Regra de três** — listar sempre exatamente 3 itens

### Estilo
- **Excesso de travessão** — em vez de vírgula ou ponto
- **Negrito excessivo** — bold em tudo que "parece importante"
- **Títulos em Title Case** — Cada Palavra Capitalizada
- **Emoji em excesso** — especialmente no começo de cada parágrafo

### Comunicação
- **Tom sycofante** — "Ótima pergunta!", "Com certeza!", "Absolutamente!"
- **Disclaimers de corte** — "Como IA, eu...", "Meu conhecimento vai até..."

### Preenchimento
- **Frases de enchimento** — "É importante notar que", "Vale ressaltar que"
- **Hedging excessivo** — "pode ser", "talvez", "possivelmente" em todo parágrafo
- **Conclusões genéricas** — "Em conclusão, vimos que...", "Em resumo..."

## Modos de uso

### Modo Score
Avalia o texto de 0-100 (quanto maior, mais parece IA).
`"quanto esse texto parece IA? [texto]"`

### Modo Análise
Lista os padrões encontrados com trechos específicos.
`"analisa esse texto por padrões de IA"`

### Modo Humanizar
Reescreve o texto removendo os padrões detectados.
`"humaniza esse texto: [texto]"`
`"reescreve isso de forma mais natural: [texto]"`

### Modo Automático
Quando Alfred gera copy longa (posts, newsletters, artigos), pode passar automaticamente pelo humanizer antes de entregar ao usuário. Ativar com:
`"sempre humanize antes de me entregar copy"`

## Regras de reescrita

1. **Mantém o significado** — não muda o que foi dito, só como foi dito
2. **Mantém o tom de voz** — se houver brand-voice configurado, respeita
3. **Varia estrutura de frases** — mistura curtas e longas naturalmente
4. **Usa vocabulário do nicho** — substitui termos genéricos por específicos do contexto
5. **Remove redundâncias** — IA tende a repetir a mesma ideia com outras palavras

## Integração com sovereign-brand-voice-writer

Quando usado após geração de conteúdo, aplica humanização respeitando o tom de voz do cliente. Fluxo ideal:
```
Gerar conteúdo (brand-voice-writer) → Humanizar (ai-humanizer) → Entregar
```
