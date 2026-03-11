# load-testing.md — Turbo Sub-Skill: Load Testing
# Ativa quando: "load test", "stress test", "quantos usuários", "k6"

---

## Tipos de Teste — Quando Usar Cada Um

| Tipo | Objetivo | Duração | Quando Usar |
|------|----------|---------|-------------|
| **Smoke** | Valida que o sistema funciona | 1-2 min | Antes de qualquer outro teste |
| **Load** | Valida carga normal esperada | 30-60 min | Antes de lançamento |
| **Stress** | Encontra o ponto de quebra | 1-2h | Capacidade máxima / scaling |
| **Soak** | Detecta memory leaks | 4-8h | Sistemas novos, antes de produção |
| **Spike** | Testa pico súbito de tráfego | 15-30 min | Black Friday, lançamento marketing |

---

## Como Definir Carga Realista

Nunca chute — use dados reais:

```bash
# 1. Analytics histórico (Google Analytics / Mixpanel)
# - Peak concurrent users (PCU)
# - Requests per second no pico
# - Páginas mais acessadas

# 2. Logs de servidor
# Nginx: requests por minuto no pico
grep "$(date --date='yesterday' +%d/%b/%Y)" /var/log/nginx/access.log \
  | awk '{print $4}' \
  | cut -d: -f2 \
  | sort | uniq -c | sort -rn | head -10

# 3. Fórmula básica
# VUs (Virtual Users) = RPS × tempo_médio_sessão_segundos
# Ex: 100 req/s × 3s sessão = 300 VUs simultâneos
```

---

## Template k6 Completo Wolf

```javascript
// tests/load/baseline.js
import http from 'k6/http'
import { check, sleep } from 'k6'
import { Counter, Rate, Trend } from 'k6/metrics'

// Métricas customizadas
const erros = new Counter('erros_http')
const taxaErro = new Rate('taxa_erro')
const latenciaAPI = new Trend('latencia_api_ms')

// Configuração de stages — Load Test padrão Wolf
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // ramp-up suave
    { duration: '5m', target: 50 },   // carga crescendo
    { duration: '10m', target: 100 }, // carga normal
    { duration: '5m', target: 150 },  // pico
    { duration: '5m', target: 100 },  // volta ao normal
    { duration: '2m', target: 0 },    // ramp-down
  ],

  thresholds: {
    // p95 das requisições < 500ms
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    // Taxa de erro < 1%
    http_req_failed: ['rate<0.01'],
    // Métrica customizada
    latencia_api_ms: ['p(95)<300'],
  },
}

const BASE_URL = __ENV.BASE_URL || 'https://staging.seusite.com'

// Cenários de uso realista
export default function () {
  // Grupo: página inicial
  const resHome = http.get(`${BASE_URL}/`)
  check(resHome, {
    'home: status 200': (r) => r.status === 200,
    'home: < 1s': (r) => r.timings.duration < 1000,
  })
  taxaErro.add(resHome.status !== 200)
  latenciaAPI.add(resHome.timings.duration)

  sleep(1)

  // Grupo: listagem de produtos
  const resLista = http.get(`${BASE_URL}/api/produtos?page=1&limit=20`)
  check(resLista, {
    'lista: status 200': (r) => r.status === 200,
    'lista: tem dados': (r) => {
      const body = JSON.parse(r.body)
      return body.data && body.data.length > 0
    },
  })
  if (resLista.status !== 200) erros.add(1)

  sleep(2)

  // Grupo: detalhe de produto
  const produtoId = Math.floor(Math.random() * 100) + 1
  const resProduto = http.get(`${BASE_URL}/api/produtos/${produtoId}`)
  check(resProduto, {
    'produto: status 200 ou 404': (r) => [200, 404].includes(r.status),
    'produto: < 500ms': (r) => r.timings.duration < 500,
  })

  sleep(1)
}

// Lifecycle hooks
export function setup() {
  console.log(`Iniciando load test em: ${BASE_URL}`)
  // Verificação de saúde antes de começar
  const health = http.get(`${BASE_URL}/health`)
  if (health.status !== 200) {
    throw new Error(`Sistema não está saudável: ${health.status}`)
  }
}

export function teardown(data) {
  console.log('Teste concluído.')
}
```

### Smoke Test (sempre primeiro)
```javascript
// tests/load/smoke.js
import http from 'k6/http'
import { check } from 'k6'

export const options = {
  vus: 1,
  duration: '1m',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
}

export default function () {
  const res = http.get(__ENV.BASE_URL || 'https://staging.seusite.com')
  check(res, { 'status 200': (r) => r.status === 200 })
}
```

### Stress Test (encontrar limite)
```javascript
// tests/load/stress.js
export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 300 },
    { duration: '5m', target: 300 },
    { duration: '2m', target: 400 },
    { duration: '5m', target: 400 },
    { duration: '10m', target: 0 },  // ramp-down
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'], // aceita até 5% de erro em stress
  },
}
```

### Soak Test (detectar leak)
```javascript
// tests/load/soak.js
export const options = {
  stages: [
    { duration: '5m', target: 50 },
    { duration: '4h', target: 50 },  // carga constante por horas
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
}
```

### Spike Test (pico súbito)
```javascript
// tests/load/spike.js
export const options = {
  stages: [
    { duration: '10s', target: 100 }, // spike imediato
    { duration: '1m', target: 100 },  // sustenta
    { duration: '10s', target: 10 },  // cai rápido
    { duration: '3m', target: 10 },   // recuperação
    { duration: '10s', target: 0 },
  ],
}
```

---

## Como Rodar

```bash
# Instalar k6
brew install k6  # macOS
# ou
docker pull grafana/k6

# Rodar smoke test
k6 run tests/load/smoke.js

# Rodar com variável de ambiente
k6 run -e BASE_URL=https://staging.seusite.com tests/load/baseline.js

# Rodar com output para Grafana
k6 run --out influxdb=http://localhost:8086/k6 tests/load/baseline.js

# Docker
docker run --rm -v $(pwd)/tests:/tests grafana/k6 run \
  -e BASE_URL=https://staging.seusite.com \
  /tests/load/baseline.js
```

---

## Interpretação de Resultados

```
SAÍDA TÍPICA DO K6
==================

✓ home: status 200
✓ lista: tem dados
✗ produto: < 500ms  [92%] ← 8% das requisições ultrapassaram 500ms

     checks.........................: 97.33% ✓ 8760 ✗ 234
     data_received..................: 45 MB  750 kB/s
     data_sent......................: 1.2 MB 20 kB/s
     http_req_blocked...............: avg=1.2ms  p(95)=2.1ms  p(99)=10ms
     http_req_duration..............: avg=145ms  p(50)=120ms  p(95)=480ms  p(99)=920ms
                                    ↑ média    ↑ mediana    ↑ importante  ↑ outliers
     http_req_failed................: 0.23%  ✓ (< 1% threshold)
     vus............................: 150 max
     vus_max........................: 150

INTERPRETAÇÃO:
- p50 (120ms): metade das requisições respondem em 120ms ou menos
- p95 (480ms): 95% respondem em até 480ms — esse é o SLA usual
- p99 (920ms): 1% demora quase 1s — usuários lentos
- Diferença p50→p95 grande: há outliers / comportamento não uniforme
```

### Sinais de Alerta
```
PROBLEMA: p95 crescendo linearmente com VUs
→ Sem cache efetivo, ou banco sem índice, escala linear

PROBLEMA: p99 muito maior que p95
→ Outliers: GC pause, connection pool esgotado, lock no banco

PROBLEMA: erro rate sobe acima de 0.5% sob carga
→ Servidor derrubando conexões, rate limiting, timeout de serviço externo

PROBLEMA: memória cresce durante soak sem estabilizar
→ Memory leak confirmado — precisa de profiling

SINAL BOM: p50 estável enquanto VUs sobem
→ Sistema escala horizontalmente de forma eficiente
```

---

## Regras de Quando e Onde Rodar

```
ONDE:
✓ Ambiente de staging (espelho de prod)
✗ NUNCA em produção sem janela de manutenção comunicada
✗ NUNCA apontar para banco de produção
✗ NUNCA rodar contra APIs externas (Stripe, SendGrid) sem sandbox

QUANDO:
✓ Antes de todo lançamento significativo
✓ Após mudança de infra (novo tier, scaling)
✓ Quando analytics mostrar crescimento de tráfego de 2x
✓ Após otimizações de performance (validar melhoria)
✗ Não rodar durante pico de tráfego em staging se compartilhado

JANELA EM PRODUÇÃO (se necessário):
- Comunicar time com 24h de antecedência
- Horário de menor tráfego (madrugada)
- Smoke test apenas — nunca stress em prod
- Equipe de plantão durante o teste
- Rollback plan pronto
```

---

## Checklist Load Test Wolf

```
Preparação
[ ] Smoke test passou antes de qualquer outro
[ ] Carga baseada em dados reais de analytics
[ ] Ambiente de staging configurado igual à prod
[ ] Banco de staging com volume similar ao prod
[ ] Serviços externos em modo sandbox / mock

Execução
[ ] Thresholds definidos antes de rodar (não ajuste depois)
[ ] Monitoramento ativo durante o teste (CPU, memória, DB)
[ ] Logs capturados para análise posterior

Análise
[ ] p95 dentro do threshold definido
[ ] Taxa de erro < 1% em carga normal
[ ] Identificado o ponto de saturação (stress test)
[ ] Comportamento sob spike documentado

Pós-teste
[ ] Resultado documentado com contexto (data, versão, carga)
[ ] Comparado com baseline anterior
[ ] Ações de melhoria listadas se thresholds falharam
```
