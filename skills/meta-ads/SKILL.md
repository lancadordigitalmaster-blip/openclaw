# SKILL.md — Meta Ads · Gerenciamento de Campanhas
# Wolf Agency AI System | Versão: 1.0 | Criado: 2026-03-05

> Criar, duplicar, pausar, ativar e gerenciar campanhas no Meta Ads
> Aprovação humana obrigatória antes de qualquer publicação

---

## Agent

**Alfred** — orquestrador. Gabi pode solicitar ações via Alfred.
Toda operação de escrita passa por aprovação humana no Telegram.

---

## Triggers

```
"cria campanha" | "sobe campanha" | "nova campanha" | "campanha meta"
"duplica campanha" | "copia campanha" | "clona campanha"
"pausa campanha" | "pausar campanha" | "desliga campanha"
"ativa campanha" | "reativar campanha" | "liga campanha"
"status campanhas" | "campanhas ativas" | "minhas campanhas"
"/meta" | "meta ads" | "facebook ads criar"
"briefing campanha" | "sobe do briefing"
"aprova campanha" | "rejeita campanha"
```

---

## Configuração

```bash
# Em: /Users/thomasgirotto/.openclaw/.env
META_ADS_ACCESS_TOKEN=...        # User ou System User Token (ads_management + ads_read)
META_AD_ACCOUNT_ID=act_XXXXXXX   # Conta de anúncios (formato act_)
META_PAGE_ID=...                 # ID da página do Facebook
META_INSTAGRAM_ACTOR_ID=...      # ID da conta Instagram vinculada (opcional)
META_PIXEL_ID=...                # Pixel para conversões (opcional)
FACEBOOK_APP_ID=3783969975067279 # App ID (já configurado)
```

### Permissões necessárias no token
- `ads_management` — criar/editar/pausar campanhas
- `ads_read` — ler métricas e campanhas existentes
- `business_management` — gerenciar conta de negócios
- `pages_read_engagement` — vincular página nos criativos

### Gerar novo token
Graph API Explorer: https://developers.facebook.com/tools/explorer/
- Selecionar app Wolf Agency (ID: 3783969975067279)
- Marcar permissões acima
- Gerar token → copiar para .env

---

## API Meta — Referência

Base URL: `https://graph.facebook.com/v21.0`

### Headers padrão
```bash
META_TOKEN=$(grep META_ADS_ACCESS_TOKEN /Users/thomasgirotto/.openclaw/.env | cut -d= -f2)
META_ACCOUNT=$(grep META_AD_ACCOUNT_ID /Users/thomasgirotto/.openclaw/.env | cut -d= -f2)
META_PAGE=$(grep META_PAGE_ID /Users/thomasgirotto/.openclaw/.env | cut -d= -f2)
```

---

## Operações Disponíveis

### 1. Listar campanhas ativas

```bash
curl -s -G "https://graph.facebook.com/v21.0/$META_ACCOUNT/campaigns" \
  -d "fields=id,name,status,objective,daily_budget,lifetime_budget,start_time,stop_time" \
  -d "filtering=[{\"field\":\"effective_status\",\"operator\":\"IN\",\"value\":[\"ACTIVE\",\"PAUSED\"]}]" \
  -d "access_token=$META_TOKEN"
```

### 2. Criar campanha (PAUSED)

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/$META_ACCOUNT/campaigns" \
  -d "name=[RASCUNHO] NOME_DA_CAMPANHA" \
  -d "objective=OUTCOME_SALES" \
  -d "status=PAUSED" \
  -d "buying_type=AUCTION" \
  -d "special_ad_categories=[]" \
  -d "access_token=$META_TOKEN"
```

Objetivos válidos (API v21.0):
- `OUTCOME_AWARENESS` — Reconhecimento
- `OUTCOME_TRAFFIC` — Tráfego
- `OUTCOME_ENGAGEMENT` — Engajamento
- `OUTCOME_LEADS` — Leads/Cadastros
- `OUTCOME_APP_PROMOTION` — Promoção de app
- `OUTCOME_SALES` — Vendas/Conversões

### 3. Criar conjunto de anúncios

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/$META_ACCOUNT/adsets" \
  -d "name=NOME_CONJUNTO" \
  -d "campaign_id=CAMPAIGN_ID" \
  -d "daily_budget=10000" \
  -d "start_time=2026-03-10T00:00:00-0300" \
  -d "billing_event=IMPRESSIONS" \
  -d "optimization_goal=CONVERSIONS" \
  -d "bid_strategy=LOWEST_COST_WITHOUT_CAP" \
  -d "targeting={\"age_min\":18,\"age_max\":65,\"geo_locations\":{\"countries\":[\"BR\"]},\"publisher_platforms\":[\"facebook\",\"instagram\"]}" \
  -d "status=PAUSED" \
  -d "access_token=$META_TOKEN"
```

Nota: `daily_budget` em centavos (R$100 = 10000)

### 4. Criar criativo (ad creative)

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/$META_ACCOUNT/adcreatives" \
  -d "name=NOME_CRIATIVO" \
  -d 'object_story_spec={"page_id":"PAGE_ID","link_data":{"message":"TEXTO DO ANUNCIO","link":"https://exemplo.com","name":"TITULO","description":"DESCRICAO","call_to_action":{"type":"LEARN_MORE"},"image_url":"https://exemplo.com/imagem.jpg"}}' \
  -d "access_token=$META_TOKEN"
```

CTAs válidos: `SHOP_NOW`, `LEARN_MORE`, `SIGN_UP`, `CONTACT_US`, `BOOK_TRAVEL`, `DOWNLOAD`, `GET_OFFER`, `GET_QUOTE`, `SUBSCRIBE`, `WHATSAPP_MESSAGE`

### 5. Criar anúncio (vinculando criativo ao adset)

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/$META_ACCOUNT/ads" \
  -d "name=NOME_ANUNCIO" \
  -d "adset_id=ADSET_ID" \
  -d "creative={\"creative_id\":\"CREATIVE_ID\"}" \
  -d "status=PAUSED" \
  -d "access_token=$META_TOKEN"
```

### 6. Pausar campanha

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/CAMPAIGN_ID" \
  -d "status=PAUSED" \
  -d "access_token=$META_TOKEN"
```

### 7. Ativar campanha (após aprovação)

```bash
curl -s -X POST "https://graph.facebook.com/v21.0/CAMPAIGN_ID" \
  -d "status=ACTIVE" \
  -d "name=NOME_SEM_RASCUNHO" \
  -d "access_token=$META_TOKEN"
```

### 8. Buscar campanhas por nome

```bash
curl -s -G "https://graph.facebook.com/v21.0/$META_ACCOUNT/campaigns" \
  -d "fields=id,name,status,objective" \
  -d "filtering=[{\"field\":\"name\",\"operator\":\"CONTAIN\",\"value\":\"TERMO_BUSCA\"}]" \
  -d "access_token=$META_TOKEN"
```

### 9. Buscar interesses (para targeting)

```bash
curl -s -G "https://graph.facebook.com/v21.0/search" \
  -d "type=adinterest" \
  -d "q=TERMO" \
  -d "access_token=$META_TOKEN"
```

### 10. Duplicar campanha

Não há endpoint nativo de duplicação. O protocolo é:
1. GET campanha original (fields: name,objective,adsets{...},ads{creative})
2. POST nova campanha com mesmos dados + status PAUSED
3. POST novo adset copiando targeting/budget
4. POST novo ad vinculando criativo existente

---

## Protocolo de Criação (Campanha do Zero)

```
META_ADS_CREATE_PROTOCOL:

  1. COLETAR DADOS — perguntar ao usuário ou extrair do briefing:
     → Nome da campanha
     → Objetivo (conversão, tráfego, leads, etc.)
     → Orçamento diário (em R$)
     → Data de início (e fim, se houver)
     → Público-alvo (idade, gênero, localização, interesses)
     → Texto do anúncio (título, corpo, descrição)
     → CTA (Comprar, Saiba Mais, etc.)
     → URL de destino
     → Imagem/vídeo (URL ou descrição)

  2. VALIDAR antes de criar:
     → Nome preenchido?
     → Objetivo válido?
     → Orçamento >= R$1,00/dia e <= R$500,00/dia (limite de segurança)?
     → Título <= 40 chars?
     → Texto <= 125 chars?
     → CTA definido?
     → URL válida?

  3. MOSTRAR RESUMO ao usuário e pedir confirmação:
     "Vou criar a seguinte campanha como RASCUNHO (pausada):"
     [exibir todos os dados formatados]
     "Confirma? (sim/não)"

  4. CRIAR na Meta (tudo PAUSED):
     → POST campaign (status: PAUSED, nome com prefixo [RASCUNHO])
     → POST adset (budget, targeting, otimização)
     → POST adcreative (copy, imagem, CTA)
     → POST ad (vinculando criativo ao conjunto)

  5. ENVIAR APROVAÇÃO no Telegram:
     Mensagem formatada com todos os dados + IDs
     Instruir: "Responda 'aprovar [ID]' para ativar ou 'rejeitar [ID]' para descartar"

  6. AGUARDAR APROVAÇÃO:
     → "aprovar [CAMPAIGN_ID]" → ativar campanha (ACTIVE) + remover [RASCUNHO] do nome
     → "rejeitar [CAMPAIGN_ID]" → deletar ou manter pausada
     → Sem resposta em 1h → manter pausada, notificar

  NUNCA criar campanha com status ACTIVE.
  NUNCA pular a etapa de confirmação do usuário.
```

---

## Protocolo de Briefing (Texto Natural → Campanha)

```
META_ADS_BRIEFING_PROTOCOL:

  O usuário pode enviar um briefing em texto livre. Exemplo:
  "Cliente: Nike | Produto: Air Max | R$150/dia | Conversão
   Público: 18-35, esportes e moda | Copy: Corra com estilo"

  PASSOS:
  1. Extrair campos do texto (nome, objetivo, budget, público, copy, etc.)
  2. Inferir campos faltantes com defaults seguros:
     → Objetivo não informado → OUTCOME_TRAFFIC (mais seguro)
     → Idade não informada → 18-65
     → Gênero não informado → todos
     → Localização não informada → Brasil inteiro
     → CTA não informado → LEARN_MORE
     → Data início não informada → amanhã
  3. Mostrar o que foi extraído + o que foi inferido
  4. Pedir confirmação antes de criar
  5. Seguir META_ADS_CREATE_PROTOCOL a partir do passo 4
```

---

## Protocolo de Duplicação

```
META_ADS_DUPLICATE_PROTOCOL:

  1. Buscar campanha original por ID ou nome parcial
  2. Se múltiplas encontradas → listar e pedir seleção
  3. GET dados completos (campanha + adsets + ads + criativos)
  4. Perguntar o que alterar:
     → Novo nome? (default: "[CÓPIA] nome_original")
     → Novo orçamento?
     → Novo público?
     → Novas datas?
  5. Criar nova campanha PAUSED com dados copiados + alterações
  6. Seguir fluxo de aprovação
```

---

## Protocolo de Pausa/Ativação

```
META_ADS_PAUSE_ACTIVATE_PROTOCOL:

  PAUSAR:
  1. Buscar campanha(s) por ID, nome parcial, ou "todas do cliente X"
  2. Se múltiplas → listar e pedir confirmação: "Pausar todas essas?"
  3. POST status=PAUSED para cada uma
  4. Confirmar: "Campanha [NOME] pausada."

  ATIVAR:
  1. Buscar campanha pausada por ID ou nome
  2. Mostrar dados da campanha (orçamento, público)
  3. Pedir confirmação: "Ativar [NOME] com R$[X]/dia?"
  4. POST status=ACTIVE
  5. Confirmar: "Campanha [NOME] ativada."

  REGRA: Ativar campanha é operação sensível — SEMPRE pedir confirmação.
```

---

## Regras de Segurança (NÃO NEGOCIÁVEIS)

```
META_ADS_SECURITY:

  1. STATUS INICIAL: toda campanha criada deve ser PAUSED — sem exceção
  2. PREFIXO: nome sempre começa com "[RASCUNHO]" até ser aprovada
  3. LIMITE ORÇAMENTO DIÁRIO: máximo R$500,00/dia sem aprovação especial
  4. LIMITE ORÇAMENTO VITALÍCIO: máximo R$5.000,00 total
  5. CONFIRMAÇÃO OBRIGATÓRIA para: criar, ativar, pausar múltiplas, alterar orçamento
  6. CTA OBRIGATÓRIO: não criar anúncio sem call-to-action
  7. TOKEN APENAS DO .ENV: nunca exibir, logar ou armazenar token em outro lugar
  8. LOG DE TODA OPERAÇÃO: registrar em shared/memory/meta-ads-log.yaml
  9. CAMPANHAS ATIVAS: nunca editar campanha ativa sem pausar primeiro
  10. ORÇAMENTO EM CENTAVOS: converter R$ → centavos antes de enviar (R$100 = 10000)
```

---

## Business Managers e Tokens

3 BMs configurados — usar o token correto para cada conta:

| BM | Env Var | App ID |
|----|---------|--------|
| Wolf (principal) | `META_ADS_ACCESS_TOKEN` | EAAUR6... |
| Forlan | `META_ADS_TOKEN_FORLAN` | EAA1xg... |
| Marcos | `META_ADS_TOKEN_MARCOS` | EAAVNk... |

Todos os tokens acessam as mesmas 30+ contas. Usar `META_ADS_ACCESS_TOKEN` (Wolf) como padrão.

## Contas Vinculadas (status=1 ativas)

| Conta | Ad Account ID | Uso |
|-------|---------------|-----|
| Netto Girotto | act_135916159825609 | Wolf principal |
| William Forlan | act_299753830 | Forlan |
| CA 02 - Samela Vaz | act_1361305232030279 | Samela |
| CA 05 - Samela Vaz | act_4412988082269343 | Samela reserva |
| CA 01 - Douglas Barros | act_443286126941481 | Douglas |
| Ticomia | act_1336968033454787 | Ticomia |
| CA Mariana | act_1252598652228497 | Mariana |
| Wolf - Conta Ativa | act_778150330707016 | Wolf |
| Alcance Digital 01 | act_802335904872502 | Alcance |
| CA - 03 | act_284816457777004 | - |
| CA - MARIANA | act_373729035058420 | Mariana |
| CA - WOLF | act_373707301883674 | Wolf |
| savvymatchapp | act_2035845846791700 | - |
| Conta 02 | act_253546710763500 | - |
| CA02 - Pix da Lora | act_941256024067459 | - |
| CA - RODRIGO | act_1423910631544031 | Rodrigo |
| CA 02 | act_1075849246976763 | - |
| CA 05 | act_1267972427509860 | - |
| CA Vitor - 03 | act_3017291581746738 | Vitor |
| Nova Conta Wolf - 01 | act_553368457476412 | Wolf |
| CA - Victor | act_1079755044205405 | Victor |
| CA Vitor - 02 | act_1024002839843359 | Vitor |
| CA 01 - Imperatriz | act_598174206429014 | Imperatriz |
| CA - Wolf Ativa | act_765280409786040 | Wolf |
| 01 | act_753495254070575 | - |

Contas desativadas (status=2/3): GR Veiculos, Cambistas, Cambistas 02, Samela vaz 01, Wolf Pack CA Nova

Default: usar `META_AD_ACCOUNT_ID` do .env (act_135916159825609). Se usuário especificar cliente, usar a conta correspondente.

---

## Tratamento de Erros

| Código | Significado | Ação |
|--------|-------------|------|
| 100 | Parâmetro inválido | Identificar campo errado e pedir correção |
| 190 | Token expirado | Notificar: "Token Meta expirado. Gere um novo em developers.facebook.com/tools/explorer/" |
| 200 | Permissão negada | Verificar escopos do token |
| 294 | Conta desabilitada | Bloquear operações e alertar |
| 1487394 | Política violada | Revisar copy/criativo — possível texto proibido |
| 17 | Rate limit | Aguardar 60s e tentar novamente |
| 2500 | Token inválido | Mesmo tratamento do 190 |

---

## Formato de Aprovação (Telegram)

```
APROVAÇÃO NECESSÁRIA — Meta Ads
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Campanha: [NOME]
Objetivo: [OBJETIVO]
Orçamento diário: R$ [VALOR]
Início: [DATA]
Público: [DESCRIÇÃO]
Placements: Automático

Preview:
  Título: [TÍTULO]
  Texto: [TEXTO]
  CTA: [CTA]
  URL: [URL]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID: [CAMPAIGN_ID]

Responda:
  "aprovar [ID]" para publicar
  "rejeitar [ID]" para descartar
```

---

## Formato de Confirmação

```
Meta Ads atualizado: [ação executada]
ID: [id retornado]
Status: [PAUSED/ACTIVE]
```

---

## Log de Auditoria

Salvar em `shared/memory/meta-ads-log.yaml`:

```yaml
- timestamp: "2026-03-05T10:00:00-03:00"
  action: CREATE_CAMPAIGN
  operator: netto
  campaign_id: "123456789"
  campaign_name: "[RASCUNHO] Nike Air Max - Conversão"
  budget_daily: 15000  # centavos
  result: SUCCESS
  approved: false
```

---

## Integração com Gabi

Gabi pode solicitar criação de campanhas via Alfred:
- Gabi analisa e recomenda estrutura de campanha
- Alfred executa via meta-ads skill
- Resultado volta para Gabi avaliar

Gabi NUNCA cria campanhas diretamente — sempre via Alfred + aprovação humana.

---

*Skill: meta-ads | Versão: 1.0 | Criado: 2026-03-05*
