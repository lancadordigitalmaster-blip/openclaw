# security.md — Titan Sub-Skill: Segurança
# Ativa quando: "segurança", "vulnerabilidade", "token exposto", "acesso indevido"

---

## CHECKLIST DE SEGURANÇA WOLF

```
NÍVEL 1 — BÁSICO (todo projeto)
  □ Secrets em .env, nunca no código
  □ .env no .gitignore
  □ .env.example com chaves mas sem valores
  □ HTTPS em todos os endpoints (não HTTP)
  □ JWT com expiração definida (não "never expires")
  □ Senhas hasheadas com bcrypt (não MD5, não SHA1 puro)

NÍVEL 2 — APIs E INTEGRAÇÕES
  □ Rate limiting em endpoints públicos
  □ Validação de input em TODOS os endpoints (não só no frontend)
  □ Headers de segurança: CORS configurado corretamente
  □ Webhook secrets verificados (não aceita qualquer POST)
  □ API keys com escopo mínimo necessário (read-only quando possível)

NÍVEL 3 — DADOS E BANCO
  □ Queries parametrizadas (prepared statements)
  □ Dados sensíveis encriptados em repouso (não só em trânsito)
  □ Backup automático configurado
  □ Acesso ao banco só por connection string
  □ Princípio do menor privilégio: usuário do app não tem acesso de admin

NÍVEL 4 — OPENCLAW ESPECÍFICO
  □ API keys dos agentes com permissões mínimas
  □ Gate de aprovação humana para ações irreversíveis
  □ Logs de auditoria para ações dos agentes
  □ SOUL.md com limites explícitos documentados
  □ Nunca injeta conteúdo de página web diretamente como prompt (prompt injection)
```

---

## RESPOSTA A INCIDENTE DE SEGURANÇA

```
T+0 — CONTENÇÃO IMEDIATA
  1. Revoga credenciais expostas IMEDIATAMENTE (não espera investigar)
  2. Isola o sistema se necessário (coloca em manutenção)
  3. Preserva logs (não apaga nada — evidência)
  4. Notifica Netto no Telegram

T+1h — AVALIAÇÃO
  □ O que foi exposto? (quais dados/sistemas)
  □ Por quanto tempo a brecha existiu?
  □ Vetor de entrada: como aconteceu?
  □ Quem pode ter acessado? (IPs, user agents nos logs)

T+4h — REMEDIAÇÃO
  □ Corrige a vulnerabilidade explorada
  □ Gera novas credenciais
  □ Deploy da versão corrigida
  □ Verifica que a brecha está fechada

T+24h — POST-MORTEM
  □ Linha do tempo completa
  □ Causa raiz (não o sintoma)
  □ Por que não foi detectado antes?
  □ Ações para não acontecer de novo
  □ Notificações legais se dados pessoais foram expostos (LGPD: < 72h para ANPD)
```

---

## SCAN DE SEGURANÇA RÁPIDO

```bash
# Procura secrets no código (nunca deve retornar nada)
grep -rn "sk-\|api_key\|apikey\|password\|secret\|token" \
  --include="*.js" --include="*.ts" --include="*.py" \
  --exclude-dir=node_modules --exclude-dir=.git .

# Verifica dependências com vulnerabilidades
npm audit --audit-level=moderate   # Node.js
pip-audit                           # Python

# Verifica se .env está no .gitignore
cat .gitignore | grep -c "\.env"   # deve retornar >= 1
```
