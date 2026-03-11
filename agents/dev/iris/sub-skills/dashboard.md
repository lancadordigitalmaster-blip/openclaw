# dashboard.md — IRIS Sub-Skill: Dashboard Design & Implementation
# Ativa quando: "dashboard", "visualização", "gráfico", "relatório"

---

## Princípios de Design Wolf

**Regra 1 — North Star Metric (NSM)**
Todo dashboard tem UMA métrica principal que fica no topo, maior, em destaque. Sem NSM definida, o dashboard não começa.

**Regra 2 — 7±2 Métricas**
Máximo de 9 métricas por view. Acima disso, crie abas ou dashboards separados. Menos é mais.

**Regra 3 — Contexto Sempre**
Número sozinho não tem valor. Toda métrica exibe:
- Comparativo com período anterior (MoM, WoW, YoY)
- Delta percentual (▲ +12% ou ▼ -8%)
- Meta, se houver

**Regra 4 — Hierarquia Visual**
1. NSM (grande, topo)
2. Métricas secundárias (cards médios)
3. Gráficos de tendência
4. Tabelas de detalhe (bottom)

---

## Tipos de Gráfico Corretos

| Dado | Gráfico | Motivo |
|------|---------|--------|
| Tendência no tempo | Linha | Mostra evolução contínua |
| Comparação entre categorias | Barras verticais | Fácil comparação visual |
| Comparação entre períodos | Barras agrupadas | Contraste direto |
| Proporção simples (max 5 fatias) | Pizza/Donut | Apenas para proporção |
| Correlação entre variáveis | Scatter plot | Relação entre métricas |
| Performance vs meta | Gauge/Bullet | Progresso claro |
| Distribuição geográfica | Mapa de calor | Dados regionais |
| Retenção/cohort | Heatmap | Padrões temporais |

**Nunca use pizza com mais de 5 fatias.** Use barras horizontais.

---

## Stack Tecnológica Wolf

### Metabase — Dashboards Internos
Usar para: relatórios de operação, dashboards para gestores, dados do ClickUp, métricas internas.

```sql
-- Exemplo de query Metabase: ROAS por cliente no mês
SELECT
    client_name,
    SUM(revenue) / NULLIF(SUM(ad_spend), 0) AS roas,
    SUM(ad_spend) AS total_spend,
    SUM(conversions) AS total_conversions
FROM campaign_metrics
WHERE date_trunc('month', date) = date_trunc('month', CURRENT_DATE)
GROUP BY client_name
ORDER BY roas DESC;
```

### Recharts — Dashboards em Código (React)
```tsx
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface MetricData {
  date: string;
  roas: number;
  cpa: number;
}

export function RoasTrendChart({ data }: { data: MetricData[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="date" />
        <YAxis />
        <Tooltip formatter={(value: number) => value.toFixed(2)} />
        <Legend />
        <Line
          type="monotone"
          dataKey="roas"
          stroke="#2563eb"
          strokeWidth={2}
          dot={false}
          name="ROAS"
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
```

### Chart.js — Dashboards em Vanilla JS / Python
```python
import matplotlib.pyplot as plt
import pandas as pd

def plot_metric_trend(df: pd.DataFrame, metric: str, title: str):
    """Plota tendência de métrica com contexto."""
    fig, ax = plt.subplots(figsize=(12, 5))

    ax.plot(df['date'], df[metric], linewidth=2, color='#2563eb', label=metric.upper())

    # Linha de média móvel como contexto
    rolling_avg = df[metric].rolling(window=7).mean()
    ax.plot(df['date'], rolling_avg, linewidth=1, color='#94a3b8',
            linestyle='--', label='Média 7 dias')

    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.set_xlabel('Data')
    ax.set_ylabel(metric.upper())
    ax.legend()
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig
```

---

## Checklist Antes de Construir Dashboard

**Definição:**
- [ ] NSM definida com o stakeholder
- [ ] Audiência mapeada (quem vai usar, com que frequência)
- [ ] Fonte de dados mapeada e validada
- [ ] Período padrão definido (últimos 30d, mês atual, etc.)
- [ ] Comparativo definido (MoM, YoY, vs meta)

**Design:**
- [ ] Máximo de 9 métricas na view principal
- [ ] NSM em destaque visual claro
- [ ] Contexto em todas as métricas (delta, comparativo)
- [ ] Tipos de gráfico corretos para cada dado
- [ ] Mobile-friendly se for acessado em celular

**Dados:**
- [ ] Dados validados contra fonte original
- [ ] Atualização automática configurada (refresh rate)
- [ ] Tratamento de dados nulos/ausentes
- [ ] Timezone padronizado (Brasil: UTC-3)

**Entrega:**
- [ ] Dashboard compartilhado com acesso correto (view-only para clientes)
- [ ] Explicação das métricas documentada
- [ ] Alerta de anomalia configurado (ver anomaly-detection.md)

---

## Padrão de Nomenclatura

```
[CLIENTE] - [SERVIÇO] - [FREQUÊNCIA]
Exemplo: ACME - Tráfego Pago - Semanal
```

Dashboards de cliente sempre em modo view-only. Nunca editar direto no acesso do cliente.
