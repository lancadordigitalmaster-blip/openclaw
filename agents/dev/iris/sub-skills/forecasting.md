# forecasting.md — IRIS Sub-Skill: Forecasting & Projeções
# Ativa quando: "forecast", "previsão", "tendência", "projeção"

---

## Quando Usar Forecasting

| Uso | Modelo Indicado | Dados Mínimos |
|-----|----------------|---------------|
| Projeção de budget mensal | Média móvel / Regressão linear | 60 dias |
| Tendência de crescimento | Regressão linear | 90 dias |
| Sazonalidade (datas comemorativas) | Prophet | 12 meses |
| Projeção de ROAS / CPA | Média móvel ponderada | 30 dias |
| Forecast de leads | Prophet | 6 meses |

**Regra:** Menos de 30 pontos de dados = não faça forecast. Use baseline + julgamento profissional.

---

## Modelo 1 — Média Móvel

Simples, confiável para séries com pouca sazonalidade.

```python
import pandas as pd
import numpy as np

def moving_average_forecast(series: pd.Series, window: int = 7,
                             periods_ahead: int = 30) -> pd.Series:
    """
    Forecast por média móvel simples.

    Args:
        series: Série temporal com índice de datas
        window: Janela de média (7 = semanal)
        periods_ahead: Quantos períodos projetar

    Returns:
        Série com as projeções
    """
    values = list(series.values)

    for _ in range(periods_ahead):
        next_val = np.mean(values[-window:])
        values.append(next_val)

    last_date = series.index[-1]
    freq = pd.infer_freq(series.index) or "D"
    forecast_index = pd.date_range(
        start=last_date + pd.tseries.frequencies.to_offset(freq),
        periods=periods_ahead,
        freq=freq,
    )

    return pd.Series(values[-periods_ahead:], index=forecast_index, name="forecast")


# Uso
# forecast = moving_average_forecast(df["conversions"], window=7, periods_ahead=30)
```

---

## Modelo 2 — Regressão Linear

Boa para tendências de crescimento/queda contínuos.

```python
from sklearn.linear_model import LinearRegression
import numpy as np
import pandas as pd

def linear_regression_forecast(series: pd.Series,
                                periods_ahead: int = 30) -> dict:
    """
    Forecast por regressão linear com intervalo de confiança.

    Returns:
        dict com valores de forecast e intervalos
    """
    X = np.arange(len(series)).reshape(-1, 1)
    y = series.values

    model = LinearRegression()
    model.fit(X, y)

    # Projeção
    future_X = np.arange(len(series), len(series) + periods_ahead).reshape(-1, 1)
    forecast_values = model.predict(future_X)

    # Erro residual para intervalo de confiança
    residuals = y - model.predict(X)
    std_error = np.std(residuals)

    last_date = series.index[-1]
    freq = pd.infer_freq(series.index) or "D"
    forecast_index = pd.date_range(
        start=last_date + pd.tseries.frequencies.to_offset(freq),
        periods=periods_ahead,
        freq=freq,
    )

    return {
        "forecast": pd.Series(forecast_values, index=forecast_index, name="forecast"),
        "upper": pd.Series(forecast_values + 1.96 * std_error,
                           index=forecast_index, name="upper_95"),
        "lower": pd.Series(np.maximum(forecast_values - 1.96 * std_error, 0),
                           index=forecast_index, name="lower_95"),
        "r2": model.score(X, y),
        "slope": model.coef_[0],
        "trend": "up" if model.coef_[0] > 0 else "down",
    }
```

---

## Modelo 3 — Prophet (Recomendado para Marketing)

Ideal para dados com sazonalidade semanal e anual (campanhas, feriados).

```python
from prophet import Prophet
import pandas as pd

def prophet_forecast(df: pd.DataFrame, date_col: str, metric_col: str,
                     periods: int = 90, freq: str = "D") -> pd.DataFrame:
    """
    Forecast com Prophet — suporta sazonalidade e feriados.

    Args:
        df: DataFrame com coluna de data e métrica
        date_col: Nome da coluna de data
        metric_col: Nome da coluna da métrica
        periods: Dias para projetar
        freq: Frequência dos dados ("D" = diário, "W" = semanal)

    Returns:
        DataFrame com forecast e intervalos
    """
    # Prophet exige colunas "ds" e "y"
    prophet_df = df[[date_col, metric_col]].rename(
        columns={date_col: "ds", metric_col: "y"}
    )
    prophet_df["ds"] = pd.to_datetime(prophet_df["ds"])

    model = Prophet(
        yearly_seasonality=True,
        weekly_seasonality=True,
        daily_seasonality=False,
        changepoint_prior_scale=0.05,  # conservador por padrão
        interval_width=0.80,           # 80% de confiança
    )

    # Feriados brasileiros relevantes para marketing
    model.add_country_holidays(country_name="BR")

    model.fit(prophet_df)

    future = model.make_future_dataframe(periods=periods, freq=freq)
    forecast = model.predict(future)

    # Retorna apenas a projeção futura
    result = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].tail(periods)
    result.columns = ["date", "forecast", "lower_80", "upper_80"]

    return result


def plot_prophet_forecast(model, forecast):
    """Plota forecast com componentes."""
    fig1 = model.plot(forecast)
    fig2 = model.plot_components(forecast)
    return fig1, fig2
```

---

## Comunicação de Incerteza

**Regra Wolf:** Nunca entregue forecast sem comunicar incerteza.

### Template de Comunicação

```markdown
## Projeção [MÉTRICA] — [CLIENTE] — [PERÍODO]

**Cenário Base:** [valor] ± [margem]
**Cenário Otimista (+1 desvio padrão):** [valor]
**Cenário Conservador (-1 desvio padrão):** [valor]

**Premissas:**
- Baseado em [N] dias de histórico
- Sem mudanças no budget ou estratégia
- Sazonalidade típica para o período

**Limitações:**
- Não considera eventos externos (crises, virais, mudanças de plataforma)
- Precisão diminui além de [X] dias
- Modelo: [nome do modelo]

**Confiança:** [Alta/Média/Baixa] — R² = [valor] ou MAPE = [%]
```

---

## Validação do Forecast

```python
from sklearn.metrics import mean_absolute_percentage_error
import numpy as np

def validate_forecast(actual: pd.Series, predicted: pd.Series) -> dict:
    """Calcula métricas de qualidade do forecast."""

    # Remove zeros do denominador para MAPE
    mask = actual != 0
    mape = mean_absolute_percentage_error(actual[mask], predicted[mask]) * 100

    mae = np.mean(np.abs(actual - predicted))

    return {
        "mape": round(mape, 2),       # < 20% = bom, < 10% = ótimo
        "mae": round(mae, 4),
        "accuracy_class": (
            "Otimo" if mape < 10 else
            "Bom" if mape < 20 else
            "Aceitavel" if mape < 30 else
            "Ruim"
        ),
    }
```

**Referência de qualidade:**
- MAPE < 10% = Ótimo — confiar no forecast
- MAPE 10-20% = Bom — usar com ressalvas
- MAPE 20-30% = Aceitável — só para tendência, não valores absolutos
- MAPE > 30% = Ruim — não usar ou aumentar dados

---

## Casos de Uso Wolf

### Projeção de Budget Mensal
```python
# "Com base no histórico de ROAS, qual budget precisamos para 100 conversões?"
def budget_projection(target_conversions: int, avg_cpa: float,
                      cpa_trend: float = 0.0) -> dict:
    """
    Projeta budget necessário para atingir meta de conversões.

    Args:
        target_conversions: Meta de conversões
        avg_cpa: CPA médio atual
        cpa_trend: Tendência de mudança no CPA (negativo = melhorando)
    """
    projected_cpa = avg_cpa * (1 + cpa_trend)
    budget_needed = target_conversions * projected_cpa

    return {
        "target_conversions": target_conversions,
        "projected_cpa": round(projected_cpa, 2),
        "budget_needed": round(budget_needed, 2),
        "budget_conservative": round(budget_needed * 1.20, 2),  # +20% buffer
    }
```

---

## Checklist Forecast

- [ ] Mínimo 30 pontos de dados (ideal 90+)
- [ ] Dados validados (sem gaps, sem outliers não explicados)
- [ ] Modelo escolhido conforme tipo de dado e sazonalidade
- [ ] Intervalo de confiança calculado e reportado
- [ ] MAPE calculado em dados de validação
- [ ] Premissas documentadas explicitamente
- [ ] Limitações comunicadas ao stakeholder
- [ ] Revisão agendada (forecast de 90 dias → revisar a cada 30 dias)
