# backup.md — ATLAS Sub-Skill: Backup & Restore
# Ativa quando: "backup banco", "restore", "dump", "pg_dump"

## pg_dump e pg_restore

### Backup completo (recomendado: formato custom para restauração seletiva)
```bash
# Formato custom (-Fc) — comprimido, restauração seletiva possível
pg_dump \
  --format=custom \
  --compress=9 \
  --no-owner \
  --no-privileges \
  --verbose \
  --file="backup_$(date +%Y%m%d_%H%M%S).dump" \
  "$DATABASE_URL"

# Formato SQL (para inspeção manual, maior tamanho)
pg_dump \
  --format=plain \
  --no-owner \
  --file="backup_$(date +%Y%m%d_%H%M%S).sql" \
  "$DATABASE_URL"

# Só schema (sem dados — para comparação estrutural)
pg_dump \
  --schema-only \
  --no-owner \
  --file="schema_$(date +%Y%m%d).sql" \
  "$DATABASE_URL"
```

### Restore
```bash
# Restore completo de formato custom
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --verbose \
  --dbname="$RESTORE_DATABASE_URL" \
  backup_20240315_120000.dump

# Restore de tabela específica
pg_restore \
  --table=ad_campaigns \
  --data-only \
  --no-owner \
  --dbname="$RESTORE_DATABASE_URL" \
  backup_20240315_120000.dump

# Restore de arquivo SQL plain
psql "$RESTORE_DATABASE_URL" < backup_20240315_120000.sql
```

---

## Script de Backup Automatizado

```bash
#!/bin/bash
# scripts/backup-db.sh

set -euo pipefail

# Configurações
BACKUP_DIR="/var/backups/wolf-db"
S3_BUCKET="${BACKUP_S3_BUCKET:-s3://wolf-backups/postgres}"
DATABASE_URL="${DATABASE_URL:?DATABASE_URL obrigatória}"
RETENTION_DAILY=7
RETENTION_WEEKLY=28   # 4 semanas
RETENTION_MONTHLY=90  # 3 meses

# Tipos de backup por dia da semana
DAY_OF_WEEK=$(date +%u)   # 1=segunda, 7=domingo
DAY_OF_MONTH=$(date +%d)

if [ "$DAY_OF_MONTH" = "01" ]; then
  BACKUP_TYPE="monthly"
elif [ "$DAY_OF_WEEK" = "7" ]; then
  BACKUP_TYPE="weekly"
else
  BACKUP_TYPE="daily"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="${BACKUP_TYPE}_${TIMESTAMP}.dump"
BACKUP_PATH="${BACKUP_DIR}/${FILENAME}"

# Cria diretório se não existir
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Iniciando backup ${BACKUP_TYPE}: ${FILENAME}"

# Executa backup
pg_dump \
  --format=custom \
  --compress=9 \
  --no-owner \
  --no-privileges \
  --file="$BACKUP_PATH" \
  "$DATABASE_URL"

# Verifica integridade do arquivo
BACKUP_SIZE=$(stat -f%z "$BACKUP_PATH" 2>/dev/null || stat -c%s "$BACKUP_PATH")
if [ "$BACKUP_SIZE" -lt 1024 ]; then
  echo "[ERRO] Backup suspeito — tamanho menor que 1KB: ${BACKUP_SIZE} bytes"
  exit 1
fi

echo "[$(date)] Backup criado: ${BACKUP_PATH} ($(du -sh "$BACKUP_PATH" | cut -f1))"

# Upload para S3
aws s3 cp "$BACKUP_PATH" "${S3_BUCKET}/${BACKUP_TYPE}/${FILENAME}" \
  --storage-class STANDARD_IA

echo "[$(date)] Upload concluído: ${S3_BUCKET}/${BACKUP_TYPE}/${FILENAME}"

# Limpeza local — mantém últimos 2 backups locais
ls -t "${BACKUP_DIR}/${BACKUP_TYPE}_"*.dump | tail -n +3 | xargs -r rm -f

# Limpeza S3 por tipo
case "$BACKUP_TYPE" in
  daily)
    # Remove diários com mais de 7 dias
    aws s3 ls "${S3_BUCKET}/daily/" | \
      awk '{print $4}' | \
      sort | head -n -${RETENTION_DAILY} | \
      xargs -I{} aws s3 rm "${S3_BUCKET}/daily/{}"
    ;;
  weekly)
    aws s3 ls "${S3_BUCKET}/weekly/" | \
      awk '{print $4}' | \
      sort | head -n -4 | \
      xargs -I{} aws s3 rm "${S3_BUCKET}/weekly/{}"
    ;;
  monthly)
    aws s3 ls "${S3_BUCKET}/monthly/" | \
      awk '{print $4}' | \
      sort | head -n -3 | \
      xargs -I{} aws s3 rm "${S3_BUCKET}/monthly/{}"
    ;;
esac

echo "[$(date)] Backup ${BACKUP_TYPE} concluído com sucesso."
```

### Cron para backup automatizado:
```bash
# /etc/cron.d/wolf-db-backup (no servidor de produção ou via job do Railway/Render)

# Backup diário às 3h
0 3 * * * root DATABASE_URL="$DATABASE_URL" BACKUP_S3_BUCKET="s3://wolf-backups/postgres" /opt/scripts/backup-db.sh >> /var/log/wolf-backup.log 2>&1
```

---

## Backup Incremental vs Completo

| Tipo         | Quando usar                                 | Ferramenta             |
|--------------|---------------------------------------------|------------------------|
| Completo     | Padrão Wolf — simples e confiável           | pg_dump custom format  |
| Incremental  | Tabelas > 50GB, WAL archiving necessário    | pg_basebackup + WAL    |
| PITR         | Ambientes enterprise, RPO < 1 hora          | Supabase PITR, Barman  |

Para 99% dos projetos Wolf: **backup completo diário é suficiente e mais seguro**.

```bash
# pg_basebackup para backup incremental (quando necessário)
pg_basebackup \
  --pgdata=/var/backups/basebackup \
  --format=tar \
  --gzip \
  --wal-method=stream \
  --checkpoint=fast \
  --progress \
  --dbname="$DATABASE_URL"
```

---

## Teste de Restore — OBRIGATÓRIO

**Um backup não testado não é um backup.**

```bash
#!/bin/bash
# scripts/test-restore.sh — executar mensalmente ou após mudanças críticas

set -euo pipefail

BACKUP_FILE="${1:?Informe o arquivo de backup}"
TEST_DB="wolf_restore_test_$(date +%Y%m%d)"
DATABASE_HOST="${DATABASE_HOST:-localhost}"

echo "[$(date)] Iniciando teste de restore: ${BACKUP_FILE}"

# Cria banco de teste
psql -h "$DATABASE_HOST" -U postgres -c "CREATE DATABASE ${TEST_DB};"

# Restaura
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --dbname="postgresql://postgres@${DATABASE_HOST}/${TEST_DB}" \
  "$BACKUP_FILE"

echo "[$(date)] Restore concluído. Validando dados..."

# Validações básicas
psql -h "$DATABASE_HOST" -U postgres -d "$TEST_DB" <<'EOF'
-- Conta tabelas principais
SELECT table_name, (xpath('/row/cnt/text()',
  query_to_xml(format('SELECT count(*) AS cnt FROM %I', table_name), false, true, ''))
)[1]::text::int AS row_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY row_count DESC;
EOF

# Remove banco de teste após validação
psql -h "$DATABASE_HOST" -U postgres -c "DROP DATABASE ${TEST_DB};"

echo "[$(date)] Teste de restore concluído com sucesso. Banco de teste removido."
```

---

## Política de Retenção Wolf

| Tipo       | Frequência    | Retenção     | Storage S3          |
|------------|---------------|--------------|---------------------|
| Diário     | Toda noite 3h | 7 dias       | STANDARD_IA         |
| Semanal    | Domingo 2h    | 4 semanas    | STANDARD_IA         |
| Mensal     | Dia 1 do mês  | 3 meses      | GLACIER             |

---

## Supabase Backup Automático

```bash
# Supabase Pro e acima: Point-in-Time Recovery (PITR) nativo
# Configurar em: Dashboard > Settings > Database > Backups

# Backup manual via Supabase CLI
supabase db dump --db-url "$SUPABASE_DB_URL" > backup_$(date +%Y%m%d).sql

# Restore via Supabase CLI
supabase db restore --db-url "$TARGET_SUPABASE_DB_URL" < backup_20240315.sql
```

### Checklist Supabase Backup:
- [ ] PITR habilitado (requer plano Pro ou superior)
- [ ] Retenção de PITR configurada (padrão: 7 dias)
- [ ] Backup manual testado antes de cada release major
- [ ] `supabase db dump` testado na máquina local

---

## Checklist Backup

- [ ] Script de backup automatizado com cron configurado
- [ ] Upload para S3 ou storage externo (não apenas local)
- [ ] Política de retenção implementada (diário/semanal/mensal)
- [ ] Integridade do arquivo verificada após cada backup
- [ ] Teste de restore executado mensalmente e documentado
- [ ] Alertas de falha de backup configurados (email/Slack)
- [ ] Acesso ao backup restrito (IAM policy no S3, credenciais separadas)
- [ ] Tempo de restore medido e documentado (RPO/RTO conhecidos)
