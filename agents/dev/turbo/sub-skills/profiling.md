# profiling.md — Turbo Sub-Skill: Profiling e Flame Graphs
# Ativa quando: "profiling", "flame graph", "CPU", "memória", "leak"

---

## Quando Usar Profiling

Profiling tem overhead. Meça impacto antes de rodar em produção.

```
USE PROFILING QUANDO:
- Diagnóstico identificou alto consumo de CPU (htop mostra > 80%)
- Requisições lentas mas banco e rede estão OK
- Memória crescendo continuamente (suspeita de leak)
- Event loop lag alto (node --inspect mostra event loop delay)
- Antes de otimizar: para saber ONDE otimizar, não adivinhar

NÃO USE EM PRODUÇÃO SEM:
- Estimar overhead (clinic: 5-15%, 0x: > 20%)
- Janela de tráfego baixo
- Monitoramento de impacto ativo
- Plano de rollback se degradar
```

---

## Node.js — clinic.js

```bash
# Instalar
npm install -g clinic

# 1. Doctor — diagnóstico automático (menor overhead)
# Detecta: I/O bloqueante, memory leak, event loop delay
clinic doctor -- node server.js
# Roda, faz carga (ab, k6), Ctrl+C para parar
# Abre relatório HTML automaticamente

# 2. Flame — CPU profiling (onde o tempo vai)
clinic flame -- node server.js
# Similar ao doctor mas gera flame graph

# 3. Bubbleprof — async profiling
# Mostra gargalos em operações assíncronas
clinic bubbleprof -- node server.js

# Com scripts npm
clinic doctor -- node -r ./register.js dist/server.js
```

---

## Node.js — 0x (Flame Graphs Interativos)

```bash
# Instalar
npm install -g 0x

# Rodar
0x server.js

# Fazer carga enquanto roda (ab, k6, curl)
ab -n 1000 -c 50 http://localhost:3000/api/endpoint

# Ctrl+C para parar — gera flame graph HTML interativo
# Arquivo salvo em: 0x-[timestamp]/flamegraph.html
```

### Como Ler um Flame Graph
```
LEITURA DE FLAME GRAPH:
========================
Eixo X → tempo (largura = % do tempo total de CPU)
Eixo Y → call stack (topo = função atual, base = quem chamou)

PROCURE:
- Platôs largos no topo → função que consome muito CPU
- Towers altas → call stacks profundas (recursão?)
- Laranja/vermelho → código da aplicação (seu código)
- Cinza/azul → código de terceiros / runtime

IGNORE (geralmente):
- node::* → internals do Node
- v8::* → garbage collection / JIT

AÇÃO:
- Platô largo no seu código → otimizar aquela função
- Platô largo em lib externa → considerar alternativa ou cache
```

---

## Python — py-spy (Profiling sem Pausar o Processo)

```bash
# Instalar
pip install py-spy

# Flame graph de processo em execução (SEM reiniciar)
py-spy record -o profile.svg --pid $(pgrep -f "uvicorn main:app")
# Faz carga enquanto roda, Ctrl+C para parar
# Abre profile.svg no browser

# Top ao vivo (como htop mas para Python)
py-spy top --pid $(pgrep -f "uvicorn main:app")

# Para script simples
py-spy record -o profile.svg -- python meu_script.py

# Speedscope format (UI melhor para análise)
py-spy record -o profile.json -f speedscope --pid 12345
# Abrir em https://www.speedscope.app
```

### cProfile — Profiling Detalhado em Dev
```python
# profiling em bloco específico
import cProfile
import pstats
import io

def profilear(func, *args, **kwargs):
    pr = cProfile.Profile()
    pr.enable()
    resultado = func(*args, **kwargs)
    pr.disable()

    s = io.StringIO()
    ps = pstats.Stats(pr, stream=s).sort_stats('cumulative')
    ps.print_stats(20)  # top 20 funções
    print(s.getvalue())
    return resultado

# Uso
resultado = profilear(processar_dados_pesados, dataset)
```

```python
# FastAPI — profiling por rota
from fastapi import FastAPI, Request
import cProfile
import pstats
import io

app = FastAPI()

@app.middleware("http")
async def profiling_middleware(request: Request, call_next):
    if request.headers.get("X-Profile") == "true":  # header especial
        pr = cProfile.Profile()
        pr.enable()
        response = await call_next(request)
        pr.disable()

        s = io.StringIO()
        pstats.Stats(pr, stream=s).sort_stats('cumulative').print_stats(20)
        print(f"\nPROFILE {request.url}:\n{s.getvalue()}")
        return response

    return await call_next(request)
```

---

## Memory Leak — Node.js

### Detectar
```bash
# 1. Monitorar uso de memória ao longo do tempo
node --expose-gc server.js
# No código: global.gc() para forçar GC e ver se memória volta

# 2. Métrica de heap ao longo do tempo
# Se heap sobe continuamente sem descer → leak
watch -n 5 "node -e \"console.log(process.memoryUsage())\""
```

### Heapdump e Análise
```javascript
// Capturar heap dump via endpoint (só em dev/staging)
import { writeHeapSnapshot } from 'v8'
import { Router } from 'express'

const router = Router()

// GET /debug/heap — gera snapshot
router.get('/debug/heap', (req, res) => {
  const filename = writeHeapSnapshot()
  res.json({ file: filename, message: 'Heap snapshot gerado' })
})
```

```bash
# Analisar com clinic heapprofiler
clinic heapprofiler -- node server.js

# OU abrir .heapsnapshot no Chrome DevTools
# Chrome → DevTools → Memory → Load...
# Procurar: objetos com muitas instâncias que não deveriam acumular
```

### Causas Comuns de Memory Leak em Node.js
```javascript
// 1. Event listeners não removidos
class Servico extends EventEmitter {
  iniciar() {
    // LEAK: listener adicionado a cada chamada, nunca removido
    process.on('message', this.handleMessage)
  }

  // FIX: guardar referência e remover
  iniciar() {
    this.boundHandler = this.handleMessage.bind(this)
    process.on('message', this.boundHandler)
  }

  parar() {
    process.off('message', this.boundHandler)
  }
}

// 2. Closures retendo referências desnecessárias
function criarHandler(dadosGrandes) {
  // LEAK: dadosGrandes (5MB) fica retido enquanto handler existir
  return function handler(req, res) {
    res.json({ id: dadosGrandes.id }) // só usa .id
  }
}

// FIX: extrair só o necessário
function criarHandler(dadosGrandes) {
  const id = dadosGrandes.id // extrai antes, libera o resto
  return function handler(req, res) {
    res.json({ id })
  }
}

// 3. Cache sem limite
const cache = new Map() // LEAK: cresce infinitamente

// FIX: LRU cache com limite
import { LRUCache } from 'lru-cache'
const cache = new LRUCache({ max: 1000, ttl: 1000 * 60 * 5 })
```

---

## Event Loop Bloqueado

```javascript
// Detectar event loop lag
import { monitorEventLoopDelay } from 'perf_hooks'

const h = monitorEventLoopDelay({ resolution: 20 })
h.enable()

setInterval(() => {
  const lagMs = h.mean / 1e6 // nanoseconds → milliseconds
  if (lagMs > 50) {
    console.warn(`Event loop lag: ${lagMs.toFixed(2)}ms`)
  }
  h.reset()
}, 5000)

// Causas comuns de event loop bloqueado:
// - JSON.parse / JSON.stringify de payloads > 1MB
// - crypto síncrono (bcrypt sync, scrypt sync)
// - fs.readFileSync em hot path
// - Loops com milhares de iterações sem yield
// - Regex complexo com backtracking exponencial
```

```javascript
// FIX: mover operação pesada para Worker Thread
import { Worker, isMainThread, parentPort, workerData } from 'worker_threads'

// worker.js
if (!isMainThread) {
  const resultado = processarDadosPesados(workerData)
  parentPort.postMessage(resultado)
}

// main.js
function processarNoWorker(dados) {
  return new Promise((resolve, reject) => {
    const worker = new Worker('./worker.js', { workerData: dados })
    worker.on('message', resolve)
    worker.on('error', reject)
  })
}
```

---

## Profiling em Produção — Protocolo Wolf

```
ANTES:
[ ] Medir overhead esperado da ferramenta (clinic: ~5%, py-spy: ~2%)
[ ] Selecionar janela de baixo tráfego
[ ] Avisar time
[ ] Configurar alerta: se latência > 2x baseline → abortar

DURANTE:
[ ] Monitorar CPU e latência em tempo real
[ ] Tempo máximo de profiling: 5 minutos
[ ] Capturar apenas o período problemático

DEPOIS:
[ ] Confirmar que métricas voltaram ao normal
[ ] Analisar output com contexto do problema
[ ] Documentar hot spots encontrados
[ ] Criar plano de otimização rankeado
```

---

## Checklist Profiling Wolf

```
Preparação
[ ] Problema confirmado com métricas (não profila por curiosidade)
[ ] Ferramenta adequada escolhida para o tipo de problema
[ ] Ambiente definido (dev: à vontade, prod: protocolo acima)

Execução
[ ] Carga realista aplicada durante profiling
[ ] Duração adequada (> 30s para padrões significativos)
[ ] Output salvo para análise posterior

Análise
[ ] Hot spots identificados no flame graph
[ ] Causa raiz distinguida: CPU vs I/O vs GC vs memória
[ ] Platôs largos no código próprio mapeados

Ação
[ ] Hipóteses de otimização rankeadas por impacto
[ ] Benchmark antes/depois para validar melhoria
[ ] Resultado documentado
```
