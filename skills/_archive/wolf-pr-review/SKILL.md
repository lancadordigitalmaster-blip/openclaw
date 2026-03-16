---

## Agent

**Shield** — QA e revisao

---
name: wolf-pr-review
description: >
  Automatically review GitHub pull requests when triggered by webhook.
  Fetch the diff using gh CLI, analyze for common issues, and send
  a concise review to Telegram. Never post comments to GitHub directly.
  Activate on: pull_request.opened, pull_request.synchronize webhook events.
---

# Wolf PR Review

## Contexto
Alfred recebe eventos de webhook do GitHub quando um PR é aberto ou
atualizado. Analisa o diff e envia review para o Telegram do usuário.
O objetivo é capturar problemas óbvios antes da revisão humana —
**não substituir** a revisão humana.

## Pré-requisitos

- `gh` CLI instalado e autenticado (`gh auth login`)
- Token com permissão `repo:read` (somente leitura)
- Webhook configurado no repo GitHub apontando para o gateway

## Protocolo de Execução

Ao receber o evento de webhook:

1. **Extrair do payload:**
   - `PR_NUMBER` — número do PR
   - `PR_TITLE` — título
   - `PR_AUTHOR` — quem abriu
   - `REPO` — formato `owner/repo`
   - `BASE_BRANCH` — branch de destino
   - `PR_URL` — link direto

2. **Buscar metadados:**
   ```bash
   gh pr view {PR_NUMBER} --repo {REPO} \
     --json title,body,additions,deletions,changedFiles,files
   ```

3. **Buscar o diff:**
   ```bash
   gh pr diff {PR_NUMBER} --repo {REPO}
   ```

4. **Verificar tamanho do diff:**
   - Se `additions + deletions > 500 linhas`:
     - Analisar apenas a lista de arquivos modificados
     - Sinalizar "diff muito grande — revisão manual necessária"
   - Se dentro do limite: analisar o diff completo

5. **Analisar buscando:**

   | Categoria | O que verificar |
   |---|---|
   | 🔴 Crítico | Secrets/tokens hardcoded, SQL injection patterns, credenciais expostas |
   | ⚠️ Atenção | `console.log` com dados sensíveis, ausência de error handling em novos `try/catch` |
   | ⚠️ Atenção | Funções novas sem testes correspondentes |
   | ⚠️ Atenção | Breaking changes em APIs existentes sem versioning |
   | ⚠️ Atenção | Inconsistências com convenções Wolf (prefixos `wolf-*`, `alfred-*`) |
   | ✅ OK | Destacar o que está bem feito (reforço positivo) |

6. **Enviar para Telegram** no formato abaixo
7. **Nunca postar comentários diretamente no GitHub**

## Formato da Mensagem Telegram

```
🔀 PR #{NUMBER} — {TITLE}
👤 {AUTHOR} → {BASE_BRANCH}
📊 +{additions} -{deletions} linhas | {N} arquivos

✅ OK:
  • [ponto positivo 1]
  • [ponto positivo 2]

⚠️ Atenção:
  • {arquivo}:{linha} — [descrição do problema]
  • [descrição do problema]

🔴 Crítico:
  • {arquivo}:{linha} — [descrição do problema]
  (ou "Nenhum encontrado")

🔗 {PR_URL}
```

Se diff muito grande:
```
🔀 PR #{NUMBER} — {TITLE}
👤 {AUTHOR} → {BASE_BRANCH}
📊 +{additions} -{deletions} linhas | {N} arquivos

⚠️ Diff muito grande para análise automática ({N} linhas).
   Arquivos modificados:
   • {arquivo 1}
   • {arquivo 2}
   • ...

🔗 {PR_URL}
```

## Regras de Segurança

| Ação | Permitido |
|---|---|
| Ler diffs e metadados via `gh` CLI | ✅ Sim |
| Enviar review para Telegram | ✅ Sim |
| Postar comentários no GitHub | ❌ Nunca |
| Fazer merge ou aprovar o PR | ❌ Nunca |
| Executar código do PR | ❌ Nunca |
| Checkout do branch do PR localmente | ❌ Nunca (risco de execução de código não confiável) |

## Configuração do Webhook no GitHub

**Settings → Webhooks → Add webhook:**

| Campo | Valor |
|---|---|
| Payload URL | `https://SEU_TUNEL/webhook/github` |
| Content type | `application/json` |
| Secret | Mesmo valor configurado em `openclaw.json` |
| Events | Pull requests: `opened`, `synchronize` |

## Exposição do Gateway (Mac Mini local)

O Mac Mini precisa de URL pública para receber webhooks do GitHub:

```bash
# Instalar cloudflared
brew install cloudflared

# Túnel temporário (para testes)
cloudflared tunnel --url http://localhost:18789

# Túnel permanente (produção)
cloudflared tunnel create wolf-webhook
cloudflared tunnel route dns wolf-webhook webhook.seudominio.com
```

## Limitações Conhecidas

- Análise estática apenas — não executa o código
- Diff > 500 linhas: análise superficial por arquivos
- Sem contexto de histórico do PR em iterações anteriores
- Falsos positivos esperados — sempre revisar com olho humano antes de merge
