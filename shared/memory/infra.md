# Infraestrutura Wolf Agency — OpenClaw

## Gateway
- **Plataforma:** Mac Mini local
- **Porta:** 18789
- **LaunchAgent:** ai.openclaw.gateway
- **Restart:** `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`

## W.O.L.F. API
- **Status:** INATIVO — ngrok removido do sistema
- **URL no .env:** comentada (limpa em 2026-03-07)
- **Webhook receiver:** porta 18790 (LaunchAgent ai.openclaw.wolf-webhook) — pode ser desativado
- **Proxima acao:** Migrar para Cloudflare Tunnel quando Netto decidir
  - Requer: conta Cloudflare + dominio proprio
  - Comando: `brew install cloudflare/cloudflare/cloudflared`

## Plugins
- **telegram:** ativo, funcional
- **lobster:** habilitado mas sem atividade nos logs — provavelmente plugin interno do OpenClaw (nao interfere)
- **llm-task:** ativo, spawn de subagentes

## Providers sem API Key (catalogados mas inativos)
- **xAI (Grok 4 Fast):** `XAI_API_KEY=sua_key_aqui` — nao funcional
- **MiniMax (M2.5):** `MINIMAX_API_KEY=sua_key_aqui` — nao funcional
- Nenhum cron ou fallback usa esses providers — impacto zero
- Acao: Netto pode gerar keys quando quiser usar esses modelos

## Notas
- Atualizado: 2026-03-07
