# TOOLS.md — Inventario de Skills & Plugins
# Wolf Agency AI System | Atualizado: 2026-03-26

---

## Skills Ativas (skills/)

### Wolf Agency — Operacao (24 skills)

| Skill | Funcao | Agente | Status |
|-------|--------|--------|--------|
| wolf-mission-control | Bridge com Supabase (missoes) | Alfred | Operacional |
| wolf-reminders | Lembretes proativos | Alfred | Operacional |
| wolf-quality-check | Checklist pre-entrega | Alfred | Operacional |
| wolf-briefing-monitor | Analise de briefings | Alfred | Operacional |
| wolf-meeting-summary | Resumo de reunioes | Alfred | Operacional |
| wolf-process-docs | Documentacao de SOPs | Alfred | Operacional |
| wolf-clickup-digest | Digest diario ClickUp | Alfred | Operacional |
| wolf-reports | Reports PDF profissionais | Alfred | Operacional |
| wolf-self-heal | Auto-diagnostico e recuperacao | Alfred | Operacional |
| wolf-criar-grupo | Criacao de grupos Telegram | Alfred | Operacional |
| wolf-weather | Previsao do tempo | Alfred | Operacional |
| wolf-learning-engine | Aprendizado continuo, style guides | Alfred | Operacional |
| wolf-caption-gen | Legendas para Instagram | Luna | Operacional |
| wolf-creative-analysis | Analise de criativos | Luna | Operacional |
| wolf-reference-curator | Curadoria de referencias visuais | Luna | Operacional |
| wolf-proposal-draft | Rascunho de propostas comerciais | Nova | Operacional |
| wolf-nova-research | Pesquisa profunda multi-fontes | Nova | Operacional |
| meta-ads | Meta Ads CRUD + workflows | Gabi | Operacional (3 tokens ativos) |
| natiely-ops | Operacoes de design e gestao | Alfred | Operacional |
| wolf-video-pipeline | Pipeline producao de video | Editor | Operacional |
| wolf-voice | Transcricao de audio Telegram | Alfred | Operacional |
| wolf-shorts-factory | Criacao de shorts/reels | Editor | Operacional |
| dark-radar | Inteligencia de mercado | Scout/Sage | Desabilitado (pip broken) |
| modo-sono | Rotina de fechamento diario (00-05h) | Alfred | Latente |

### Wolf Agency — Ferramentas (7 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| clickup-api | API ClickUp direto | Operacional |
| clickup-auditor | Auditoria de tarefas ClickUp | Operacional |
| design-system | Extracao de Design Systems (Figma, HTML, JSON, Tailwind) | Operacional |
| knowledge-brain | Base de conhecimento (Supabase, 1199+ cards) | Operacional |
| wolf-voice-debug | Debug via audio Telegram | Latente |
| youtube-monitor | Monitor de canais YouTube | Operacional (standalone) |
| youtube-transcript | Transcricao de videos YouTube | Operacional |

### Plataforma OpenClaw (19 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| agent-browser | Navegacao web | Operacional |
| blogburst | Blog posts em massa | Requer BLOGBURST_API_KEY |
| competitor-analysis-report | Analise de concorrentes | Operacional |
| content-creator | Criacao de conteudo | Operacional |
| find-skills | Busca de skills no ClawdHub | Operacional |
| frontend-design | Design web profissional | Operacional |
| github | Integracao GitHub | Operacional |
| google-meet | Google Meet API | Operacional |
| google-slides | Google Slides API | Operacional |
| google-trends | Google Trends | Operacional |
| humanizer | Humanizacao de texto AI | Operacional |
| invoice-tracker-pro | Rastreador de faturas | Operacional |
| markdown-converter | Conversao Markdown | Operacional |
| n8n-workflow-automation | Automacao n8n | Operacional |
| nano-pdf | Geracao de PDFs | Operacional |
| news-summary | Resumo de noticias | Operacional |
| tavily-search | Busca web Tavily | Requer TAVILY_API_KEY |
| excel-xlsx | Geracao de planilhas Excel | Operacional |
| word-docx | Geracao de documentos Word | Operacional |

### Marketing & Criacao (12 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| postwall | Mural de posts | Requer POSTWALL_API_KEY |
| quick-reminders | Lembretes rapidos | Operacional |
| social-data | Dados de redes sociais | Requer MC_API |
| summarize | Resumos gerais | Operacional |
| content-engine | Conteudo nativo por plataforma | Operacional |
| cost-aware-llm-pipeline | Roteamento de modelo por custo | Operacional |
| strategic-compact | Compactacao estrategica de contexto | Operacional |
| auto-shorts-repurposer | Repurpose long-form → shorts | Operacional |
| email-sequence | Sequencias de email marketing | Operacional |
| marketing-psychology | Frameworks de psicologia de marketing | Operacional |
| page-architect | Arquitetura de landing pages | Operacional |
| video-subtitles | Geracao de legendas em video | Operacional |

### Utilidades (5 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| task-resume | Retomada de tarefas | Operacional |
| todo-boss | Gestao de todos | Operacional |
| whatsapp-business | WhatsApp Business API | Operacional |
| powerpoint-pptx | Geracao de apresentacoes | Operacional |
| sovereign-brand-voice-writer | Escrita com voz de marca | Operacional |

### Nao configuradas / Requer API key

| Skill | Funcao | Key necessaria |
|-------|--------|----------------|
| cold-email | Email frio automatizado | MACHFIVE_API_KEY |
| genviral | Conteudo viral com API | GENVIRAL_API_KEY |
| google-ads-api | Google Ads API | MATON_API_KEY |
| tiktok-ads | TikTok Ads API | TBD |

### Provavelmente abandonadas (candidatas a _archive)

| Skill | Motivo |
|-------|--------|
| capability-evolver | Self-evolution generico, sem uso Wolf |
| cs-pricing-strategy | Pricing tool generico, sem uso ativo |
| feishu-evolver-wrapper | Plataforma chinesa, irrelevante |
| mac-compute-use | MCP GUI automation, sem uso ativo |
| proactive-agent | Nao documentado, sem referencias |
| tavily-web-search-for-openclaw | Duplicata de tavily-search |
| transcriptapi | Duplicata de wolf-voice / youtube-transcript |

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

### Dev Squad (13 — Echo removido, diretorio ausente)

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
| CFO Wolf | agents/cfo-wolf/ | Diretor Financeiro (requer MATON_API_KEY) |

---

## Plugins OpenClaw (3)

| Plugin | Status | Nota |
|--------|--------|------|
| Telegram | Operacional | Bot @alfredwolf_bot, polling ativo |
| llm-task | Operacional | Spawn de subagentes (maxConcurrent: 2) |
| Lobster | Desconhecido | Ativo no openclaw.json, funcao nao documentada |

---

*Atualizado: 2026-03-26 — Auditoria completa: removidos 6 fantasmas, adicionadas 29 skills nao-documentadas, Echo removido (dir ausente), status de API keys atualizado*
