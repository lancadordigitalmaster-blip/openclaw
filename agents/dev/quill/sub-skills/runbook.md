# runbook.md — Quill Sub-Skill: Runbooks Operacionais
# Ativa quando: "runbook", "como operar", "troubleshooting", "manual"

## Propósito

Runbook existe para ser executado às 3h da manhã por um dev estressado que não conhece o sistema em detalhes. Se o runbook depende de conhecimento implícito, ele falhou.

**Princípios:**
- Passos numerados, um por um. Sem ambiguidade.
- Saída esperada após cada comando relevante.
- O que fazer quando der errado — não só o happy path.
- Rollback sempre documentado.

---

## Template de Runbook Wolf

```markdown
# Runbook: [Nome do Procedimento]

**Serviço:** nome-do-servico
**Owner:** @nome-do-responsavel
**Última atualização:** YYYY-MM-DD
**Testado em:** YYYY-MM-DD

---

## Quando Usar

Descreva exatamente quando este runbook deve ser executado.
Exemplo: "Quando o serviço de campanhas não está processando novas tarefas
e o dashboard mostra fila > 1000 items por mais de 5 minutos."

## Pré-condições

- [ ] Acesso SSH ao servidor de produção configurado
- [ ] Variável `$ENV` exportada (staging | production)
- [ ] 1Password aberto com vault "Wolf Infra"
- [ ] Alguém de plantão informado no canal #eng-ops

## Sintomas que Levam Aqui

- Fila de jobs travada por > 5 minutos
- Alertas: `job_processor_queue_depth > 1000`
- Dashboard: coluna "Processando" congelada

---

## Procedimento

### 1. Verificar estado atual

```bash
kubectl get pods -n production | grep job-processor
```

**Saída esperada:**
```
job-processor-7d8f9c-xxxxx   1/1     Running   0          2d
job-processor-7d8f9c-yyyyy   1/1     Running   0          2d
```

**Se diferente:** se algum pod está em `CrashLoopBackOff` ou `Error`, ir para [Seção: Pod em Crash](#pod-em-crash).

### 2. Verificar logs do último restart

```bash
kubectl logs -n production deployment/job-processor --previous --tail=100
```

Procurar por: `ERROR`, `FATAL`, `OOM`, `connection refused`.

**Se encontrar `connection refused` para Redis:** ir para [Seção: Redis Indisponível](#redis-indisponível).

### 3. Verificar profundidade da fila

```bash
redis-cli -h $REDIS_HOST -p 6379 -a $REDIS_PASSWORD LLEN jobs:pending
```

**Saída esperada:** número. Se > 10000, escalar para @tech-lead antes de continuar.

### 4. Reiniciar os workers

```bash
kubectl rollout restart deployment/job-processor -n production
```

**Aguardar rollout completar:**
```bash
kubectl rollout status deployment/job-processor -n production
```

**Saída esperada:**
```
deployment "job-processor" successfully rolled out
```

### 5. Verificar que fila está drenando

Aguardar 2 minutos, então:

```bash
redis-cli -h $REDIS_HOST -p 6379 -a $REDIS_PASSWORD LLEN jobs:pending
```

O número deve estar diminuindo. Se não diminuiu após 2 minutos, ir para [Seção: Fila Não Drena](#fila-não-drena).

---

## Troubleshooting por Cenário

### Pod em Crash

```bash
# Ver eventos do pod específico
kubectl describe pod -n production [POD_NAME]

# Se OOMKilled: aumentar memory limit temporariamente
kubectl set resources deployment/job-processor -n production \
  --limits=memory=2Gi --requests=memory=1Gi
```

### Redis Indisponível

```bash
# Verificar se Redis está de pé
kubectl get pods -n production | grep redis

# Se Redis está down: NÃO tente resolver sozinho às 3h
# Acionar @infra-on-call via PagerDuty
```

### Fila Não Drena

```bash
# Verificar se há jobs com erro travando a fila
redis-cli -h $REDIS_HOST -p 6379 -a $REDIS_PASSWORD LRANGE jobs:failed 0 10

# Se sim: mover jobs com erro para dead-letter
redis-cli -h $REDIS_HOST -p 6379 -a $REDIS_PASSWORD \
  RENAME jobs:failed jobs:dead-letter-$(date +%Y%m%d)
```

---

## Verificação Final

Após procedimento concluído:

- [ ] Todos os pods em `Running`
- [ ] Fila `jobs:pending` diminuindo ativamente
- [ ] Dashboard mostra novas tasks sendo processadas
- [ ] Alertas fechados no Grafana
- [ ] Nenhum erro nos logs dos últimos 5 minutos

```bash
# Comando de verificação rápida
kubectl get pods -n production | grep job-processor && \
  redis-cli -h $REDIS_HOST LLEN jobs:pending
```

---

## Rollback

Se o restart piorou a situação (fila aumentando, erros novos):

```bash
# Voltar para versão anterior
kubectl rollout undo deployment/job-processor -n production

# Verificar que voltou
kubectl rollout status deployment/job-processor -n production
```

Se rollback também falhar: acionar @tech-lead imediatamente.

---

## Histórico de Incidentes

| Data | Sintoma | Causa Raiz | Solução | Tempo de Resolução |
|------|---------|------------|---------|-------------------|
| 2024-11-15 | Fila travada | Leak de memória no worker | Rollback + hotfix | 45min |
| 2024-10-02 | CrashLoopBackOff | Variável ENV faltando | Atualizar secret | 15min |
```

---

## Exemplos de Runbooks Wolf

### Deploy Manual de Emergência

```markdown
# Runbook: Deploy Manual de Emergência

## Quando Usar
CI/CD está down e precisamos fazer deploy crítico de hotfix em produção.

## Procedimento

1. Build local da imagem
```bash
docker build -t wolf-registry/app:hotfix-$(git rev-parse --short HEAD) .
docker push wolf-registry/app:hotfix-$(git rev-parse --short HEAD)
```

2. Atualizar imagem no cluster
```bash
kubectl set image deployment/app app=wolf-registry/app:hotfix-$(git rev-parse --short HEAD) -n production
kubectl rollout status deployment/app -n production
```

3. Verificar logs pós-deploy
```bash
kubectl logs -n production deployment/app --since=5m | grep -E "ERROR|WARN"
```
```

### Restore de Backup PostgreSQL

```markdown
# Runbook: Restore de Backup PostgreSQL

## ATENÇÃO: Operação Destrutiva

Este runbook apaga dados. Confirme DUAS VEZES antes de executar.

## Pré-condições
- [ ] Backup específico identificado (ver S3: s3://wolf-backups/postgres/)
- [ ] Janela de manutenção comunicada
- [ ] Todos os serviços que usam o banco em modo manutenção

## Procedimento

1. Colocar serviços em manutenção
```bash
kubectl scale deployment/api --replicas=0 -n production
```

2. Fazer backup do estado atual (antes de restaurar)
```bash
pg_dump $DATABASE_URL > /tmp/pre-restore-backup-$(date +%Y%m%d-%H%M%S).sql
```

3. Baixar backup do S3
```bash
aws s3 cp s3://wolf-backups/postgres/backup-YYYY-MM-DD.sql.gz /tmp/
gunzip /tmp/backup-YYYY-MM-DD.sql.gz
```

4. Restaurar
```bash
psql $DATABASE_URL < /tmp/backup-YYYY-MM-DD.sql
```

5. Verificar integridade
```bash
psql $DATABASE_URL -c "SELECT COUNT(*) FROM campaigns;"
```

6. Reativar serviços
```bash
kubectl scale deployment/api --replicas=3 -n production
```
```

---

## Checklist de Runbook Completo

- [ ] "Quando usar" com sintomas específicos (não genérico)
- [ ] Pré-condições com checklist antes de começar
- [ ] Cada passo numerado com comando exato
- [ ] Saída esperada documentada para passos críticos
- [ ] Troubleshooting para cada cenário de falha
- [ ] Verificação final com comandos de confirmação
- [ ] Rollback documentado
- [ ] Histórico de incidentes iniciado
- [ ] Owner identificado
- [ ] Data de última atualização
- [ ] Data de último teste real
