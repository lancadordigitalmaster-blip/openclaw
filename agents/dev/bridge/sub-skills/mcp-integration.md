# mcp-integration.md — Bridge Sub-Skill: Integração de Novos MCPs
# Ativa quando: "MCP", "plugin", "conecta ferramenta", "novo MCP"

## Propósito

Bridge é o agente responsável por desenvolver e manter MCPs (Model Context Protocol plugins) que conectam ferramentas externas ao sistema Wolf. Quando uma nova API precisa ser integrada como MCP, Bridge lidera o processo do design à documentação.

---

## O que é um MCP no Contexto Wolf

MCP é uma camada de abstração que expõe ferramentas de uma API externa de forma padronizada para os agentes Wolf utilizarem. Em vez de cada agente integrar diretamente com Meta Ads API, eles chamam `mcp-meta-ads.getCampaignInsights()`.

**Benefícios:**
- Lógica de autenticação centralizada
- Rate limiting e retry gerenciados em um lugar
- Mudanças de API externa afetam apenas o MCP
- Outros agentes não precisam saber sobre OAuth, paginação, etc.

---

## Fonte da Verdade: MCP-GUIDE.md

Toda informação sobre MCPs disponíveis no sistema Wolf vive em:

```
workspace/MCP-GUIDE.md
```

Antes de criar um MCP novo, verificar se já existe ou se pode estender um existente.

---

## Processo de Integração: API Nova → MCP

### Fase 1: Design (antes de qualquer código)

```markdown
# MCP Design Doc: [Nome]

## API a Integrar
- Nome: Meta Ads Graph API
- Versão: v19.0
- Docs: https://developers.facebook.com/docs/marketing-apis/
- Auth: OAuth 2.0 (long-lived token)
- Rate Limit: 200 calls/hora/app

## Ferramentas a Expor (tools)
Lista das operações que os agentes precisarão:
1. `getCampaignInsights(accountId, dateRange, fields?)` → insights agregados
2. `listCampaigns(accountId, status?)` → lista de campanhas
3. `updateCampaignStatus(campaignId, status)` → ativa/pausa campanha
4. `getAdCreatives(adId)` → criativos do anúncio

## Ferramentas a NÃO Expor (agora)
- Criação de campanhas (fora do escopo Wolf atual)
- Gestão de públicos (outro MCP futuro)

## Dependências
- Redis (cache de tokens e rate limit)
- PostgreSQL (armazenamento de refresh_tokens encriptados)

## Estimativa
- Implementação: 3 dias
- Testes: 1 dia
- Documentação: 0.5 dia
```

### Fase 2: Implementação

```typescript
// src/mcps/meta-ads/index.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { MetaAdsClient } from './client';
import { withRetry } from '../../lib/retry';
import { metaAdsCircuit } from '../../lib/circuit-breaker';
import { apiCache } from '../../lib/cache';

const server = new McpServer({
  name: 'mcp-meta-ads',
  version: '1.0.0',
});

// Tool: getCampaignInsights
server.tool(
  'getCampaignInsights',
  {
    description: 'Busca insights de campanhas Meta Ads para um período',
    inputSchema: z.object({
      accountId: z.string().describe('ID da conta no formato act_XXXXXXXXXX'),
      since: z.string().describe('Data de início YYYY-MM-DD'),
      until: z.string().describe('Data de fim YYYY-MM-DD'),
      level: z.enum(['account', 'campaign', 'adset', 'ad']).default('campaign'),
      fields: z.array(z.string()).optional(),
    }),
  },
  async ({ accountId, since, until, level, fields }) => {
    const client = await MetaAdsClient.forAccount(accountId);
    const cacheKey = `meta-insights:${accountId}:${since}:${until}:${level}`;

    const data = await apiCache.get(cacheKey, async () => {
      return metaAdsCircuit.execute(() =>
        withRetry(() => client.getInsights({ accountId, since, until, level, fields }))
      );
    }, { ttl: 3600 });

    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data, null, 2),
      }],
    };
  }
);

// Tool: listCampaigns
server.tool(
  'listCampaigns',
  {
    description: 'Lista campanhas de uma conta Meta Ads',
    inputSchema: z.object({
      accountId: z.string(),
      status: z.array(z.enum(['ACTIVE', 'PAUSED', 'ARCHIVED'])).optional(),
    }),
  },
  async ({ accountId, status }) => {
    const client = await MetaAdsClient.forAccount(accountId);
    const campaigns = await client.getCampaigns(accountId, status);

    return {
      content: [{
        type: 'text',
        text: JSON.stringify(campaigns, null, 2),
      }],
    };
  }
);

export { server };
```

### Fase 3: Testes

```typescript
// src/mcps/meta-ads/__tests__/meta-ads.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest';

describe('MCP Meta Ads', () => {
  describe('getCampaignInsights', () => {
    it('retorna insights cacheados na segunda chamada', async () => {
      const fetcher = vi.fn().mockResolvedValue(mockInsights);
      // Primeira chamada
      await tool.call({ accountId: 'act_123', since: '2024-01-01', until: '2024-01-07' });
      // Segunda chamada
      await tool.call({ accountId: 'act_123', since: '2024-01-01', until: '2024-01-07' });

      expect(fetcher).toHaveBeenCalledTimes(1); // Cache deve ter funcionado
    });

    it('usa fallback quando Meta API retorna 500', async () => {
      vi.spyOn(metaAdsClient, 'getInsights').mockRejectedValue(
        new Error('Meta API Error 500')
      );
      const result = await tool.call({ accountId: 'act_123', since: '2024-01-01', until: '2024-01-07' });
      expect(result._stale).toBe(true); // Deveria retornar cache stale
    });

    it('rejeita accountId sem prefixo act_', async () => {
      await expect(
        tool.call({ accountId: '123456789', since: '2024-01-01', until: '2024-01-07' })
      ).rejects.toThrow();
    });
  });
});
```

### Fase 4: Documentação

Atualizar `MCP-GUIDE.md` e criar sub-skill correspondente.

---

## Estrutura de Diretório de um MCP

```
src/mcps/
└── meta-ads/
    ├── index.ts              # Definição das tools e servidor MCP
    ├── client.ts             # Cliente da API (autenticação, requests)
    ├── types.ts              # TypeScript interfaces
    ├── constants.ts          # Campos padrão, configs
    ├── __tests__/
    │   ├── meta-ads.test.ts  # Testes unitários
    │   └── fixtures/         # Mocks de resposta da API
    └── README.md             # Documentação do MCP
```

---

## MCPs Bridge Já Implementados

### mcp-evolution (WhatsApp)

**Tools disponíveis:**
- `sendMessage(instanceName, phone, text)` — envia texto
- `sendMedia(instanceName, phone, options)` — envia mídia
- `getInstanceStatus(instanceName)` — estado da conexão
- `listInstances()` — todas as instâncias ativas

**Localização:** `src/mcps/evolution/`

### mcp-meta-ads (Meta Ads API)

**Tools disponíveis:**
- `getCampaignInsights(accountId, dateRange, level?, fields?)` — insights
- `listCampaigns(accountId, status?)` — lista de campanhas
- `updateCampaignStatus(campaignId, status)` — ativar/pausar
- `getAdCreatives(adId)` — criativos do anúncio

**Localização:** `src/mcps/meta-ads/`

---

## Checklist de Novo MCP

### Design
- [ ] Design doc criado e revisado antes de codar
- [ ] Tools necessárias listadas (não mais que o necessário)
- [ ] Rate limits e auth mapeados
- [ ] Dependências identificadas (Redis, banco, etc.)

### Implementação
- [ ] Zod schema para cada tool input
- [ ] Retry + circuit breaker integrados
- [ ] Cache implementado onde faz sentido
- [ ] Fallback gracioso quando API cai
- [ ] Timeouts configurados

### Testes
- [ ] Testes unitários com mocks da API externa
- [ ] Teste de comportamento com cache
- [ ] Teste de fallback quando API retorna erro
- [ ] Teste de validação de inputs inválidos

### Documentação
- [ ] `MCP-GUIDE.md` atualizado com novas tools
- [ ] `README.md` no diretório do MCP
- [ ] Sub-skill correspondente em `sub-skills/` (se relevante)
- [ ] Examples no README com inputs/outputs reais
