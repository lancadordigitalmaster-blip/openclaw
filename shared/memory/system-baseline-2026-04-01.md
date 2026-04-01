# Baseline pos-auditoria
# Data: 2026-04-01 BRT

---

## Auditoria Completa Realizada

Auditoria de ponta a ponta do sistema OpenClaw/Wolf Agency. Resultado:
- Merge conflicts resolvidos (SOUL.md, ORCHESTRATOR.md)
- API autenticada (WOLF_API_KEY, ADMIN_SECRET forte)
- Rate limiting implementado
- CORS restritivo com whitelist
- Edge Functions migradas de OpenRouter para Anthropic direto
- Codigo morto removido (archives + stubs dormentes)
- Modulos compartilhados criados (_lib/)

## Estado dos Modelos LLM

- **Primario:** claude-sonnet-4-6 (conversas Telegram)
- **Crons:** claude-haiku-4-5-20251001 (tarefas automaticas)
- **Edge Functions (WMC):** claude-haiku-4-5-20251001 (Anthropic direto)
- **Fallback:** Haiku 4.5 (Anthropic) → Gemini 2.5 Flash (OpenRouter)
- OpenRouter removido como dependencia das Edge Functions

## Estado das Skills

- **58 skills ativas** em `skills/`
- **0 skills arquivadas** (diretorio `_archive/` removido)
- 19 stubs dormentes sem codigo removidos
- Duplicatas consolidadas (meta-ads-manager, meta-ads-report removidos)

## Estado da API (Vercel)

- 7 endpoints: health, proposal, proposta, parse-proposal, update-proposal, track-view, admin
- Autenticacao: x-api-key (parse/update), x-admin-key (admin)
- Rate limiting: parse-proposal 5/min, track-view 30/min
- CORS: whitelist configuravel (ALLOWED_ORIGINS)
- Modulos: supabase-client, slug-utils, rate-limit, cors
- Auto-prune de system_logs > 7 dias

## Estado das Edge Functions (WMC)

- 5 funcoes deployed: trigger-mission, quality-gate, alfred-router, memory-writer, telegram-notifier
- Todas usando Anthropic API direto (sem OpenRouter)
- Quality gate threshold: 0.65 (65%)
- Max revisoes automaticas: 2

## Estado dos Agentes

- **20 agentes ativos** em `agents/`
- UUIDs completos para todos os 22 agentes no wolf-mission-control
- Sem archives (limpos)

## Env Vars Configuradas (Vercel)

- ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
- WOLF_API_KEY (novo), ADMIN_SECRET (novo, forte)
- PROPOSAL_BASE_URL, OPENROUTER_API_KEY, TELEGRAM_BOT_TOKEN

## Pendencias

- Renovar token Meta Ads (Marcos) — expirado
- Configurar Evolution API (WhatsApp) — credenciais pendentes
- Figma token — expirado
- Testes automatizados — em implementacao

---

Proximo review: apos implementacao de testes
