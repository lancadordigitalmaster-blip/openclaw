---
name: "meeting-autopilot"
description: "When the user shares a meeting transcript or notes and wants to extract action items, decisions, follow-ups or create tasks. Triggers: 'meeting autopilot', 'transcrição de reunião', 'resumo da reunião', 'tarefas da reunião', 'action items', 'ata de reunião', 'o que ficou decidido na reunião', 'extrai tarefas dessa reunião'."
---

# Meeting Autopilot — Wolf Agency

Transforma transcrições de reuniões em outputs operacionais. Não é um resumidor — é um operador.

**REGRA CRÍTICA:** Nunca criar tarefas no ClickUp automaticamente. Sempre apresentar o rascunho e perguntar antes de criar qualquer item.

## Inputs aceitos

- Texto colado diretamente no Telegram
- Arquivo `.txt`, `.vtt`, `.srt`
- Transcrição gerada pelo `transcriptapi` (já instalado)

Não faz transcrição de áudio diretamente. Para áudio, usar `transcriptapi` primeiro.

## Fluxo de processamento

**Passo 1 — Receber transcrição**
Aceitar texto colado ou arquivo. Detectar formato automaticamente.

**Passo 2 — Contexto opcional**
Se não informado, perguntar: título da reunião e data (ou derivar do texto).

**Passo 3 — Extração em 3 passes**
- Parse → estrutura o texto bruto
- Extract → identifica decisões, tarefas, dúvidas, pontos em aberto
- Generate → formata outputs

**Passo 4 — Entregar relatório completo**

```
📋 REUNIÃO — [Título] | [Data]
━━━━━━━━━━━━━━━━━━━━━━

✅ DECISÕES:
• [decisão] — motivo: [contexto]

📌 TAREFAS:
| Tarefa | Responsável | Prazo | Status |
|--------|-------------|-------|--------|
| ...    | ...         | ...   | Aberta |

❓ PERGUNTAS EM ABERTO:
• [questão não resolvida]

🗂 PARKING LOT:
• [tópico para próxima reunião]

📧 RASCUNHO DE E-MAIL (pronto para enviar):
Assunto: [Alinhamentos — reunião [data]]
[corpo do e-mail]

🎯 TAREFAS PARA CLICKUP (aguardando confirmação):
• "[nome da tarefa]" → lista: [sugestão] — confirmar antes de criar
```

**Passo 5 — Perguntar sobre ClickUp**
Após entregar o relatório, perguntar: "Deseja criar essas tarefas no ClickUp? Posso ajustar responsáveis, prazos ou listas antes."

Só criar após confirmação explícita.

## Uso no Telegram

- `"meeting autopilot — reunião com [Cliente] [data]"` + cola transcrição
- `"extrai tarefas dessa reunião: [texto]"`
- `"ata da reunião de hoje: [texto]"`

## Integração com transcriptapi

Para reuniões gravadas em áudio/vídeo:
1. `"transcreve esse áudio"` → transcriptapi gera o texto
2. `"meeting autopilot"` + cola a transcrição gerada

## Histórico

Outputs salvos em `shared/memory/meetings/[data]-[slug].md` para referência futura.
