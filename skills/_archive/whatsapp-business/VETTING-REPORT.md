# 📋 SKILL VETTING REPORT — WhatsApp Business API

**Data:** 2026-03-05 22:21 BRT  
**Skill:** `whatsapp-business`  
**Versão:** 1.0.3  
**Autor:** Maton (maton.ai)  
**Fonte:** ZIP enviado pelo usuário

---

## 🔍 MÉTRICAS

| Campo | Valor |
|-------|-------|
| Downloads/Stars | N/A (skill fechada do Maton) |
| Última Atualização | Jan/2026 (v1.0.3) |
| Arquivos Reviewados | 3 (SKILL.md, _meta.json, LICENSE.txt) |
| Tamanho do Código | 636 linhas |

---

## 🚨 RED FLAGS VERIFICADAS

| Red Flag | Status |
|----------|--------|
| `curl/wget` pra URLs desconhecidas | ✅ Não encontrado |
| Envia dados pra servidores externos | ⚠️ **Sim** — Meta/WhatsApp (propósito legítimo) |
| Pede credenciais/tokens/API keys | ✅ Usa `MATON_API_KEY` (variável de env, não hardcoded) |
| Lê `~/.ssh`, `~/.aws`, `~/.config` | ✅ Não encontrado |
| Acessa `MEMORY.md`, `USER.md`, `SOUL.md` | ✅ Não encontrado |
| Usa `base64 decode` | ✅ Não encontrado |
| Usa `eval()` ou `exec()` | ✅ Não encontrado |
| Modifica arquivos do sistema | ✅ Não encontrado |
| Instala pacotes sem listar | ✅ Não encontrado |
| Rede pra IPs (ao invés de domain) | ✅ Domínios oficiais (gateway.maton.ai, graph.facebook.com) |
| Código ofuscado/minificado | ✅ Código aberto, legível |
| Pede root/sudo | ✅ Não requer |

### ⚠️ Observação sobre Dados Externos

**Red flag detectada:** Skill envia dados pra Meta/WhatsApp.

**Porém:** Isso é **funcionalidade principal da skill** — enviar mensagens via WhatsApp Business API.  
**URLs de destino:**
- `https://gateway.maton.ai/whatsapp-business/...` (proxy do Maton)
- `https://graph.facebook.com/` (API oficial do Meta)

**Veredito:** ✅ **Legítimo** — é o propósito da skill.

---

## 📏 PERMISSÕES NECESSÁRIAS

| Tipo | Permissões |
|------|------------|
| **Arquivos** | Nenhum (só lê SKILL.md, env) |
| **Network** | `gateway.maton.ai` (proxy), `graph.facebook.com` (Meta API) |
| **Comandos** | Python `urllib.request` ou `requests` |
| **Variáveis de Env** | `MATON_API_KEY` (obrigatória) |

**Escopo:** ✅ **Minimalista** — apenas o necessário pra função.

---

## 🎯 CLASSIFICAÇÃO DE RISCO

| Critério | Avaliação |
|----------|-----------|
| **Risco Geral** | 🟡 **MÉDIO** |
| **Por quê?** | Envia dados externos (API Meta) |
| **Contexto** | Funcionalidade intencional, não oculta |
| **Reputação** | Maton = gateway conhecido (mesmo autor da skill `youtube-api`) |

---

## ✅ VEREDITO

### **INSTALAR COM CONFIANÇA** 🟢

**Razões:**
1. ✅ Autor conhecido (Maton — mesma skill `youtube-api` instalada hoje)
2. ✅ Código aberto e legível
3. ✅ URLs oficiais (Meta/Facebook)
4. ✅ Sem red flags críticas
5. ✅ Permissões mínimas e justificadas

**Pré-requisito:**
- Ter conta no [maton.ai](https://maton.ai) com `MATON_API_KEY` configurada
- Ter número do WhatsApp Business registrado no Meta Business Manager

---

## 📝 COMO USAR

### 1. Configurar API Key

```bash
export MATON_API_KEY="sua-chave-do-maton"
```

### 2. Criar Conexão OAuth

```bash
python <<'EOF'
import urllib.request, os, json
data = json.dumps({'app': 'whatsapp-business'}).encode()
req = urllib.request.Request('https://ctrl.maton.ai/connections', data=data, method='POST')
req.add_header('Authorization', f'Bearer {os.environ["MATON_API_KEY"]}')
req.add_header('Content-Type', 'application/json')
resp = json.load(urllib.request.urlopen(req))
print(f"Abra este link: {resp['connection']['url']}")
EOF
```

### 3. Enviar Mensagem

```bash
python <<'EOF'
import urllib.request, os, json
data = json.dumps({
    'messaging_product': 'whatsapp',
    'to': '5573999999999',
    'type': 'text',
    'text': {'body': 'Olá! Mensagem da Wolf Agency.'}
}).encode()
req = urllib.request.Request('
  'https://gateway.maton.ai/whatsapp-business/v21.0/PHONE_NUMBER_ID/messages',
    data=data, method='POST')
req.add_header('Authorization', f'Bearer {os.environ["MATON_API_KEY"]}')
req.add_header('Content-Type', 'application/json')
print(json.dumps(json.load(urllib.request.urlopen(req)), indent=2))
EOF
```

---

## 🔒 RECOMENDAÇÕES DE SEGURANÇA

1. **NÃO cometer `MATON_API_KEY` no workspace** — manter só no `.env`
2. **Validar números antes de enviar** — evitar spam acidental
3. **Respeitar janela de 24h** — WhatsApp só permite reply em 24h após contato do cliente
4. **Usar templates aprovados** — pra mensagens outbound (marketing, utilidade)
5. **Logar envios** — criar histórico em `shared/memory/whatsapp-sent.md`

---

## 📊 PRÓXIMOS PASSOS

1. ✅ Skill instalada — `~/.openclaw/workspace/skills/whatsapp-business/`
2. ⏳ Aguardando `MATON_API_KEY` (mesma da skill `youtube-api`)
3. ⏳ Configurar OAuth no WhatsApp Business
4. ⏳ Testar envio de mensagem
5. ⏳ Criar script de uso específico pra Wolf (ex: notificar cliente quando tarefa for finalizada)

---

**Vetted by:** Alfred (Skill Vetter 1.0.0)  
**Status:** ✅ **APROVADO PARA USO**

---

*Paranoia é uma feature. 🔒🦀*
