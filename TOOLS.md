# TOOLS.md — Inventario de Skills & Plugins
# Wolf Agency AI System | Atualizado: 2026-03-08

---

## ⚠️ Skills Bloqueados (3 skills — Requerem Acao)

| Skill | Status | Motivo | Acao Necessaria |
|-------|--------|--------|---|
| meta-ads | Bloqueado | Token expirado | Renovar token Meta Ads |
| google-sheets | Requer OAuth | Autenticacao pendente | Aprovar OAuth Google |
| youtube-api | Requer OAuth | Autenticacao pendente | Aprovar OAuth Google |

---

## Skills Ativas (57 skills em skills/)

### Wolf Agency — Operacao (23 skills)

| Skill | Funcao | Agente | Status |
|-------|--------|--------|--------|
| wolf-ops | Integracao W.O.L.F. (GET/POST) | Alfred | Operacional |
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
| meta-ads | Meta Ads CRUD (criar/pausar/ativar) | Gabi | Bloqueado (token expirado) |
| natiely-ops | Operacoes de design e gestao | Alfred | Operacional |
| wolf-video-pipeline | Pipeline producao de video | Editor | Operacional |
| wolf-voice | Transcricao de audio Telegram | Alfred | Operacional |
| modo-sono | Rotina de fechamento diario (00-05h) | Alfred | Latente |

### Wolf Agency — Ferramentas (6 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| clickup-api | API ClickUp direto | Operacional |
| clickup-auditor | Auditoria de tarefas ClickUp | Operacional |
| instagram-ingest | Pipeline Reels -> RAG | Latente |
| wolf-pr-review | Review automatico de PRs | Latente |
| wolf-voice-debug | Debug via audio Telegram | Latente |
| youtube-monitor | Monitor de canais YouTube | Operacional (standalone) |

### Plataforma OpenClaw (19 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| agent-browser | Navegacao web | Operacional |
| blogburst | Blog posts em massa | Operacional |
| competitor-analysis-report | Analise de concorrentes | Operacional |
| content-creator | Criacao de conteudo | Operacional |
| find-skills | Busca de skills no ClawdHub | Operacional |
| frontend-design | Design web profissional | Operacional |
| github | Integracao GitHub | Operacional |
| google-meet | Google Meet API | Operacional |
| google-sheets | Google Sheets API | Requer OAuth |
| google-slides | Google Slides API | Operacional |
| google-trends | Google Trends | Operacional |
| humanizer | Humanizacao de texto AI | Operacional |
| invoice-tracker-pro | Rastreador de faturas | Operacional |
| markdown-converter | Conversao Markdown | Operacional |
| n8n-workflow-automation | Automacao n8n | Operacional |
| nano-pdf | Geracao de PDFs | Operacional |
| news-summary | Resumo de noticias | Operacional |
| openai-whisper | Transcricao audio (Whisper) | Operacional |
| tavily-search | Busca web Tavily | Operacional |

### Marketing & Criacao (4 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| postwall | Mural de posts | Operacional |
| quick-reminders | Lembretes rapidos | Operacional |
| social-data | Dados de redes sociais | Operacional |
| summarize | Resumos gerais | Operacional |

### Utilidades (5 skills)

| Skill | Funcao | Status |
|-------|--------|--------|
| task-resume | Retomada de tarefas | Operacional |
| todo-boss | Gestao de todos | Operacional |
| whatsapp-business | WhatsApp Business API | Operacional |
| youtube-api | YouTube Data API | Requer OAuth |
| youtube-transcript | Transcricao de videos YouTube | Operacional |

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

### Dev Squad (14)

| Agente | Pasta | Funcao |
|--------|-------|--------|
| Titan | agents/dev/titan/ | Lider dev, arquitetura |
| Pixel | agents/dev/pixel/ | Frontend, UI/UX |
| Forge | agents/dev/forge/ | Backend, APIs |
| Vega | agents/dev/vega/ | Data, analytics |
| Shield | agents/dev/shield/ | Seguranca |
| Atlas | agents/dev/atlas/ | Infraestrutura |
| Bridge | agents/dev/bridge/ | Integracoes |
| Craft | agents/dev/craft/ | Qualidade |
| Echo | agents/dev/echo/ | Testes |
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
| CFO Wolf | agents/cfo-wolf/ | Diretor Financeiro — DRE, fluxo de caixa, projecoes, relatorio socios |

---

## Plugins OpenClaw (3)

| Plugin | Status | Nota |
|--------|--------|------|
| Telegram | Operacional | Bot @alfredwolf_bot, polling ativo |
| llm-task | Operacional | Spawn de subagentes (maxConcurrent: 2) |
| Lobster | Desconhecido | Ativo no openclaw.json, funcao nao documentada |

---

## Arquivados (11 skills em skills/_archive/)

| Skill | Motivo |
|-------|--------|
| agente-alfred-kaizen | Formato antigo, superseded por SOUL.md |
| agente-cut-edicao | Formato antigo, replaced por video-editor-pro |
| agente-gabi-trafego | Formato antigo, replaced por agents/gabi/ |
| agente-mi-social | Formato antigo, agente Mi descontinuado |
| auto-updater | Generico OpenClaw, nao Wolf-specific |
| clawddocs | Generico OpenClaw docs |
| knowledge-traffic | Incompleto, sem SKILL.md |
| self-reflection | Superseded por wolf-learning-engine |
| video-editor-pro | Duplicata — canonical em agents/video-editor-pro/ |
| wolf-coding-loop | Quebrado — referencia QUEUE.md deletado |
| wolf-facebook-ads | Superseded por meta-ads (write-enabled) |

---

*Atualizado: 2026-03-08 23:00 — Heartbeat Noturno*
