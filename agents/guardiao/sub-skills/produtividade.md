# Produtividade — Módulo 03 do Guardião

## OBJETIVO

Calcular e registrar métricas de produtividade do time de design ao final de cada dia útil (22h BRT).

---

## MÉTRICAS CALCULADAS

### 1. Throughput por Designer

**Definição:** tarefas finalizadas no dia vs meta diária

**Fonte:** ClickUp API — tarefas com `due_date = hoje` e `status = finalizada`

**Metas configuradas:**
```
Pedro: 17 | Leoneli: 12 | Abilio: 14 | Eliedson: 8 | Levi: 2
```

**Cálculo:**
```
throughput_pct = tarefas_finalizadas / meta * 100
```

### 2. Taxa de Revisão por Designer

**Definição:** % de tarefas do dia que passaram por `em alteração`

**Fonte:** `clickup-history.jsonl` — eventos `status_after = em alteração` do dia

**Cálculo:**
```
taxa_revisao = tarefas_com_revisao / tarefas_totais_do_designer * 100
```

Alerta se taxa_revisao > 30% (mais de 1 em 3 tarefas foi revisada).

### 3. Aging — Tarefas Sem Finalizar

**Definição:** tarefas com `due_date <= hoje` que não estão em `finalizada` ou `enviado ao cliente`

**Alarme:** se aging > 2 dias → incluir no relatório diário com urgência ALTA

---

## RELATÓRIO DE PRODUTIVIDADE (22h)

Salvo em `~/.openclaw/reports/produtividade-{YYYY-MM-DD}.json`:

```json
{
  "data": "2026-03-10",
  "designers": {
    "Pedro": {
      "finalizadas": 14,
      "meta": 17,
      "throughput_pct": 82,
      "taxa_revisao_pct": 12,
      "aging_tasks": []
    }
  },
  "aging_critico": [
    {"task_id": "xxx", "nome": "...", "atraso_dias": 3, "designer": "Eliedson"}
  ]
}
```

---

## ALERTAS AUTOMÁTICOS

| Condição | Ação |
|----------|------|
| throughput < 70% | Incluir no relatório diário com flag 🔴 |
| taxa_revisao > 30% | Comentário educativo no grupo [ATD] do designer |
| aging > 2 dias | Escalar para Netto via Telegram |
| throughput >= 100% | Registrar conquista no relatório com flag 🟢 |

---

## INTEGRAÇÃO COM design-production-report.py

O Módulo 03 complementa o `design-production-report.py` com dados de tendência semanal.
O script de produção faz o report visual por WhatsApp; o Guardião mantém o histórico persistido para análise acumulada.

---

## REGRAS

- Calculado apenas 1x por dia (22h)
- Dados persistidos em JSON local para análise semanal
- Não envia mensagem ao grupo [DSG] — apenas alimenta o relatório do Módulo 04
- Deduplication: se já rodou hoje, não recalcular (checar timestamp no JSON)
