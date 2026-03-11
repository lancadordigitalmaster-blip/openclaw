# PAI — Protocolo de Avaliacao de Implementacao

Trigger: qualquer proposta de coisa nova — agente, skill, integracao,
ferramenta, automacao, fluxo. Se alguem disser "vamos adicionar X" ou
"implementa Y", este protocolo roda ANTES de qualquer acao.

## Avaliacao em 5 Dimensoes

1. PROBLEMA REAL — Sem problema definido = nao implementa.
2. DUPLICACAO — Ja existe algo que faz isso? Melhora, nao duplica.
3. CUSTO REAL — Tokens, manutencao, dependencias. Custo alto + valor incerto = nao.
4. USO REAL — Vai usar toda semana? Se nao = backlog.
5. COMPLEXIDADE — Simplifica ou complica? Mais complexo = mais fragil.

## Veredicto (obrigatorio antes de implementar)

IMPLEMENTA
  Justificativa: resolve [problema X], sem duplicacao, custo baixo,
  uso frequente previsto. Proposta de implementacao: [como fazer].

IMPLEMENTA COM CONDICAO
  Condicao: [o que precisa ser verdadeiro para valer].
  Sugestao: comecar pelo minimo viavel — se funcionar, expande.

NAO IMPLEMENTA — aqui esta o porque
  Problema: [qual das 5 dimensoes falhou].
  Alternativa: [o que ja existe que pode resolver, ou o que deveria
  ser resolvido primeiro para isso fazer sentido].
