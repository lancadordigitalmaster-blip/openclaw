# performance-test.md — VEGA Sub-Skill: Performance Testing
# Ativa quando: "load test", "stress test", "k6", "Artillery", "quantos usuários"

## k6 — Padrão Wolf

Stack: **k6** para testes de carga e stress. Open-source, scripts em JavaScript/TypeScript, output para Grafana.

```bash
# Instalação
brew install k6          # macOS
# ou via Docker:
docker pull grafana/k6

# Executar teste
k6 run scripts/load-test.js
k6 run --vus 50 --duration 5m scripts/load-test.js   # override rápido
```

---

## Tipos de Teste Wolf

| Tipo    | Objetivo                              | Duração     | VUs          | Quando usar                        |
|---------|---------------------------------------|-------------|--------------|-------------------------------------|
| Smoke   | Valida que script funciona            | 1 min       | 1-5          | Após cada mudança no script         |
| Load    | Carga normal de produção              | 10-30 min   | Estimado real| Pré-deploy em staging               |
| Stress  | Encontra ponto de quebra              | 10-20 min   | Crescente    | Antes de lançamento grande          |
| Soak    | Detecta memory leaks e degradação     | 2-4 horas   | Carga normal | Validação de estabilidade           |

---

## Template k6 Básico Wolf

```javascript
// scripts/load-test.js

import http from 'k6/http'
import { check, sleep, group } from 'k6'
import { Counter, Rate, Trend } from 'k6/metrics'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js'

// Métricas customizadas
const campaignCreateErrors = new Counter('campaign_create_errors')
const reportGenerationTime = new Trend('report_generation_time')
const apiErrorRate = new Rate('api_error_rate')

// Configuração de stages (ramp up -> plateau -> ramp down)
export const options = {
  stages: [
    { duration: '2m', target: 20 },    // ramp up para 20 VUs
    { duration: '5m', target: 20 },    // mantém 20 VUs por 5 min
    { duration: '2m', target: 50 },    // spike: 50 VUs
    { duration: '3m', target: 50 },    // mantém spike
    { duration: '2m', target: 0 },     // ramp down
  ],
  thresholds: {
    // p95 de todas as requests < 500ms
    http_req_duration: ['p(95)<500'],
    // p99 < 1 segundo
    'http_req_duration{type:report}': ['p(99)<2000'],  // relatórios podem ser mais lentos
    // Taxa de erro < 1%
    http_req_failed: ['rate<0.01'],
    api_error_rate: ['rate<0.01'],
    // Erros de criação de campanha: zero tolerância
    campaign_create_errors: ['count<5'],
  },
}

// URL base — nunca produção diretamente
const BASE_URL = __ENV.BASE_URL || 'https://staging.wolfagency.app'

// Token de teste (gerado previamente)
const TEST_TOKEN = __ENV.TEST_TOKEN || 'token-de-staging-aqui'

const headers = {
  Authorization: `Bearer ${TEST_TOKEN}`,
  'Content-Type': 'application/json',
}

const ORG_IDS = ['org-test-1', 'org-test-2', 'org-test-3']

export default function () {
  const orgId = randomItem(ORG_IDS)

  group('Dashboard', () => {
    const res = http.get(`${BASE_URL}/api/dashboard?orgId=${orgId}`, { headers })

    check(res, {
      'dashboard returns 200': (r) => r.status === 200,
      'dashboard has campaigns': (r) => {
        const body = JSON.parse(r.body)
        return Array.isArray(body.campaigns)
      },
    })

    apiErrorRate.add(res.status >= 400)
    sleep(1)
  })

  group('Campaigns List', () => {
    const res = http.get(`${BASE_URL}/api/campaigns?limit=20`, { headers })

    check(res, {
      'campaigns list returns 200': (r) => r.status === 200,
      'campaigns list has items': (r) => {
        const body = JSON.parse(r.body)
        return body.items !== undefined
      },
    })

    apiErrorRate.add(res.status >= 400)
    sleep(0.5)
  })

  group('Create Campaign', () => {
    const payload = JSON.stringify({
      name: `Load Test Campaign ${Date.now()}`,
      platform: randomItem(['meta', 'google']),
      adAccountId: 'acc-load-test',
      budgetDaily: 100,
    })

    const res = http.post(`${BASE_URL}/api/campaigns`, payload, { headers })

    const success = check(res, {
      'campaign created': (r) => r.status === 201,
      'response has id': (r) => JSON.parse(r.body).id !== undefined,
    })

    if (!success) {
      campaignCreateErrors.add(1)
    }

    apiErrorRate.add(res.status >= 400)
    sleep(2)
  })

  group('Report Generation', () => {
    const start = Date.now()
    const res = http.post(
      `${BASE_URL}/api/reports/generate`,
      JSON.stringify({ period: '2024-03', organizationId: orgId }),
      { headers, timeout: '30s' }
    )

    reportGenerationTime.add(Date.now() - start)

    check(res, {
      'report generation accepted': (r) => r.status === 202 || r.status === 200,
    })

    apiErrorRate.add(res.status >= 400)
    sleep(3)
  })
}

// Lifecycle hooks
export function setup() {
  console.log(`Starting load test against: ${BASE_URL}`)

  // Valida que a aplicação está respondendo
  const healthCheck = http.get(`${BASE_URL}/api/health`)
  if (healthCheck.status !== 200) {
    throw new Error(`Health check failed: ${healthCheck.status}`)
  }
}

export function teardown(data) {
  console.log('Load test completed')
}
```

---

## Teste de Stress (encontra ponto de quebra)

```javascript
// scripts/stress-test.js

export const options = {
  stages: [
    { duration: '2m', target: 50 },
    { duration: '3m', target: 100 },
    { duration: '3m', target: 200 },   // dobra a carga
    { duration: '3m', target: 300 },   // stress pesado
    { duration: '3m', target: 400 },   // além do esperado
    { duration: '2m', target: 0 },     // ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.10'],    // aceita até 10% de erro em stress
    http_req_duration: ['p(99)<5000'], // p99 até 5s em stress
  },
}
```

---

## Relatório de Resultado

```
scenarios: (100.00%) 1 scenario, 50 max VUs, 14m30s max duration

✓ dashboard returns 200
✓ campaigns list returns 200
✗ campaign created               <-- FALHOU
  ↳ 94% — ✓ 847 / ✗ 53

checks.........................: 98.21% ✓ 2841 ✗ 53
data_received..................: 18 MB  21 kB/s
http_req_blocked...............: avg=1.28ms  p(95)=2.45ms
http_req_duration..............: avg=142ms   p(95)=487ms   p(99)=831ms
  { type:report }...............: avg=1.2s    p(95)=2.1s    p(99)=3.4s
http_req_failed................: 1.83%  ✗ 53  <-- ACIMA DO THRESHOLD de 1%
http_reqs......................: 2894   56.2/s
iteration_duration.............: avg=4.2s
vus............................: 50 max

FALHA: http_req_failed threshold excedido (1.83% > 1%)
```

### Interpretando o resultado:
- `p(95)<500` PASSOU: 95% das requests < 500ms
- `http_req_failed` FALHOU: 1.83% de erro supera threshold de 1%
- Investigar: campanhas falhando podem indicar rate limit ou DB lento sob carga

---

## Quando Rodar em Staging

| Evento                          | Tipo de Teste   | Automático |
|---------------------------------|-----------------|------------|
| Antes de cada deploy importante | Smoke + Load    | Via CI     |
| Antes de lançamento de feature  | Load + Stress   | Manual     |
| Quinzenalmente                  | Soak            | Cron       |
| Após mudança de infra           | Stress          | Manual     |

```yaml
# .github/workflows/load-test.yml

name: Load Test (Staging)

on:
  workflow_dispatch:           # manual
  schedule:
    - cron: '0 8 * * 1'       # toda segunda às 8h

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run k6 smoke test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: scripts/load-test.js
          flags: '--env BASE_URL=${{ secrets.STAGING_URL }} --env TEST_TOKEN=${{ secrets.STAGING_TEST_TOKEN }}'

      - name: Upload k6 results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: k6-results
          path: results/
```

---

## Checklist Performance Test

- [ ] Script k6 com stages configurados (ramp up/down)
- [ ] Thresholds definidos: `p(95)<500ms`, `error_rate<1%`
- [ ] Nunca rodar load test contra produção (somente staging)
- [ ] Token de staging separado do token de produção
- [ ] Health check no `setup()` antes de iniciar carga
- [ ] Métricas customizadas para fluxos críticos (criação, relatório)
- [ ] Smoke test automatizado no CI antes de cada deploy
- [ ] Resultado de load test arquivado para comparação histórica
- [ ] Alertas configurados se p95 > 500ms ou error rate > 0.5% em produção
- [ ] Relatório compartilhado com time após testes de stress manuais
