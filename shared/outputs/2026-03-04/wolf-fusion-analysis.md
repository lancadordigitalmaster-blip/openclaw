# Análise Comparativa & Plano de Fusão
# Wolf Agency AI System (Alfred) × W.O.L.F. v3.0
# Data: 2026-03-04 | Analista: Alfred (Nova + Alfred)

---

## 1. MAPA DOS DOIS SISTEMAS

### Wolf Agency AI System — Alfred
```
Canal: Telegram (@alfredwolf_bot)
Gateway: OpenClaw local (macOS LaunchAgent)
Modelo: Kimi K2.5 → Gemini Flash → Gemini Pro

Agentes (18):
  Marketing: Rex · Luna · Sage · Nova
  Dev Squad: Titan · Pixel · Forge · Ops · Atlas · Vega · Flux · Echo · Iris · Shield · Quill · Bridge · Turbo · Craft

Skills (13):
  wolf-reminders · wolf-clickup-digest · wolf-meeting-summary
  wolf-briefing-monitor · wolf-quality-check · wolf-process-docs
  wolf-report-generator · wolf-caption-gen · wolf-creative-analysis
  wolf-reference-curator · wolf-proposal-draft · wolf-self-heal · nano-banana

Dados persistentes: clients.yaml (vazio) · activity.log · alerts.yaml
```

### W.O.L.F. v3.0
```
Canal: WhatsApp (Evolution API)
Backend: Node.js + PostgreSQL + Redis
Modelo: Groq LLM (Anthropic desconectado)

Agentes (19):
  Ops:   Alpha (COO/orquestrador) · AlphaRouter · OpsAgent · ClientAgent
         CommAgent · FinOpsAgent · Alocador · Triagem
  Plan:  Analyst · SpecAgent · ArchAgent
  Build: ScrumMaster · FrontendEng · BackendEng · QAGate
  Misc:  Dashboard · ClienteBot · CopyAgent · Onboard

Automações ativas (6):
  Daily Briefing 09h · Kanban Archive 08h · Pattern Detection seg 10h
  Journal Summary 18:30 · Weekly Report sex 17h · Daily Report Netto 22h

Automações suspensas (2):
  Alert Checker (Playbooks) · FinOps Worker

Clientes identificados: Giovani Calçados · Studio Beleza · Dr. Marcos · Stephane Souza
```

---

## 2. ANÁLISE DE SOBREPOSIÇÃO — O QUE CADA SISTEMA FAZ

| Domínio | Wolf Agency (Alfred) | W.O.L.F. | Sobreposição |
|---------|---------------------|-----------|--------------|
| Orquestração | Alfred (intent router + agent dispatch) | Alpha (COO) + AlphaRouter | 🟡 Parcial — escopos diferentes |
| Tráfego Pago | Rex (Meta Ads, Google Ads, ROAS, budget) | ❌ Ausente | 🔴 Apenas Alfred |
| Social Media | Luna (conteúdo, calendário, publicação, listening) | CopyAgent (só copy) | 🟡 Parcial — Luna >> CopyAgent |
| SEO / Orgânico | Sage (rankings, keywords, auditoria técnica) | ❌ Ausente | 🔴 Apenas Alfred |
| Estratégia | Nova (pesquisa, personas, advisory board) | ❌ Ausente | 🔴 Apenas Alfred |
| Saúde do Cliente | Alfred (escalação, follow-up) | ClientAgent + ClienteBot | 🟡 Parcial |
| Reports | wolf-report-generator (dados de Rex+Luna+Sage) | Dashboard (compilação operacional) | 🟡 Fontes diferentes |
| ClickUp | wolf-clickup-digest (digest diário) | ClickUp connected | ✅ Mesma fonte |
| Qualidade | wolf-quality-check (checklist saída) | QAGate (review de build) | 🟡 Contextos diferentes |
| Gestão de Equipe | ❌ Ausente | OpsAgent + Alocador + Triagem | 🔴 Apenas W.O.L.F. |
| Kanban / Projetos | ❌ Ausente | Board com 10 cards ativos | 🔴 Apenas W.O.L.F. |
| Capacidade / Carga | ❌ Ausente | Load tracking (6 membros) | 🔴 Apenas W.O.L.F. |
| FinOps | ❌ Ausente | FinOpsAgent (SUSPENSO) | 🔴 Nenhum funcional |
| Dev / Produto | Titan + 13 especialistas (completo) | FrontendEng + BackendEng + QAGate (básico) | 🟡 Alfred >> W.O.L.F. |
| Onboarding | Alfred (skill) | Onboard (agente dedicado) | ✅ Redundante |
| WhatsApp | ❌ Ausente | Evolution API (conectado) | 🔴 Apenas W.O.L.F. |
| Briefing Monitor | wolf-briefing-monitor (checklist entrada) | Triagem (classificação de demandas) | 🟡 Parcial |

---

## 3. O QUE O W.O.L.F. PRECISA CORRIGIR AGORA

### 3.1 Integrações Desconectadas (CRÍTICO)

| Integração | Impacto do Desligamento | Ação |
|------------|------------------------|------|
| Anthropic | Agentes usando Groq em vez de Claude — qualidade inferior | Reconectar API key no painel |
| Meta Ads | Rex não consegue auditar campanhas dos clientes | Reconectar token no painel |
| Google Ads | Rex cego para performance do Google | Reconectar credentials |
| Google Analytics 4 | Rex sem dados de conversão; Dashboard sem métricas de site | Reconectar property |
| Email SMTP | ClientAgent e CommAgent não conseguem enviar emails | Configurar SMTP no painel |
| GitHub | ArchAgent e dev squad sem acesso a repositórios | Reconectar OAuth |

**Prioridade de reconexão:**
1. Anthropic (impacta todos os agentes)
2. Meta Ads + Google Ads + GA4 (impacta Rex diretamente)
3. Email SMTP (impacta comunicação com clientes)
4. GitHub (impacta dev squad)

### 3.2 Automações Suspensas — Reativar

**Alert Checker (Playbooks)**
- Função: verificação automática de alertas
- Suspensão cria blind spot — alertas só são detectados manualmente
- Ação: verificar por que foi suspenso (erro de config? dependência?) e reativar

**FinOps Worker**
- Função: monitoramento de custos de IA
- Com Groq + (futuramente) Anthropic reconectado, custo pode crescer invisível
- Ação: reativar com threshold de alerta

### 3.3 Equipe — Redistribuição Urgente

| Membro | Carga | Status | Ação |
|--------|-------|--------|------|
| Mariana | 90% | 🔴 Overloaded há 2 dias | Redistribuir demandas para Sindy (58%) ou Ilana (45%) |
| Gabriela | 85% | ⚠️ Borda do limite | Monitorar — qualquer nova entrada → redistribuir |
| Sindy | 58% | 🟢 Disponível | Absorver overflow de Mariana |
| Ilana | 45% | 🟢 Disponível | Absorver overflow de Mariana |

### 3.4 Kanban — Cards Críticos

| Card | Status | Prioridade | Problema |
|------|--------|------------|---------|
| Landing Page — Giovani Calçados | working | URGENT | SLA 7d violado — overdue |
| Copy Black Friday — Studio Beleza | working | URGENT | Sob pressão de prazo |
| Pack Criativos — Studio Beleza | standby | HIGH | Deadline 24h, nem começou |
| Estratégia Digital — Dr. Marcos | briefing | HIGH | Travado há 8 dias |
| Campanha Google Ads — Giovani Calçados | standby | NORMAL | Aguardando desbloqueio |

### 3.5 Modelo — Trocar Groq por Anthropic/Kimi

O W.O.L.F. está usando Groq como LLM principal (Anthropic desconectado).
Benefícios de migrar:
- Contexto maior (256K vs ~32K do Groq)
- Raciocínio mais sofisticado para Alpha e analistas
- Consistência com Alfred (mesmo modelo = mesma qualidade)

---

## 4. MELHORIAS E OTIMIZAÇÕES DO W.O.L.F.

### 4.1 Adicionar Marketing Intelligence (GAP CRÍTICO)

O W.O.L.F. não tem NENHUM agente de marketing ativo:
- CopyAgent faz copy mas não analisa performance
- Não há monitoramento de ROAS, CPA, budget pacing
- Não há SEO tracking
- Não há social media listening
- Não há estratégia de mercado

**Solução:** Integrar Rex, Luna, Sage e Nova do Alfred como agentes do W.O.L.F.
Ou, mais pragmático: Alfred lê W.O.L.F. para contexto operacional e entrega intelligence de volta.

### 4.2 Expandir CopyAgent → Luna

CopyAgent está fazendo apenas copy (campanha Black Friday).
Luna faz: copy + calendário + publicação + listening + competitor watch.
Substituir/expandir CopyAgent com as capacidades de Luna = ganho imediato.

### 4.3 Ativar FinOps corretamente

FinOpsAgent (suspenso) deveria monitorar:
- Custo por agente/sessão
- ROI por cliente
- Alertar quando custo LLM ultrapassa threshold
Com Anthropic reconectado, custo pode subir — precisa de monitoramento.

### 4.4 ClienteBot → Upgrade para Account Intelligence

ClienteBot está em REVIEW fazendo health check de Giovani Calçados (90% progresso).
Isso é apenas saúde reativa. Deveria também:
- Alertar proativamente quando cliente está sem contato por X dias
- Detectar risco de churn por padrão de comportamento
- Integrar com Nova para análise de valor estratégico do cliente

### 4.5 Tirar Triagem de IDLE

Triagem está IDLE mas há 3 novos itens "aguardando cliente" para Giovani Calçados.
Triagem deveria estar processando — verificar se há bloqueio ou configuração incorreta.

---

## 5. PLANO DE FUSÃO — ALFRED × W.O.L.F.

### Visão Geral

```
ESTADO ATUAL (dois sistemas isolados):
  Alfred → Telegram → Marketing Intelligence
  W.O.L.F. → WhatsApp → Gestão Operacional

ESTADO FUTURO (sistema unificado):
  Alfred (interface única) → lê W.O.L.F. em tempo real
                          → entrega marketing intelligence ao W.O.L.F.
                          → escreve de volta no W.O.L.F. (kanban, alertas, tasks)
```

### Fase 1 — Integração de Leitura (já iniciada)

✅ Alfred já lê W.O.L.F. via GET endpoint
✅ Credenciais salvas no .env
✅ /status mostra dados do W.O.L.F.
✅ alerts.yaml sincronizado com alertas críticos

**Próximo passo:** Integrar leitura do W.O.L.F. no heartbeat global do Alfred (SOUL.md)

### Fase 2 — Clientes Compartilhados

Os clientes visíveis no W.O.L.F. precisam entrar no clients.yaml do Alfred:

```yaml
# Clientes identificados no W.O.L.F. que devem ser adicionados ao clients.yaml:
clientes:
  giovani-calcados:
    nome: "Giovani Calçados"
    status: "ativo"
    alertas_wolf: ["landing page overdue", "3 itens aguardando cliente"]

  studio-beleza:
    nome: "Studio Beleza"
    status: "ativo"
    alertas_wolf: ["pack criativos deadline 24h"]

  dr-marcos:
    nome: "Dr. Marcos"
    status: "ativo"
    alertas_wolf: ["sem entrega há 8 dias"]

  stephane-souza:
    nome: "Stephane Souza"
    status: "ativo"
    alertas_wolf: ["onboarding concluído"]
```

### Fase 3 — Escrita Bidirecional (requer endpoint POST no W.O.L.F.)

Alfred poderia escrever de volta ao W.O.L.F.:
- Criar card no kanban quando Rex detectar alerta de campanha
- Criar task no ClickUp quando Sage identificar quick win de SEO
- Atualizar status de onboarding quando Luna finalizar calendário

**Depende de:** Netto expor endpoints POST no W.O.L.F. para Alfred usar

### Fase 4 — Agentes Compartilhados

```
MODELO HÍBRIDO PROPOSTO:

  Alpha (W.O.L.F.) → COO operacional (kanban, equipe, projetos)
  Alfred (Wolf Agency) → CMO de IA (campanhas, conteúdo, SEO, estratégia)

  Comunicação: Alfred consulta Alpha via API a cada heartbeat
               Alpha notifica Alfred via webhook quando há tarefa de marketing

  Canal único: Alfred responde pelo Telegram (já funcionando)
               W.O.L.F. continua com WhatsApp para clientes
```

### Fase 5 — Base Unificada de Dados

Hoje:
- W.O.L.F. tem PostgreSQL + Redis com dados operacionais
- Alfred tem clients.yaml (arquivo texto, vazio)

Ideal:
- Alfred usa W.O.L.F. como backend de clientes
- clients.yaml vira um cache/read do PostgreSQL do W.O.L.F.
- Toda alteração em cliente reflete em ambos os sistemas

---

## 6. ROADMAP PRIORIZADO

### Semana 1 (esta semana)
```
[ ] Reconectar Anthropic no W.O.L.F.
[ ] Reconectar Meta Ads + Google Ads + GA4 no W.O.L.F.
[ ] Redistribuir carga da Mariana
[ ] Desbloquear Landing Page Giovani Calçados
[ ] Pack Criativos Studio Beleza — alocar hoje
[ ] Reativar Alert Checker no W.O.L.F.
[ ] Preencher clients.yaml com os 4 clientes identificados
```

### Semana 2
```
[ ] Integrar leitura W.O.L.F. no heartbeat do Alfred (SOUL.md)
[ ] Alfred notifica via Telegram quando W.O.L.F. tem alerta crítico
[ ] Adicionar Rex capabilities ao W.O.L.F. (ou integrar via Alfred)
[ ] Reativar FinOps Worker com threshold de custo configurado
```

### Semana 3–4
```
[ ] Endpoint POST no W.O.L.F. para Alfred criar cards/tasks
[ ] clients.yaml sincronizado com W.O.L.F. PostgreSQL
[ ] Luna expandindo CopyAgent no W.O.L.F.
[ ] Trocar Groq → Anthropic (Claude) no W.O.L.F.
```

### Mês 2+
```
[ ] Dashboard unificado: Alfred + W.O.L.F. em uma view só
[ ] Agentes dev do Alfred integrados ao pipeline do W.O.L.F.
[ ] Single source of truth para todos os dados de cliente
[ ] Automação de onboarding unificada
```

---

## 7. SCORE DE SAÚDE — ANTES E DEPOIS

| Sistema | Antes | Depois (Fase 1-2) | Depois (Fusão completa) |
|---------|-------|-------------------|------------------------|
| Marketing Intelligence | Alfred: 70% / W.O.L.F.: 15% | Alfred: 80% | Unificado: 90% |
| Gestão Operacional | Alfred: 20% / W.O.L.F.: 65% | Alfred: 40% | Unificado: 85% |
| Dados de Cliente | Alfred: 10% / W.O.L.F.: 60% | Alfred: 50% | Unificado: 90% |
| Alertas Automáticos | Alfred: 60% / W.O.L.F.: 30% | Alfred: 75% | Unificado: 95% |
| Cobertura de Canal | Alfred: Telegram / W.O.L.F.: WhatsApp | Ambos | Ambos + novos |

---

*Relatório gerado por Alfred (Nova + Alfred) | 2026-03-04*
*Fonte: W.O.L.F. API endpoint + Wolf Agency workspace files*
