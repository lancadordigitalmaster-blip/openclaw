# SKILL.md — Wolf Process Docs

> Documenta processos da Wolf em formato SOP. Reduz dependência do Netto.

## Agent

**Alfred** — responsável por documentação e gestão do conhecimento interno.

---

## Description

Transforma descrições verbais ou anotações em SOPs (Standard Operating Procedures) documentados.
Output salvo em `shared/outputs/YYYY-MM-DD/alfred/sop-[nome].md`.

---

## Tools

### process-doc

Documenta um processo no formato SOP Wolf.

**Parameters:**
- `process_name`: Nome do processo (ex: "Onboarding de Cliente", "Criação de Campanha Meta")
- `description`: Descrição do processo — cole diretamente no Telegram ou descreva verbalmente
- `owner`: Responsável pelo processo (ex: "Netto", "Designer", "Gestor de Tráfego")
- `frequency`: Com que frequência é executado (ex: "por novo cliente", "semanal", "mensal")

**Returns:** Documento SOP estruturado completo

---

## Template SOP

```markdown
# SOP — [NOME DO PROCESSO]

**Responsável:** [nome]
**Frequência:** [frequência]
**Tempo estimado:** [X minutos/horas]
**Última atualização:** [data]

## 1. Objetivo
[Para que serve este processo]

## 2. Quando usar
[Gatilho ou condição que dispara o processo]

## 3. Pré-requisitos
- [O que precisa estar pronto antes de começar]

## 4. Passo a Passo
1. [Passo 1]
2. [Passo 2]
...

## 5. Checklist de Qualidade
- [ ] [Item de verificação]

## 6. Recursos Necessários
- [Ferramenta, acesso, template]

## 7. Exceções e Problemas Comuns
- [Situação] → [Como resolver]
```

---

## Usage

```
"alfred, documenta o processo de onboarding de clientes: [descreve o processo]"
"alfred, cria SOP para aprovação de criativos, responsável: designer"
```

---

## Output

Salvo em: `shared/outputs/YYYY-MM-DD/alfred/sop-[process-name-slug].md`

---

## Activity Log

```
[TIMESTAMP] [Alfred] AÇÃO: process-doc "[process_name]" | RESULTADO: ok, salvo em shared/outputs/...
```

---

*Agente: Alfred | Versão: 2.0 | Atualizado: 2026-03-04*
