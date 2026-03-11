# SKILL.md — Wolf Meeting Summary

> Transforma anotações ou transcrições de reuniões em resumos estruturados.

## Agent

**Alfred** — responsável por operações administrativas e documentação.

---

## Description

Recebe anotações ou transcrição de reunião (colada no chat do Telegram) e gera um resumo estruturado com decisões, próximos passos e responsáveis.
Output salvo automaticamente em `shared/outputs/YYYY-MM-DD/alfred/`.

---

## Tools

### meeting-summary

Gera resumo estruturado de reunião.

**Parameters:**
- `content`: Texto com notas ou transcrição (colado diretamente no Telegram)
- `participants`: Lista de participantes (ex: "Netto, Maria, João do Cliente X")
- `client`: Nome do cliente relacionado (opcional — referencia clients.yaml)
- `meeting_type`: `interna` | `cliente` | `fornecedor` (default: `cliente`)

**Returns:**
```
🎩 RESUMO DE REUNIÃO
━━━━━━━━━━━━━━━━━━━━━━
📅 Data: [inferida ou hoje]
👥 Participantes: [lista]
🏢 Contexto: [cliente/projeto]

📌 DECISÕES TOMADAS:
1. [Decisão]

⏭️ PRÓXIMOS PASSOS:
| Ação | Responsável | Prazo |
|------|------------|-------|

❓ PONTOS EM ABERTO:
- [Item sem decisão]
━━━━━━━━━━━━━━━━━━━━━━
✅ Feito: resumo salvo em shared/outputs/[data]/alfred/
```

---

## Usage

```
"alfred, resume essa reunião: [cola o texto]"
"alfred, meeting summary — participantes: Netto e João, cliente: Empresa X"
```

---

## Client Context

Quando `client` é informado, Alfred consulta `shared/memory/clients.yaml` para enriquecer o contexto.

---

## Output

Salvo em: `shared/outputs/YYYY-MM-DD/alfred/meeting-[timestamp].md`

---

## Activity Log

```
[TIMESTAMP] [Alfred] AÇÃO: meeting-summary cliente=[client] | RESULTADO: ok, salvo em shared/outputs/...
```

---

*Agente: Alfred | Versão: 2.0 | Atualizado: 2026-03-04*
