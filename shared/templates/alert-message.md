# Template — Mensagem de Alerta (Telegram)

> Usado pelos agentes para notificar Netto via Telegram sobre situações urgentes.

---

## Formato de Alerta

```
🚨 ALERTA [SEVERIDADE] — [AGENTE]
━━━━━━━━━━━━━━━━━━━━━━
Cliente: [NOME DO CLIENTE]
Tipo: [BUDGET / CRIATIVO / RANKING / PERFORMANCE]

📌 O que aconteceu:
[Descrição objetiva do problema]

📊 Dados:
[Métrica relevante: valor atual vs. esperado]

⚡ Ação sugerida:
[O que o agente recomenda fazer]

✅ Para confirmar: responda "ok [id do alerta]"
❌ Para ignorar: responda "skip [id do alerta]"
```

---

## Exemplos por Agente

### Gabi — Alerta de Budget
```
🚨 ALERTA ALTA — Gabi 🎯
━━━━━━━━━━━━━━━━━━━━━━
Cliente: Cliente X
Tipo: BUDGET

📌 O que aconteceu:
Campanha "Conversão - Produto A" consumiu 92% do budget diário às 14h.

📊 Dados:
Budget diário: R$ 200 | Gasto atual: R$ 184 | Horas restantes: 10h

⚡ Ação sugerida:
Aumentar budget em R$ 50 para não perder volume de conversão à tarde.

✅ Para confirmar: responda "ok alerta-024"
❌ Para ignorar: responda "skip alerta-024"
```

### Luna — Alerta de Criativo
```
⚠️ ALERTA MÉDIA — Luna 🌙
━━━━━━━━━━━━━━━━━━━━━━
Cliente: Cliente Y
Tipo: CRIATIVO

📌 O que aconteceu:
Criativo "Banner Black Friday" pendente de aprovação há 52h.

📊 Dados:
Criado em: 02/03 | Prazo de publicação: 05/03

⚡ Ação sugerida:
Contatar cliente para aprovação ou substituir por criativo alternativo.

✅ Para confirmar: responda "ok alerta-025"
```

---

## Severidades

| Ícone | Severidade | Uso |
|-------|-----------|-----|
| 🚨 | ALTA | Ação necessária nas próximas horas |
| ⚠️ | MÉDIA | Ação necessária hoje |
| ℹ️ | BAIXA | Para conhecimento, sem urgência |
