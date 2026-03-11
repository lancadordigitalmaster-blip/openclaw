# anomaly-detection.md — IRIS Sub-Skill: Anomaly Detection
# Ativa quando: "anomalia", "fora do padrão", "detecta", "alerta de dados"

---

## Tipos de Anomalia Wolf

| Tipo | Definição | Criticidade |
|------|-----------|-------------|
| Spike positivo | +30% vs semana anterior sem motivo | Média (investigar) |
| Drop abrupto | -30% vs semana anterior | Alta (agir) |
| Zero conversões | Dia útil sem nenhuma conversão | Crítica (agir imediato) |
| Spike sem correspondência | Tráfego explode mas conversões não | Alta (suspeita de bot/problema) |
| Custo sem resultado | Spend alto, conversões zero | Crítica (pausar campanha) |
| Dados ausentes | Período sem dados (API caiu, pixel quebrou) | Alta |

---

## Implementação Python — Detecção Simples

```python
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

class WolfAnomalyDetector:
    """Detector de anomalias em métricas de marketing."""

    def __init__(self, threshold_pct: float = 0.30, zero_alert: bool = True):
        self.threshold_pct = threshold_pct  # 30% por padrão
        self.zero_alert = zero_alert

    def detect(self, df: pd.DataFrame, metric: str,
               date_col: str = "date") -> list[dict]:
        """
        Detecta anomalias em uma série temporal.

        Args:
            df: DataFrame com coluna de data e métrica
            metric: Nome da coluna da métrica
            date_col: Nome da coluna de data

        Returns:
            Lista de anomalias detectadas com contexto
        """
        df = df.copy()
        df[date_col] = pd.to_datetime(df[date_col])
        df = df.sort_values(date_col).reset_index(drop=True)

        anomalies = []

        for i in range(7, len(df)):
            current = df.iloc[i]
            # Semana anterior: mesmo dia da semana
            week_ago_idx = i - 7
            week_ago = df.iloc[week_ago_idx]

            current_val = current[metric]
            prev_val = week_ago[metric]

            # Alerta: zero em dia útil
            if self.zero_alert and current_val == 0:
                day_of_week = current[date_col].weekday()
                if day_of_week < 5:  # Segunda a Sexta
                    anomalies.append({
                        "date": current[date_col].strftime("%Y-%m-%d"),
                        "type": "ZERO_VALUE",
                        "metric": metric,
                        "current": 0,
                        "expected": prev_val,
                        "severity": "CRITICAL",
                    })
                    continue

            # Skip se valor anterior for zero (evita divisão por zero)
            if prev_val == 0:
                continue

            # Variação percentual
            pct_change = (current_val - prev_val) / abs(prev_val)

            if abs(pct_change) > self.threshold_pct:
                anomalies.append({
                    "date": current[date_col].strftime("%Y-%m-%d"),
                    "type": "SPIKE" if pct_change > 0 else "DROP",
                    "metric": metric,
                    "current": current_val,
                    "previous_week": prev_val,
                    "pct_change": round(pct_change * 100, 1),
                    "severity": "HIGH" if abs(pct_change) > 0.50 else "MEDIUM",
                })

        return anomalies


def detect_spend_without_conversion(df: pd.DataFrame,
                                    spend_col: str = "spend",
                                    conv_col: str = "conversions",
                                    min_spend: float = 100.0) -> list[dict]:
    """Detecta dias com spend acima do mínimo mas zero conversões."""
    anomalies = []

    for _, row in df.iterrows():
        if row[spend_col] >= min_spend and row[conv_col] == 0:
            anomalies.append({
                "date": str(row.get("date", "unknown")),
                "type": "SPEND_NO_CONVERSION",
                "spend": row[spend_col],
                "conversions": 0,
                "severity": "CRITICAL",
            })

    return anomalies


def detect_traffic_conversion_mismatch(
    df: pd.DataFrame,
    traffic_col: str = "clicks",
    conversion_col: str = "conversions",
    expected_cvr: float = 0.02  # 2% baseline
) -> list[dict]:
    """Detecta spike de tráfego sem correspondência em conversões (bot?)."""
    anomalies = []

    for _, row in df.iterrows():
        if row[traffic_col] == 0:
            continue

        actual_cvr = row[conversion_col] / row[traffic_col]

        # CVR abaixo de 20% do esperado com tráfego alto
        if actual_cvr < (expected_cvr * 0.2) and row[traffic_col] > 100:
            anomalies.append({
                "date": str(row.get("date", "unknown")),
                "type": "TRAFFIC_NO_CONVERSION",
                "clicks": row[traffic_col],
                "conversions": row[conversion_col],
                "actual_cvr_pct": round(actual_cvr * 100, 3),
                "expected_cvr_pct": round(expected_cvr * 100, 1),
                "severity": "HIGH",
            })

    return anomalies
```

---

## Alertas Automáticos via Telegram

```python
import requests
from typing import Optional

class TelegramAlerter:
    """Envia alertas de anomalia via Telegram."""

    def __init__(self, bot_token: str, chat_id: str):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{bot_token}"

    def send_alert(self, anomaly: dict, client_name: str) -> bool:
        """Formata e envia alerta de anomalia."""

        severity_emoji = {
            "CRITICAL": "🔴",
            "HIGH": "🟠",
            "MEDIUM": "🟡",
        }

        emoji = severity_emoji.get(anomaly.get("severity", "MEDIUM"), "⚪")

        message = self._format_message(anomaly, client_name, emoji)

        return self._send(message)

    def _format_message(self, anomaly: dict, client_name: str, emoji: str) -> str:
        atype = anomaly["type"]

        if atype == "ZERO_VALUE":
            return (
                f"{emoji} *ALERTA CRÍTICO — {client_name}*\n\n"
                f"Zero conversões detectadas\n"
                f"Data: {anomaly['date']}\n"
                f"Métrica: {anomaly['metric']}\n"
                f"Esperado: ~{anomaly.get('expected', 'N/A')}\n\n"
                f"Verificar: pixel, landing page, integração de conversão."
            )

        elif atype in ("SPIKE", "DROP"):
            direction = "Spike" if atype == "SPIKE" else "Queda"
            sign = "+" if anomaly["pct_change"] > 0 else ""
            return (
                f"{emoji} *{direction} detectado — {client_name}*\n\n"
                f"Métrica: {anomaly['metric']}\n"
                f"Data: {anomaly['date']}\n"
                f"Atual: {anomaly['current']:.2f}\n"
                f"Semana anterior: {anomaly['previous_week']:.2f}\n"
                f"Variação: {sign}{anomaly['pct_change']}%"
            )

        elif atype == "SPEND_NO_CONVERSION":
            return (
                f"{emoji} *GASTO SEM CONVERSÃO — {client_name}*\n\n"
                f"Data: {anomaly['date']}\n"
                f"Investimento: R$ {anomaly['spend']:.2f}\n"
                f"Conversões: 0\n\n"
                f"Ação: Verificar campanha imediatamente."
            )

        return f"{emoji} Anomalia detectada — {client_name}: {anomaly}"

    def _send(self, message: str) -> bool:
        url = f"{self.base_url}/sendMessage"
        payload = {
            "chat_id": self.chat_id,
            "text": message,
            "parse_mode": "Markdown",
        }
        try:
            response = requests.post(url, json=payload, timeout=10)
            return response.status_code == 200
        except Exception as e:
            print(f"Falha ao enviar alerta Telegram: {e}")
            return False
```

---

## Pipeline de Detecção Completo

```python
def run_anomaly_check(df: pd.DataFrame, client_name: str,
                      client_config: dict, alerter: TelegramAlerter):
    """Executa verificação completa de anomalias para um cliente."""

    thresholds = client_config.get("thresholds", {})
    detector = WolfAnomalyDetector(
        threshold_pct=thresholds.get("pct_change", 0.30),
        zero_alert=thresholds.get("zero_alert", True),
    )

    all_anomalies = []

    # Métricas para verificar
    metrics_to_check = ["conversions", "clicks", "spend", "roas"]
    for metric in metrics_to_check:
        if metric in df.columns:
            anomalies = detector.detect(df, metric)
            all_anomalies.extend(anomalies)

    # Verificações específicas
    if "spend" in df.columns and "conversions" in df.columns:
        min_spend = thresholds.get("min_spend_for_alert", 100.0)
        spend_anomalies = detect_spend_without_conversion(df, min_spend=min_spend)
        all_anomalies.extend(spend_anomalies)

    # Enviar apenas anomalias críticas e altas imediatamente
    for anomaly in all_anomalies:
        if anomaly["severity"] in ("CRITICAL", "HIGH"):
            alerter.send_alert(anomaly, client_name)

    return all_anomalies
```

---

## Thresholds Configuráveis por Cliente

```python
# config/clients.py
CLIENT_CONFIGS = {
    "client_acme": {
        "thresholds": {
            "pct_change": 0.30,         # 30% variação
            "zero_alert": True,
            "min_spend_for_alert": 150.0,
        },
        "telegram_chat_id": "-100XXXXXXXXX",
    },
    "client_beta": {
        "thresholds": {
            "pct_change": 0.50,         # 50% — cliente com variação natural alta
            "zero_alert": True,
            "min_spend_for_alert": 50.0,
        },
        "telegram_chat_id": "-100YYYYYYYYY",
    },
}
```

---

## Checklist Configuração de Alertas

- [ ] Thresholds definidos por cliente (não usar padrão cego para todos)
- [ ] Bot Telegram criado e token salvo em secrets
- [ ] Chat ID do grupo de alertas correto
- [ ] Detecção de zero conversões ativa para dias úteis
- [ ] Detecção de spend sem conversão ativa com mínimo configurado
- [ ] Script agendado (diário, 08:00 BRT)
- [ ] Falsos positivos mapeados e documentados
- [ ] Responsável por investigar cada tipo de alerta definido
