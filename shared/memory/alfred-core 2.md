# Alfred Core — Estado Operacional
# Atualizado: 2026-03-08 23:00 BRT (heartbeat noturno sab)

---

## Quem e Alfred

Orquestrador central da Wolf Agency. Coordena 20 agentes (5 marketing + 14 dev + 1 ops).
Opera via Telegram (@alfredwolf_bot) e OpenClaw gateway local.
Modelo primario: kimi-k2.5 (Ollama Cloud Pro).

---

## Estado dos Sistemas

| Sistema | Status | Nota |
|---------|--------|------|
| Gateway OpenClaw | Operacional | PID ativo, porta 18789 |
| Telegram Bot | Operacional | Polling ativo |
| Ollama Cloud | Operacional | Plano Pro, kimi-k2.5 |
| Web Search | Operacional | Provider: gemini |
| Wolf Mission Control | Operacional | Supabase sa-east-1 |
| W.O.L.F. Webhook | INATIVO | ngrok removido, aguardando Cloudflare Tunnel |
| Meta Ads | Bloqueado | Token expirado |
| Moonshot/Kimi (web_search) | Suspenso | Saldo insuficiente — migrado para Gemini |

---

## Projetos Ativos

| Projeto | Cliente | Status | Responsavel | Proximo Passo |
|---------|---------|--------|-------------|---------------|
| Wolf Mission Control | Wolf Agency | Operacional | Alfred | Monitorar edge functions |
| Meta Ads Integration | Wolf Agency | Bloqueado | Netto | Renovar token expirado |
| Webhook W.O.L.F. | Wolf Agency | INATIVO | Alfred | Aguardando Cloudflare Tunnel |

---

## Decisoes Recentes

| Data | Decisao | Impacto |
|------|---------|---------|
| 2026-03-07 | Skills cleanup: 11 arquivadas, 69 ativas, TOOLS.md reescrito | Inventario limpo e atualizado |
| 2026-03-07 | Agents cleanup: mi/nova/sage/titan stubs removidos, editor arquivado | Dirs orfaos eliminados |
| 2026-03-07 | SOUL.md reescrito v2.1 (~10K chars) | Cabe no limite de 20K dos crons |
| 2026-03-07 | web_search migrado para Gemini | Kimi suspenso por saldo |
| 2026-03-07 | YouTube Monitor: IDs corrigidos + web_fetch | Sem dependencia de web_search |
| 2026-03-06 | Todos crons migrados para kimi-k2.5 | Modelos anteriores nao suportavam tools |
| 2026-03-05 | delivery.mode: none em todos crons | Evitar duplicatas no Telegram |
| 2026-03-05 | Rex renomeado para Gabi | Agente de trafego com nome proprio |

---

## Grupos Telegram

| ID | Nome | Proposito | Agente | Desde |
|----|------|-----------|--------|-------|
| 789352357 | Netto (DM) | Canal direto com o dono | Alfred | 2026-03-04 |
| -1003441388244 | Wolf Kaizen | Operacional | Alfred | 2026-03-04 |
| -1003823242231 | Wolf Reports | Relatorios | Alfred | 2026-03-04 |
| -5162116276 | A identificar | — | Alfred | — |
| -5245811611 | A identificar | — | Alfred | — |
| -5086938074 | A identificar | — | Alfred | — |

---

## Pendencias

- Token Meta Ads expirado — Netto precisa gerar novo
- Preencher shared/memory/clients.yaml com clientes reais
- 2 crons com timeout recorrente:
  * Check Diário - Wolf (3 erros, disabled)
  * ClickUp — Alertas Diarios (1 erro, disabled)
  → Investigar: scripts valem a pena ou substituir por comando direto?
- Investigar limite de comandos Telegram (setMyCommands)

## Status Sábado 8 Março

✓ Boot-context atualizado: 29 crons ativos, 2 com erro
✓ TOOLS.md data atualizada
✓ Docs consistency check OK
✓ Sessions.json: 2214 linhas (OK, <5000)
✓ Gateway: respondendo
✓ Nenhum arquivo crítico danificado

**Saude geral: VERDE** — Sistema operacional, 2 anomalias menores (crons timeout = disabled anyway)
