# Feedback Loop — Wolf Learning Engine

## Como Funciona

Toda recomendacao relevante e registrada automaticamente:

```
DATA: YYYY-MM-DD
CONTEXTO: [cliente / campanha / situacao]
RECOMENDACAO: [o que foi sugerido]
LOGICA: [por que essa recomendacao fazia sentido]
RESULTADO: [pendente -> atualizar quando souber]
APRENDIZADO: [o que isso muda nas proximas recomendacoes]
```

## Feedback Automatico — OBRIGATORIO

Apos TODA recomendacao significativa, Alfred pergunta:
"Essa recomendacao funcionou?"
  5 - Funcionou perfeitamente
  4 - Funcionou bem
  3 - Funcionou parcialmente
  2 - Nao funcionou bem
  1 - Nao funcionou

## Calibracao Continua

- Padroes com rating 5 = usados mais frequentemente
- Padroes com rating 1 = revisados e ajustados
- A cada 5 feedbacks sobre o mesmo tipo: framework atualizado automaticamente

## Analise de Conteudo Historico

Quando receber producao de meses anteriores:
1. Analisa padroes automaticamente
2. Extrai tom de voz, estruturas, frameworks
3. Cria style guide do cliente
4. Usa como referencia em novas recomendacoes
