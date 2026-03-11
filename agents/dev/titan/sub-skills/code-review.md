# code-review.md — Titan Sub-Skill: Code Review
# Ativa quando: "revisa", "review", "está certo esse código", "analisa"

---

## PROTOCOLO DE REVIEW

```
ANTES DE REVISAR:
  □ Entendo o que esse código deveria fazer?
  □ Conheço o contexto do sistema onde vai rodar?
  Se não: pergunta antes de revisar

LEITURA EM 3 PASSES:

  PASS 1 — VISÃO GERAL (entendimento)
    → O que este código faz?
    → Faz sentido para o problema que resolve?
    → A estrutura está clara ou precisa de mapa?

  PASS 2 — DETALHAMENTO (bugs e segurança)
    → Linha por linha das partes críticas
    → Foco: edge cases, erros não tratados, segurança
    → Marca com: 🔴 BLOQUEADOR / 🟡 IMPORTANTE / 🟢 SUGESTÃO

  PASS 3 — QUALIDADE (manutenibilidade)
    → Nomes descritivos?
    → Funções com responsabilidade única?
    → Complexidade desnecessária?
    → Código duplicado abstraível?

CHECKLIST SEGURANÇA (nunca pula):
  □ Inputs externos são validados antes de usar
  □ Nenhum secret/token no código (usar .env)
  □ Queries SQL usam prepared statements ou ORM
  □ Autenticação verificada antes de operações sensíveis
  □ Logs não expõem dados sensíveis (senha, CPF, token)
  □ Rate limiting em endpoints públicos
```

---

## FORMATO DE OUTPUT DO REVIEW

```
🔴 BLOQUEADORES (não vai pra produção assim)
  [arquivo:linha] — Descrição do problema
  Por quê é bloqueador: [risco concreto]
  Fix sugerido: [código ou direção]

🟡 IMPORTANTES (deve ser corrigido, mas não bloqueia)
  [arquivo:linha] — Descrição
  Impacto se não corrigir: [consequência]
  Fix sugerido: [código ou direção]

🟢 SUGESTÕES (melhoria, não obrigatório)
  [arquivo:linha] — Sugestão
  Benefício: [por que seria melhor]

💡 APRENDIZADOS (contexto e explicação)
  Tema: [conceito]
  Contexto: [por que é relevante aqui]
  Referência: [link ou explicação]

RESUMO:
  Bloqueadores: N | Importantes: N | Sugestões: N
  Decisão: [aprovado / aprovado com ressalvas / requer mudanças]
```
