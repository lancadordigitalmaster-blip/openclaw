# Conformidade de Processo — Módulo 02 do Guardião

## OBJETIVO

Detectar desvios de processo: tarefas paradas e loops de revisão.

---

## DETECÇÃO 1 — TAREFA PARADA

**Critério:** tarefa em status intermediário sem mudança por >48h

**Status intermediários monitorados:**
- `produzindo`
- `conferência interna`
- `em alteração`
- `formatos`

**Fonte de dados:** `clickup-history.jsonl` — campo `ts` do último evento da tarefa

**Algoritmo:**
```
1. Para cada tarefa com status intermediário:
2.   Buscar último evento em clickup-history.jsonl
3.   Se (agora - ultimo_evento) > 48h:
4.     Registrar como tarefa_parada
5.     Calcular nivel de escalonamento
```

**Mensagem de alerta:**
```
🚨 *Tarefa Parada — {horas}h sem movimento*

Tarefa: {nome}
Status atual: {status}
Parada desde: {data_hora}
Designer: {nome_designer}

@{atendimento_lid} esta tarefa está parada. Verifica com o designer o que está acontecendo.
```

---

## DETECÇÃO 2 — LOOP DE REVISÃO

**Critério:** tarefa voltou de `conferência interna` ou `enviado ao cliente` para `em alteração`

**Algoritmo:**
```
1. Ler clickup-history.jsonl para a tarefa
2. Contar sequências: (conferência interna|enviado ao cliente) → em alteração
3. N = contagem de loops
4. Aplicar escalamento por N
```

**Níveis de escalonamento:**

| Loops (N) | Nível | Ação |
|-----------|-------|------|
| 1 | Nível 1 | Comentário educativo no ClickUp |
| 2 | Nível 2 | Comentário + alerta no [ATD] individual |
| 3 | Nível 3 | Comentário + alerta no [ATD] Gestão de Atendimento |
| 4+ | Nível 4 | Comentário + alerta no [ATD] Gestão aguardando decisão |

---

## COMENTÁRIO NO CLICKUP POR NÍVEL

**Nível 1:**
```
🔄 *Loop de Revisão Detectado (1ª vez)*

Esta tarefa passou por revisão do cliente e voltou para alteração.
Loops frequentes impactam a produtividade do time.

Certifique-se de que o briefing está claro antes de enviar ao cliente.
```

**Nível 2:**
```
⚠️ *Loop de Revisão — 2ª Ocorrência*

Esta tarefa já teve 2 ciclos de revisão.
O Atendimento foi notificado para acompanhar de perto.

Verifique com o cliente se o briefing precisa ser revisado.
```

**Nível 3:**
```
🚨 *Loop de Revisão Crítico — {N} ciclos*

Esta tarefa acumulou {N} rodadas de revisão.
A gestão foi notificada para avaliação.

Aguardando decisão sobre continuidade ou renegociação com o cliente.
```

---

## PERSISTÊNCIA DE ESTADO

O estado de loops por tarefa é salvo em `~/.openclaw/guardiao-state.json`:

```json
{
  "task_id": {
    "loops": N,
    "last_level_notified": 2,
    "stopped_at_parada": false,
    "first_seen": "ISO_DATETIME"
  }
}
```

Isso evita notificações duplicadas a cada poll.
