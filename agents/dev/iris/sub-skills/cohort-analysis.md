# cohort-analysis.md — IRIS Sub-Skill: Cohort Analysis
# Ativa quando: "cohort", "LTV", "retenção", "funil de dados"

---

## Tipos de Análise Wolf

| Análise | O que responde | Uso principal |
|---------|---------------|---------------|
| Cohort de retenção | "Clientes de Jan ainda estão conosco?" | Medir saúde de carteira |
| LTV por cohort | "Quanto vale um cliente adquirido em X período?" | Decisão de budget/CAC |
| Cohort de conversão | "Em quanto tempo leads viram clientes?" | Otimizar funil de vendas |
| Funil de conversão | "Onde perdemos as pessoas?" | Melhorar campanhas |
| Churn analysis | "Quem vai sair? Quando?" | Retenção proativa |

---

## Funil de Conversão Wolf

```
Impressão → Clique → Landing Page → Lead → Proposta → Cliente
    ↓           ↓          ↓           ↓        ↓          ↓
[benchmark] [CTR>1.5%] [bounce<60%] [CVR>2%] [close>20%] [LTV]
```

### Implementação
```python
import pandas as pd

def calculate_funnel(df: pd.DataFrame, stages: list[str]) -> pd.DataFrame:
    """
    Calcula funil de conversão com taxa entre cada etapa.

    Args:
        df: DataFrame com coluna para cada etapa
        stages: Lista de colunas em ordem do funil
              Ex: ["impressions", "clicks", "leads", "proposals", "clients"]
    """
    funnel_data = []

    for i, stage in enumerate(stages):
        volume = df[stage].sum()
        prev_volume = df[stages[i - 1]].sum() if i > 0 else volume

        funnel_data.append({
            "stage": stage,
            "volume": int(volume),
            "conversion_from_previous": round((volume / prev_volume * 100), 1) if prev_volume > 0 else 100.0,
            "conversion_from_top": round((volume / df[stages[0]].sum() * 100), 2) if df[stages[0]].sum() > 0 else 100.0,
        })

    return pd.DataFrame(funnel_data)


# Uso
# stages = ["impressions", "clicks", "leads", "clients"]
# funnel = calculate_funnel(campaign_df, stages)
```

---

## Análise de Cohort — Retenção de Clientes

```python
import pandas as pd
import numpy as np

def build_retention_cohort(df: pd.DataFrame,
                            client_col: str = "client_id",
                            date_col: str = "date",
                            period: str = "M") -> pd.DataFrame:
    """
    Constrói matriz de retenção de clientes por cohort mensal.

    Args:
        df: DataFrame com client_id e date (cada linha = atividade/cobrança)
        client_col: Coluna de identificação do cliente
        date_col: Coluna de data
        period: "M" = mensal, "W" = semanal

    Returns:
        Matriz de retenção (cohort × período)
    """
    df = df.copy()
    df[date_col] = pd.to_datetime(df[date_col])
    df["period"] = df[date_col].dt.to_period(period)

    # Período de entrada de cada cliente (primeiro mês)
    cohort_df = df.groupby(client_col)["period"].min().reset_index()
    cohort_df.columns = [client_col, "cohort_period"]

    df = df.merge(cohort_df, on=client_col)

    # Índice: distância em períodos desde entrada
    df["period_number"] = (
        df["period"] - df["cohort_period"]
    ).apply(lambda x: x.n)

    # Contar clientes únicos por cohort e período
    cohort_data = (
        df.groupby(["cohort_period", "period_number"])[client_col]
        .nunique()
        .reset_index()
    )

    # Pivotar para formato de matriz
    cohort_pivot = cohort_data.pivot_table(
        index="cohort_period",
        columns="period_number",
        values=client_col,
    )

    # Calcular percentual de retenção (cohort 0 = 100%)
    cohort_size = cohort_pivot[0]
    retention_matrix = cohort_pivot.divide(cohort_size, axis=0) * 100

    return retention_matrix.round(1)
```

---

## Visualização de Cohort — Heatmap

```python
import matplotlib.pyplot as plt
import seaborn as sns

def plot_cohort_heatmap(retention_matrix: pd.DataFrame,
                        title: str = "Retenção de Clientes por Cohort"):
    """Visualiza matriz de retenção como heatmap."""

    fig, ax = plt.subplots(figsize=(14, 7))

    sns.heatmap(
        retention_matrix,
        annot=True,
        fmt=".0f",
        cmap="YlOrRd_r",   # Verde = alta retenção, Vermelho = baixa
        vmin=0,
        vmax=100,
        ax=ax,
        cbar_kws={"label": "Retenção (%)"},
        linewidths=0.5,
    )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15)
    ax.set_xlabel("Meses após entrada", fontsize=11)
    ax.set_ylabel("Cohort (mês de entrada)", fontsize=11)

    plt.tight_layout()
    return fig
```

---

## LTV por Tipo de Cliente

```python
def calculate_ltv(df: pd.DataFrame,
                  client_col: str = "client_id",
                  revenue_col: str = "mrr",
                  date_col: str = "date") -> pd.DataFrame:
    """
    Calcula LTV por cliente e estatísticas por segmento.

    Returns:
        DataFrame com LTV individual e agregado por segmento
    """
    df = df.copy()
    df[date_col] = pd.to_datetime(df[date_col])

    # Duração de cada cliente em meses
    client_stats = df.groupby(client_col).agg(
        first_date=(date_col, "min"),
        last_date=(date_col, "max"),
        avg_mrr=(revenue_col, "mean"),
        total_revenue=(revenue_col, "sum"),
    ).reset_index()

    client_stats["months_active"] = (
        (client_stats["last_date"] - client_stats["first_date"]).dt.days / 30
    ).clip(lower=1).round(1)

    client_stats["ltv"] = client_stats["total_revenue"]

    # Segmentação por quartil de LTV
    client_stats["ltv_segment"] = pd.qcut(
        client_stats["ltv"],
        q=4,
        labels=["Bronze", "Silver", "Gold", "Platinum"],
    )

    return client_stats


def ltv_summary(client_stats: pd.DataFrame) -> dict:
    """Resumo estatístico de LTV."""
    return {
        "avg_ltv": round(client_stats["ltv"].mean(), 2),
        "median_ltv": round(client_stats["ltv"].median(), 2),
        "avg_months": round(client_stats["months_active"].mean(), 1),
        "by_segment": client_stats.groupby("ltv_segment")["ltv"].agg(
            ["count", "mean", "median"]
        ).round(2).to_dict(),
    }
```

---

## Churn Analysis

```python
def identify_churn_risk(df: pd.DataFrame,
                         client_col: str = "client_id",
                         date_col: str = "date",
                         churn_threshold_days: int = 45) -> pd.DataFrame:
    """
    Identifica clientes em risco de churn (inatividade).

    Args:
        churn_threshold_days: Dias sem atividade = risco de churn
    """
    df = df.copy()
    df[date_col] = pd.to_datetime(df[date_col])

    last_activity = df.groupby(client_col)[date_col].max().reset_index()
    last_activity.columns = [client_col, "last_activity"]

    today = pd.Timestamp.now()
    last_activity["days_since_activity"] = (
        today - last_activity["last_activity"]
    ).dt.days

    last_activity["churn_risk"] = last_activity["days_since_activity"].apply(
        lambda d: (
            "CRITICAL" if d > churn_threshold_days * 2 else
            "HIGH" if d > churn_threshold_days else
            "LOW"
        )
    )

    at_risk = last_activity[last_activity["churn_risk"] != "LOW"].sort_values(
        "days_since_activity", ascending=False
    )

    return at_risk
```

---

## Checklist Análise de Cohort

- [ ] Dados históricos suficientes (mínimo 6 meses para cohort mensal)
- [ ] Identificador único de cliente consistente nos dados
- [ ] Definição de "atividade" clara (pagamento? login? campanha ativa?)
- [ ] Churn definido formalmente (X dias sem atividade = churned)
- [ ] Heatmap gerado e interpretado com stakeholder
- [ ] LTV calculado por segmento de cliente
- [ ] Comparação LTV vs CAC feita (LTV deve ser > 3x CAC)
- [ ] Clientes em risco mapeados e ação definida
