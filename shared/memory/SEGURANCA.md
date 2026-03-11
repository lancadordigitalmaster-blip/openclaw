# 🔒 SEGURANÇA DO ALFRED
## Configuração de Acesso | Wolf Agency

---

## ✅ CONFIGURAÇÃO ATUAL

### Acesso no Privado (DM)
```
Política: ALLOWLIST (lista de permissão)
Apenas IDs autorizados: [789352357]
```

**Significado:**
- ✅ **Netto (789352357)** — Acesso total no privado
- ❌ **Outros usuários** — Bloqueados no privado

### Acesso em Grupos
```
Política: OPEN (aberto)
Funcionamento: Responde a menções e comandos
```

**Significado:**
- ✅ Qualquer pessoa pode me usar em grupos
- ✅ Respondo quando mencionado (@alfredwolf_bot)
- ✅ Respondo a comandos (/status, /relatorio, etc)

---

## 🛡️ MENSAGEM DE BLOQUEIO

Quando alguém tentar me usar no privado sem autorização:

```
🚫 Acesso Negado

Este bot é privado e exclusivo para uso da Wolf Agency.

Se você faz parte da equipe, entre em contato com:
📧 Netto (@wilsongirotto)

Para suporte comercial:
🌐 wolfagency.com
```

---

## 🔧 COMO FUNCIONA

### No Privado (Direct Message)
1. Usuário envia mensagem
2. Sistema verifica ID
3. Se ID = 789352357 → ✅ Processa
4. Se ID ≠ 789352357 → ❌ Bloqueia + envia mensagem

### Em Grupos
1. Qualquer pessoa pode me mencionar
2. Qualquer pessoa pode usar comandos
3. Sistema processa normalmente
4. Respostas visíveis para todos

---

## 📝 ARQUIVO DE CONFIGURAÇÃO

**Local:** `~/.openclaw/openclaw.json`

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "allowFrom": ["789352357"],
      "groupPolicy": "open",
      ...
    }
  }
}
```

---

## 🔄 COMO ALTERAR

### Adicionar novo usuário autorizado (privado):
1. Editar `openclay.json`
2. Adicionar ID em `allowFrom`
3. Reiniciar o bot

### Bloquear grupo específico:
1. Editar `openclay.json`
2. Remover grupo de `groups`
3. Reiniciar o bot

---

## 📊 LOGS DE ACESSO

Tentativas de acesso não autorizado são registradas em:
- Console do sistema
- Arquivos de log do OpenClaw

---

## 🎯 RESUMO

| Contexto | Quem pode usar |
|----------|----------------|
| Privado (DM) | Apenas Netto (789352357) |
| Grupos | Qualquer membro do grupo |
| Comandos | Qualquer membro (em grupos) |

**Status:** ✅ SEGURO — Configurado corretamente

---

*Configuração de Segurança | Alfred | Wolf Agency*
*Atualizado: 2026-03-05*
