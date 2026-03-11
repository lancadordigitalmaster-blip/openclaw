# exports.md — IRIS Sub-Skill: Data Exports & Integrations
# Ativa quando: "export", "planilha", "excel", "csv", "integra sistema"

---

## Stack de Export Wolf

| Destino | Biblioteca | Uso |
|---------|-----------|-----|
| CSV | pandas | Export simples, ingestão por terceiros |
| Google Sheets | gspread + google-auth | Relatórios colaborativos, dashboards ao vivo |
| Excel (.xlsx) | openpyxl | Relatórios formais para clientes |
| PDF | WeasyPrint / ReportLab | Relatórios executivos |
| Google Drive | google-api-python-client | Depósito automático de arquivos |

---

## 1. Export CSV com pandas

```python
import pandas as pd
from pathlib import Path
from datetime import datetime

def export_csv(df: pd.DataFrame, filename: str,
               output_dir: str = "./exports") -> str:
    """
    Exporta DataFrame para CSV com timestamp no nome.

    Returns:
        Caminho completo do arquivo gerado
    """
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = f"{output_dir}/{filename}_{timestamp}.csv"

    df.to_csv(
        filepath,
        index=False,
        encoding="utf-8-sig",   # UTF-8 com BOM — compatível com Excel
        sep=",",
        date_format="%Y-%m-%d",
    )

    print(f"CSV exportado: {filepath} ({len(df)} linhas)")
    return filepath


# Uso
# path = export_csv(df_campaigns, "campanhas_meta_acme")
```

---

## 2. Google Sheets — Leitura e Escrita Automática

### Setup de credenciais
```bash
# Service Account: Google Cloud Console → IAM → Service Accounts
# Baixar JSON → salvar como credentials/sheets_sa.json
# Compartilhar a planilha com o email do Service Account
```

```python
import gspread
from google.oauth2.service_account import Credentials
import pandas as pd

SCOPES = [
    "https://spreadsheets.google.com/feeds",
    "https://www.googleapis.com/auth/drive",
]

def get_sheets_client(credentials_path: str) -> gspread.Client:
    """Retorna cliente autenticado do Google Sheets."""
    creds = Credentials.from_service_account_file(credentials_path, scopes=SCOPES)
    return gspread.authorize(creds)


def read_sheet(spreadsheet_id: str, worksheet_name: str,
               credentials_path: str) -> pd.DataFrame:
    """Lê planilha Google como DataFrame."""
    client = get_sheets_client(credentials_path)
    sheet = client.open_by_key(spreadsheet_id).worksheet(worksheet_name)
    data = sheet.get_all_records()
    return pd.DataFrame(data)


def write_sheet(df: pd.DataFrame, spreadsheet_id: str,
                worksheet_name: str, credentials_path: str,
                clear_first: bool = True):
    """
    Escreve DataFrame em planilha Google.

    Args:
        clear_first: Limpa a aba antes de escrever (padrão True para refresh)
    """
    client = get_sheets_client(credentials_path)
    spreadsheet = client.open_by_key(spreadsheet_id)

    try:
        sheet = spreadsheet.worksheet(worksheet_name)
    except gspread.WorksheetNotFound:
        sheet = spreadsheet.add_worksheet(title=worksheet_name, rows=5000, cols=50)

    if clear_first:
        sheet.clear()

    # Header + dados
    values = [df.columns.tolist()] + df.fillna("").astype(str).values.tolist()
    sheet.update(values, "A1")

    print(f"Google Sheets atualizado: {worksheet_name} ({len(df)} linhas)")


def append_sheet_row(row: dict, spreadsheet_id: str,
                     worksheet_name: str, credentials_path: str):
    """Adiciona uma linha no final da planilha."""
    client = get_sheets_client(credentials_path)
    sheet = client.open_by_key(spreadsheet_id).worksheet(worksheet_name)
    sheet.append_row(list(row.values()))
```

---

## 3. Excel com openpyxl — Relatório Formatado

```python
import openpyxl
from openpyxl.styles import (
    Font, PatternFill, Alignment, Border, Side, numbers
)
from openpyxl.chart import LineChart, Reference
import pandas as pd
from datetime import datetime

def create_excel_report(data: dict[str, pd.DataFrame],
                         client_name: str,
                         output_path: str) -> str:
    """
    Cria relatório Excel com múltiplas abas formatadas.

    Args:
        data: Dict com nome_aba → DataFrame
        client_name: Nome do cliente (título)
        output_path: Caminho de saída

    Returns:
        Caminho do arquivo gerado
    """
    wb = openpyxl.Workbook()
    wb.remove(wb.active)  # Remove aba vazia padrão

    # Cores Wolf Agency
    HEADER_COLOR = "1E40AF"    # Azul Wolf
    HEADER_FONT = "FFFFFF"     # Branco
    ALT_ROW = "EFF6FF"         # Azul claro alternado

    for sheet_name, df in data.items():
        ws = wb.create_sheet(title=sheet_name)

        # Título da aba
        ws.merge_cells("A1:Z1")
        title_cell = ws["A1"]
        title_cell.value = f"{client_name} — {sheet_name} — {datetime.now().strftime('%d/%m/%Y')}"
        title_cell.font = Font(name="Calibri", size=14, bold=True, color=HEADER_FONT)
        title_cell.fill = PatternFill(fill_type="solid", fgColor=HEADER_COLOR)
        title_cell.alignment = Alignment(horizontal="center", vertical="center")
        ws.row_dimensions[1].height = 30

        # Header da tabela (linha 3)
        for col_idx, col_name in enumerate(df.columns, start=1):
            cell = ws.cell(row=3, column=col_idx, value=col_name)
            cell.font = Font(bold=True, color=HEADER_FONT, name="Calibri")
            cell.fill = PatternFill(fill_type="solid", fgColor="374151")
            cell.alignment = Alignment(horizontal="center")

        # Dados
        for row_idx, row in enumerate(df.itertuples(index=False), start=4):
            fill_color = ALT_ROW if row_idx % 2 == 0 else "FFFFFF"
            for col_idx, value in enumerate(row, start=1):
                cell = ws.cell(row=row_idx, column=col_idx, value=value)
                cell.fill = PatternFill(fill_type="solid", fgColor=fill_color)
                cell.font = Font(name="Calibri", size=10)

                # Formatação numérica automática
                if isinstance(value, float):
                    col_name = df.columns[col_idx - 1].lower()
                    if any(k in col_name for k in ["roas", "ctr", "rate"]):
                        cell.number_format = "0.00"
                    elif any(k in col_name for k in ["spend", "revenue", "cpa", "cpl"]):
                        cell.number_format = 'R$ #,##0.00'
                    elif "%" in col_name:
                        cell.number_format = "0.0%"

        # Ajustar largura das colunas automaticamente
        for col in ws.columns:
            max_len = max(
                (len(str(cell.value)) for cell in col if cell.value), default=10
            )
            ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 40)

        # Congelar cabeçalho
        ws.freeze_panes = "A4"

    filepath = output_path if output_path.endswith(".xlsx") else f"{output_path}.xlsx"
    wb.save(filepath)
    print(f"Excel gerado: {filepath}")
    return filepath
```

---

## 4. PDF com WeasyPrint

```python
from weasyprint import HTML, CSS
from jinja2 import Template
import pandas as pd
from datetime import datetime

REPORT_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: 'Helvetica', sans-serif; color: #1f2937; margin: 40px; }
  h1 { color: #1e40af; border-bottom: 3px solid #1e40af; padding-bottom: 10px; }
  h2 { color: #374151; margin-top: 30px; }
  table { width: 100%; border-collapse: collapse; margin-top: 15px; }
  th { background: #1e40af; color: white; padding: 10px; text-align: left; }
  td { padding: 8px 10px; border-bottom: 1px solid #e5e7eb; }
  tr:nth-child(even) { background: #eff6ff; }
  .metric-card { display: inline-block; background: #1e40af; color: white;
                  padding: 20px 30px; border-radius: 8px; margin: 10px;
                  text-align: center; min-width: 150px; }
  .metric-value { font-size: 28px; font-weight: bold; }
  .metric-label { font-size: 12px; opacity: 0.9; }
  .footer { margin-top: 40px; color: #9ca3af; font-size: 10px; text-align: center; }
</style>
</head>
<body>
  <h1>{{ title }}</h1>
  <p><strong>Período:</strong> {{ period }} | <strong>Gerado em:</strong> {{ generated_at }}</p>

  <h2>Resumo Executivo</h2>
  <div>
    {% for metric in summary_metrics %}
    <div class="metric-card">
      <div class="metric-value">{{ metric.value }}</div>
      <div class="metric-label">{{ metric.label }}</div>
    </div>
    {% endfor %}
  </div>

  {% for section in sections %}
  <h2>{{ section.title }}</h2>
  {{ section.table_html }}
  {% endfor %}

  <div class="footer">Wolf Agency — Relatório gerado automaticamente</div>
</body>
</html>
"""

def generate_pdf_report(title: str, period: str,
                         summary_metrics: list[dict],
                         sections: list[dict],
                         output_path: str) -> str:
    """
    Gera relatório PDF.

    Args:
        summary_metrics: [{"label": "ROAS", "value": "4.2x"}, ...]
        sections: [{"title": "Campanhas", "dataframe": df}, ...]
    """
    processed_sections = []
    for section in sections:
        processed_sections.append({
            "title": section["title"],
            "table_html": section["dataframe"].to_html(
                index=False, classes="data-table", border=0
            ),
        })

    html_content = Template(REPORT_TEMPLATE).render(
        title=title,
        period=period,
        generated_at=datetime.now().strftime("%d/%m/%Y %H:%M"),
        summary_metrics=summary_metrics,
        sections=processed_sections,
    )

    filepath = output_path if output_path.endswith(".pdf") else f"{output_path}.pdf"
    HTML(string=html_content).write_pdf(filepath)
    print(f"PDF gerado: {filepath}")
    return filepath
```

---

## 5. Google Drive — Depósito Automático

```python
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2.service_account import Credentials

def upload_to_drive(file_path: str, folder_id: str,
                    credentials_path: str,
                    mime_type: str = "application/octet-stream") -> str:
    """
    Faz upload de arquivo para pasta específica no Google Drive.

    Returns:
        ID do arquivo no Drive
    """
    creds = Credentials.from_service_account_file(
        credentials_path,
        scopes=["https://www.googleapis.com/auth/drive.file"],
    )
    service = build("drive", "v3", credentials=creds)

    file_name = file_path.split("/")[-1]

    file_metadata = {
        "name": file_name,
        "parents": [folder_id],
    }

    media = MediaFileUpload(file_path, mimetype=mime_type, resumable=True)

    file = service.files().create(
        body=file_metadata,
        media_body=media,
        fields="id, webViewLink",
    ).execute()

    print(f"Arquivo enviado ao Drive: {file.get('webViewLink')}")
    return file.get("id")
```

---

## Agendamento de Exports Automáticos

```python
# main_exports.py — Executado via GitHub Actions ou cron
import os
from datetime import datetime, timedelta

def run_weekly_exports():
    """Pipeline de export semanal para clientes."""

    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=7)
    period_str = f"{start_date.strftime('%d/%m')} a {end_date.strftime('%d/%m/%Y')}"

    for client_id, config in CLIENT_CONFIGS.items():
        try:
            # 1. Buscar dados
            df = fetch_client_metrics(client_id, start_date, end_date)

            # 2. Export Excel
            excel_path = create_excel_report(
                {"Campanhas": df},
                client_name=config["name"],
                output_path=f"/tmp/{client_id}_semanal",
            )

            # 3. Upload Drive
            upload_to_drive(
                file_path=excel_path,
                folder_id=config["drive_folder_id"],
                credentials_path="credentials/drive_sa.json",
                mime_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )

            # 4. Atualiza Sheets
            write_sheet(
                df=df,
                spreadsheet_id=config["sheets_id"],
                worksheet_name=f"Semana {end_date.strftime('%d-%m')}",
                credentials_path="credentials/sheets_sa.json",
            )

            print(f"[OK] {config['name']} — exports concluídos")

        except Exception as e:
            print(f"[ERRO] {config['name']}: {e}")
            # Alertar via Telegram
```

---

## Checklist Export

- [ ] Encoding UTF-8 com BOM para CSV (compatível com Excel brasileiro)
- [ ] Datas no formato DD/MM/YYYY para relatórios de cliente
- [ ] Service Account com permissão mínima necessária (não admin)
- [ ] Pasta de Drive compartilhada com o e-mail do Service Account
- [ ] Nome de arquivo com timestamp (evita sobrescrever versões)
- [ ] Tratamento de erro individual por cliente (um falha, não bloqueia os outros)
- [ ] Log de exports gerados
- [ ] Limpeza de arquivos temporários após upload
