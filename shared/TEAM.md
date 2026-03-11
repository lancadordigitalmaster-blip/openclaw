# TEAM.md — Registry de Agentes

> Quem faz o quê no time de agentes da Wolf

---

## 🎯 Estrutura do Time

```
Gateway (1 servidor OpenClaw)
├── Alfred 🎩 ← Orquestrador (HUB)
│   ├── Gabi 🎯  ← Tráfego Pago
│   ├── Luna 🌙  ← Social Media
│   ├── Sage 🌿  ← SEO & Conteúdo
│   └── Nova ✨  ← Estratégia & Inteligência
```

---

## 👥 Agentes Ativos

| Agente | Papel | Nível | Modelo | Status | Desde |
|--------|-------|-------|--------|--------|-------|
| **Alfred** 🎩 | Orquestrador / Hub | L4 (Trusted) | Gemini 2.5 Flash | ✅ Ativo | 2026-03-04 |
| **Gabi** 🎯 | Tráfego Pago | L2 (Contributor) | Gemini 2.5 Flash | ✅ Ativo | 2026-03-04 |
| **Luna** 🌙 | Social Media | L2 (Contributor) | Gemini 2.5 Flash | ✅ Ativo | 2026-03-04 |
| **Sage** 🌿 | SEO & Conteúdo | L2 (Contributor) | Gemini 2.5 Flash | ✅ Ativo | 2026-03-04 |
| **Nova** ✨ | Estratégia & Inteligência | L2 (Contributor) | Gemini 2.5 Flash | ✅ Ativo | 2026-03-04 |

---

## 📊 Sistema de Leveling (Kevin Simback)

| Nível | Nome | Autonomia | Revisão |
|-------|------|-----------|---------|
| L1 | Observer | Zero — output sempre revisado | Cada entrega |
| L2 | Contributor | Baixa — pode sugerir, não executar | Semanal |
| L3 | Operator | Média — executa dentro de guidelines | Semanal |
| L4 | Trusted | Alta — autonomia quase total | Quinzenal |

**Regras:**
- Promoção via performance review semanal
- Rebaixamento é possível (se qualidade cair)
- NUNCA "rushar" um agente pra L3+ sem histórico

---

## 🗂️ Pastas Compartilhadas

```
shared/
├── memory/
│   ├── clients.yaml   ← Base de clientes
│   ├── activity.log   ← Log de ações de todos os agentes
│   └── alerts.yaml    ← Alertas abertos
├── templates/
│   ├── report-client.md
│   ├── alert-message.md
│   └── brief-creative.md
├── outputs/           ← Resultados por data/agente (YYYY-MM-DD/[agente]/)
├── lessons/           ← Aprendizados do time
└── TEAM.md            ← Este arquivo (registry)
```

---

## 🛠️ Skills por Agente

| Agente | Skills Responsável |
|--------|-------------------|
| Alfred | wolf-reminders, wolf-clickup-digest, wolf-meeting-summary, wolf-briefing-monitor, wolf-quality-check, wolf-process-docs, wolf-report-generator |
| Luna | wolf-caption-gen, wolf-creative-analysis, wolf-reference-curator |
| Nova | wolf-proposal-draft |
| Gabi | (via wolf-report-generator para dados de tráfego) |
| Sage | (via wolf-report-generator para dados de SEO) |

---

## 📝 Histórico de Alterações

| Data | Alteração |
|------|-----------|
| 2026-03-04 | Estrutura base criada (só Alfred) |
| 2026-03-04 | Migração para Wolf Agency v2.0 — Rex, Luna, Sage, Nova ativados |
| 2026-03-05 | Rex renomeado para Gabi (agente de tráfego) |

---

*Próxima revisão: Após primeira semana de uso dos agentes especializados*
