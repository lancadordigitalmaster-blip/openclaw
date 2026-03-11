# Alerta de Divergência — Relatório vs. Metas do Sistema

> Sistema de validação automática de relatórios de demanda

---

## 🎯 Objetivo

Detectar quando o relatório manual enviado pela equipe diverge das metas oficiais cadastradas no sistema (`memory/metas-wolf.md`).

---

## ⚠️ Alertas de Divergência

### Tipo 1: Meta Incorreta no Relatório
```
🚨 DIVERGÊNCIA DETECTADA — Meta do Designer

Designer: [NOME]
Meta no relatório: [X]
Meta no sistema: [Y]

✅ Ação: Usar meta do sistema ([Y])
```

### Tipo 2: Status Calculado Errado
```
🚨 DIVERGÊNCIA DETECTADA — Status do Designer

Designer: [NOME]
Atual: [A] | Meta sistema: [M]
Capacidade real: [M - A]

Relatório diz: [status errado]
Correto: [status correto]

✅ Ação: [recomendação]
```

### Tipo 3: Designer sem Meta
```
⚠️ DESIGNER SEM META CADASTRADA

Designer: [NOME]
Demandas atuais: [X]

🔧 Ação necessária: Definir meta em memory/metas-wolf.md
```

---

## 📋 Designers com Divergências Atuais

| Designer | Relatório (10h) | Meta Sistema | Divergência |
|----------|-----------------|--------------|-------------|
| **Leoneli** | 4/14 (+10) | 4/12 (+8) | ⚠️ Meta relatório: 14, sistema: 12 |
| **Levi** | 2/5 (+3) | 2/2 (0) | ⚠️ Meta relatório: 5, sistema: 2 |
| **Mateus** | 0/3 | — | ⚠️ Sem meta no sistema |

---

## 🔄 Processo de Validação

```
1. Receber relatório manual
   ↓
2. Comparar com memory/metas-wolf.md
   ↓
3. Detectar divergências
   ↓
4. Enviar alerta (se houver)
   ↓
5. Usar meta do sistema para análise
   ↓
6. Gerar recomendações corretas
```

---

## ✅ Regras de Ouro

1. **Sempre usar meta do sistema** — `memory/metas-wolf.md` é a fonte da verdade
2. **Alertar, não corrigir** — Notificar divergência, não alterar relatório da equipe
3. **Manter histórico** — Registrar quando metas mudaram
4. **Solicitar atualização** — Pedir para equipe alinhar relatório com sistema

---

## 📝 Template de Alerta para Equipe

```
📊 VALIDAÇÃO DE RELATÓRIO — DESIGNERS

Relatório recebido: DD/MM/YYYY HHh
Status: ⚠️ DIVERGÊNCIAS ENCONTRADAS

🔍 Divergências:
• Leoneli: Meta relatório (14) ≠ Meta sistema (12)
• Levi: Meta relatório (5) ≠ Meta sistema (2)
• Mateus: Sem meta cadastrada no sistema

✅ Ação tomada: Usadas metas do sistema para análise

📋 Recomendações com base nas metas oficiais:
[recomendações atualizadas]

🔧 Ação necessária da equipe:
Atualizar metas no relatório manual ou solicitar alteração no sistema.
```

---

*Sistema de validação automática — Wolf Agency*
