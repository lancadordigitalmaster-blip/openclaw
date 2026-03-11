# SKILL.md — Wolf Criar Grupo · Criação Inteligente de Grupos Telegram
# Wolf Agency AI System | Versão: 1.0 | Criado: 2026-03-05

> Cria e configura grupos Telegram com propósito, boas-vindas e pin automático.
> Funciona em 2 fases: Alfred prepara o setup → usuário cria o grupo → Alfred configura.

---

## Agent

**Alfred** — orquestrador da Wolf Agency. Netto usa esta skill via DM ou grupo.

---

## Triggers

```
"/criargrupo"
"/criar_grupo"
"cria um grupo" | "criar grupo" | "novo grupo"
"cria o grupo de" | "cria o grupo para"
"cria um grupo para o cliente" | "cria o grupo da campanha"
"/configurargrupo"
"/configurar_grupo"
"configura esse grupo" | "configurar o grupo"
```

---

## Limitação importante (leia antes de executar)

A API do Telegram NÃO permite que bots criem grupos. Apenas contas de usuário
podem criar grupos/supergrupos. Por isso esta skill opera em 2 fases:

- **FASE 1 — /criargrupo**: Alfred prepara tudo (nome formatado, descrição, mensagem de
  boas-vindas) e envia o pacote completo para Netto criar o grupo manualmente (30 segundos).
- **FASE 2 — /configurargrupo**: Após o grupo criado e o bot adicionado como admin, Alfred
  usa a API do Telegram (setChatDescription + sendMessage + pinChatMessage) para completar
  a configuração automaticamente.

---

## FASE 1 — Comando /criargrupo

### Sintaxe aceita

```
/criargrupo [nome do grupo] | [propósito]
/criargrupo [nome do grupo]
cria um grupo para [contexto]
cria o grupo [nome] focado em [propósito]
```

### Exemplos reais

```
/criargrupo Campanha Nike Julho | Gestão da campanha de mídia paga Nike Q3
/criargrupo Onboarding Cliente ABC | Comunicação interna do onboarding ABC
/criargrupo Sprint Design Semana 12 | Revisão e aprovação das peças da semana 12
cria um grupo para o cliente [nome] focado em criativos de julho
```

### Protocolo de execução — FASE 1

```
WOLF_CRIAR_GRUPO_FASE1:

  1. PARSEAR o input:
     → Separar por "|" se presente: parte esquerda = nome, parte direita = propósito
     → Se não houver "|": nome = input completo, propósito = deduzir do contexto
     → Remover "/criargrupo" e variações naturais do início
     → Truncar nome para máximo 255 caracteres (manter palavras inteiras)

  2. FORMATAR o nome do grupo:
     → Capitalizar corretamente (título case)
     → Remover caracteres especiais problemáticos (\n, \t, excesso de espaços)
     → Se propósito não informado: deduzir do nome ("Campanha X" → "Gestão da campanha X")

  3. GERAR a descrição oficial:
     Formato: "[PROPÓSITO] • Criado em [DD/MM/YYYY] • by Alfred"
     Máximo: 255 caracteres (truncar com "..." se necessário)

  4. GERAR a mensagem de boas-vindas usando o template abaixo

  5. SALVAR o pacote em /tmp/wolf-grupo-pendente.json para FASE 2

  6. RESPONDER ao usuário com o pacote de criação (formato abaixo)
```

### Template mensagem de boas-vindas

Usar exatamente este template, substituindo as variáveis:

```
👋 *Bem-vindos ao [NOME_DO_GRUPO]*

📋 *Propósito*
[PROPÓSITO]

📌 *Regras do grupo*
1. Mantenha as conversas focadas no propósito acima
2. Use threads para assuntos específicos
3. Marque @Alfred para ações, dúvidas ou automações
4. Decisões importantes devem ser fixadas

🤖 *Alfred está ativo neste grupo*
Comandos disponíveis:
• /status — resumo das atividades
• /tarefa [descrição] — criar tarefa no ClickUp
• /resumo — resumir as últimas mensagens
• /ajuda — ver todos os comandos

_Grupo criado em [DD/MM/YYYY] via OpenClaw_
```

### Salvar pacote pendente

Salvar em `/tmp/wolf-grupo-pendente.json`:

```bash
cat > /tmp/wolf-grupo-pendente.json << 'JSONEOF'
{
  "nome": "[NOME_FORMATADO]",
  "proposito": "[PROPÓSITO]",
  "descricao": "[DESCRIÇÃO_FORMATADA]",
  "boas_vindas": "[MENSAGEM_BOAS_VINDAS_ESCAPADA]",
  "criado_por": "[chat_id do solicitante]",
  "criado_em": "[ISO timestamp]"
}
JSONEOF
```

### Resposta para Netto — FASE 1

Enviar esta resposta formatada:

```
✅ *Pacote de grupo preparado!*

📌 *Nome:* [NOME]
🎯 *Propósito:* [PROPÓSITO]
📝 *Descrição:* [DESCRIÇÃO]

━━━━━━━━━━━━━━━━━━
*Próximos passos (30 segundos):*
1. No Telegram: Novo Grupo → nome: *[NOME]*
2. Adicione *@alfredwolf_bot* ao grupo
3. Promova o bot a *Administrador*
   _(permissões: Gerenciar grupo + Fixar mensagens + Convidar usuários)_
4. No novo grupo, envie: `/configurargrupo`
━━━━━━━━━━━━━━━━━━

_Quando você enviar /configurargrupo no grupo, Alfred vai:_
_→ definir descrição oficial_
_→ enviar e fixar a mensagem de boas-vindas_
_→ confirmar aqui quando pronto_
```

---

## FASE 2 — Comando /configurargrupo

### Quando executar

Este comando deve ser enviado **dentro do novo grupo** após o bot ter sido adicionado
como administrador. Alfred vai completar a configuração automaticamente.

### Configuração necessária

```bash
# Ler token do bot de openclaw.json
BOT_TOKEN=$(cat /Users/thomasgirotto/.openclaw/openclaw.json | python3 -c "
import json,sys
cfg = json.load(sys.stdin)
print(cfg['channels']['telegram']['botToken'])
")
```

### Protocolo de execução — FASE 2

```
WOLF_CRIAR_GRUPO_FASE2:

  1. LER o pacote pendente de /tmp/wolf-grupo-pendente.json
     → Se arquivo não existir: pedir ao usuário para descrever o propósito
       (exemplo: "Para qual propósito é este grupo? Vou configurá-lo agora.")

  2. OBTER o chat_id do grupo atual (disponível no contexto da mensagem)

  3. LER o BOT_TOKEN de openclaw.json (ver configuração acima)

  4. EXECUTAR os 3 passos via API do Telegram (ver comandos bash abaixo)

  5. CONFIRMAR para Netto no DM original (se criado_por disponível no pacote)
```

### Passo 2a — Definir descrição

```bash
# Definir descrição do grupo
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setChatDescription" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": CHAT_ID_AQUI,
    \"description\": \"DESCRIÇÃO_AQUI\"
  }"
```

### Passo 2b — Enviar mensagem de boas-vindas

```bash
# Enviar mensagem de boas-vindas
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": CHAT_ID_AQUI,
    \"text\": \"MENSAGEM_BOAS_VINDAS_AQUI\",
    \"parse_mode\": \"Markdown\"
  }")

# Extrair o message_id da resposta para usar no pin
MESSAGE_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['message_id'])")
```

### Passo 2c — Fixar a mensagem de boas-vindas

```bash
# Fixar a mensagem de boas-vindas
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/pinChatMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": CHAT_ID_AQUI,
    \"message_id\": ${MESSAGE_ID},
    \"disable_notification\": false
  }"
```

### Passo 2d — Gerar link de convite

```bash
# Gerar link de convite permanente
INVITE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/createChatInviteLink" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": CHAT_ID_AQUI,
    \"name\": \"Link oficial — [NOME_DO_GRUPO]\",
    \"creates_join_request\": false
  }")

INVITE_LINK=$(echo "$INVITE" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['invite_link'])")
```

### Passo 2e — Limpar arquivo temporário

```bash
rm -f /tmp/wolf-grupo-pendente.json
```

### Resposta de confirmação — FASE 2

Enviar no grupo e no DM do solicitante:

```
✅ *Grupo configurado com sucesso!*

📌 *[NOME_DO_GRUPO]*
🎯 *Propósito:* [PROPÓSITO]
📝 *Descrição:* definida ✅
📌 *Mensagem de boas-vindas:* fixada ✅
🔗 *Link de convite:* [INVITE_LINK]

_Alfred está ativo. Use /ajuda para ver os comandos disponíveis._
```

---

## Tratamento de erros

| Erro | O que fazer |
|------|-------------|
| `/tmp/wolf-grupo-pendente.json` não encontrado | Pedir ao usuário o nome e propósito do grupo para completar o setup |
| `setChatDescription` retorna erro | Verificar se o bot é administrador com permissão "Gerenciar grupo" e instruir Netto |
| `sendMessage` retorna erro | Tentar novamente. Se falhar, enviar a mensagem de boas-vindas manualmente no chat |
| `pinChatMessage` retorna erro `not_enough_rights` | Informar: "Para fixar a mensagem, promova o bot a admin com permissão 'Fixar mensagens'" |
| `createChatInviteLink` retorna erro | Pular este passo e omitir o link na confirmação |
| Bot não é admin no grupo | Responder: "Preciso ser administrador para configurar o grupo. Vá em Configurações do Grupo → Administradores → Adicione @alfredwolf_bot com as permissões: Gerenciar grupo, Fixar mensagens, Convidar usuários" |

---

## Tratamento de linguagem natural

Quando o usuário usar variações naturais (sem /criargrupo), Alfred deve:

1. Detectar a intenção de criar um grupo via palavras-chave nos Triggers
2. Extrair nome e propósito do texto natural:
   - "cria um grupo para o cliente X focado em Y" → nome: "Cliente X", propósito: "Y"
   - "cria o grupo da campanha Z" → nome: "Campanha Z", propósito: deduzir do contexto
   - "novo grupo para sprint design semana 12" → nome: "Sprint Design Semana 12"
3. Se nome ou propósito forem ambíguos, perguntar antes de continuar:
   - "Vou criar o grupo *[NOME]*. Correto? Qual o propósito principal?"
4. Após confirmação, executar FASE 1 normalmente

---

## Configuração padrão (para referência)

```json
{
  "groupCreation": {
    "supergroup": true,
    "autoPin": true,
    "defaultPermissions": {
      "can_send_messages": true,
      "can_send_media_messages": true,
      "can_invite_users": false
    }
  }
}
```

> Nota: `can_invite_users: false` protege o grupo de membros adicionarem pessoas sem
> aprovação. Membros novos devem ser adicionados via link de convite gerado pelo bot.

---

## Activity Log

```
[TIMESTAMP] [WolfCriarGrupo] FASE: [1/2] | GRUPO: [nome] | RESULTADO: ok/erro | DETALHE: [resumo]
```

---

*Skill: wolf-criar-grupo | Versão: 1.0 | Criado: 2026-03-05*
