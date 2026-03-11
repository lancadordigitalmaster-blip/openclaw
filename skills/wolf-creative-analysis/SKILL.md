# SKILL.md — Wolf Creative Analysis

> Análise de criativos antes de publicação ou aprovação do cliente.

## Agent

**Luna** — especialista em social media e análise visual.

---

## Description

Revisa criativos (imagens, vídeos, carrosséis) antes de irem para aprovação do cliente ou publicação.

**Como enviar o criativo via Telegram:**
1. Envie a imagem/vídeo diretamente no chat com Alfred
2. Na legenda, escreva: "analisa esse criativo — plataforma: instagram — objetivo: engajamento — cliente: X"
3. Alfred aciona Luna para análise

---

## Tools

### creative-check

Analisa criativo enviado via Telegram.

**Parameters:**
- `platform`: `instagram` | `facebook` | `stories` | `reels` | `youtube` | `tiktok`
- `objective`: `engajamento` | `conversao` | `branding` | `trafego`
- `client`: Nome do cliente (referencia clients.yaml para identidade de marca)
- `context`: Contexto adicional sobre o criativo (opcional)

**Returns:**
```
🌙 ANÁLISE DE CRIATIVO — Luna
━━━━━━━━━━━━━━━━━━━━━━
Cliente: [nome]
Plataforma: [plataforma]
Objetivo: [objetivo]

✅ PONTOS FORTES:
- [ponto positivo]

⚠️ SUGESTÕES DE MELHORIA:
- [sugestão específica]

❌ PROBLEMAS CRÍTICOS:
- [problema que deve ser corrigido antes da publicação]

📊 CHECKLIST:
- CTA visível: ✅/❌
- Marca/logo presente: ✅/❌
- Texto legível: ✅/❌
- Cores da marca: ✅/❌
- Tamanho adequado para [plataforma]: ✅/❌
- Tom de voz consistente: ✅/❌

🎯 RECOMENDAÇÃO: Aprovado / Revisar / Reprovar
━━━━━━━━━━━━━━━━━━━━━━
```

---

## Usage

```
[Envia imagem no Telegram] + "analisa esse criativo — instagram — engajamento — cliente: X"
"alfred, análise criativa do stories que mandei, cliente Y"
```

---

## Client Context

Luna lê `shared/memory/clients.yaml` para:
- Cores e fontes da marca do cliente
- Tom de voz definido
- Itens a evitar

---

## Activity Log

```
[TIMESTAMP] [Luna] AÇÃO: creative-check cliente=[client] plataforma=[platform] | RESULTADO: aprovado/revisão/reprovado
```

---

*Agente: Luna | Versão: 2.0 | Atualizado: 2026-03-04*
