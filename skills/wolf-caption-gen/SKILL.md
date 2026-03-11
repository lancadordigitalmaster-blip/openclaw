# SKILL.md — Wolf Caption Generator

> Gerador de legendas para posts de redes sociais dos clientes Wolf.

## Agent

**Luna** — especialista em social media e copywriting.

---

## Description

Gera 3 opções de legenda para posts baseadas no tema e objetivo. Cada opção tem um tom diferente.
Antes de gerar, Luna consulta o tom de voz do cliente em `shared/memory/clients.yaml`.

---

## Tools

### caption-gen

Gera legendas para posts.

**Parameters:**
- `theme`: Tema/objetivo do post (ex: "lançamento de produto", "dica de segurança")
- `client`: Nome do cliente (consulta tom de voz em clients.yaml)
- `platform`: `instagram` | `facebook` | `linkedin` | `tiktok` (default: `instagram`)
- `tone`: Tom desejado — `profissional` | `descontraido` | `inspirador` | `urgente` (sobrescreve clients.yaml se informado)
- `cta`: Call to action desejado (ex: "link na bio", "fale conosco", "saiba mais")
- `hashtags`: `sim` | `nao` (default: `sim`)

**Returns:** 3 opções de legenda com:
- Opção A: Tom conforme clients.yaml (ou `tone` informado)
- Opção B: Variação mais emocional/storytelling
- Opção C: Variação mais direta/objetiva
- Hashtags sugeridas (quando habilitado)

---

## Usage

```
"alfred, gera legenda pro post de lançamento do cliente X, CTA: link na bio"
"luna, caption para dica de marketing no instagram, tom profissional"
```

---

## Client Context

Alfred lê `shared/memory/clients.yaml` para buscar:
- `marca.tom_de_voz` do cliente
- `marca.evitar` (palavras/abordagens proibidas)
- Plataformas ativas do cliente

---

## Activity Log

```
[TIMESTAMP] [Luna] AÇÃO: caption-gen cliente=[client] platform=[platform] | RESULTADO: 3 opções geradas
```

---

*Agente: Luna | Versão: 2.0 | Atualizado: 2026-03-04*
