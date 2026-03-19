# Knowledge Brain — Consulta de Base de Conhecimento

## Quando usar
- Quando qualquer agente precisa de conhecimento técnico sobre marketing digital
- Quando Netto pergunta algo sobre tráfego, SEO, copy, vendas, atendimento, etc.
- Quando precisa de regras práticas, frameworks ou decisões baseadas em conhecimento absorvido
- Quando Gabi precisa tomar decisões sobre campanhas

## Como consultar

### Via Supabase REST (sem LLM)
```bash
# Busca textual por título
curl -s "${SUPABASE_URL}/rest/v1/kb_cards?title=ilike.*CPA*&select=title,content,type,confidence,author&limit=5" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"

# Filtrar por domínio
curl -s "${SUPABASE_URL}/rest/v1/kb_cards?domain_id=eq.trafego_pago&select=title,content,type&limit=10" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"

# Filtrar por tipo de card
curl -s "${SUPABASE_URL}/rest/v1/kb_cards?type=eq.regra_pratica&domain_id=eq.trafego_pago&select=title,trigger_condition,practical_output&limit=10" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"

# Filtrar por tópico
curl -s "${SUPABASE_URL}/rest/v1/kb_cards?topics=cs.{escala,cpa}&select=title,content&limit=5" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
```

### Via busca vetorial (com Voyage AI embedding)
```bash
# 1. Gerar embedding da pergunta
EMBEDDING=$(curl -s https://api.voyageai.com/v1/embeddings \
  -H "Authorization: Bearer ${VOYAGE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"input\": [\"Como escalar campanha sem perder CPA?\"], \"model\": \"voyage-3\", \"input_type\": \"query\"}" \
  | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['data'][0]['embedding']))")

# 2. Buscar cards similares via RPC
curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/kb_search" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"p_query_embedding\": $EMBEDDING,
    \"p_domain\": \"trafego_pago\",
    \"p_limit\": 5,
    \"p_agent\": \"alfred\"
  }"
```

### Via script (mais prático)
```bash
# Consulta rápida
node knowledge-brain/scripts/query.js "Como escalar campanha?" --domain trafego_pago --limit 5
```

## Domínios disponíveis
| ID | Nome | Disciplinas |
|----|------|-------------|
| trafego_pago | Tráfego Pago | meta_ads, google_ads, tiktok_ads, linkedin_ads |
| social_media | Social Media | instagram, tiktok_organico, youtube |
| seo | SEO | seo_tecnico, seo_onpage, seo_offpage, seo_local |
| estrategia | Estratégia | - |
| copy | Copywriting | - |
| criativos | Criativos | - |
| vendas | Vendas | crm |
| atendimento | Atendimento | agendamento, scripts_atendimento |
| analytics | Analytics | - |
| automacao | Automação | - |
| email_marketing | Email Marketing | - |
| branding | Branding | - |
| lancamentos | Lançamentos | - |
| ecommerce | E-commerce | - |

## Tipos de card
- `regra_pratica` — "Quando X, faça Y" (acionável)
- `conceito` — Definição/explicação
- `framework` — Metodologia/modelo mental
- `passo_a_passo` — Tutorial com etapas
- `decisao` — Árvore de decisão
- `metrica` — Benchmark/KPI
- `ferramenta` — Como usar uma tool
- `caso_de_uso` — Exemplo real
- `anti_pattern` — O que NÃO fazer

## Regras de uso
1. **Sempre cite a fonte**: "Segundo [autor], no curso [curso]..."
2. Priorize cards `regra_pratica` e `decisao` pra ações
3. Priorize `conceito` e `framework` pra explicações
4. Se confidence = `baixa`, mencione que é opinião do autor
5. Se não encontrar cards relevantes, diga que não tem na base

## Absorção de novos cursos
```bash
cd knowledge-brain

# Hotmart (Chrome aberto e logado)
bash scripts/absorb.sh hotmart URL --author "Autor" --domain dominio

# YouTube
bash scripts/absorb.sh youtube URL --author "Autor" --domain dominio

# Status
bash scripts/absorb.sh status
```
