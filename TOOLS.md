# TOOLS.md — Inventario de Skills & Plugins
# Wolf Agency AI System | Atualizado: 2026-03-26

---

## Skills Ativas (skills/)

### Wolf Agency — Operacao (22 skills)

| Skill | Funcao | Agente | Status |
|-------|--------|--------|--------|
| wolf-mission-control | Bridge com Supabase (missoes) | Alfred | Operacional |
| wolf-reminders | Lembretes proativos | Alfred | Operacional |
| wolf-quality-check | Checklist pre-entrega | Alfred | Operacional |
| wolf-briefing-monitor | Analise de briefings | Alfred | Operacional |
| wolf-meeting-summary | Resumo de reunioes | Alfred | Dormant |
| wolf-process-docs | Documentacao de SOPs | Alfred | Dormant |
| wolf-clickup-digest | Digest diario ClickUp | Alfred | Operacional |
| wolf-reports | Reports PDF profissionais | Alfred | Dormant |
| wolf-self-heal | Auto-diagnostico e recuperacao | Alfred | Operacional |
| wolf-learning-engine | Aprendizado continuo, style guides | Alfred | Dormant |
| wolf-caption-gen | Legendas para Instagram | Luna | Operacional |
| wolf-creative-analysis | Analise de criativos | Luna | Operacional |
| wolf-reference-curator | Curadoria de referencias visuais | Luna | Operacional |
| wolf-proposal-draft | Rascunho de propostas comerciais | Nova | Operacional |
| wolf-nova-research | Pesquisa profunda multi-fontes | Nova | Operacional |
| meta-ads | Meta Ads CRUD + workflows | Gabi | Operacional (3 tokens ativos) |
| natiely-ops | Operacoes de design e gestao | Alfred | Operacional |
| wolf-video-pipeline | Pipeline producao de video | Editor | Operacional |
| wolf-voice | Transcricao de audio Telegram | Alfred | Operacional |
| wolf-shorts-factory | Criacao de shorts/reels | Editor | Dormant |
| dark-radar | Inteligencia de mercado | Scout/Sage | Desabilitado (pip broken) |
| modo-sono | Rotina de fechamento diario (00-05h) | Alfred | Latente |

### Wolf Agency — Ferramentas (5 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| clickup-api | API ClickUp direto | Operacional |
| design-system | Extracao de Design Systems (Figma) | Operacional |
| knowledge-brain | Base de conhecimento (1199+ cards) | Operacional |
| youtube-monitor | Monitor de canais YouTube | Dormant |
| youtube-transcript | Transcricao de videos YouTube | Dormant |

### Plataforma OpenClaw (13 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| agent-browser | Navegacao web | Operacional |
| competitor-analysis-report | Analise de concorrentes | Operacional |
| content-creator | Criacao de conteudo | Operacional |
| find-skills | Busca de skills no ClawdHub | Operacional |
| frontend-design | Design web profissional | Dormant |
| github | Integracao GitHub | Operacional |
| google-trends | Google Trends | Operacional |
| humanizer | Humanizacao de texto AI | Operacional |
| invoice-tracker-pro | Rastreador de faturas | Dormant |
| markdown-converter | Conversao Markdown | Operacional |
| nano-pdf | Geracao de PDFs | Operacional |
| news-summary | Resumo de noticias | Operacional |
| excel-xlsx | Geracao de planilhas Excel | Dormant |

### Marketing & Criacao (11 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| quick-reminders | Lembretes rapidos | Operacional |
| summarize | Resumos gerais | Operacional |
| content-engine | Conteudo nativo por plataforma | Dormant |
| cost-aware-llm-pipeline | Roteamento de modelo por custo | Dormant |
| strategic-compact | Compactacao estrategica de contexto | Dormant |
| auto-shorts-repurposer | Repurpose long-form → shorts | Dormant |
| email-sequence | Sequencias de email marketing | Dormant |
| marketing-psychology | Frameworks de psicologia de marketing | Dormant |
| page-architect | Arquitetura de landing pages | Operacional |
| video-subtitles | Geracao de legendas em video | Dormant |
| sovereign-brand-voice-writer | Escrita com voz de marca | Operacional |

### Utilidades (5 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| task-resume | Retomada de tarefas | Operacional |
| todo-boss | Gestao de todos | Operacional |
| powerpoint-pptx | Geracao de apresentacoes | Dormant |
| word-docx | Geracao de documentos Word | Dormant |
| cfo-wolf | Diretor Financeiro | Operacional |

---

## Agentes (20 agentes em agents/)

### Marketing Squad (5)

| Agente | Pasta | Funcao |
|--------|-------|--------|
| Gabi | agents/gabi/ | Trafego pago (Meta Ads) |
| Luna | agents/social/ | Social media |
| Sage | agents/seo/ | SEO e conteudo |
| Nova | agents/strategy/ | Estrategia e inteligencia |
| Editor (Ed) | agents/video-editor-pro/ | Edicao de video |

### Dev Squad (13)

| Agente | Pasta | Funcao |
|--------|-------|--------|
| Titan | agents/dev/titan/ | Lider dev, arquitetura |
| Pixel | agents/dev/pixel/ | Frontend, UI/UX, Design System |
| Forge | agents/dev/forge/ | Backend, APIs |
| Vega | agents/dev/vega/ | Data, analytics |
| Shield | agents/dev/shield/ | Seguranca |
| Atlas | agents/dev/atlas/ | Infraestrutura |
| Bridge | agents/dev/bridge/ | Integracoes |
| Craft | agents/dev/craft/ | Qualidade |
| Flux | agents/dev/flux/ | CI/CD |
| Iris | agents/dev/iris/ | Monitoramento |
| Ops | agents/dev/ops/ | DevOps |
| Quill | agents/dev/quill/ | Documentacao |
| Turbo | agents/dev/turbo/ | Performance |

### Operacional (1)

| Agente | Pasta | Funcao |
|--------|-------|--------|
| Natiely | agents/natiely/ | Gestao de design e prazos |

### Financeiro (1)

| Agente | Pasta | Funcao |
|--------|-------|--------|
| CFO Wolf | agents/cfo-wolf/ | Diretor Financeiro |

---

## Plugins OpenClaw (3)

| Plugin | Status | Nota |
|--------|--------|------|
| Telegram | Operacional | Bot @alfredwolf_bot, polling ativo |
| llm-task | Operacional | Spawn de subagentes (maxConcurrent: 2) |
| Lobster | Desconhecido | Ativo no openclaw.json, funcao nao documentada |

---

## Arquivadas (skills/_archive/) — 22 skills

blogburst, capability-evolver, cold-email, cs-pricing-strategy, feishu-evolver-wrapper,
genviral, google-ads-api, google-meet, google-slides, mac-compute-use, n8n-workflow-automation,
postwall, proactive-agent, social-data, tavily-search, tavily-web-search-for-openclaw,
tiktok-ads, transcriptapi, whatsapp-business + 3 anteriores

---

*Atualizado: 2026-03-26 — Limpeza completa: 12 skills mortas arquivadas, 5 abandonadas arquivadas, 2 duplicatas removidas, docs alinhados com disco*
