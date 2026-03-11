# secrets.md — SHIELD Sub-Skill: Secrets Management
# Ativa quando: "secrets", "credenciais", ".env", "API key", "vazamento"

---

## Hierarquia de Secrets Wolf

```
Desenvolvimento local   → .env.local (nunca commitado)
Staging                 → .env.staging (nunca commitado) ou Doppler staging
Produção                → Doppler production / GitHub Secrets / Variáveis do servidor
```

**Regra absoluta:** Nenhum arquivo `.env` com valores reais vai para o repositório. Jamais.

---

## Estrutura de .env Wolf

```bash
# .env.example — COMMITADO (valores fictícios, documenta todas as variáveis)
NODE_ENV=development
APP_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# JWT
JWT_SECRET=your-super-secret-key-here
JWT_REFRESH_SECRET=your-refresh-secret-here

# Google APIs
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GA4_PROPERTY_ID=123456789

# Meta Ads
META_ACCESS_TOKEN=your-meta-access-token
META_APP_SECRET=your-meta-app-secret

# Telegram
TELEGRAM_BOT_TOKEN=bot:your-token-here
TELEGRAM_ALERT_CHAT_ID=-100123456789
```

```bash
# .env.local — NUNCA commitado (valores reais de dev)
NODE_ENV=development
DATABASE_URL=postgresql://wolf:senha_real@localhost:5432/wolf_dev
JWT_SECRET=dev-secret-muito-seguro-32-chars-min
# ...
```

---

## Doppler — Gestão de Secrets por Ambiente

```bash
# Instalar Doppler CLI
brew install dopplerhq/cli/doppler    # macOS

# Autenticar
doppler login

# Configurar projeto
doppler setup
# Selecionar: projeto → ambiente

# Rodar aplicação com secrets injetados
doppler run -- node server.js
doppler run -- python main.py
doppler run -- npm run dev

# Ver secrets do ambiente atual
doppler secrets

# Exportar para .env (uso local temporário)
doppler secrets download --no-file --format env > .env.local
```

---

## GitHub Secrets — CI/CD

```yaml
# .github/workflows/deploy.yml
# Secrets configurados em: Settings → Secrets and variables → Actions

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
          META_ACCESS_TOKEN: ${{ secrets.META_ACCESS_TOKEN }}
        run: ./deploy.sh
```

```bash
# Adicionar secret via GitHub CLI
gh secret set DATABASE_URL --body "postgresql://..."
gh secret set JWT_SECRET < jwt-secret.txt  # De arquivo (mais seguro para valores longos)

# Listar secrets (sem revelar valores)
gh secret list
```

---

## Scan de Secrets no Código

### git-secrets — Prevenção em Pre-commit
```bash
# Instalar
brew install git-secrets

# Configurar no repo
cd /path/to/repo
git secrets --install
git secrets --register-aws

# Adicionar patterns customizados Wolf
git secrets --add 'META_ACCESS_TOKEN[A-Za-z0-9_-]{100,}'
git secrets --add 'PRIVATE KEY'
git secrets --add 'bot:[0-9]+:[A-Za-z0-9_-]+'  # Telegram bot token pattern

# Scan do histórico completo
git secrets --scan-history
```

### TruffleHog — Scan Profundo
```bash
# Scan de repositório local
docker run --rm -v "$PWD:/pwd" trufflesecurity/trufflehog:latest \
  git file:///pwd --only-verified

# Scan de repositório GitHub
docker run --rm trufflesecurity/trufflehog:latest \
  github --org=wolf-agency --only-verified

# Scan de histórico de commits
trufflehog git https://github.com/wolf-agency/repo.git
```

### GitHub Secret Scanning (automático)
```yaml
# Ativar em: Settings → Code security → Secret scanning
# Alertas automáticos quando secrets de parceiros são detectados
# (AWS, GCP, Meta, GitHub, etc.)

# Para repos privados: ativar "Push protection"
# Bloqueia push se contiver secrets conhecidos
```

---

## Quando um Secret Vaza

### Protocolo Wolf — Resposta Imediata

```
T+0: REVOGA o secret comprometido (não espera confirmar — age primeiro)
T+0: Regenera credencial nova
T+15min: Audita logs de acesso do período de exposição
T+30min: Atualiza todas as instâncias com a nova credencial
T+1h: Confirma que todas as integrações estão funcionando
T+4h: Post-mortem (como vazou, como prevenir)
```

### Checklist por Tipo de Secret

**API Key genérica:**
```bash
# 1. Revogar imediatamente no painel do serviço
# 2. Gerar nova key
# 3. Auditar logs do serviço para uso suspeito
# 4. Atualizar em todos os ambientes/deployments
```

**AWS Credentials:**
```bash
# 1. Desativar access key imediatamente
aws iam update-access-key --access-key-id AKIA... --status Inactive
# 2. Verificar uso suspeito
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIA...
# 3. Gerar nova key, aplicar principle of least privilege
# 4. Deletar a key comprometida
aws iam delete-access-key --access-key-id AKIA...
```

**Database credentials:**
```bash
# 1. Alterar senha imediatamente
ALTER USER wolf_user WITH PASSWORD 'nova_senha_forte';
# 2. Revogar sessões ativas
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'wolf_user';
# 3. Auditar query logs do período
# 4. Verificar se dados foram exfiltrados
```

**JWT Secret:**
```bash
# Trocar o secret invalida TODOS os tokens existentes (todos os usuários precisam relogar)
# 1. Trocar JWT_SECRET e JWT_REFRESH_SECRET
# 2. Fazer deploy imediato
# 3. Comunicar usuários se necessário
```

---

## Rotação Periódica de Credenciais

| Tipo | Frequência | Responsável |
|------|-----------|-------------|
| Tokens de API de clientes (Meta, Google) | A cada 60 dias ou quando membro sai | Dev/Ops |
| Tokens internos de integração | 90 dias | Dev |
| Database passwords (prod) | 180 dias | Ops |
| Service Account keys | 90 dias | Dev |
| JWT secrets | 180 dias (ou após incidente) | Dev |

```python
# Script para verificar credenciais próximas da expiração
from datetime import datetime, timedelta
import json

def check_credential_rotation(credentials_registry: list[dict]) -> list[dict]:
    """Verifica credenciais que precisam de rotação em breve."""
    today = datetime.now().date()
    due_soon = []

    for cred in credentials_registry:
        last_rotated = datetime.strptime(cred["last_rotated"], "%Y-%m-%d").date()
        next_rotation = last_rotated + timedelta(days=cred["rotation_days"])
        days_until = (next_rotation - today).days

        if days_until <= 14:  # Avisar 14 dias antes
            due_soon.append({
                **cred,
                "days_until_rotation": days_until,
                "overdue": days_until < 0,
            })

    return sorted(due_soon, key=lambda x: x["days_until_rotation"])
```

---

## .gitignore Obrigatório

```gitignore
# Secrets — NUNCA commitar
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
.env.staging
.env.production

# Credenciais de serviços
credentials/
*.pem
*.key
*.p12
*_sa.json
service-account*.json
google-credentials*.json

# Outros
*.log
node_modules/
__pycache__/
.venv/
```

---

## Checklist Secrets

- [ ] .env.example com todos os campos (sem valores reais) commitado
- [ ] .env.local e .env.* com valores reais no .gitignore
- [ ] git-secrets instalado com hooks no repo
- [ ] GitHub Secret Scanning ativado (inclui Push Protection)
- [ ] Doppler ou equivalente configurado para CI/CD
- [ ] Rotação de credenciais calendarizada
- [ ] Registro de credenciais ativas mantido (sem os valores)
- [ ] Processo de resposta a vazamento documentado e de conhecimento da equipe
