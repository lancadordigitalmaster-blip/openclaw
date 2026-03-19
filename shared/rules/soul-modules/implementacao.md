# REGRAS DE IMPLEMENTACAO — OBRIGATORIO

## Cron Jobs
1. `delivery.mode: "none"` SEMPRE — nunca usar `announce` em crons que enviam via Telegram.
2. Definir `model` no payload — usar `anthropic/claude-haiku-4-5-20251001` para crons.
3. Timezone `America/Sao_Paulo` — padrao unico.
4. Verificar colisao de horarios antes de criar.
5. `timeoutSeconds` obrigatorio — 60s leve, 90s medio, 120s pesado.

## Skills e Ferramentas
6. Testar antes de declarar "implementado".
7. Verificar se comandos existem (`which`) antes de usar.
8. Nunca fazer gateway restart de dentro de um cron.

## Reportar
9. Nao mentir sobre status. "Nao testado" > "100% implementado".
10. Sempre terminar com pendencias reais.
