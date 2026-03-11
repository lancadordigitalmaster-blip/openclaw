# pipeline.md — IRIS Sub-Skill: ETL Pipeline Architecture
# Ativa quando: "pipeline", "ETL", "ingestão", "transformação de dados"

---

## Arquitetura ETL Wolf

```
EXTRACT → TRANSFORM → LOAD → VALIDATE → ALERT
   ↓           ↓          ↓        ↓         ↓
 APIs       pandas     banco     testes    Telegram
 CSVs      limpeza    sheets   schema     anomalia
 webhooks  enrich.    S3/GCS   nulls      falha
```

**Princípio:** Cada etapa é isolada. Falha em uma etapa não corrompe dados já carregados.

---

## Fontes de Dados Wolf

| Fonte | Tipo | Frequência | Auth |
|-------|------|-----------|------|
| GA4 API | REST | Diário | Service Account JSON |
| Meta Ads API | REST | Diário | Access Token + App Secret |
| Google Ads API | REST | Diário | OAuth2 + Developer Token |
| ClickUp API | REST | Horário | API Key |
| Google Sheets | REST | Sob demanda | Service Account JSON |

---

## Estrutura de Projeto Pipeline

```
pipeline/
├── extract/
│   ├── ga4.py
│   ├── meta_ads.py
│   ├── google_ads.py
│   └── clickup.py
├── transform/
│   ├── normalize.py
│   ├── enrich.py
│   └── aggregate.py
├── load/
│   ├── database.py
│   └── sheets.py
├── validate/
│   └── schema.py
├── utils/
│   ├── logger.py
│   └── alerts.py
├── config/
│   └── settings.py
└── main.py
```

---

## Extract — Exemplos por Fonte

### GA4 API
```python
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    DateRange, Dimension, Metric, RunReportRequest
)

def extract_ga4(property_id: str, start_date: str, end_date: str) -> list[dict]:
    """Extrai dados do GA4 para período especificado."""
    client = BetaAnalyticsDataClient()

    request = RunReportRequest(
        property=f"properties/{property_id}",
        dimensions=[
            Dimension(name="date"),
            Dimension(name="sessionSource"),
        ],
        metrics=[
            Metric(name="sessions"),
            Metric(name="conversions"),
            Metric(name="totalRevenue"),
        ],
        date_ranges=[DateRange(start_date=start_date, end_date=end_date)],
    )

    response = client.run_report(request)

    rows = []
    for row in response.rows:
        rows.append({
            "date": row.dimension_values[0].value,
            "source": row.dimension_values[1].value,
            "sessions": int(row.metric_values[0].value),
            "conversions": int(row.metric_values[1].value),
            "revenue": float(row.metric_values[2].value),
        })

    return rows
```

### Meta Ads API
```python
import requests
from datetime import date

def extract_meta_ads(account_id: str, access_token: str,
                     start_date: str, end_date: str) -> list[dict]:
    """Extrai insights de campanhas Meta Ads."""
    url = f"https://graph.facebook.com/v19.0/act_{account_id}/insights"

    params = {
        "access_token": access_token,
        "fields": "campaign_name,spend,impressions,clicks,actions",
        "time_range": f'{{"since":"{start_date}","until":"{end_date}"}}',
        "level": "campaign",
        "limit": 500,
    }

    response = requests.get(url, params=params)
    response.raise_for_status()

    data = response.json().get("data", [])

    rows = []
    for item in data:
        conversions = 0
        for action in item.get("actions", []):
            if action["action_type"] == "purchase":
                conversions = int(action["value"])

        rows.append({
            "campaign_name": item["campaign_name"],
            "spend": float(item.get("spend", 0)),
            "impressions": int(item.get("impressions", 0)),
            "clicks": int(item.get("clicks", 0)),
            "conversions": conversions,
        })

    return rows
```

---

## Transform — Normalização e Schema Padrão

```python
import pandas as pd
from datetime import datetime

# Schema padronizado de output Wolf
WOLF_SCHEMA = {
    "date": "datetime64[ns]",
    "client_id": "str",
    "source": "str",           # ga4, meta_ads, google_ads
    "campaign_name": "str",
    "impressions": "int64",
    "clicks": "int64",
    "spend": "float64",
    "conversions": "int64",
    "revenue": "float64",
    "ctr": "float64",          # calculado
    "cpa": "float64",          # calculado
    "roas": "float64",         # calculado
}

def transform_metrics(df: pd.DataFrame, client_id: str, source: str) -> pd.DataFrame:
    """Normaliza dados para schema Wolf padrão."""

    # Tipos corretos
    df["date"] = pd.to_datetime(df["date"])
    df["client_id"] = client_id
    df["source"] = source

    # Garantir colunas numéricas
    numeric_cols = ["impressions", "clicks", "spend", "conversions", "revenue"]
    for col in numeric_cols:
        if col not in df.columns:
            df[col] = 0
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

    # Métricas calculadas
    df["ctr"] = df.apply(
        lambda r: r["clicks"] / r["impressions"] if r["impressions"] > 0 else 0,
        axis=1
    )
    df["cpa"] = df.apply(
        lambda r: r["spend"] / r["conversions"] if r["conversions"] > 0 else 0,
        axis=1
    )
    df["roas"] = df.apply(
        lambda r: r["revenue"] / r["spend"] if r["spend"] > 0 else 0,
        axis=1
    )

    # Remover duplicatas
    df = df.drop_duplicates(subset=["date", "client_id", "source", "campaign_name"])

    # Ordenar
    df = df.sort_values("date").reset_index(drop=True)

    return df
```

---

## Load — Banco de Dados

```python
import sqlalchemy as sa
from sqlalchemy import create_engine

def load_to_database(df: pd.DataFrame, table: str, engine: sa.Engine):
    """Carrega dados no banco com upsert."""

    # Upsert: evita duplicatas em reprocessamento
    temp_table = f"{table}_temp_{int(datetime.now().timestamp())}"

    with engine.begin() as conn:
        # Carrega em tabela temporária
        df.to_sql(temp_table, conn, if_exists="replace", index=False)

        # Upsert para tabela principal
        conn.execute(sa.text(f"""
            INSERT INTO {table}
            SELECT * FROM {temp_table}
            ON CONFLICT (date, client_id, source, campaign_name)
            DO UPDATE SET
                impressions = EXCLUDED.impressions,
                clicks = EXCLUDED.clicks,
                spend = EXCLUDED.spend,
                conversions = EXCLUDED.conversions,
                revenue = EXCLUDED.revenue,
                ctr = EXCLUDED.ctr,
                cpa = EXCLUDED.cpa,
                roas = EXCLUDED.roas,
                updated_at = NOW();
        """))

        # Remove temporária
        conn.execute(sa.text(f"DROP TABLE {temp_table};"))
```

---

## Agendamento

### GitHub Actions (recomendado para pipelines de dados)
```yaml
# .github/workflows/daily-pipeline.yml
name: Daily Data Pipeline

on:
  schedule:
    - cron: '0 6 * * *'  # 06:00 UTC (03:00 BRT)
  workflow_dispatch:       # Trigger manual

jobs:
  run-pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run pipeline
        env:
          GA4_CREDENTIALS: ${{ secrets.GA4_CREDENTIALS }}
          META_ACCESS_TOKEN: ${{ secrets.META_ACCESS_TOKEN }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: python pipeline/main.py

      - name: Notify on failure
        if: failure()
        run: python pipeline/utils/alerts.py --message "Pipeline falhou - verificar logs"
```

### Cron (alternativa local/servidor)
```bash
# Editar crontab: crontab -e
# Pipeline diário às 03:00 BRT
0 6 * * * cd /opt/wolf-pipeline && /usr/bin/python3 main.py >> /var/log/wolf-pipeline.log 2>&1
```

---

## Tratamento de Falhas

```python
import logging
from functools import wraps
from utils.alerts import send_telegram_alert

logger = logging.getLogger(__name__)

def with_retry(max_retries: int = 3, delay: float = 5.0):
    """Decorator para retry automático em caso de falha."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_error = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_error = e
                    logger.warning(f"Tentativa {attempt + 1}/{max_retries} falhou: {e}")
                    if attempt < max_retries - 1:
                        import time
                        time.sleep(delay * (attempt + 1))  # backoff exponencial

            logger.error(f"Todas as tentativas falharam: {last_error}")
            send_telegram_alert(f"PIPELINE FALHOU: {func.__name__} — {last_error}")
            raise last_error
        return wrapper
    return decorator

@with_retry(max_retries=3)
def extract_ga4_safe(property_id: str, start_date: str, end_date: str):
    return extract_ga4(property_id, start_date, end_date)
```

---

## Checklist Pipeline Novo

- [ ] Fontes de dados mapeadas e credenciais configuradas em .env/secrets
- [ ] Schema de output definido e documentado
- [ ] Tratamento de nulls e tipos implementado
- [ ] Upsert configurado (evita dados duplicados em reprocessamento)
- [ ] Retry com backoff implementado
- [ ] Logs estruturados ativos
- [ ] Alerta Telegram em caso de falha
- [ ] Agendamento configurado (GH Actions ou cron)
- [ ] Teste com 7 dias de dados históricos antes de ativar
