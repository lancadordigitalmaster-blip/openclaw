---
name: wolf-coding-loop
description: >
  Autonomous overnight coding loop for Wolf Agency workspace.
  Read QUEUE.md, execute pending tasks one by one, run tests,
  commit locally, and send a Telegram report when done.
  Activate when message contains: "start coding loop", "roda o loop",
  "processa a fila", or when the nightly cron fires.
---

# Wolf Coding Loop

## Contexto
Alfred executa tarefas de desenvolvimento de forma autônoma enquanto o
usuário dorme. Todas as operações ficam **restritas ao workspace local**.
Nenhum push para remote é feito sem aprovação humana explícita.

## Fonte de Tarefas

Arquivo: `~/workspace/tasks/QUEUE.md`

### Formato esperado de cada task:

```markdown
## TASK-001 [ PENDING ]
Target: workspace/agents/alfred/
Goal: Adicionar retry logic no wolf-tool-fallback.sh quando API retorna 429
Tests: bash workspace/scripts/wolf-tool-fallback.sh --test
Commit: yes
Max iterations: 10
```

**Status válidos:** `PENDING` | `IN_PROGRESS` | `DONE` | `FAILED` | `BLOCKED`

## Protocolo de Execução

1. Ler `workspace/tasks/QUEUE.md`
2. Encontrar a primeira task com status `PENDING`
3. Marcar como `IN_PROGRESS` no arquivo
4. Ler os arquivos do `Target` indicado
5. Implementar o `Goal` descrito
6. Executar o comando em `Tests`
7. Se testes passarem:
   - `git add <arquivos modificados>`
   - `git commit -m "wolf-loop: TASK-XXX: [descrição curta]"`
   - Marcar como `DONE`
   - Avançar para próxima task `PENDING`
8. Se testes falharem:
   - Analisar o erro e tentar corrigir
   - Repetir até atingir `Max iterations`
   - Se ainda falhar: marcar como `FAILED`, registrar o último erro, avançar
9. Ao processar todas as tasks: enviar relatório via Telegram

## Regras de Segurança — NÃO NEGOCIÁVEL

| Ação | Permitido |
|---|---|
| Ler arquivos em `~/workspace/` | ✅ Sim |
| Modificar arquivos em `~/workspace/` | ✅ Sim |
| Executar testes definidos na task | ✅ Sim |
| `git add` e `git commit` local | ✅ Sim |
| `git push` para remote | ❌ Nunca |
| Modificar `~/.openclaw/.env` | ❌ Nunca |
| Modificar `~/.openclaw/openclaw.json` | ❌ Nunca |
| Tocar arquivos fora de `~/workspace/` | ❌ Nunca |
| Comandos destrutivos (`rm -rf`, etc.) | ❌ Nunca |
| Operações em banco de dados em produção | ❌ Nunca |
| Runtime total > 4 horas | ❌ Parar e reportar |

Se em dúvida sobre qualquer ação: marcar task como `BLOCKED`, descrever a dúvida, avançar para próxima.

## Formato do Relatório Telegram

Enviar ao final de todas as tasks (ou ao atingir limite de 4h):

```
🌙 Wolf Coding Loop — [DIA DD/MM/YYYY]

✅ DONE: [N] tasks
  → TASK-001: [descrição] | commit: [hash curto]
  → TASK-002: [descrição] | commit: [hash curto]

⚠️ FAILED: [N] tasks
  → TASK-003: testes falharam após [N] iterações
     último erro: [mensagem de erro]
     arquivo: [caminho:linha]

⏭ BLOCKED: [N] tasks
  → TASK-004: [razão do bloqueio — precisa de decisão humana]

⏩ SKIPPED: [N] tasks (status não era PENDING)

🕐 Runtime: [X]h [Y]min
📝 [N] commits locais — push manual necessário
💰 Custo estimado: ~$[X.XX]
```

## Teste Manual

```bash
# Rodar imediatamente sem esperar o cron
openclaw cron run <job-id>

# Ou enviar direto pelo Telegram:
# "Alfred, roda o coding loop agora"
```

## Boas Práticas para Escrever Tasks

- **Goal deve ser específico** — quanto mais claro, menos iterações
- **Tests devem ser executáveis** — sempre um comando que retorna 0 para sucesso
- **Max iterations conservador** — comece com 10, ajuste conforme experiência
- **Uma responsabilidade por task** — tasks grandes falham mais
- **Nunca colocar tasks que dependem de decisões** — essas vão para BLOCKED
