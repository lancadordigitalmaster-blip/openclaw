# SKILL.md — Wolf Reminders

> Sistema de lembretes proativos para Netto. Nada cai no esquecimento.

## Agent

**Alfred** — gerencia agenda e operações internas.
Usa o sistema de cron nativo do OpenClaw. Não cria sistema próprio de agendamento.

---

## Description

Gerencia lembretes de follow-ups, prazos e compromissos via cron do OpenClaw.
Ao adicionar um lembrete, Alfred agenda no cron existente e notifica via Telegram no horário definido.

---

## Tools

### remind-add

Adiciona um novo lembrete agendado no cron do OpenClaw.

**Parameters:**
- `task`: Descrição do lembrete
- `when`: Quando lembrar — aceita: "amanhã 14h", "em 3 dias", "sexta 10h", "2026-03-10 09:00"
- `priority`: `alta` | `media` | `baixa`
- `client`: Nome do cliente relacionado (opcional — referencia clients.yaml)

**Returns:** Confirmação com ID do lembrete e horário agendado

### remind-list

Lista todos os lembretes pendentes, ordenados por data.

**Returns:** Lista formatada com ID, tarefa, horário e prioridade

### remind-done

Marca lembrete como concluído e remove do cron.

**Parameters:**
- `id`: ID do lembrete

**Returns:** Confirmação de conclusão

---

## Usage

```
"alfred, lembra de ligar pro cliente X amanhã às 14h — alta prioridade"
"alfred, quais são meus lembretes?"
"alfred, conclui o lembrete 003"
```

---

## Client Context

Quando `client` é informado, Alfred consulta `shared/memory/clients.yaml` para enriquecer o contexto do lembrete com dados do cliente (contato, responsável, etc.).

---

## Activity Log

```
[TIMESTAMP] [Alfred] AÇÃO: remind-add "[tarefa]" para [data] | RESULTADO: ok (id: XXX)
[TIMESTAMP] [Alfred] AÇÃO: remind-done id=[id] | RESULTADO: ok
```

---

*Agente: Alfred | Versão: 2.0 | Atualizado: 2026-03-04*
