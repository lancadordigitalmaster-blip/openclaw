# diagnosis.md — Turbo Sub-Skill: Diagnóstico de Performance
# Ativa quando: "lento", "demora", "travando", "timeout", "performance"

---

## Protocolo Wolf: Nunca Assume — Mede Primeiro

Antes de qualquer hipótese, colete dados. Performance sem métricas é opinião.

**Regra de ouro:** O gargalo raramente está onde você acha que está.

---

## Mapa de Latência Completo

```
Usuário
  └── DNS lookup
  └── TCP handshake
  └── TLS handshake
        └── Rede (ISP, CDN, roteamento)
              └── Servidor (Load Balancer / Reverse Proxy)
                    └── Aplicação (código, runtime, GC)
                          └── Banco de Dados (query, índice, lock)
                          └── Serviços externos (APIs, filas)
                    └── Serialização / Resposta
              └── Rede (volta)
        └── Browser (parse, render, JS execution)
  └── Percepção do usuário (LCP, INP, CLS)
```

Cada camada pode ser o gargalo. Meça todas antes de agir.

---

## Perguntas de Triagem Obrigatórias

Responda antes de abrir qualquer ferramenta:

```
1. Lento ONDE?
   - Frontend (navegador lento)?
   - Rede (requisição demora a chegar)?
   - Backend (servidor processa devagar)?
   - Banco (query pesada)?
   - Serviço externo (API de terceiro)?

2. SEMPRE ou ÀS VEZES?
   - Sempre = problema estrutural (query sem índice, bundle pesado)
   - Às vezes = problema de carga, race condition, ou memória

3. Começou QUANDO?
   - Após deploy? → Regression introduzida
   - Gradualmente? → Crescimento de dados ou memory leak
   - Do início? → Nunca foi otimizado
   - Sob carga? → Problema de escala

4. O que MUDOU?
   - Novo código deployado?
   - Volume de dados cresceu?
   - Tráfego aumentou?
   - Dependência atualizada?
   - Configuração de infra alterada?

5. Qual o impacto REAL?
   - Quantos usuários afetados?
   - Qual a latência atual vs aceitável?
   - Perda de conversão / receita?
```

---

## Ferramentas por Camada

### Camada: Browser / Frontend
```bash
# Chrome DevTools
# Network tab → waterfall de requests
# Performance tab → flame graph de JS
# Lighthouse → Core Web Vitals

# WebPageTest (https://webpagetest.org)
# Testa de múltiplas localizações e dispositivos reais

# CrUX (Chrome UX Report)
# Dados reais de usuários, não lab data
```

### Camada: Rede
```bash
# curl com timing detalhado
curl -w "\n--- Timing ---\n\
DNS: %{time_namelookup}s\n\
TCP: %{time_connect}s\n\
TLS: %{time_appconnect}s\n\
TTFB: %{time_starttransfer}s\n\
Total: %{time_total}s\n\
Size: %{size_download} bytes\n" \
-o /dev/null -s https://seudominio.com/api/endpoint

# ping e traceroute para latência de rede
ping -c 10 seudominio.com
traceroute seudominio.com

# mtr para análise contínua de rota
mtr --report seudominio.com
```

### Camada: Servidor / Infra
```bash
# htop — visão geral de CPU, memória, processos
htop

# vmstat — I/O, memória, CPU over time
vmstat 1 10

# iostat — performance de disco
iostat -x 1 5

# netstat — conexões abertas
netstat -an | grep ESTABLISHED | wc -l

# free — uso de memória
free -h

# df — uso de disco
df -h
```

### Camada: Aplicação (Node.js)
```bash
# clinic.js — profiling automático
npx clinic doctor -- node server.js
npx clinic flame -- node server.js
npx clinic bubbleprof -- node server.js

# 0x — flame graphs interativos
npx 0x server.js

# --inspect para profiling manual
node --inspect server.js
# Conectar no chrome://inspect
```

### Camada: Banco de Dados (PostgreSQL)
```sql
-- Queries mais lentas dos últimos X dias
SELECT query,
       calls,
       total_exec_time / calls AS avg_ms,
       rows / calls AS avg_rows,
       mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Queries rodando agora
SELECT pid, now() - query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- EXPLAIN ANALYZE na query suspeita
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM tabela WHERE coluna = 'valor';
```

---

## Processo de Hipóteses Rankeadas

Após coletar métricas, construa hipóteses em ordem de probabilidade:

```
RANKING DE HIPÓTESES
====================
Prioridade | Hipótese                          | Evidência | Facilidade Fix
-----------|-----------------------------------|-----------|---------------
1          | Query sem índice (Seq Scan)       | EXPLAIN   | Alta
2          | Bundle JS pesado (> 500KB parsed) | DevTools  | Média
3          | N+1 queries no ORM               | slow log  | Média
4          | Sem cache em dados estáticos      | TTFB alto | Alta
5          | Imagens sem otimização            | Network   | Alta
6          | Connection pool insuficiente      | pg_stat   | Alta
7          | Memory leak (uso cresce c/ tempo) | htop      | Baixa
```

**Regra de priorização:**
- Primeiro: o que tem maior impacto no usuário
- Segundo: o que é mais fácil de corrigir (quick wins)
- Terceiro: o que temos dados suficientes para confirmar

---

## Checklist de Diagnóstico Wolf

```
[ ] Coletou métricas de baseline (antes de qualquer mudança)
[ ] Respondeu as 5 perguntas de triagem
[ ] Identificou a camada do problema (frontend/rede/backend/banco)
[ ] Usou ferramenta adequada para a camada suspeita
[ ] Reproduziu o problema de forma controlada
[ ] Tem hipótese rankeada com evidência
[ ] Definiu métrica de sucesso para validar a fix
[ ] Criou ambiente de teste para validar antes de prod
```

---

## Template de Relatório de Diagnóstico

```markdown
## Diagnóstico de Performance — [Data]

**Sintoma reportado:** [o que o usuário descreveu]

**Métricas coletadas:**
- TTFB: Xms (aceitável: < 200ms)
- Tempo total: Xms (aceitável: < 1000ms)
- Query mais lenta: Xms

**Camada do problema:** [frontend/rede/backend/banco]

**Causa raiz identificada:** [descrição técnica precisa]

**Evidência:** [output do EXPLAIN, screenshot do DevTools, etc]

**Solução proposta:** [o que fazer]

**Impacto esperado:** [de Xms para Yms = Z% melhoria]

**Como validar:** [métrica e ferramenta para confirmar]
```
