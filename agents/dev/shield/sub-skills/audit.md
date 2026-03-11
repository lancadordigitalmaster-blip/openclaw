# audit.md — SHIELD Sub-Skill: Security Audit
# Ativa quando: "audit", "auditoria", "revisa segurança", "vulnerabilidade"

---

## Processo de Auditoria Wolf

```
1. ESCOPO → 2. COLETA → 3. ANÁLISE → 4. RELATÓRIO → 5. REMEDIAÇÃO → 6. VERIFICAÇÃO
```

**Escopo antes de começar:** Definir sistemas, componentes e profundidade. Auditoria sem escopo é retrabalho.

---

## Checklist de Auditoria Completo

### Código
- [ ] Secrets/credenciais hardcoded no código
- [ ] Inputs sem validação/sanitização
- [ ] SQL queries com concatenação de string (SQL injection)
- [ ] Outputs não escapados (XSS)
- [ ] Logs com dados sensíveis (senhas, tokens, PII)
- [ ] Funções criptográficas fracas (MD5, SHA1 para senhas)
- [ ] Tratamento de erros que expõe stack traces
- [ ] Dependências com versões pinadas

### Dependências
- [ ] Dependências desatualizadas com CVEs conhecidas
- [ ] Dependências não utilizadas (aumentam superfície de ataque)
- [ ] Licenças incompatíveis com uso comercial

### Configurações
- [ ] Debug mode ativo em produção
- [ ] Headers de segurança HTTP ausentes
- [ ] CORS muito permissivo (`Access-Control-Allow-Origin: *`)
- [ ] Rate limiting ausente em endpoints críticos
- [ ] HTTPS forçado em todos os endpoints
- [ ] Cookies sem flags `httpOnly` e `Secure`

### Acessos
- [ ] Princípio do menor privilégio aplicado
- [ ] Contas de serviço com permissões excessivas
- [ ] MFA ativo para acessos críticos (Cloud, GitHub, etc.)
- [ ] Tokens e API keys com escopo mínimo necessário
- [ ] Acessos de ex-funcionários revogados

---

## Ferramentas por Categoria

### JavaScript / Node.js
```bash
# Auditoria de dependências
npm audit
npm audit --audit-level=high

# Auditoria com fix automático (cuidado: pode quebrar compatibilidade)
npm audit fix

# Análise estática de segurança
npx semgrep --config=p/javascript --include="*.js,*.ts" .
```

### Python
```bash
# Auditoria de dependências
pip install pip-audit
pip-audit

# Scan de secrets e vulnerabilidades
pip install semgrep
semgrep --config=p/python .

# Checagem de pacotes com CVEs
safety check
```

### Git — Secrets no Histórico
```bash
# Instalar git-secrets
brew install git-secrets       # macOS
git secrets --install          # instala hooks no repo atual
git secrets --register-aws     # patterns AWS

# Scan do histórico completo
git secrets --scan-history

# TruffleHog — scan profundo
docker run --rm -it -v "$PWD:/pwd" trufflesecurity/trufflehog:latest \
  filesystem /pwd --only-verified
```

### Análise Estática Geral
```bash
# Semgrep — regras para múltiplas linguagens
semgrep --config=p/security-audit .
semgrep --config=p/owasp-top-ten .
semgrep --config=p/secrets .

# Output em JSON para relatório
semgrep --config=p/security-audit --json > audit_results.json
```

---

## Template de Relatório de Auditoria

```markdown
# Relatório de Auditoria de Segurança
**Sistema:** [nome]
**Data:** [data]
**Auditor:** SHIELD / [nome]
**Escopo:** [descrição]

## Resumo Executivo
- **Críticas:** [N]
- **Altas:** [N]
- **Médias:** [N]
- **Baixas:** [N]

## Findings

### [ID-001] [Título da Vulnerabilidade]
**Severidade:** CRÍTICA / ALTA / MÉDIA / BAIXA
**Categoria:** OWASP A0X
**Arquivo/Localização:** `path/to/file.ts:42`

**Descrição:**
[O que é o problema e por que é um risco]

**Evidência:**
```código vulnerável aqui```

**Remediação:**
```código corrigido aqui```

**Prazo:** [imediato / 7 dias / 30 dias]

---

## Plano de Remediação
| ID | Severidade | Responsável | Prazo | Status |
|----|-----------|-------------|-------|--------|
| 001 | CRÍTICA | Dev | 24h | Pendente |
```

---

## Severidade e SLA de Remediação

| Severidade | Critério | SLA Wolf |
|-----------|---------|---------|
| CRÍTICA | Exposição de dados, auth bypass, RCE | 24 horas |
| ALTA | Escalada de privilégios, injection | 7 dias |
| MÉDIA | Informação sensível exposta, CSRF | 30 dias |
| BAIXA | Boas práticas, melhorias | 90 dias |

---

## Frequência de Auditoria

| Tipo | Frequência |
|------|-----------|
| Scan automático de dependências | A cada PR (GitHub Actions) |
| Scan de secrets | A cada push (pre-commit hook) |
| Auditoria completa de código | Trimestral |
| Pentest completo | Semestral |
| Revisão de acessos | Mensal |

### GitHub Actions — Scan Automático
```yaml
# .github/workflows/security-audit.yml
name: Security Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit
        run: npm audit --audit-level=high

      - name: Run Semgrep
        uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/secrets
            p/owasp-top-ten
```
