# Baseline pos-consolidacao
# Data: 2026-03-07 23:30 BRT

---

## Estado dos Crons

- **22 ativos** (todos testados e funcionando)
- **2 disabled** (YouTube Monitor, Organizacao de Fundo)
- **0 NEVER** (todos os 12 que eram NEVER foram corrigidos)
- Cron orfao `agente-cut-edicao` removido
- Timeouts ajustados: Watchdog 180s, ClickUp 120s, Consolidacao 300s
- Novo cron: Wolf Atualizacao Diaria de Docs (23h)

## Estado das Skills

- **69 skills ativas** em `skills/`
  - 22 Wolf Agency operacao
  - 8 Wolf ferramentas
  - 22 plataforma OpenClaw
  - 11 marketing e criacao
  - 6 utilidades
- **11 skills arquivadas** em `skills/_archive/`
  - 4 formato antigo (agente-*)
  - 3 duplicatas (video-editor-pro, wolf-facebook-ads, knowledge-traffic)
  - 4 quebradas/genericas (wolf-coding-loop, self-reflection, auto-updater, clawddocs)

## Estado dos Agentes

- **20 agentes ativos** em `agents/`
  - 5 marketing: Gabi, Luna (social), Sage (seo), Nova (strategy), Editor (video-editor-pro)
  - 14 dev: Titan, Pixel, Forge, Vega, Shield, Atlas, Bridge, Craft, Echo, Flux, Iris, Ops, Quill, Turbo
  - 1 ops: Natiely
- **2 arquivados** em `agents/_archive/`
  - editor (superseded por video-editor-pro)
  - mi (vazio, descontinuado)
- **3 stubs vazios removidos**: nova/, sage/, titan/ (reais em strategy/, seo/, dev/titan/)

## Estado da Memoria

- `memory/` = cerebro privado do Alfred (38 arquivos)
- `shared/memory/` = dados compartilhados (15 arquivos)
- Symlinks ativos: activity.log, alfred-core.md, clients.md
- SOUL.md e BOOT.md atualizados com paths explicitos

## Estado do Gateway

- PID: ativo (porta 18789)
- Modelo: kimi-k2.5 (Ollama Cloud Pro)
- Telegram: operacional (polling)
- Auto-heal: LaunchAgent a cada 5min (4 checks)
- Sessions: 3 keys (saudavel)

## Documentacao Atualizada

- CLAUDE.md: 20 agentes, 22 crons, 69 skills, regras de retry
- TOOLS.md: inventario completo reescrito
- alfred-core.md: decisoes e pendencias atualizadas
- BOOT.md: paths corrigidos, Rex->Gabi
- ORCHESTRATOR.md: Rex->Gabi em 6 pontos

## Pendencias (do usuario)

- Token Meta Ads expirado — Netto precisa gerar novo
- Preencher shared/memory/clients.yaml com clientes reais

## Sistemas Inativos

- W.O.L.F. Webhook: ngrok removido, aguardando Cloudflare Tunnel
- Meta Ads: token expirado
- YouTube Monitor: cron disabled

---

Ultimo health check: OK
Proximo review: apos primeira semana de uso
