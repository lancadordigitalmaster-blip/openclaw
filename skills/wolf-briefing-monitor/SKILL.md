# SKILL.md — Wolf Briefing Monitor

> Checklist de ENTRADA — valida briefings antes de ir para a equipe.

## Agent

**Alfred** — gatekeeper operacional. Garante que nenhum briefing incompleto chegue à equipe.

---

## Description

Analisa briefings de clientes antes de serem repassados para a equipe interna.
Identifica gaps, informações faltantes e gera perguntas para o cliente.

**Distinção importante:**
- `wolf-briefing-monitor` = checklist de **ENTRADA** (o cliente nos deu informação suficiente?)
- `wolf-quality-check` = checklist de **SAÍDA** (o que vamos entregar ao cliente está ok?)

---

## Tools

### briefing-check

Analisa um briefing e identifica gaps.

**Parameters:**
- `content`: Texto do briefing (colado no Telegram) ou descrição do projeto
- `client`: Nome do cliente (referencia clients.yaml para contexto de marca)
- `project_type`: `social_media` | `trafego_pago` | `branding` | `site` | `video` | `campanha`

**Returns:**
```
🎩 ANÁLISE DE BRIEFING
━━━━━━━━━━━━━━━━━━━━━━
Cliente: [nome]
Projeto: [tipo]

✅ INFORMAÇÕES PRESENTES:
- [item ok]

❌ GAPS IDENTIFICADOS:
- [item faltando] → Pergunta sugerida: "[pergunta para o cliente]"

⚠️ PONTOS DE ATENÇÃO:
- [ambiguidade ou risco]

📋 SCORE: [X/8 itens completos]
━━━━━━━━━━━━━━━━━━━━━━
✅ Feito: análise concluída
📋 Pendente: [N] itens para confirmar com o cliente
```

---

## Checklist de Briefing

1. Objetivo claro do projeto
2. Público-alvo definido
3. Entregáveis especificados
4. Prazo definido
5. Orçamento/valores (quando aplicável)
6. Referências fornecidas
7. Informações de contato do responsável
8. Tom de voz / identidade da marca

---

## Usage

```
"alfred, checa esse briefing: [cola o texto]"
"alfred, briefing-check para projeto de social media do Cliente X"
```

---

## Activity Log

```
[TIMESTAMP] [Alfred] AÇÃO: briefing-check cliente=[client] tipo=[project_type] | RESULTADO: score=[X/8], gaps=[N]
```

---

*Agente: Alfred | Versão: 2.0 | Atualizado: 2026-03-04*
