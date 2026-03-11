# meta-ads.md — Bridge Sub-Skill: Meta Ads API
# Ativa quando: "Meta Ads", "Facebook API", "graph API", "campanhas"

## Propósito

Integração completa com Meta Ads Graph API para coleta de insights, gestão de campanhas e automações Wolf. Cobre autenticação, endpoints principais, paginação, rate limiting e queries otimizadas.

---

## Autenticação

### Token de Longa Duração (60 dias)

```typescript
// Trocar short-lived token por long-lived
async function exchangeForLongLivedToken(shortLivedToken: string): Promise<{
  accessToken: string;
  expiresIn: number;
}> {
  const url = new URL('https://graph.facebook.com/v19.0/oauth/access_token');
  url.searchParams.set('grant_type', 'fb_exchange_token');
  url.searchParams.set('client_id', process.env.META_APP_ID);
  url.searchParams.set('client_secret', process.env.META_APP_SECRET);
  url.searchParams.set('fb_exchange_token', shortLivedToken);

  const response = await fetch(url.toString());
  const data = await response.json();

  if (data.error) throw new MetaAPIError(data.error);

  return {
    accessToken: data.access_token,
    expiresIn: data.expires_in, // ~5184000 segundos (60 dias)
  };
}
```

### Scopes Necessários por Caso de Uso

```typescript
// Apenas leitura de insights
const READ_SCOPES = ['ads_read', 'read_insights'];

// Gestão completa
const MANAGEMENT_SCOPES = ['ads_read', 'ads_management', 'business_management', 'read_insights'];

// Verificar scopes do token atual
async function checkTokenScopes(accessToken: string) {
  const { data } = await metaClient.get('/debug_token', {
    params: {
      input_token: accessToken,
      access_token: `${process.env.META_APP_ID}|${process.env.META_APP_SECRET}`,
    },
  });
  return data.data.scopes;
}
```

---

## Cliente Meta Ads Wolf

```typescript
import axios, { AxiosInstance } from 'axios';

class MetaAdsClient {
  private client: AxiosInstance;
  private readonly API_VERSION = 'v19.0';
  private readonly BASE_URL = `https://graph.facebook.com/${this.API_VERSION}`;

  constructor(private accessToken: string) {
    this.client = axios.create({
      baseURL: this.BASE_URL,
      params: { access_token: this.accessToken },
      timeout: 30000,
    });

    // Rate limit handling
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 429) {
          const retryAfter = parseInt(error.response.headers['x-app-usage'] || '60');
          await sleep(retryAfter * 1000);
          return this.client.request(error.config);
        }
        throw error;
      }
    );
  }

  async get<T>(path: string, params?: object): Promise<T> {
    const { data } = await this.client.get<T>(path, { params });
    return data;
  }
}
```

---

## Campos Padrão Wolf para Insights

```typescript
// Campos base para toda consulta de insights
export const CAMPAIGN_INSIGHT_FIELDS = [
  'campaign_id',
  'campaign_name',
  'status',
  'spend',
  'impressions',
  'reach',
  'clicks',
  'actions',      // Inclui conversões
  'action_values', // Valor das conversões
  'cpm',
  'cpc',
  'ctr',
  'frequency',
  'date_start',
  'date_stop',
].join(',');

export const ADSET_INSIGHT_FIELDS = [
  'adset_id',
  'adset_name',
  'campaign_id',
  'spend',
  'impressions',
  'clicks',
  'actions',
  'action_values',
  'cpm',
  'cpc',
  'ctr',
  'optimization_goal',
].join(',');
```

---

## Endpoints Principais

### Insights de Campanha

```typescript
async function getCampaignInsights(params: {
  adAccountId: string;  // act_XXXXXXXXXX
  since: string;        // YYYY-MM-DD
  until: string;        // YYYY-MM-DD
  level?: 'account' | 'campaign' | 'adset' | 'ad';
  breakdown?: 'age' | 'gender' | 'country' | 'device_platform';
}) {
  const { adAccountId, since, until, level = 'campaign', breakdown } = params;

  const result = await metaClient.get(`/${adAccountId}/insights`, {
    fields: CAMPAIGN_INSIGHT_FIELDS,
    time_range: JSON.stringify({ since, until }),
    level,
    ...(breakdown && { breakdowns: breakdown }),
    limit: 100,
  });

  return paginateAll(result);
}
```

### Listar Campanhas

```typescript
async function getCampaigns(adAccountId: string, status?: string[]) {
  return metaClient.get(`/${adAccountId}/campaigns`, {
    fields: 'id,name,status,effective_status,daily_budget,lifetime_budget,start_time,stop_time',
    ...(status && { effective_status: JSON.stringify(status) }),
    limit: 100,
  });
}
```

### Atualizar Status de Campanha

```typescript
async function updateCampaignStatus(
  campaignId: string,
  status: 'ACTIVE' | 'PAUSED' | 'ARCHIVED',
) {
  return metaClient.post(`/${campaignId}`, { status });
}
```

### Creatives

```typescript
async function getAdCreatives(adId: string) {
  return metaClient.get(`/${adId}`, {
    fields: 'creative{id,name,body,title,image_url,video_id,thumbnail_url}',
  });
}
```

---

## Paginação de Resultados

Meta usa cursor-based pagination. Iterar até não ter `next`.

```typescript
async function paginateAll<T>(firstPage: {
  data: T[];
  paging?: { cursors?: { after: string }; next?: string };
}): Promise<T[]> {
  const allData: T[] = [...firstPage.data];
  let paging = firstPage.paging;

  while (paging?.next) {
    const response = await fetch(paging.next);
    const page = await response.json();
    allData.push(...page.data);
    paging = page.paging;

    // Segurança: máximo de 50 páginas (5000 itens com limit=100)
    if (allData.length > 5000) {
      logger.warn('Paginação atingiu limite de 5000 itens');
      break;
    }
  }

  return allData;
}
```

---

## Janelas de Atribuição

```typescript
// Parâmetros de atribuição para insights
const attributionParams = {
  // Padrão Meta: clique 7 dias, view 1 dia
  action_attribution_windows: JSON.stringify(['1d_view', '7d_click']),

  // Wolf padrão para e-commerce: 1 dia click only
  // action_attribution_windows: JSON.stringify(['1d_click']),

  // Customizável por cliente
};

// Campos de conversão com janela específica
const conversionFields = [
  'actions',
  'action_values',
  // Para janela específica no breakdown:
  'website_purchase_roas', // ROAS de compras (1d_click, 7d_click)
];
```

---

## Rate Limiting e Cache

```typescript
// Monitorar uso do rate limit via headers
function extractRateLimitInfo(headers: Record<string, string>) {
  // X-App-Usage: {"call_count":15,"total_cputime":20,"total_time":15}
  const usage = JSON.parse(headers['x-app-usage'] || '{}');
  return {
    callCount: usage.call_count || 0,        // % do limite por hora
    cpuTime: usage.total_cputime || 0,        // % de CPU
    totalTime: usage.total_time || 0,         // % de tempo total
  };
}

// Cache para evitar chamadas repetidas
const INSIGHTS_CACHE_TTL = 3600; // 1 hora

async function getCachedInsights(cacheKey: string, fetcher: () => Promise<any>) {
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  const data = await fetcher();
  await redis.setex(cacheKey, INSIGHTS_CACHE_TTL, JSON.stringify(data));
  return data;
}

// Uso
const insights = await getCachedInsights(
  `insights:${adAccountId}:${since}:${until}`,
  () => getCampaignInsights({ adAccountId, since, until }),
);
```

---

## Exemplos de Queries Wolf

### Relatório semanal por campanha

```typescript
const weeklyReport = await getCampaignInsights({
  adAccountId: 'act_123456789',
  since: '2024-12-01',
  until: '2024-12-07',
  level: 'campaign',
});

// Calcular ROAS
const reportWithROAS = weeklyReport.map(row => ({
  ...row,
  roas: calculateROAS(
    row.action_values?.find(a => a.action_type === 'purchase')?.value || 0,
    parseFloat(row.spend),
  ),
}));
```

### Breakdown por device

```typescript
const deviceBreakdown = await getCampaignInsights({
  adAccountId: 'act_123456789',
  since: '2024-12-01',
  until: '2024-12-07',
  level: 'ad',
  breakdown: 'device_platform',
});
```

---

## Checklist de Integração Meta Ads

- [ ] Token de longa duração obtido e armazenado encriptado
- [ ] Scopes verificados antes de operações de escrita
- [ ] Campos CAMPAIGN_INSIGHT_FIELDS padronizados
- [ ] Paginação implementada (não assume que primeira página tem tudo)
- [ ] Cache Redis para insights (TTL 1h)
- [ ] Rate limit monitorado via X-App-Usage header
- [ ] Retry automático em 429 com backoff
- [ ] Janela de atribuição documentada e consistente
- [ ] adAccountId sempre no formato `act_XXXXXXXXXX`
- [ ] Logs com adAccountId para rastreamento
