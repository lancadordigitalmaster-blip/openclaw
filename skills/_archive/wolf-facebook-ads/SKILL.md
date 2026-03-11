---
name: wolf-facebook-ads
description: Integração com Facebook Ads API para consultar métricas de campanhas, criativos, e análise de performance. Acesso apenas leitura.
---

# Wolf Facebook Ads Integration 📊

Integração com Meta Marketing API para análise de campanhas.

## Configuração

Token salvo em: `.env.facebook`
- Access Token: Configurado ✅
- API Version: v18.0
- Permissões: ads_read, business_management

## Contas vinculadas

| Conta | ID | Status |
|-------|-----|--------|
| William Forlan | 299753830 | ✅ Ativa |
| Netto Girotto | 135916159825609 | ✅ Ativa |
| CA 02 - Samela Vaz | 1361305232030279 | ✅ Ativa |
| CA 05 - Samela Vaz | 4412988082269343 | ✅ Ativa |
| CA 01 I Douglas Barros | 443286126941481 | ✅ Ativa |
| CA Mariana¹ | 1252598652228497 | ✅ Ativa |

## Comandos disponíveis

### Listar campanhas
```bash
wolf-facebook --account="act_135916159825609" --action="campaigns"
```

### Métricas de campanha
```bash
wolf-facebook --account="act_135916159825609" --campaign="123" --metrics="impressions,clicks,spend,cpc,ctr"
```

### Resumo de performance
```bash
wolf-facebook --account="act_135916159825609" --action="summary" --days=7
```

## Métricas disponíveis

- `impressions` — Impressões
- `clicks` — Cliques
- `spend` — Gasto (R$)
- `cpc` — Custo por clique
- `ctr` — Click-through rate
- `conversions` — Conversões
- `cost_per_conversion` — Custo por conversão
- `roas` — Return on ad spend
- `frequency` — Frequência
- `reach` — Alcance

## Uso via Alfred

**Consultar campanhas:**
> "Alfred, mostra as campanhas ativas da conta Netto Girotto"

**Análise de performance:**
> "Alfred, puxa métricas dos últimos 7 dias da campanha X"

**Resumo geral:**
> "Alfred, como estão as campanhas no Facebook?"

## Limitações

- Apenas leitura (não cria/edita campanhas)
- Dados em tempo real (atraso de ~15 min)
- Limite de chamadas: 200/h por usuário

---

*Configurado: 2026-03-05 | Token: Ativo ✅*