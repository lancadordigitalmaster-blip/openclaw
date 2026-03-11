---
name: alfred-auto-optimizer
description: Monitora tempo de resposta do Alfred e alterna automaticamente entre LLMs (Groq, Kimi, Gemini) quando detecta lentidão. Mantém a operação fluida sem intervenção manual.
---

# Alfred Auto-Optimizer

Skill de auto-otimização de performance para o Alfred.

## Como funciona

### Monitoramento contínuo
- Verifica tempo de resposta da API a cada 30 segundos
- Registra logs em `logs/alfred-performance.log`

### Thresholds

| Situação | Tempo | Ação |
|----------|-------|------|
| Normal | < 5s | Continua com modelo atual |
| Aviso | 5-10s | Log de alerta, mantém modelo |
| Crítico | > 10s | **Alterna automaticamente** para modelo mais rápido |

### Hierarquia de Modelos

1. **Ultra-rápido** (emergência): `groq/llama-3.1-8b-instant`
2. **Rápido** (padrão): `groq/llama-3.3-70b-versatile` ← **Atual**
3. **Balanceado**: `google/gemini-2.5-flash`
4. **Qualidade**: `moonshot/kimi-k2.5`

### Comportamento

```
Resposta lenta detectada (>10s)
        ↓
  Alterna para modelo mais rápido
        ↓
  Continua monitorando
        ↓
  Se normalizar por 5 minutos → Volta ao modelo padrão
```

## Uso

### Iniciar monitoramento
```bash
./scripts/alfred-auto-optimizer.sh
```

### Ver status
```bash
tail -f logs/alfred-performance.log
```

### Parar
```bash
kill $(cat /tmp/alfred-auto-optimizer.pid)
```

## Configuração

Edite o script para ajustar:
- `THRESHOLD_WARNING` — tempo para alerta (ms)
- `THRESHOLD_SWITCH` — tempo para troca automática (ms)
- Modelos disponíveis

## Notas

- A troca automática só ocorre em caso de lentidão crítica
- O sistema tenta voltar ao modelo de qualidade quando a performance normaliza
- Logs mantêm histórico de todas as alternâncias