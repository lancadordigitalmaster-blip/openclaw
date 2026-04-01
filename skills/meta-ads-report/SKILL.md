---
name: "meta-ads-report"
description: "When the user asks about Meta Ads performance, spend, CAC, conversions, or ad events for any client. Triggers: 'performance meta', 'quanto gastei', 'CAC', 'relatório de anúncios', 'resultados meta', 'spend meta', 'conversões meta', 'eventos meta', 'report meta', 'resultado das campanhas'."
---

# Meta Ads Analytics & Event Finder — Wolf Agency

Analisa performance de anúncios Meta (Facebook/Instagram) para múltiplos clientes Wolf.

## Contas disponíveis

| Cliente | Token env | Account env |
|---|---|---|
| Wolf (padrão) | `META_ADS_ACCESS_TOKEN` | `META_AD_ACCOUNT_ID` |
| Wolf 26 | `META_ADS_ACCESS_TOKEN` | `META_AD_ACCOUNT_WOLF26` |
| Forlan | `META_ADS_TOKEN_FORLAN` | `META_AD_ACCOUNT_FORLAN` |
| Marcos | `META_ADS_TOKEN_MARCOS` | — (perguntar ao usuário) |
| Ticomia | `META_ADS_TOKEN_TICOMIA` | — (perguntar ao usuário) |
| GR Veículos | `META_TOKEN_GR_VEICULOS` | `META_ACCOUNT_GR_VEICULOS` |

Se o usuário não especificar cliente, usar **Wolf (padrão)**.

## Como usar as credenciais

```bash
ENV=/Users/thomasgirotto/.openclaw/.env
TOKEN=$(grep META_ADS_ACCESS_TOKEN "$ENV" | cut -d= -f2)
ACCOUNT=$(grep META_AD_ACCOUNT_ID "$ENV" | cut -d= -f2)
```

## Capacidades

### 1. Performance de anúncios

Retorna Spend, Impressões, Cliques, CTR, CPM, Conversões e CAC por ad set.

Suporta períodos em linguagem natural: "ontem", "últimos 7 dias", "esse mês", "semana passada", "01/03 a 31/03".

```bash
# Converter período para datas (exemplo últimos 7 dias):
DATE_PRESET="last_7d"
# ou usar since/until: since=2026-03-01&until=2026-03-31

curl -s -G "https://graph.facebook.com/v21.0/$ACCOUNT/insights" \
  --data-urlencode "fields=campaign_name,adset_name,spend,impressions,clicks,ctr,cpm,actions,cost_per_action_type" \
  --data-urlencode "date_preset=$DATE_PRESET" \
  --data-urlencode "level=adset" \
  --data-urlencode "access_token=$TOKEN"
```

**Calcular CAC:**
- Encontrar actions onde `action_type` = `META_EVENT_NAME` (padrão: `offsite_conversion.fb_pixel_custom`)
- CAC = spend / conversões

### 2. Descobrir eventos do pixel

Quando conversões aparecem zeradas, listar eventos disponíveis:

```bash
curl -s -G "https://graph.facebook.com/v21.0/$ACCOUNT/insights" \
  --data-urlencode "fields=actions" \
  --data-urlencode "date_preset=last_30d" \
  --data-urlencode "access_token=$TOKEN"
```

Extrair todos os `action_type` únicos da resposta e listar para o usuário.

### 3. Campanhas ativas

```bash
curl -s -G "https://graph.facebook.com/v21.0/$ACCOUNT/campaigns" \
  --data-urlencode "fields=id,name,status,objective,daily_budget,lifetime_budget" \
  --data-urlencode "filtering=[{\"field\":\"effective_status\",\"operator\":\"IN\",\"value\":[\"ACTIVE\"]}]" \
  --data-urlencode "access_token=$TOKEN"
```

## Formato de resposta

```
📊 META ADS — [Cliente] | [Período]
━━━━━━━━━━━━━━━━━━━━━━
💰 Spend total: R$ X.XXX,XX
👁 Impressões: X.XXX.XXX
🖱 Cliques: X.XXX (CTR: X,XX%)
🎯 Conversões: XX
📈 CAC: R$ XXX,XX

Por ad set:
• [Nome adset]: R$ XX,XX spend | XX conv. | CAC R$ XX,XX
• ...
━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

- **Conversões zeradas:** pedir "lista os eventos do pixel" e verificar `META_EVENT_NAME` correto
- **Token expirado:** avisar que o token precisa ser renovado no Graph API Explorer com permissões `ads_read` + `read_insights`
- **Conta não encontrada:** confirmar que `META_AD_ACCOUNT_ID` tem o prefixo `act_`
