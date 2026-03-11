# CLAUDE.md — Wolf Agency Workspace

## Contexto

Este workspace pertence a **Wolf Agency**, agencia de marketing digital dirigida por Netto (Wilson Girotto).
O sistema roda em um Mac Mini local com OpenClaw como gateway de IA.

**Alfred** e o orquestrador central — coordena 20 agentes especializados via Telegram e crons.
Toda a logica de identidade e comportamento do Alfred esta em `SOUL.md`.

## Arquitetura

```
OpenClaw Gateway (porta 18789)
  ├── Telegram Bot (@alfredwolf_bot)
  ├── 7 crons LLM ativos + ~30 scripts crontab (jobs.json + crontab)
  ├── 57 skills ativas + 20 agentes (TOOLS.md)
  ├── Wolf Mission Control (Supabase)
  ├── wolf-monitor.sh (bash puro, 30min) + wolf-queue.sh (LLM condicional)
  └── Anthropic API (Sonnet 4.6 primario, Haiku 4.5 crons)
```

## Arquivos principais

| Arquivo | Funcao |
|---------|--------|
| `SOUL.md` | System prompt do Alfred v4.0 — identidade, regras, protocolos |
| `orchestrator/ORCHESTRATOR.md` | Roteamento de mensagens v5.1 |
| `TOOLS.md` | Inventario completo: 57 skills + 20 agentes + 3 plugins |
| `agents/*/SKILL.md` | Skills dos 20 agentes especializados |
| `shared/memory/team.yaml` | Equipe real da Wolf (designers, atendimento) |
| `shared/memory/clients.yaml` | Base de clientes (a preencher) |
| `skills/` | Automacoes e integrações do Alfred |
| `scripts/` | Scripts de suporte (cost-tracker, backup, auto-heal) |

## Modelos LLM (Anthropic-first, atualizado 2026-03-08)

- **Primario:** `anthropic/claude-sonnet-4-6` (Sonnet 4.6) — conversas Telegram
- **Crons:** `anthropic/claude-haiku-4-5-20251001` (Haiku 4.5) — tarefas automaticas
- **Fallbacks:** Haiku 4.5 (Anthropic) → Haiku 4.5 (OpenRouter) → Gemini 2.5 Flash (OpenRouter)
- **Heartbeat:** Haiku 4.5 (Anthropic)
- **Custo estimado:** ~$2.50-5.50/mes (muito abaixo do antigo Ollama Cloud Pro $20/mes)

## Crons

- Config: `~/.openclaw/cron/jobs.json`
- 7 crons LLM ativos + ~30 scripts crontab (sem LLM), todos com `delivery.mode: "none"`
- Crons LLM usam `anthropic/claude-haiku-4-5-20251001` (atualizado 2026-03-08)
- Monitoramento: `wolf-monitor.sh` (bash puro) + `wolf-queue.sh` (LLM condicional)
- Timezone: `America/Sao_Paulo` (unico padrao)
- CLI: `/opt/homebrew/opt/node/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/index.js`
- Restart: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`

## Wolf Mission Control

- Supabase projeto `dqhiafxbljujahmpcdhf` (sa-east-1)
- Dashboard: `wolf-mission-control-final.html` (servido na porta 8765)
- Bridge skill: `skills/wolf-mission-control/SKILL.md`
- REST API: apikey + service key (diferentes!)

## Telegram

- Bot: @alfredwolf_bot (ID: 789352357 = Netto direto)
- Grupo Kaizen: -1003441388244
- Grupo Reports: -1003823242231
- Stale-socket: polling pode travar, restart resolve (offset persistido)

## Regras para Claude Code

1. **Idioma:** Netto comunica em pt-BR
2. **Self-healing autorizado:** se o sistema der problema, corrigir autonomamente
3. **MODO EXTERNO:** quando Netto diz isso, ele NAO esta no Mac — suporte via Telegram
4. **Crons usam Haiku 4.5** — nunca usar modelos sem function calling para crons com tools
5. **delivery.mode: "none"** em todos os crons — evita duplicatas
6. **Nunca expor API keys** em logs ou mensagens
7. **Meta Ads token esta EXPIRADO** — Netto precisa gerar novo
8. **Sessions acumulam:** se Alfred travar, limpar `~/.openclaw/agents/main/sessions/sessions.json` + restart
9. **Ferramenta com falha:** retry 2x → abordagem alternativa → so escalar pro usuario em ultimo caso
10. **skills/_archive/** contem 11 skills arquivadas — nao usar
11. **agents/_archive/** contem agents/editor (superseded por video-editor-pro) e agents/mi (vazio)
12. **Regra de analise pre-implementacao:** antes de implementar QUALQUER mudanca, analisar se melhora o sistema ou se pode causar regressao/quebra. Avaliar impacto, riscos e beneficios. Essa regra e obrigatoria para toda implementacao.
13. **Modo Sono:** rotina de fechamento diario autonomo (00:00-05:00) — ver `skills/modo-sono/` quando implementado
