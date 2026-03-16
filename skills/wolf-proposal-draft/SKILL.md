# SKILL.md — Wolf Proposal Draft

> Gerador dinâmico de propostas comerciais da Wolf Agency.

## Agent

**Nova** — estratégia e inteligência comercial.

---

## Description

Recebe o pedido do vendedor em **texto livre** — com itens, quantidades e preços — e transforma em proposta cinematográfica via `build_proposal`.

O vendedor NÃO precisa seguir formato fixo. Ele envia o que quiser e o sistema adapta.

---

## Biblioteca de Referência

O arquivo `shared/memory/services.yaml` contém templates de serviços com bullets, entregáveis e preços sugeridos.

**Use como referência, NÃO como menu obrigatório.**
- Se o vendedor envia itens customizados → use os itens dele, não os templates
- Se o vendedor pede "social media" sem detalhar → aí sim puxe do catálogo
- Se o vendedor especifica preços → use os preços dele, não os do catálogo

---

## Fluxo Dinâmico

### Passo 1 — Ler o input do vendedor

O vendedor pode enviar de QUALQUER forma:

```
Tipo A — Pacote detalhado com itens e preços:
"Pacote Mensal – Divulgação
▪️16 artes feed/stories R$ 800
▪️2 reels R$ 400
Total: R$ 1.200/mês"

Tipo B — Serviço genérico:
"proposta de tráfego pago para cliente João"

Tipo C — Múltiplos serviços:
"proposta social media + site para empresa X, R$5.000"

Tipo D — Projeto único:
"landing page para evento dia 20, R$ 2.500"
```

### Passo 2 — Extrair os dados

De qualquer input, extrair:

1. **Nome do pacote/serviço** → `service_type`
2. **Itens individuais** → cada item vira uma entrada em `services[]`
   - Cada item: `name` (o que é), `tag` (categoria curta), `bullets` (detalhes)
3. **Valores** → Se o vendedor deu preços por item, montar breakdown
4. **Investimento total** → `investment.amount`
5. **Nome do cliente** → `client_name` (se mencionado)

### Passo 3 — Montar services[]

Cada item do vendedor vira um objeto no array `services`:

```json
{
  "name": "Nome do item/serviço",
  "tag": "categoria curta",
  "bullets": ["detalhe 1", "detalhe 2"]
}
```

**Regra:** respeitar exatamente o que o vendedor pediu.
- Se ele listou 4 itens → 4 entries em services
- Se ele pediu 1 serviço → 1 entry em services
- Se ele não detalhou bullets → puxar da biblioteca (services.yaml)

### Passo 4 — Montar deliverables[]

Criar fases a partir dos itens:
- Itens mensais (recorrentes) → badge "Mensal"
- Itens únicos → badge "Entrega Única"
- Se há mix → separar em fases (Mensal + Único)

Cada deliverable:
```json
{
  "badge": "Mensal",
  "title": "Título descritivo",
  "rows": [
    {"label": "Item", "value": "Quantidade"},
    {"label": "Item 2", "value": "Quantidade"}
  ]
}
```

### Passo 5 — Montar investment{}

Se o vendedor deu breakdown de preços:
```json
{
  "currency": "R$",
  "amount": "valor total",
  "suffix": "/mês ou vazio",
  "breakdown": [
    {"item": "16 artes feed/stories", "value": "800,00"},
    {"item": "2 reels editados", "value": "400,00"}
  ],
  "payment_options": [usar pagamento_padrao do services.yaml]
}
```

Se deu só o total:
```json
{
  "currency": "R$",
  "amount": "valor total",
  "suffix": "/mês ou vazio",
  "payment_options": [usar pagamento_padrao do services.yaml]
}
```

### Passo 6 — Chamar build_proposal

Montar o JSON completo e encaminhar para Pixel via page-architect.
Usar `suporte_padrao` do services.yaml para o campo `support`.

---

## Campos do build_proposal

| Campo | Origem |
|-------|--------|
| `client_name` | Nome do cliente (input do vendedor) |
| `tagline` | Gerar baseado no contexto do serviço |
| `service_type` | Nome do pacote/serviço |
| `year` | Ano atual |
| `whatsapp` | "5573991484716" (Wolf padrão) |
| `ticker_items` | Palavras-chave dos serviços selecionados |
| `context` | Sobre o cliente (se tiver info) ou sobre a Wolf |
| `services[]` | Itens extraídos do input |
| `deliverables[]` | Fases montadas dos itens |
| `investment{}` | Valores do input do vendedor |
| `support[]` | suporte_padrao do services.yaml |
| `close` | CTA padrão Wolf |
| `template` | "classic" |

---

## Usage

```
"Pacote Mensal – Divulgação de Eventos
▪️16 artes R$ 800
▪️2 reels R$ 400
▪️2 animações R$ 250
▪️Identidade visual R$ 1.800
Mensal R$ 1.450 / Total R$ 3.250"
→ Gera proposta com 4 itens, breakdown de preços, separando mensal de único

"proposta de landing page para evento dia 20, cliente Maria, R$ 2.500"
→ Gera proposta com 1 serviço (site/LP), puxa bullets da biblioteca

"social media + tráfego pago para Padaria do João, R$ 3.000/mês"
→ Gera proposta com 2 serviços, puxando bullets da biblioteca
```

---

## Rules

- NUNCA enviar proposta para cliente sem aprovação explícita do Netto
- **RESPEITAR os itens e preços que o vendedor enviou** — não substituir por templates
- Se o vendedor não detalhou → aí sim puxar bullets/preços da biblioteca
- Validade da proposta: 7 dias
- Sempre usar pagamento_padrao e suporte_padrao do services.yaml

---

*Agente: Nova | Versão: 3.1 | Atualizado: 2026-03-13*
