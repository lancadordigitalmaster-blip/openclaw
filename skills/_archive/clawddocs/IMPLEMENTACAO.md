# ClawdDocs — Skill de Documentação Clawdbot

> Especialista em documentação do Clawdbot com navegação por árvore de decisão, scripts de busca, fetch de docs, versionamento e snippets de configuração.

---

## 📋 RESUMO DA IMPLEMENTAÇÃO

**Status:** ✅ Implementada e testada

| Componente | Status |
|------------|--------|
| Skill instalada | ✅ `skills/clawddocs/` |
| Scripts | ✅ 8 scripts funcionais |
| Snippets | ✅ Configurações comuns |
| Teste | ✅ Sitemap funcionou |

---

## 🎯 O QUE FAZ

**Especialista em documentação do Clawdbot:**

1. **Navegação inteligente** — Árvore de decisão para encontrar docs rapidamente
2. **Busca** — Keyword search, full-text index (qmd), sitemap
3. **Fetch de docs** — Baixa documentação específica sob demanda
4. **Versionamento** — Track de mudanças entre versões
5. **Snippets** — Configurações prontas (providers, gateway, tools)

---

## 🌳 ÁRVORE DE DECISÃO (Como Usa)

| Pergunta do Usuário | Onde Buscar |
|---------------------|-------------|
| "Como configurar X?" | `providers/` ou `gateway/` |
| "Por que X não funciona?" | `debugging/` ou `troubleshooting/` |
| "O que é X?" | `concepts/` |
| "Como automatizar X?" | `automation/` |
| "Como instalar/deploy?" | `install/` ou `platforms/` |

---

## 🛠️ SCRIPTS DISPONÍVEIS

### Core
| Script | Uso |
|--------|-----|
| `sitemap.sh` | Lista todas as docs por categoria |
| `cache.sh status` | Status do cache |
| `cache.sh refresh` | Atualiza sitemap |

### Busca & Descoberta
| Script | Uso |
|--------|-----|
| `search.sh [keyword]` | Busca por palavra-chave |
| `recent.sh [dias]` | Docs atualizadas nos últimos N dias |
| `fetch-doc.sh [path]` | Baixa doc específica |

### Full-Text Index (requer `qmd`)
| Script | Uso |
|--------|-----|
| `build-index.sh fetch` | Baixa todas as docs |
| `build-index.sh build` | Cria índice de busca |
| `build-index.sh search "[termo]"` | Busca semântica |

### Versionamento
| Script | Uso |
|--------|-----|
| `track-changes.sh snapshot` | Salva estado atual |
| `track-changes.sh list` | Lista snapshots |
| `track-changes.sh since [data]` | Mudanças desde data |

---

## 📁 CATEGORIAS DE DOCUMENTAÇÃO

| Categoria | Conteúdo |
|-----------|----------|
| `/start/` | Getting started, onboarding, FAQ |
| `/gateway/` | Configuração, exemplos, troubleshooting |
| `/providers/` | Telegram, Discord, WhatsApp, etc. |
| `/concepts/` | Arquitetura, sessões, models, queues |
| `/tools/` | Browser, cron, message, TTS, etc. |
| `/automation/` | Cron jobs, webhooks, Gmail pubsub |
| `/cli/` | Comandos, flags, exemplos |
| `/platforms/` | Linux, macOS, Docker, Raspberry Pi |
| `/nodes/` | Device pairing, camera, screen, location |
| `/web/` | Web interface, Canvas |
| `/install/` | Docker, source, package managers |
| `/reference/` | API reference, schemas |

---

## 🧪 TESTE REALIZADO

**Comando:**
```bash
bash ./scripts/sitemap.sh
```

**Resultado:** ✅ Funcionou
```
📁 /start/
📁 /gateway/
📁 /providers/
📁 /concepts/
📁 /tools/
📁 /automation/
📁 /cli/
📁 /platforms/
📁 /nodes/
📁 /web/
📁 /install/
📁 /reference/
```

---

## 💡 CASOS DE USO (Wolf Agency)

### 1. **Configuração de Novos Recursos**
- "Como configurar webhook para novos leads?"
- Skill busca em `automation/webhook` + `providers/telegram`

### 2. **Debug de Problemas**
- "Telegram não está enviando mensagens"
- Skill busca em `providers/troubleshooting` + `gateway/debugging`

### 3. **Otimização do Sistema**
- "Como melhorar performance do gateway?"
- Skill busca em `concepts/sessions` + `gateway/configuration`

### 4. **Automações Novas**
- "Como criar cron job para reports?"
- Skill busca em `automation/cron-jobs` + exemplos prontos

### 5. **Deploy em Servidor**
- "Como rodar em VPS Linux?"
- Skill busca em `platforms/linux` + `install/docker`

---

## 📝 EXEMPLO DE USO

**Você pergunta:**
```
"Como configuro cron jobs no Clawdbot?"
```

**Eu faço:**
1. Identifico: é automação → `automation/cron-jobs`
2. Rodo: `./scripts/fetch-doc.sh automation/cron-jobs`
3. Leio a doc
4. Entrego:
   - Explicação do conceito
   - Exemplo de configuração JSON
   - Comandos para testar
   - Troubleshooting comum

---

## 🔧 INSTALAÇÃO

**Dependências:**
```bash
# Opcional: para full-text search
brew install qmd  # Não instalado ainda
```

**Localização:**
```
~/.openclaw/workspace/skills/clawddocs/
├── SKILL.md
├── _meta.json
├── package.json
├── scripts/          (8 scripts)
└── snippets/         (configs prontas)
```

**Scripts:**
- ✅ Todos com `chmod +x`
- ✅ Testado: `sitemap.sh`

---

## 📊 COMPARAÇÃO: Antes vs Depois

| Antes (sem skill) | Depois (com ClawdDocs) |
|-------------------|------------------------|
| Busca manual em docs.clawd.bot | Scripts automatizados |
| Navegação lenta | Árvore de decisão direta |
| Configs copiadas do site | Snippets locais prontos |
| Sem versionamento | Track de mudanças |
| Busca genérica no Google | Busca semântica (qmd) |

---

## 🚀 PRÓXIMOS PASSOS SUGERIDOS

1. **Full-Text Index**
   - Instalar `qmd`
   - Rodar `build-index.sh fetch + build`
   - Busca semântica em toda documentação

2. **Cache Local**
   - Configurar `cache.sh refresh` diário
   - Docs disponíveis offline

3. **Integração com Alfred**
   - Ao receber pergunta sobre Clawdbot → auto-fetch da doc
   - Resposta já com contexto completo

4. **Versionamento**
   - Snapshot semanal com `track-changes.sh snapshot`
   - Saber o que mudou entre versões

---

## 📦 ESTRUTURA INSTALADA

```
clawddocs/
├── SKILL.md                 ✅
├── _meta.json               ✅
├── package.json             ✅
├── scripts/
│   ├── build-index.sh       ✅
│   ├── cache.sh             ✅
│   ├── fetch-doc.sh         ✅
│   ├── recent.sh            ✅
│   ├── search.sh            ✅
│   ├── sitemap.sh           ✅
│   ├── sitemap.sh           ✅
│   └── track-changes.sh     ✅
└── snippets/
    └── common-configs.md    ✅
```

---

## 📈 VALOR PARA WOLF AGENCY

| Benefício | Impacto |
|-----------|---------|
| **Configuração mais rápida** | Menos tempo procurando docs |
| **Debug eficiente** | Troubleshooting direto ao ponto |
| **Automações prontas** | Snippets de configuração |
| **Versionamento** | Saber o que mudou nas updates |
| **Busca semântica** | Encontra docs por contexto, não só keyword |

---

*Implementado: 2026-03-05 21:57 BRT*  
*Testado: sitemap.sh funcionou ✅*  
*Próximo: full-text index com qmd (opcional)*
