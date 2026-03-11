# SKILL.md — Wolf Quality Check

> Checklist de SAÍDA — revisa entregas antes de ir para o cliente.

## Agent

**Alfred** — gatekeeper de qualidade. Nada sai da Wolf sem passar por este checklist.

---

## Description

Revisa entregas da Wolf antes de irem para o cliente. Verifica marca, qualidade técnica, textos, CTA e consistência com o brief.

**Distinção importante:**
- `wolf-briefing-monitor` = checklist de **ENTRADA** (o cliente nos deu informação suficiente?)
- `wolf-quality-check` = checklist de **SAÍDA** (o que vamos entregar ao cliente está ok?)

---

## Tools

### wolf-check

Revisa qualidade de uma entrega antes de enviar ao cliente.

**Parameters:**
- `content`: Descrição da entrega ou URL/arquivo (imagem enviada no Telegram)
- `client`: Nome do cliente (referencia clients.yaml para identidade de marca)
- `project_type`: `social_media` | `trafego_pago` | `branding` | `site` | `video` | `campanha`
- `brief_ref`: Referência ao briefing original (opcional)

**Returns:** Relatório de qualidade com pass/fail por critério e sugestões de melhoria

---

## Checklist de Qualidade

1. ✅ Identidade visual do cliente respeitada (cores, fontes, logo)
2. ✅ Dados do cliente corretos (nome, contato, valores)
3. ✅ Qualidade técnica adequada (resolução, formato)
4. ✅ Textos sem erros ortográficos
5. ✅ CTA (call to action) claro e presente
6. ✅ Consistente com a identidade da marca
7. ✅ Todos os requisitos do brief atendidos
8. ✅ Aprovado internamente antes de enviar ao cliente

---

## Rules

- NEVER approve without human final review
- ALWAYS flag potential issues, even minor ones
- Suggest improvements when applicable
- If score < 6/8, block delivery and request revision

---

## Usage

```
"alfred, faz o QA dessa entrega para o Cliente X: [descreve ou envia imagem]"
"alfred, wolf-check projeto branding Cliente Y"
```

---

## Client Context

Alfred lê `shared/memory/clients.yaml` para buscar:
- `marca` (cores, fontes, tom de voz, evitar)
- Histórico de alertas em `shared/memory/alerts.yaml`

---

## Activity Log

```
[TIMESTAMP] [Alfred] AÇÃO: wolf-check cliente=[client] tipo=[project_type] | RESULTADO: score=[X/8], status=aprovado/reprovado
```

---

*Agente: Alfred | Versão: 2.0 | Atualizado: 2026-03-04*
