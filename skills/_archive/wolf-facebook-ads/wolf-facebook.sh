#!/bin/bash
# Wolf Facebook Ads API Integration Script
# Uso: ./wolf-facebook.sh --account="act_XXX" --action="summary|campaigns" [--days=N]

set -e

# Carregar variáveis de ambiente
ENV_FILE="/Users/thomasgirotto/.openclaw/workspace/.env.facebook"
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Verificar token
if [[ -z "$FACEBOOK_ACCESS_TOKEN" ]]; then
    echo '{"error": "Token de acesso não configurado. Verifique .env.facebook"}'
    exit 1
fi

API_VERSION="v18.0"
BASE_URL="https://graph.facebook.com/$API_VERSION"

# Parse argumentos
ACCOUNT=""
ACTION=""
DAYS=7

while [[ $# -gt 0 ]]; do
    case $1 in
        --account=*)
            ACCOUNT="${1#*=}"
            shift
            ;;
        --action=*)
            ACTION="${1#*=}"
            shift
            ;;
        --days=*)
            DAYS="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$ACCOUNT" ]]; then
    echo '{"error": "Conta não especificada. Use --account=act_XXX"}'
    exit 1
fi

# Calcular datas
SINCE=$(date -v-${DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${DAYS} days ago" +%Y-%m-%d)
UNTIL=$(date +%Y-%m-%d)

# Executar ação
if [[ "$ACTION" == "campaigns" ]]; then
    curl -s "$BASE_URL/$ACCOUNT/campaigns?fields=id,name,status,effective_status&access_token=$FACEBOOK_ACCESS_TOKEN" | jq .
    
elif [[ "$ACTION" == "summary" ]]; then
    # Métricas agregadas da conta
    curl -s "$BASE_URL/$ACCOUNT/insights?fields=account_name,spend,impressions,clicks,ctr,cpc,conversions,cost_per_conversion,reach,frequency&time_range[since]=$SINCE&time_range[until]=$UNTIL&access_token=$FACEBOOK_ACCESS_TOKEN" | jq .
    
else
    echo '{"error": "Ação não reconhecida. Use: campaigns, summary"}'
    exit 1
fi