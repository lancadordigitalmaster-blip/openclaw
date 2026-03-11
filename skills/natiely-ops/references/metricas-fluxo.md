# Métricas de Fluxo — Fórmulas

## KPIs Principais

### 1. WIP (Work In Progress)
**Fórmula:** Contagem de tarefas em status "produzindo" por pessoa

**Alerta:** > 2 tarefas por designer

**Cálculo:**
```
WIP = COUNT(tasks WHERE status = "produzindo" AND assignee = [designer])
```

---

### 2. Aging
**Fórmula:** Dias desde última atualização em status "produzindo"

**Alerta:** > 3 dias sem avanço

**Cálculo:**
```
Aging = (NOW - last_updated_timestamp) / 86400
```

---

### 3. Throughput
**Fórmula:** Quantidade de tarefas movidas para "finalizada" no período

**Cálculo:**
```
Throughput = COUNT(tasks WHERE status = "finalizada" 
                      AND date_updated BETWEEN [inicio] AND [fim])
```

---

### 4. Cycle Time
**Fórmula:** Tempo desde "produzindo" até "finalizada"

**Cálculo:**
```
Cycle Time = timestamp("finalizada") - timestamp("produzindo")
```

**Métrica:** Mediana e percentil 90

---

### 5. Lead Time
**Fórmula:** Tempo desde criação até "finalizada"

**Cálculo:**
```
Lead Time = timestamp("finalizada") - timestamp("created")
```

---

### 6. Evidence Coverage
**Fórmula:** % de tarefas DONE com evidência

**Cálculo:**
```
Evidence Coverage = (COUNT(done WITH evidence) / COUNT(done TOTAL)) * 100
```

**Alerta:** < 80% na semana

---

### 7. Predictability
**Fórmula:** % de entregue vs planejado

**Cálculo:**
```
Predictability = (COUNT(entregue) / COUNT(planejado)) * 100
```

**Alerta:** < 70%

---

### 8. Rework Rate
**Fórmula:** % de tarefas reabertas

**Cálculo:**
```
Rework Rate = (COUNT(reabertas) / COUNT(concluídas)) * 100
```

**Alerta:** > 15%

---

## Dashboard Diário

```
📊 MÉTRICAS DE FLUXO — [DATA]

WIP Médio: [X] tarefas/designer
Aging Crítico: [Y] tarefas > 3 dias
Throughput Hoje: [Z] entregas
Evidence Coverage: [W]%
Predictability Semana: [P]%
```

## Dashboard Semanal

```
📈 MÉTRICAS SEMANAIS — [SEMANA]

Throughput: [X] entregas
Cycle Time (mediana): [Y] horas
Lead Time (mediana): [Z] horas
Evidence Coverage: [W]%
Rework Rate: [R]%
Blocked Time: [B]%
```
