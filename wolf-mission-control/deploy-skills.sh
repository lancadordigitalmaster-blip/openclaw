#!/bin/bash
# Deploy Agent Skills System ao Supabase
# Roda as migrations e seed data

set -e

echo "🚀 Deploying Agent Skills System..."
echo ""

# Cores pra output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar se jq está instalado (pra parsear JSON)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq não encontrado. Instalando...${NC}"
    brew install jq
fi

# Arquivo de config com credentials
CONFIG_FILE="$HOME/.supabase/credentials.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Arquivo de credenciais não encontrado!${NC}"
    echo "Crie em: $CONFIG_FILE"
    echo ""
    echo "Formato:"
    echo '{'
    echo '  "project_url": "https://seu-project.supabase.co",'
    echo '  "api_key": "seu-anon-key",'
    echo '  "service_role_key": "seu-service-role-key"'
    echo '}'
    exit 1
fi

# Ler credenciais
PROJECT_URL=$(jq -r '.project_url' < "$CONFIG_FILE")
SERVICE_ROLE=$(jq -r '.service_role_key' < "$CONFIG_FILE")

if [ -z "$PROJECT_URL" ] || [ -z "$SERVICE_ROLE" ]; then
    echo -e "${RED}❌ Credenciais inválidas em $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Credenciais carregadas${NC}"
echo "Project: $PROJECT_URL"
echo ""

# ─────────────────────────────────────────────────────────
# MIGRATION 1: Criar tabela agent_skills
# ─────────────────────────────────────────────────────────

MIGRATION_1="wolf-mission-control/migrations/002_agent_skills.sql"

if [ ! -f "$MIGRATION_1" ]; then
    echo -e "${RED}❌ Arquivo não encontrado: $MIGRATION_1${NC}"
    exit 1
fi

echo -e "${BLUE}🔧 Running Migration 1: Agent Skills Schema...${NC}"

SQL_1=$(cat "$MIGRATION_1")

RESPONSE=$(curl -s -X POST \
  "$PROJECT_URL/rest/v1/rpc/query" \
  -H "apikey: $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"query\": $(echo "$SQL_1" | jq -R -s .)}")

if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // .error')
    echo -e "${YELLOW}⚠️  Migration 1 retornou: $ERROR${NC}"
    echo "(Pode ser OK se a tabela já existe)"
else
    echo -e "${GREEN}✅ Migration 1 OK${NC}"
fi

echo ""

# ─────────────────────────────────────────────────────────
# MIGRATION 2: Seed data
# ─────────────────────────────────────────────────────────

SEED_FILE="wolf-mission-control/seeds/agent_skills_data.sql"

if [ ! -f "$SEED_FILE" ]; then
    echo -e "${YELLOW}⚠️  Seed file não encontrado: $SEED_FILE${NC}"
    echo "Pulando seed data..."
else
    echo -e "${BLUE}🌱 Running Seed Data...${NC}"

    SQL_SEED=$(cat "$SEED_FILE")

    RESPONSE=$(curl -s -X POST \
      "$PROJECT_URL/rest/v1/rpc/query" \
      -H "apikey: $SERVICE_ROLE" \
      -H "Content-Type: application/json" \
      -d "{\"query\": $(echo "$SQL_SEED" | jq -R -s .)}")

    if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR=$(echo "$RESPONSE" | jq -r '.error.message // .error')
        echo -e "${YELLOW}⚠️  Seed data retornou: $ERROR${NC}"
    else
        echo -e "${GREEN}✅ Seed Data OK${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Deploy completo!${NC}"
echo ""
echo "Próximos passos:"
echo "1. Integrar AgentCapabilities.jsx no Mission Control"
echo "2. Testar com: SELECT * FROM agent_capability_summary"
echo "3. Customizar seeds pra seus agentes específicos"
echo ""
