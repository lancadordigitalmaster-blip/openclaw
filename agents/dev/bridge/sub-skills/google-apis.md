# google-apis.md — Bridge Sub-Skill: Google APIs
# Ativa quando: "Google Ads", "Google Analytics", "GA4", "GSC"

## Propósito

Integração com Google Ads API, GA4 Data API e Google Search Console para relatórios, automações e análise de performance. Cobre autenticação, bibliotecas e queries padrão Wolf.

---

## Autenticação: Service Account vs OAuth

| Situação | Método | Quando Usar |
|----------|--------|-------------|
| Dados do próprio negócio Wolf | Service Account | Acesso a propriedades onde Wolf tem permissão de admin |
| Dados do cliente | OAuth 2.0 | Cliente autoriza via fluxo de login |
| Google Ads sem MCC próprio | OAuth 2.0 | Acesso às contas de clientes |
| Google Ads via MCC Wolf | Service Account + Developer Token | Wolf tem MCC gerenciando clientes |

### Service Account (servidor para servidor)

```typescript
// Instalar: pnpm add googleapis
import { google } from 'googleapis';
import { JWT } from 'google-auth-library';

// Credenciais do Service Account (JSON do Google Cloud Console)
const auth = new google.auth.GoogleAuth({
  keyFile: process.env.GOOGLE_SERVICE_ACCOUNT_KEY_PATH,
  // OU via variável de ambiente:
  credentials: JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON),
  scopes: [
    'https://www.googleapis.com/auth/analytics.readonly',
    'https://www.googleapis.com/auth/webmasters.readonly',
  ],
});

const authClient = await auth.getClient();
```

### OAuth para Clientes

Ver sub-skill `oauth.md` — seção Google OAuth.

---

## Google Ads API v16+

```bash
# Instalar
pnpm add google-ads-api
# Python:
pip install google-ads
```

### Configuração

```typescript
import { GoogleAdsApi } from 'google-ads-api';

const client = new GoogleAdsApi({
  client_id: process.env.GOOGLE_ADS_CLIENT_ID,
  client_secret: process.env.GOOGLE_ADS_CLIENT_SECRET,
  developer_token: process.env.GOOGLE_ADS_DEVELOPER_TOKEN,
});

const customer = client.Customer({
  customer_id: '123-456-7890', // ID da conta (sem hífens na API)
  refresh_token: await getRefreshToken(userId), // Obtido via OAuth
  login_customer_id: process.env.GOOGLE_ADS_MCC_ID, // MCC manager account
});
```

### Campanhas

```typescript
// Listar campanhas ativas
const campaigns = await customer.query(`
  SELECT
    campaign.id,
    campaign.name,
    campaign.status,
    campaign.bidding_strategy_type,
    campaign_budget.amount_micros,
    metrics.clicks,
    metrics.impressions,
    metrics.cost_micros,
    metrics.conversions,
    metrics.conversions_value
  FROM campaign
  WHERE campaign.status = 'ENABLED'
    AND segments.date DURING LAST_30_DAYS
  ORDER BY metrics.cost_micros DESC
`);

// Converter micros para valor real
const parseCostMicros = (micros: number) => micros / 1_000_000;
```

### Keywords

```typescript
const keywords = await customer.query(`
  SELECT
    ad_group_criterion.criterion_id,
    ad_group_criterion.keyword.text,
    ad_group_criterion.keyword.match_type,
    ad_group_criterion.status,
    metrics.clicks,
    metrics.impressions,
    metrics.ctr,
    metrics.average_cpc,
    metrics.cost_micros,
    metrics.conversions
  FROM keyword_view
  WHERE ad_group_criterion.status != 'REMOVED'
    AND segments.date DURING LAST_30_DAYS
  ORDER BY metrics.cost_micros DESC
  LIMIT 100
`);
```

### Performance Max

```typescript
const pMaxCampaigns = await customer.query(`
  SELECT
    campaign.id,
    campaign.name,
    metrics.cost_micros,
    metrics.conversions,
    metrics.conversions_value,
    metrics.impressions
  FROM campaign
  WHERE campaign.advertising_channel_type = 'PERFORMANCE_MAX'
    AND segments.date DURING LAST_7_DAYS
`);
```

---

## GA4 Data API

```typescript
import { BetaAnalyticsDataClient } from '@google-analytics/data';

const analyticsClient = new BetaAnalyticsDataClient({
  credentials: JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON),
});

const propertyId = process.env.GA4_PROPERTY_ID; // '123456789'

// Relatório de sessões por fonte
async function getSessionsBySource(startDate: string, endDate: string) {
  const [response] = await analyticsClient.runReport({
    property: `properties/${propertyId}`,
    dateRanges: [{ startDate, endDate }],
    dimensions: [
      { name: 'sessionSource' },
      { name: 'sessionMedium' },
    ],
    metrics: [
      { name: 'sessions' },
      { name: 'engagedSessions' },
      { name: 'conversions' },
      { name: 'totalRevenue' },
      { name: 'bounceRate' },
    ],
    orderBys: [{ metric: { metricName: 'sessions' }, desc: true }],
    limit: 100,
  });

  return response.rows?.map(row => ({
    source: row.dimensionValues[0].value,
    medium: row.dimensionValues[1].value,
    sessions: parseInt(row.metricValues[0].value),
    engagedSessions: parseInt(row.metricValues[1].value),
    conversions: parseFloat(row.metricValues[2].value),
    revenue: parseFloat(row.metricValues[3].value),
    bounceRate: parseFloat(row.metricValues[4].value),
  }));
}

// Funil de conversão
async function getConversionFunnel(startDate: string, endDate: string) {
  const [response] = await analyticsClient.runFunnelReport({
    property: `properties/${propertyId}`,
    dateRanges: [{ startDate, endDate }],
    funnel: {
      steps: [
        { name: 'Visitou Landing Page', filterExpression: { andGroup: { expressions: [{ filter: { fieldName: 'eventName', stringFilter: { value: 'page_view' } } }] } } },
        { name: 'Iniciou Checkout', filterExpression: { andGroup: { expressions: [{ filter: { fieldName: 'eventName', stringFilter: { value: 'begin_checkout' } } }] } } },
        { name: 'Comprou', filterExpression: { andGroup: { expressions: [{ filter: { fieldName: 'eventName', stringFilter: { value: 'purchase' } } }] } } },
      ],
    },
  });
  return response;
}
```

---

## Google Search Console API

```typescript
import { google } from 'googleapis';

const searchConsole = google.webmasters('v3');

// Queries com mais cliques
async function getTopQueries(siteUrl: string, startDate: string, endDate: string) {
  const auth = await getGoogleAuth(['https://www.googleapis.com/auth/webmasters.readonly']);

  const { data } = await searchConsole.searchanalytics.query({
    auth,
    siteUrl: encodeURIComponent(siteUrl), // ex: 'https://wolf.agency/'
    requestBody: {
      startDate,
      endDate,
      dimensions: ['query'],
      rowLimit: 100,
      dataState: 'all', // inclui dados recentes (não só finais)
    },
  });

  return data.rows?.map(row => ({
    query: row.keys[0],
    clicks: row.clicks,
    impressions: row.impressions,
    ctr: row.ctr,
    position: row.position,
  }));
}

// Performance por página
async function getPagePerformance(siteUrl: string, startDate: string, endDate: string) {
  const auth = await getGoogleAuth(['https://www.googleapis.com/auth/webmasters.readonly']);

  const { data } = await searchConsole.searchanalytics.query({
    auth,
    siteUrl: encodeURIComponent(siteUrl),
    requestBody: {
      startDate,
      endDate,
      dimensions: ['page', 'device'],
      rowLimit: 500,
    },
  });

  return data.rows;
}
```

---

## Exemplos de Relatórios Wolf

### Relatório Consolidado de Performance (Google Ads + GA4)

```typescript
async function buildWeeklyPerformanceReport(clientConfig: {
  googleAdsCustomerId: string;
  ga4PropertyId: string;
  period: { start: string; end: string };
}) {
  const [adsData, analyticsData] = await Promise.all([
    getGoogleAdsCampaigns(clientConfig.googleAdsCustomerId, clientConfig.period),
    getGA4Sessions(clientConfig.ga4PropertyId, clientConfig.period),
  ]);

  return {
    ads: {
      totalSpend: adsData.reduce((sum, c) => sum + parseCostMicros(c.metrics.cost_micros), 0),
      totalConversions: adsData.reduce((sum, c) => sum + c.metrics.conversions, 0),
      totalConversionValue: adsData.reduce((sum, c) => sum + c.metrics.conversions_value, 0),
      campaigns: adsData,
    },
    analytics: {
      totalSessions: analyticsData.reduce((sum, r) => sum + r.sessions, 0),
      totalRevenue: analyticsData.reduce((sum, r) => sum + r.revenue, 0),
      bySource: analyticsData,
    },
  };
}
```

---

## Checklist de Google APIs

- [ ] Service Account criado e JSON armazenado em vault (não no repositório)
- [ ] Scopes mínimos necessários (readonly onde não precisa escrever)
- [ ] Developer Token para Google Ads em variável de ambiente
- [ ] MCC ID configurado para acesso a múltiplas contas
- [ ] Paginação implementada para queries grandes (LIMIT + OFFSET)
- [ ] Cache para relatórios (TTL 1h mínimo)
- [ ] Tratamento de erros de quota (RESOURCE_EXHAUSTED → backoff)
- [ ] Conversão de micros para valores reais (/ 1_000_000)
- [ ] Property ID do GA4 em variável de ambiente
- [ ] Site URL do GSC com encoding correto
