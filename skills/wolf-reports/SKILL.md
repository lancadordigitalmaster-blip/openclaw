---

## Agent

**Alfred** — orquestrador central

---
name: wolf-reports
description: Generate professional PDF reports for Wolf Agency operations. Use when creating daily operational reports, designer workload summaries, SLA alerts, or ClickUp analytics for the Wolf Agency team. Generates dark-themed PDFs with metrics, alerts, and task summaries.
---

# Wolf Reports — PDF Generator

Generate professional operational reports for Wolf Agency.

## When to Use

- Daily operational reports (8h check)
- Designer workload summaries
- SLA violation alerts
- ClickUp analytics
- Team performance metrics

## Report Types

### 1. Daily Designer Report
Shows all designers with their current load vs. meta.

**Usage:**
```bash
python scripts/generate_designer_report.py --date 2026-03-04 --output report.pdf
```

### 2. SLA Alert Report
Lists all tasks with SLA violations.

**Usage:**
```bash
python scripts/generate_sla_report.py --output alerts.pdf
```

### 3. Full Operational Report
Complete report with designers, alerts, and task details.

**Usage:**
```bash
python scripts/generate_full_report.py --date 2026-03-04 --output full_report.pdf
```

## Report Format

- **Theme:** Dark background (#181D21) with white text
- **Header:** Wolf logo (🐺) + title + date
- **Sections:**
  1. Designer workload cards
  2. Alert boxes (red/amber)
  3. Task tables
  4. Summary metrics
- **Output:** PDF file

## Data Sources

- ClickUp API (tasks, statuses, custom fields)
- W.O.L.F. system (team metrics)
- Local memory files (metas, equipe)

## Templates

### PDF Reports
Use assets/report-template.html as base for HTML→PDF conversion.

### Traffic Reports (Texto/Telegram)
Templates padronizados para relatórios de Meta Ads. **Selecionados automaticamente pelo Gabi conforme o objetivo da campanha.**

| Objetivo da Campanha | Template Usado | Métricas Principais |
|---------------------|----------------|---------------------|
| Reconhecimento de marca | **Alcance** | Alcance, Impressões, Frequência, CPM, CTR, Engajamentos |
| Tráfego para site/página | **Visitas** | Alcance, Cliques, CTR, CPC, Sessões, Taxa de rejeição |
| Interações/Engajamento | **Engajamento** | Alcance, CTR, Curtidas, Comentários, Compartilhamentos, Salvamentos, Custo por engajamento |
| Captação de leads | **Leads** | Alcance, Cliques, CTR, CPC, Leads gerados, CPL, Taxa de conversão |
| Conversões/Vendas | **Vendas** | Alcance, Cliques, CTR, CPC, Vendas, Receita, CPA, ROAS |

**Como funciona:**
1. Gabi analisa o objetivo da campanha (entendimento automático)
2. Seleciona o template correspondente automaticamente
3. Preenche com as métricas relevantes
4. Adiciona diagnóstico e otimizações da Gabi

**Mapeamento de Objetivos → Templates:**

| Objetivo Meta Ads | Template Enviado |
|-------------------|------------------|
| Alcance / Reconhecimento de marca | **Alcance** |
| Tráfego / Visitas ao site | **Visitas** |
| Engajamento / Interações | **Engajamento** |
| Geração de leads / Mensagens | **Leads** |
| Vendas / Conversões | **Vendas** |

Ver templates completos em: `traffic-templates.md`
