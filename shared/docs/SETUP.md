# SETUP.md — Wolf Agency AI System
# Instalação completa do zero

---

## PRÉ-REQUISITOS

```bash
# Verifique versões
node --version    # Precisa: v22+
npm --version     # Precisa: v10+

# Se não tiver Node 22:
# Mac: brew install node@22
# Linux: nvm install 22 && nvm use 22
```

---

## PASSO 1 — Instala o OpenClaw

```bash
npm install -g openclaw@latest

# Verifica
openclaw --version

# Onboarding inicial (configura diretórios base)
openclaw onboard
# → Vai perguntar: qual AI usar (selecione Claude)
# → Vai perguntar: onde quer o workspace (ex: ~/wolf-workspace)
```

---

## PASSO 2 — Clona o Wolf System

```bash
# Copie todos os arquivos deste pacote para o seu workspace
# Estrutura esperada em ~/.openclaw/workspace/ ou ~/wolf-workspace/

cp -r wolf-agents/* ~/.openclaw/workspace/

# Ou se usar workspace customizado:
cp -r wolf-agents/* ~/wolf-workspace/
```

---

## PASSO 3 — Configura o .env

```bash
# Cria o arquivo .env na raiz do workspace
cp wolf-agents/.env.example ~/.openclaw/workspace/.env

# Edita com seus dados (use qualquer editor)
nano ~/.openclaw/workspace/.env
```

**Mínimo para começar (Gabi funcional):**
```env
# OBRIGATÓRIO — Claude API
ANTHROPIC_API_KEY=sk-ant-...

# OBRIGATÓRIO — Notificações
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# GABI — Tráfego Pago
ADSPIRER_API_KEY=
```

**Para sistema completo:**
```env
ANTHROPIC_API_KEY=sk-ant-...

# Notificações
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# GABI
ADSPIRER_API_KEY=
GA4_MEASUREMENT_ID=

# LUNA
POSTBRIDGE_API_KEY=

# SAGE
DATAFORSEO_LOGIN=
DATAFORSEO_PASSWORD=

# TODOS
CLICKUP_API_TOKEN=
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
```

---

## PASSO 4 — Primeiro Teste

```bash
# Abre o OpenClaw
openclaw

# No chat:
status
# → Deve retornar: visão geral do sistema

help
# → Lista todos os comandos disponíveis

# Adiciona primeiro cliente:
# "alfred, onboarding Wolf Teste — tráfego pago — teste@wolf.com"
```

---

## PASSO 5 — Configura Telegram Bot

```bash
# 1. Abre @BotFather no Telegram
# 2. /newbot → dá um nome → obtém o TELEGRAM_BOT_TOKEN
# 3. Adiciona o bot a um grupo ou inicia conversa direta
# 4. Obtém o CHAT_ID:
#    → Abre: https://api.telegram.org/bot[TOKEN]/getUpdates
#    → Mande uma mensagem para o bot
#    → Procure "chat": {"id": ESTE_NUMERO}
# 5. Adiciona ambos no .env

# Testa:
# No chat do OpenClaw: "manda olá no telegram"
```

---

## PASSO 6 — Instala MCPs (na ordem recomendada)

```bash
# Adspirer (Gabi — ads)
openclaw plugins install openclaw-adspirer
openclaw adspirer login   # segue fluxo OAuth

# Browser Automation (Luna, Sage, Nova)
openclaw plugins install browser-use

# GSC (Sage — SEO)
openclaw plugins install gsc-mcp
# → Segue fluxo OAuth Google

# Google Drive (todos)
openclaw plugins install gdrive-mcp
# → Segue fluxo OAuth Google
```

---

## PASSO 7 — Preenche clients.yaml

Edite `shared/memory/clients.yaml` com seu primeiro cliente real:

```yaml
clients:
  cliente_exemplo:
    nome: "Nome do Cliente"
    segmento: "e-commerce de moda"
    contato_principal: "João Silva"
    email: "joao@cliente.com"
    data_inicio: "2026-03-01"
    status: "ativo"

    servicos:
      trafego_pago: true
      social_media: true
      seo_conteudo: false
      estrategia: false

    traffic:
      contas_meta: ["ACT_123456789"]
      contas_google: ["123-456-7890"]
      roas_target: 3.5
      cpa_target: 45.00
      budget_mensal: 5000.00

    social:
      plataformas_ativas:
        instagram: 5      # posts por semana
        tiktok: 3
      brand_voice:
        personalidade: ["jovem", "direto", "sem corporativês"]
        evitar: ["emojis excessivos", "linguagem formal"]

    meta:
      grupo_whatsapp: "Wolf x ClienteA"
      projeto_clickup: "ClienteA — Sprint Mar/26"
```

---

## VERIFICAÇÃO FINAL

```bash
# No chat do OpenClaw, rode em sequência:

"status"
# ✅ Esperado: lista de agentes ativos

"clientes"
# ✅ Esperado: seu cliente de teste aparece

"Gabi, como estão as contas de [NOME DO CLIENTE]?"
# ✅ Esperado: Gabi ativa, tenta conectar via Adspirer, retorna dados ou erro de conexão descritivo

"heartbeat manual"
# ✅ Esperado: todos os agentes rodam check e retornam status
```

---

## ESTRUTURA FINAL DO WORKSPACE

```
~/.openclaw/workspace/
├── SOUL.md                    ← Identidade global
├── .env                       ← Credenciais (NÃO commitar no git)
├── orchestrator/
│   └── ORCHESTRATOR.md
├── agents/
│   ├── traffic/
│   │   ├── SKILL.md
│   │   └── sub-skills/
│   │       ├── audit.md
│   │       ├── budget-monitor.md
│   │       ├── creative-fatigue.md
│   │       ├── report-builder.md
│   │       └── creative-brief.md
│   ├── social/
│   │   ├── SKILL.md
│   │   └── sub-skills/
│   │       └── waterfall-calendar-listening-publish.md
│   ├── seo/
│   │   ├── SKILL.md
│   │   └── sub-skills/
│   ├── strategy/
│   │   ├── SKILL.md
│   │   └── sub-skills/
├── shared/
│   ├── memory/
│   │   ├── clients.yaml       ← Base de clientes
│   │   ├── activity.log       ← Log de ações (criado automaticamente)
│   │   └── alerts.yaml        ← Alertas abertos
│   └── docs/
│       ├── SETUP.md           ← Este arquivo
│       └── MCP-GUIDE.md       ← Guia de MCPs
```
