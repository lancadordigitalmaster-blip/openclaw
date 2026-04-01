---
name: video-editor-pro
description: Editor Sênior Master com padrão de estúdio. Especialista em VSL, Reels, Stories, Motion Graphics e Sound Design. Domina Premiere Pro, After Effects e Remotion. Use para especificação técnica, revisão de qualidade, e orientação de edição profissional.
---

# Video Editor Pro — Wolf Agency

Agente editor com padrão de estúdio para VSL, Reels, Stories e motion graphics.

## Capacidades

- **VSL:** Estrutura de conversão, proof-pack, ritmo, CTA
- **Reels/Stories:** Hook 0–2s, legibilidade mobile, pattern interrupts
- **Motion:** Kinetic typography, callouts, lower thirds
- **Sound Design:** Mix profissional, EQ, compressão
- **QC:** Scorecards de revisão, checklists técnicos

## Comandos

```bash
# Análise de vídeo
./agents/video-editor-pro/analyze.sh [arquivo]

# Scorecard de revisão
./agents/video-editor-pro/scorecard.sh [tipo]

# Gerar especificação
./agents/video-editor-pro/spec.sh [formato] [objetivo]
```

## Workflows

| Formato | Arquivo de Referência |
|---------|----------------------|
| VSL | `references/vsl-playbook.md` |
| Reels/Stories | `references/reels-stories-playbook.md` |
| QC/Revisão | `references/qc-scorecards.md` |
| Export | `references/export-presets.md` |
| Áudio | `references/sound-design-guide.md` |

## Integração Alfred

Mencione no Telegram:
- "revisar vídeo" → Aplica scorecard
- "especificar VSL" → Gera plano de edição
- "score Reels" → Checklist de qualidade

## Estrutura

```
agents/video-editor-pro/
├── SKILL.md
├── references/
│   ├── vsl-playbook.md
│   ├── reels-stories-playbook.md
│   ├── qc-scorecards.md
│   ├── export-presets.md
│   └── sound-design-guide.md
└── scripts/ (opcional)
    └── remotion/
```

---

*Video Editor Pro v1.0 — Wolf Agency*
