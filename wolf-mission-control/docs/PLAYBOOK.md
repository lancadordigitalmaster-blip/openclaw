# Playbook Operacional — Wolf Mission Control v1.0
# Criado: 2026-03-05

---

## Ciclo de Vida de uma Missão

```
inbox → assigned → in_progress → done
                             → handoff (gera missão filha)
                             → blocked (erro ou crítico)
              → cancelled
```

| Status | Quem define | Quando |
|--------|-------------|--------|
| `inbox` | Sistema | Missão criada mas sem agente |
| `assigned` | Alfred | Agente escolhido, trigger disparado |
| `in_progress` | Edge Function | Agente começou a executar |
| `done` | Quality Gate | Output aprovado (score ≥ 0.65) |
| `handoff` | Agente | Output gerou sinal para outro agente |
| `blocked` | Agente ou sistema | Erro, falta de contexto, timeout 30min |
| `cancelled` | Netto via Telegram | Missão cancelada manualmente |

---

## Níveis de Escalação

| Nível | Trigger | Ação | Notificação |
|-------|---------|------|-------------|
| L1 | Missão parada > 30min | Recheck automático | Log interno |
| L2 | Quality gate falha 2× | Escala para Alfred revisar | Telegram (aviso) |
| L3 | Quality gate falha 3× | Para execução, envia 3 outputs para Netto decidir | Telegram (urgente) |
| L4 | Agente em erro crítico, SLA violado | Pausa o agente, notifica Netto | Telegram (🚨) |

---

## Catálogo de Handoffs

| Signal Type | De | Para | Quando usar |
|------------|-----|------|-------------|
| `hook_fix` | Gabi | Luna | CTR < 1% — criativo precisa novo hook |
| `boost_candidate` | Gabi | Luna | Post orgânico com alta engajamento → turbinar |
| `copy_review` | Gabi | Luna | Copy do ad precisa ajuste de tom |
| `seo_angle` | Sage | Luna | Keyword com oportunidade → criar artigo |
| `content_brief` | Sage | Luna | Brief completo para artigo de pilar |
| `deploy_done` | Forge/Pixel | Titan | Deploy concluído → tech lead valida |
| `security_issue` | Shield | Titan | Vulnerabilidade encontrada → decisão técnica |
| `task_created` | Atlas | Echo | Nova tarefa no ClickUp → notificar cliente |
| `client_update` | Echo | Atlas | Cliente respondeu → atualizar status no ClickUp |
| `automation_ready` | Flux | Forge | N8N workflow pronto → integrar com backend |
| `market_signal` | Nova | Gabi | Tendência identificada → testar em ads |
| `competitor_move` | Nova | Luna | Concorrente mudou posicionamento → revisar copy |

---

## Glossário

| Termo | Definição |
|-------|-----------|
| Missão | Unidade de trabalho atribuída a um agente com objetivo claro |
| Handoff | Sinal estruturado de um agente para outro (`[SIGNALS]...[/SIGNALS]`) |
| Quality Gate | Avaliação automática do output em 4 dimensões (score 0-1) |
| Squad | Grupo de agentes por área: Core, Marketing, Dev, Ops |
| system_prompt | Instrução completa que define o comportamento de um agente |
| Escalação | Alerta que requer atenção humana (Netto) |
| pg_cron | Jobs agendados no PostgreSQL (cleanup, relatórios, checks) |
| Realtime | Subscriptions do Supabase para updates ao vivo no dashboard |
| SOUL.md | Documento de identidade da Wolf Agency (tom, valores, posicionamento) |
| priority_score | Nota 0-1 calculada por urgência × impacto financeiro × deadline |

---

## Troubleshooting

### Missão travada em `in_progress`

1. Verificar `system_logs` por erros da edge function
2. Checar se `GOOGLE_API_KEY` ou `ANTHROPIC_API_KEY` está configurada no Supabase secrets
3. Se agente sem resposta > 30min → `recheck_stale_missions()` deve ter atuado para `blocked`
4. Atualizar manualmente: `UPDATE missions SET status = 'inbox' WHERE id = '...'`

### Quality gate reprovando muito

1. Ver `QUALITY_GATE.md` → seção de thresholds
2. Comparar output real com casos de teste
3. Adicionar instrução específica no system prompt do agente
4. Rodar migration de UPDATE no Supabase SQL Editor

### Telegram não recebendo mensagens

1. Verificar `TELEGRAM_BOT_TOKEN` nos secrets da Edge Function
2. Verificar `NETTO_TELEGRAM_ID` (deve ser `789352357`)
3. Checar `system_logs` com `source = 'telegram-notifier'`
4. Testar curl: `curl -s "https://api.telegram.org/bot{TOKEN}/getMe"`

### Escalações acumulando sem resolução

1. Ir em Supabase → Table Editor → escalations
2. Filtrar por `resolved_at IS NULL`
3. Para resolver: `UPDATE escalations SET resolved_at = NOW(), resolved_by = 'netto' WHERE id = '...'`

---

## Comandos Telegram para Netto

| Comando | Ação |
|---------|------|
| `/missao [descrição]` | Cria nova missão via alfred-router |
| `/status` | Status geral do sistema (agentes + missões abertas) |
| `/decidir [mission_id] [approve\|reject]` | Decide sobre missão escalada (L3) |
| `/agentes` | Lista todos os agentes com status atual |

---

## Checklist de Deploy (Novo Ambiente)

- [ ] Criar projeto Supabase
- [ ] Executar migrations 001 a 009 na ordem, no SQL Editor
- [ ] Configurar secrets da Edge Function (GOOGLE_API_KEY, TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, NETTO_TELEGRAM_ID)
- [ ] Deploy das edge functions: trigger-mission, telegram-notifier
- [ ] Configurar webhook do Telegram: `setWebhook` para alfred-router URL
- [ ] Testar com `/status` no Telegram
- [ ] Verificar Realtime no dashboard (deve mostrar missões ao vivo)
- [ ] Rodar SQL de benchmark e confirmar que agentes aparecem como "✅ Saudável" (sem missões = OK)

---

*Wolf Mission Control · Playbook v1.0 · 2026-03-05*
