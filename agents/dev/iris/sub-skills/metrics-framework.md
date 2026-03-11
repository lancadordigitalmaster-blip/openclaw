# metrics-framework.md — IRIS Sub-Skill: Metrics Framework Wolf
# Ativa quando: "métrica", "KPI", "define como medir", "o que monitorar"

---

## Framework de Métricas Wolf por Serviço

### Tráfego Pago (Meta Ads / Google Ads)

| Métrica | Fórmula | Referência Mínima | Alerta |
|---------|---------|-------------------|--------|
| ROAS | Receita / Investimento | > 3x | < 2x |
| CPA | Investimento / Conversões | Depende do ticket | > 150% do LTV/12 |
| CTR | Cliques / Impressões | > 1.5% (Google), > 0.8% (Meta) | < 0.5% |
| CPM | Custo / 1000 Impressões | Contextual | Spike > 50% sem reason |
| Taxa de Conversão (LP) | Conversões / Cliques | > 2% | < 1% |
| Frequência (Meta) | Impressões / Alcance | < 3x | > 5x |

**NSM para Tráfego Pago:** ROAS (resultado final do investimento)

### Social Media (Orgânico)

| Métrica | Como Calcular | O Que Significa |
|---------|--------------|-----------------|
| Engajamento Real | (Curtidas + Comentários + Compartilhamentos + Salvamentos) / Alcance | Qualidade do conteúdo |
| Taxa de Salvamento | Salvamentos / Alcance | Intenção de retorno |
| Alcance Orgânico | Contas únicas atingidas | Distribuição sem pagar |
| Taxa de Crescimento | (Seguidores atuais - Seguidores anterior) / Seguidores anterior | Momentum |

**NSM para Social:** Engajamento Real (não seguidores, não curtidas isoladas)

**Nunca usar:** Curtidas como proxy de resultado. Salvamentos > Curtidas em valor.

### SEO

| Métrica | Ferramenta | Referência |
|---------|-----------|------------|
| Tráfego com Intenção | GA4 (organic search) | Crescimento MoM |
| Posição média keywords priority | Google Search Console | < 10 para palavras-chave alvo |
| CTR orgânico | Search Console | > 3% posições 1-3 |
| Core Web Vitals | PageSpeed / GSC | LCP < 2.5s, CLS < 0.1, FID < 100ms |
| Backlinks qualidade | Ahrefs/SEMrush | DR crescente, sem spam |

**NSM para SEO:** Tráfego orgânico qualificado com intenção de compra

### Operação / Agência

| Métrica | Fórmula | Meta |
|---------|---------|------|
| Retenção de Clientes | Clientes no mês / Clientes mês anterior | > 90% |
| NPS | % Promotores - % Detratores | > 50 |
| Churn Rate | Clientes perdidos / Total clientes | < 5% ao mês |
| Ticket Médio | MRR / Número de clientes | Crescimento QoQ |
| Tempo de Onboarding | Dias do contrato ao 1º relatório | < 14 dias |
| Taxa de Upsell | Clientes com upgrade / Total | > 10% ao ano |

**NSM para Operação:** Retenção de clientes (LTV impacto direto)

---

## North Star Metric por Tipo de Cliente

| Tipo de Cliente | NSM Recomendada | Razão |
|----------------|-----------------|-------|
| E-commerce | ROAS ou Receita total | Resultado direto |
| Lead generation B2B | CPL + Taxa de fechamento | Funil completo |
| Lead generation B2C | CPA (custo por cliente) | Escala |
| SaaS | MRR / CAC payback | Crescimento sustentável |
| Serviços locais | CPL + Custo por agendamento | Conversão local |
| Infoprodutos | ROAS + LTV 90 dias | Cohort de compradores |

**Como definir a NSM com o cliente:**
1. "Qual resultado final você quer que nossa campanha gere?"
2. "O que muda no seu negócio se essa métrica dobrar?"
3. Se a resposta não impactar diretamente a receita, não é a NSM.

---

## Como Definir Baseline e Meta

### Passo 1 — Coleta de Baseline
```python
import pandas as pd

def calculate_baseline(df: pd.DataFrame, metric: str, periods: int = 90) -> dict:
    """Calcula baseline de uma métrica nos últimos N dias."""

    recent = df.tail(periods)[metric].dropna()

    return {
        "metric": metric,
        "periods": periods,
        "mean": recent.mean(),
        "median": recent.median(),
        "std": recent.std(),
        "p25": recent.quantile(0.25),
        "p75": recent.quantile(0.75),
        "trend": "up" if recent.iloc[-30:].mean() > recent.iloc[:30].mean() else "down",
    }
```

### Passo 2 — Definição de Meta
**Regra Wolf:** Meta = Baseline median × fator de crescimento realista

| Contexto | Fator | Prazo |
|----------|-------|-------|
| Nova campanha (sem histórico) | 1.0x (baseline = meta inicial) | 30 dias |
| Otimização em andamento | 1.15 a 1.25x | 90 dias |
| Campanha madura, escala | 1.10x por trimestre | 12 meses |

Meta agressiva sem dados históricos = expectativa desalinhada. Recuse ou documente o risco.

---

## Leading Indicators vs Lagging Indicators

### Definição Prática

**Leading (antecedente):** Sinaliza o que vai acontecer. Permite ação preventiva.
**Lagging (consequente):** Confirma o que já aconteceu. Não dá para intervir retroativamente.

### Mapa por Serviço

| Serviço | Leading Indicators | Lagging Indicators |
|---------|-------------------|-------------------|
| Tráfego Pago | CTR, Score de qualidade, Frequência | ROAS, CPA, Receita |
| Social | Taxa de salvamento, Alcance | Seguidores, Engajamento total |
| SEO | Core Web Vitals, índice de crawl, Backlinks novos | Posição, Tráfego orgânico |
| Operação | NPS, Tempo de resposta, Tarefas em atraso | Churn, Retenção |

**Regra de uso:**
- Monitore leading indicators diariamente (detectam problemas cedo)
- Reporte lagging indicators semanalmente/mensalmente (mostram resultado)
- Nunca justifique resultado ruim só com leading indicators sem plano de ação

---

## Template de Definição de Métricas por Cliente

```markdown
## [Nome do Cliente] — Framework de Métricas

**North Star Metric:** [métrica]
**Baseline atual:** [valor]
**Meta 90 dias:** [valor]
**Meta 12 meses:** [valor]

### KPIs Primários (monitorar semanalmente)
1. [métrica] — baseline [X] — meta [Y]
2. [métrica] — baseline [X] — meta [Y]
3. [métrica] — baseline [X] — meta [Y]

### KPIs Secundários (monitorar mensalmente)
1. [métrica]
2. [métrica]

### Leading Indicators (monitorar diariamente)
1. [indicador]
2. [indicador]

### O que NÃO reportar
- [métrica vaidade] — motivo
```

---

## Checklist Definição de Métricas

- [ ] NSM definida e validada com decisor do cliente
- [ ] Baseline coletado (mínimo 30 dias, ideal 90 dias)
- [ ] Meta definida com fator realista e prazo claro
- [ ] Diferença entre leading e lagging documentada
- [ ] Fontes de dados confirmadas para cada métrica
- [ ] Frequência de monitoramento definida por métrica
- [ ] Métricas vaidade excluídas ou sinalizadas como tal
- [ ] Dashboard configurado com contexto (ver dashboard.md)
