# inline-docs.md — Quill Sub-Skill: Documentação Inline
# Ativa quando: "comentário", "JSDoc", "docstring", "inline"

## Propósito

Comentários no código comunicam intenção que o código em si não consegue expressar. O objetivo não é explicar o que o código faz (o código já faz isso) — é explicar **por que** faz assim, especialmente quando a razão não é óbvia.

**Regra Wolf:** se você precisa comentar o que o código faz, refatore o código. Se precisa comentar por que, escreva o comentário.

---

## Quando Comentar

### Comente SEMPRE:
- Decisões de negócio não óbvias no código
- Workarounds para bugs externos ou limitações de API
- Algoritmos não triviais (com referência se houver)
- Por que uma abordagem foi escolhida em vez de outra mais óbvia
- TODO/FIXME com contexto (não só "TODO: melhorar isso")

### NÃO comente:
- O que o código claramente já diz
- Ruído que fica desatualizado

---

## Exemplos: Bom vs Ruim

### Comentário ruim (explica o quê, não o porquê)

```typescript
// Multiplica por 100
const percentage = ratio * 100;

// Verifica se usuário está ativo
if (user.status === 'active') { ... }

// Loop pelos itens
for (const item of items) { ... }
```

### Comentário bom (explica por que)

```typescript
// Meta Ads API retorna spend em centavos de dólar, mas exibimos em reais.
// Taxa de câmbio é buscada diariamente às 6h (ver currency.service.ts).
const spendBRL = (spendCents / 100) * exchangeRate;

// Attribution window de 7 dias é o padrão Meta, mas clientes de e-commerce
// geralmente preferem 1 dia para evitar inflação de conversões.
// Ver ADR-012 para discussão completa.
const DEFAULT_ATTRIBUTION_WINDOW = '1d';

// Delay de 500ms necessário: Evolution API tem race condition quando
// instância acabou de conectar. Bug reportado e aberto: #evolution-api/1234.
await sleep(500);
await evolutionClient.sendMessage(instanceId, message);
```

### TODO/FIXME com contexto

```typescript
// TODO(@joao, 2025-01-15): Remover quando Meta Ads migrar para API v20.
// Field 'reach' está deprecated em v18 mas ainda funciona.
// Tracking issue: https://developers.facebook.com/...
const reach = insight.reach ?? insight.unique_reach;

// FIXME: Esta query está fazendo N+1. Precisa de eager loading.
// Impacto atual: ~200ms de overhead por request com > 10 campanhas.
// Prioridade: média. Não bloqueia, mas deve resolver antes de escalar.
const campaigns = await Campaign.findAll();
for (const campaign of campaigns) {
  campaign.adsets = await AdSet.findAll({ campaignId: campaign.id });
}
```

---

## JSDoc para TypeScript

Use JSDoc em todas as funções públicas de serviços e bibliotecas. Não em controllers (documentados pelo OpenAPI) e não em código interno óbvio.

### Função simples

```typescript
/**
 * Calcula o ROAS (Return on Ad Spend) de uma campanha.
 *
 * @param revenue - Receita gerada pelas conversões (em reais)
 * @param spend - Gasto total com anúncios (em reais)
 * @returns ROAS como número decimal. Ex: 3.5 significa R$3,50 por R$1,00 investido.
 * @throws {Error} Se spend for zero ou negativo.
 */
export function calculateROAS(revenue: number, spend: number): number {
  if (spend <= 0) throw new Error('Spend must be positive');
  return revenue / spend;
}
```

### Classe com métodos

```typescript
/**
 * Cliente para Meta Ads Graph API.
 *
 * Implementa retry automático e rate limiting.
 * Documentação da API: https://developers.facebook.com/docs/marketing-apis/
 */
export class MetaAdsClient {
  /**
   * Busca insights de campanha para um período.
   *
   * @param campaignId - ID da campanha no Meta Ads
   * @param dateRange - Período de análise (inclusive em ambos os lados)
   * @param fields - Campos a retornar. Default: CAMPAIGN_DEFAULT_FIELDS
   * @returns Insights agregados do período
   *
   * @example
   * const insights = await client.getCampaignInsights('120207...', {
   *   since: '2024-01-01',
   *   until: '2024-01-31',
   * });
   * console.log(insights.spend); // 1500.50
   */
  async getCampaignInsights(
    campaignId: string,
    dateRange: DateRange,
    fields: string[] = CAMPAIGN_DEFAULT_FIELDS,
  ): Promise<CampaignInsights> {
    // ...
  }
}
```

### Tipos complexos

```typescript
/**
 * Configuração de sincronização de dados de uma conta de anúncios.
 *
 * Controla frequência, campos e janela de atribuição usada
 * ao sincronizar dados do Meta Ads para o banco local.
 */
export interface SyncConfig {
  /** ID da conta de anúncios no Meta Business Manager */
  accountId: string;
  /**
   * Frequência de sincronização em minutos.
   * Mínimo: 1. Máximo: 1440 (24h).
   * Default varia por horário (ver adaptive-scheduler.ts).
   */
  intervalMinutes: number;
  /** Janela de atribuição para conversões. Afeta todos os dados de conversão. */
  attributionWindow: '1d' | '7d' | '28d';
}
```

---

## Docstrings Python (Google Style)

```python
def calculate_roas(revenue: float, spend: float) -> float:
    """Calcula o ROAS (Return on Ad Spend) de uma campanha.

    Args:
        revenue: Receita gerada pelas conversões, em reais.
        spend: Gasto total com anúncios, em reais.

    Returns:
        ROAS como float. Exemplo: 3.5 = R$3,50 por R$1,00 investido.

    Raises:
        ValueError: Se spend for zero ou negativo.

    Example:
        >>> calculate_roas(revenue=10500, spend=3000)
        3.5
    """
    if spend <= 0:
        raise ValueError(f"spend must be positive, got {spend}")
    return revenue / spend


def sync_account_insights(
    account_id: str,
    date_range: DateRange,
    *,
    force_refresh: bool = False,
) -> list[InsightRecord]:
    """Sincroniza insights de uma conta com o banco de dados local.

    Busca dados do Meta Ads API e upsert no banco.
    Em condições normais, usa cache de 1 hora. Use force_refresh=True
    para ignorar cache (ex: após mudança de campanha).

    Args:
        account_id: ID da conta no Meta Business Manager.
        date_range: Período a sincronizar.
        force_refresh: Se True, ignora cache e força busca na API.
            Atenção: consome quota de API. Use com moderação.

    Returns:
        Lista de registros sincronizados (inseridos + atualizados).

    Note:
        Esta função é idempotente: pode ser chamada múltiplas vezes
        para o mesmo período sem criar duplicatas.
    """
    # ...
```

---

## Documentar Decisões de Negócio no Código

Quando uma regra de negócio não óbvia influencia o código:

```typescript
// Regra de negócio: campanhas com budget < R$50/dia são consideradas "micro"
// e recebem otimização diferente (menor janela de teste, CTR mínimo mais baixo).
// Definida com CS em 2024-03-15. Valor ajustável em config/business-rules.ts.
const MICRO_BUDGET_THRESHOLD = 50;

// Clientes enterprise (plano > R$5k/mês) têm SLA de sincronização de 1 minuto.
// Demais clientes: 5 minutos. Definido em SLA.md.
const syncInterval = isEnterprise(client) ? 60_000 : 300_000;

// Meta Ads cobra por impressão, mas otimiza por conversão quando
// budget >= 50x custo por conversão estimado. Abaixo disso, o
// algoritmo não tem dados suficientes. Threshold documentado:
// https://www.facebook.com/business/help/...
if (dailyBudget < estimatedCPA * 50) {
  warnings.push('Budget insuficiente para otimização por conversão');
}
```

---

## Checklist de Inline Docs

- [ ] Funções públicas de serviços têm JSDoc/docstring
- [ ] Parâmetros não óbvios documentados com descrição e unidade
- [ ] Exemplos em JSDoc para funções complexas
- [ ] Decisões de negócio explicadas com contexto
- [ ] Workarounds de bugs externos têm link para issue
- [ ] TODO/FIXME têm owner, data e contexto
- [ ] Sem comentários que só repetem o código
- [ ] Constantes de negócio têm comentário explicando origem
