# SKILL.md — Wolf Ops · Integração Bidirecional W.O.L.F.
# Wolf Agency AI System | Versão: 1.0 | Criado: 2026-03-04

> Bridge entre Alfred e o sistema W.O.L.F. v3.0
> Leitura em tempo real + escrita de tarefas, alertas e recomendações

---

## Agent

**Alfred** — integrador operacional. Todos os agentes (Gabi, Luna, Sage, Nova) usam
esta skill para ler contexto do W.O.L.F. e escrever de volta ações concretas.

---

## Triggers

```
"status da equipe" | "carga" | "quem está disponível" | "capacidade"
"kanban" | "cards" | "o que está em andamento" | "tarefas"
"wolf" | "operacional" | "w.o.l.f"
"cria tarefa" | "abre card" | "adiciona no kanban"
"cria alerta" | "dispara alerta"
"resolve alerta" | "fecha alerta"
"manda recomendação" | "registra sugestão"
"agentes wolf" | "status dos agentes"
"automações" | "integrações desconectadas"
"manda whatsapp" | "envia whatsapp" | "whatsapp para" | "mensagem para"
```

---

## Configuração

```bash
# Em: /Users/thomasgirotto/.openclaw/.env
WOLF_API_URL=https://...ngrok-free.dev/api/webhooks/openclaw
WOLF_API_TOKEN=0c915dc2ad86c9eb9e38f95dc4590ffcc5a3cdf1aaef81b4
WOLF_WEBHOOK_PORT=18790
```

---

## API W.O.L.F. — Referência Completa

### GET — Snapshot do sistema
```bash
curl -s -X GET "$WOLF_API_URL" \
  -H "ngrok-skip-browser-warning: true"
```
Retorna: agentes, equipe (carga), alertas, kanban, automações, integrações, _actions, _hints

### POST — Executar ação
```bash
curl -s -X POST "$WOLF_API_URL" \
  -H "ngrok-skip-browser-warning: true" \
  -H "Content-Type: application/json" \
  -d '{"action": "ACTION_NAME", "payload": {...}}'
```

> Nota: Sem autenticação Bearer necessária. Rate limit: 30 req/min.

### Ações disponíveis

| Ação | Payload | Quando usar |
|------|---------|-------------|
| `create_alert` | `{"type":"red\|amber\|yellow\|cyan","message":"..."}` | Gabi detecta overspend; Luna detecta crise; Sage detecta queda de ranking |
| `resolve_alert` | `{"alertId":"..."}` | Problema confirmado como resolvido |
| `create_task` | `{"title","description?","priority?","assignee?","clientName?"}` | Nova entrega identificada; ação de marketing aprovada |
| `update_task` | `{"taskId","status?","priority?","assignee?"}` | Atualizar progresso. Status: standby, briefing, working, review, done |
| `send_recommendation` | `{"title","details","priority?","category?"}` | Alfred envia inteligência para W.O.L.F. agir |
| `send_whatsapp` | `{"number":"5573...","text":"mensagem"}` | Enviar mensagem WhatsApp via W.O.L.F. |

---

## Protocolo de Leitura (GET)

```
WOLF_READ_PROTOCOL:

  1. Busca snapshot completo via GET
  2. Extrai seções relevantes para a tarefa atual
  3. Identifica automaticamente:
     → team.members com load > 85% → não atribuir tarefas a eles
     → alerts.critical > 0 → reportar antes de qualquer outra coisa
     → kanban cards URGENT parados → verificar bloqueio
     → integrations disconnected → mencionar limitação (Gabi/Sage afetados)
     → agents STUCK ou ERROR → intervir

  CACHE: Snapshot válido por 15 minutos na mesma sessão.
  Após 15min ou se há suspeita de mudança: buscar novamente.
```

---

## Protocolo de Escrita (POST)

```
WOLF_WRITE_PROTOCOL:

  ANTES de qualquer POST:
  → Confirmar com usuário se ação tem impacto na equipe
  → Exceção: alertas gerados automaticamente por Gabi/Luna/Sage/Nova
              (não precisam de confirmação — são informativos)

  create_alert:
  → Usar tipo correto:
     red    = bloqueio, SLA violado, crise, overspend > 2x
     amber  = risco, deadline próximo, underperformance
     yellow = atenção suave, tendência negativa
     cyan   = informativo, capacidade normal, conquista

  create_task:
  → Sempre incluir clientName se a tarefa é para um cliente
  → Priority: URGENT (hoje) | HIGH (esta semana) | NORMAL (planejado)
  → Assignee: só se souber quem está disponível (verificar load antes)

  send_recommendation:
  → Alfred envia recomendações estratégicas para o W.O.L.F. agir
  → category: "marketing" | "operacional" | "estratégia" | "dev"
  → Usar quando Nova ou Gabi identificam oportunidade que requer ação da equipe

  update_task:
  → Usar taskId do kanban (pegar via GET antes de atualizar)

  send_whatsapp:
  → Sempre confirmar com usuario antes de enviar (exceto crons automaticos)
  → Numero deve incluir codigo do pais (55) + DDD + numero
  → Formato: "5573999788860" (sem +, sem espacos, sem tracos)
  → Usar nomes da tabela de contatos quando possivel
```

---

## Integrações por Agente

### Gabi usa wolf-ops para:
- `create_alert` (red/amber) quando: ROAS < target, overspend, campanha com erro
- `send_recommendation` quando: oportunidade de otimização identificada
- `create_task` quando: criativo novo aprovado precisa de produção

### Luna usa wolf-ops para:
- `create_alert` (amber/red) quando: menção negativa, crise de reputação
- `create_task` quando: calendário de conteúdo gera demandas de produção
- `send_recommendation` quando: concorrente fez algo que deve ser respondido

### Sage usa wolf-ops para:
- `create_alert` (amber) quando: queda de ranking > 5 posições
- `create_task` quando: brief de conteúdo gerado precisa ser produzido
- `send_recommendation` quando: quick win SEO identificado

### Nova usa wolf-ops para:
- `send_recommendation` quando: insights estratégicos do advisory board
- `create_task` quando: pesquisa demanda ação da equipe
- `create_alert` (cyan) quando: tendência de mercado relevante identificada

### Alfred usa wolf-ops para:
- Todas as ações acima quando orquestrando
- `resolve_alert` quando alerta foi tratado e confirmado
- `update_task` quando usuário confirma que algo foi concluído
- `send_whatsapp` quando precisa enviar mensagem WhatsApp para equipe ou clientes

---

## Contatos WhatsApp — Equipe Wolf

| Nome | Numero |
|------|--------|
| Gabriela | 5573999788860 |
| Mirelli | 5573999778729 |
| Thalita | 5573981381347 |
| Sindy | 5573981391177 |
| Mariana | 5573999423003 |
| Ilana | 5585988400361 |
| Netto | 5573991484716 |

---

## Outputs

### Leitura — Formato de resposta

```
🐺 Wolf Ops — Status W.O.L.F.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👥 Equipe: avg [X]% | ⚠ Sobrecarregados: [NOMES se load>85%]
📋 Kanban: [N] URGENT | [N] HIGH | [N] em andamento
🚨 Alertas: [N] críticos | [N] não resolvidos
🤖 Agentes: [N] ativos / [N] total
🔌 Integrações: [N] desconectadas [LISTA se relevante]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INSIGHT ou AÇÃO RECOMENDADA]
```

### Escrita — Confirmação

```
✅ W.O.L.F. atualizado: [ação executada]
📎 ID: [id retornado se disponível]
```

---

## Activity Log

```
[TIMESTAMP] [WolfOps] AÇÃO: [GET/POST action] | RESULTADO: ok/erro | DETALHE: [resumo]
```

---

*Skill: wolf-ops | Versão: 1.0 | Criado: 2026-03-04*
