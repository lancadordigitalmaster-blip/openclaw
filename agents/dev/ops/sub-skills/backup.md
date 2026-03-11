# backup.md — Ops Sub-Skill: Backup & Disaster Recovery
# Ativa quando: "backup", "restore", "disaster recovery"

## Regra de Ouro

**Backup sem teste de restore não é backup. É esperança.**

Todo backup deve ser testado periodicamente. Documentar a data do último teste de restore.

## Script de Backup PostgreSQL

```bash
#!/bin/bash
# /opt/wolfapp/backups/scripts/backup-postgres.sh

set -euo pipefail

# ─── Configurações ───────────────────────────────────────────────────────────
BACKUP_DIR="/opt/wolfapp/backups/postgres"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="wolfapp_${TIMESTAMP}.sql.gz"
LOG_FILE="/opt/wolfapp/backups/backup.log"

# Carregar variáveis de ambiente
source /opt/wolfapp/.env.prod

# ─── Funções ─────────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_telegram_alert() {
  local message="$1"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_ALERT_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_ALERT_CHAT_ID}" \
      -d "text=${message}" \
      -d "parse_mode=Markdown" > /dev/null 2>&1
  fi
}

# ─── Backup ──────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
log "Starting backup: $BACKUP_FILE"

# Dump comprimido
docker compose -f /opt/wolfapp/docker-compose.prod.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -ne 0 ]; then
  log "ERROR: Backup failed!"
  send_telegram_alert "🚨 *Backup FAILED* — wolfapp PostgreSQL — $(date '+%d/%m/%Y %H:%M')"
  exit 1
fi

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
log "Backup completed: $BACKUP_FILE ($BACKUP_SIZE)"

# ─── Upload para S3/R2 ───────────────────────────────────────────────────────
if [ -n "${S3_BUCKET:-}" ]; then
  log "Uploading to S3: s3://${S3_BUCKET}/postgres/${BACKUP_FILE}"

  AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
  aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" \
    "s3://${S3_BUCKET}/postgres/${BACKUP_FILE}" \
    --endpoint-url "${S3_ENDPOINT_URL:-https://s3.amazonaws.com}" \
    --storage-class STANDARD_IA

  if [ $? -eq 0 ]; then
    log "Upload to S3 completed"
  else
    log "WARNING: S3 upload failed, backup kept locally"
    send_telegram_alert "⚠️ *Backup S3 upload failed* — backup kept locally — $(date '+%d/%m/%Y %H:%M')"
  fi
fi

# ─── Limpeza de backups antigos ───────────────────────────────────────────────
log "Cleaning backups older than ${RETENTION_DAYS} days"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

REMAINING=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
log "Backup rotation complete. ${REMAINING} backup(s) retained."

send_telegram_alert "✅ *Backup OK* — wolfapp — ${BACKUP_FILE} (${BACKUP_SIZE}) — $(date '+%d/%m/%Y %H:%M')"
log "Backup script finished successfully"
```

```bash
# Dar permissão de execução
chmod +x /opt/wolfapp/backups/scripts/backup-postgres.sh
```

## Script de Restore

```bash
#!/bin/bash
# /opt/wolfapp/backups/scripts/restore-postgres.sh
# Uso: ./restore-postgres.sh wolfapp_20260304_030000.sql.gz

set -euo pipefail

BACKUP_FILE="${1:-}"
BACKUP_DIR="/opt/wolfapp/backups/postgres"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file.sql.gz>"
  echo "Available backups:"
  ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "No backups found"
  exit 1
fi

source /opt/wolfapp/.env.prod

BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

# Se não encontrou localmente, tentar baixar do S3
if [ ! -f "$BACKUP_PATH" ] && [ -n "${S3_BUCKET:-}" ]; then
  echo "Backup not found locally. Downloading from S3..."
  AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
  aws s3 cp \
    "s3://${S3_BUCKET}/postgres/${BACKUP_FILE}" \
    "$BACKUP_PATH" \
    --endpoint-url "${S3_ENDPOINT_URL:-https://s3.amazonaws.com}"
fi

if [ ! -f "$BACKUP_PATH" ]; then
  echo "ERROR: Backup file not found: $BACKUP_PATH"
  exit 1
fi

echo "WARNING: This will REPLACE the current database with the backup."
echo "Backup: $BACKUP_FILE"
read -p "Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo "Stopping application..."
docker compose -f /opt/wolfapp/docker-compose.prod.yml stop api workers

echo "Restoring database from: $BACKUP_FILE"
gunzip -c "$BACKUP_PATH" | docker compose -f /opt/wolfapp/docker-compose.prod.yml exec -T postgres \
  psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS ${POSTGRES_DB}; CREATE DATABASE ${POSTGRES_DB};" > /dev/null
gunzip -c "$BACKUP_PATH" | docker compose -f /opt/wolfapp/docker-compose.prod.yml exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

echo "Restore completed. Starting application..."
docker compose -f /opt/wolfapp/docker-compose.prod.yml start api workers

echo "Done. Verify application health: https://api.wolfapp.com/health"
```

## Cron de Backup Diário

```bash
# Editar crontab do usuário deploy
crontab -e

# Adicionar: backup às 3h da manhã todo dia
0 3 * * * /opt/wolfapp/backups/scripts/backup-postgres.sh >> /opt/wolfapp/backups/backup.log 2>&1

# Verificar cron
crontab -l
```

## Backup para Cloudflare R2 (S3-compatible)

```bash
# Instalar AWS CLI
apt install -y awscli

# Configurar variáveis para R2 no .env.prod
S3_BUCKET=wolfapp-backups
S3_ACCESS_KEY=seu_r2_access_key
S3_SECRET_KEY=seu_r2_secret_key
S3_ENDPOINT_URL=https://seu_account_id.r2.cloudflarestorage.com

# Testar upload
AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
aws s3 ls "s3://${S3_BUCKET}/" \
  --endpoint-url "$S3_ENDPOINT_URL"
```

## Política de Retenção

| Tipo          | Frequência | Retenção  | Destino         |
|---------------|------------|-----------|-----------------|
| Diário        | 3h         | 7 dias    | Local + R2/S3   |
| Semanal       | Domingo 4h | 4 semanas | R2/S3           |
| Mensal        | Dia 1 5h   | 12 meses  | R2/S3           |

```bash
# Cron completo (diário + semanal + mensal)
0 3 * * *   /opt/wolfapp/backups/scripts/backup-postgres.sh
0 4 * * 0   RETENTION_DAYS=28 /opt/wolfapp/backups/scripts/backup-postgres.sh
0 5 1 * *   RETENTION_DAYS=365 /opt/wolfapp/backups/scripts/backup-postgres.sh
```

## Teste de Restore — Protocolo Mensal

```bash
# 1. Identificar o backup mais recente
ls -lt /opt/wolfapp/backups/postgres/ | head -5

# 2. Criar banco de dados de teste
docker compose exec postgres psql -U wolf -c "CREATE DATABASE wolfapp_restore_test;"

# 3. Restaurar nesse banco de teste
gunzip -c /opt/wolfapp/backups/postgres/wolfapp_20260304_030000.sql.gz | \
  docker compose exec -T postgres psql -U wolf wolfapp_restore_test

# 4. Verificar contagem de registros chave
docker compose exec postgres psql -U wolf wolfapp_restore_test -c "
  SELECT
    (SELECT COUNT(*) FROM users) AS users,
    (SELECT COUNT(*) FROM campaigns) AS campaigns,
    (SELECT COUNT(*) FROM organizations) AS organizations;
"

# 5. Limpar banco de teste
docker compose exec postgres psql -U wolf -c "DROP DATABASE wolfapp_restore_test;"

# 6. Documentar resultado
echo "$(date) - Restore test OK - backup: wolfapp_20260304_030000.sql.gz" >> /opt/wolfapp/backups/restore-tests.log
```

## Checklist de Backup

- [ ] Script de backup configurado e testado manualmente
- [ ] Cron agendado para 3h da manhã
- [ ] Upload para armazenamento remoto (R2/S3) configurado
- [ ] Alertas Telegram para sucesso e falha de backup
- [ ] Política de retenção aplicada (não deixar disco lotar)
- [ ] Script de restore documentado e testado
- [ ] Teste de restore realizado e documentado (data do último teste)
- [ ] Backups de outros dados críticos identificados (uploads, configs)
