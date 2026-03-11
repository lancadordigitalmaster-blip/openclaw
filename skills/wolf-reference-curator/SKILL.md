# SKILL.md — Wolf Reference Curator

> Curador de referências visuais e de copy para inspiração da equipe Wolf.

## Agent

**Luna** — especialista em social media e tendências visuais.

---

## Description

Busca e cura referências visuais via web search nativo do Alfred.
Pesquisa em Behance, Awwwards, Dribbble, Abduzeedo e outros portais via busca web.

**Nota técnica:** Usa web search nativo — não depende de APIs proprietárias do Behance/Pinterest.

---

## Tools

### reference-curate

Busca e cura referências visuais via web search.

**Parameters:**
- `category`: `branding` | `social_media` | `web_design` | `ui_ux` | `motion` | `fotografia` | `tipografia`
- `style`: Estilo buscado (ex: "minimalista", "bold", "vintage", "dark mode")
- `sector`: Setor/nicho (ex: "saúde", "tech", "moda", "alimentação") — opcional
- `limit`: Quantidade de referências (default: 8, máx: 15)

**Returns:**
```
🌙 REFERÊNCIAS — Luna
━━━━━━━━━━━━━━━━━━━━━━
Categoria: [categoria] | Estilo: [estilo]
[N] referências encontradas

1. [Título do projeto]
   🔗 [URL]
   🏷️ Tags: [tag1, tag2]
   💡 Por que é relevante: [observação breve]

2. [...]
━━━━━━━━━━━━━━━━━━━━━━
✅ Curadoria salva em shared/outputs/[data]/luna/references-[categoria].md
```

---

## Usage

```
"alfred, busca referências de branding minimalista para o setor de saúde"
"luna, 10 referências de social media bold para cliente de moda"
```

---

## Digest Semanal

Todo sábado às 9h, Luna envia automaticamente um digest de referências semanais:
- 5 referências de branding
- 5 referências de social media
- Tendências da semana

---

## Output

Salvo em: `shared/outputs/YYYY-MM-DD/luna/references-[category].md`

---

## Activity Log

```
[TIMESTAMP] [Luna] AÇÃO: reference-curate category=[category] style=[style] | RESULTADO: [N] referências curadas
```

---

*Agente: Luna | Versão: 2.0 | Atualizado: 2026-03-04*
