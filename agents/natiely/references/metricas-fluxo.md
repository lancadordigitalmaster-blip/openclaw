# Métricas de Fluxo — Fórmulas

## WIP (Work In Progress)

**Definição:** Número de tarefas em status "produzindo" por designer

**Fórmula:**
```
WIP = COUNT(tasks WHERE status = "produzindo" AND assignee = [designer])
```

**Meta:** WIP ≤ 2 por designer
**Alerta:** WIP > 2

---

## Aging

**Definição:** Dias desde a última atualização em tarefa ativa

**Fórmula:**
```
Aging = TODAY() - MAX(date_updated) WHERE status IN ("produzindo", "em alteração")
```

**Meta:** Aging ≤ 1 dia
**Alerta:** Aging > 3 dias

---

## Throughput

**Definição:** Tarefas concluídas no período

**Fórmula:**
```
Throughput = COUNT(tasks WHERE status = "arquivado" AND date_done BETWEEN [inicio] AND [fim])
```

**Períodos:**
- Diário: últimas 24h
- Semanal: últimos 7 dias
- Mensal: mês atual

---

## Evidence Coverage

**Definição:** % de tarefas concluídas com evidência/documentação

**Fórmula:**
```
Evidence Coverage = (DONE com evidência / DONE total) × 100
```

**Meta:** ≥ 80%
**Alerta:** < 80%

---

## Carga vs Meta

**Definição:** Comparação de tarefas atuais com capacidade planejada

**Fórmula:**
```
Carga % = (Tarefas atuais / Meta diária) × 100
```

**Indicadores:**
- 🟢 ≤ 80% — Disponível
- ⚖️ 81-100% — No limite
- 🔴 > 100% — Sobrecarregado

---

## Cycle Time

**Definição:** Tempo médio de conclusão (do início ao fim)

**Fórmula:**
```
Cycle Time = AVG(date_done - date_started) WHERE status = "arquivado"
```

**Meta:** ≤ 2 dias
**Alerta:** > 3 dias

---

## Lead Time

**Definição:** Tempo desde criação até conclusão

**Fórmula:**
```
Lead Time = AVG(date_done - date_created) WHERE status = "arquivado"
```

**Meta:** ≤ 3 dias
**Alerta:** > 5 dias
