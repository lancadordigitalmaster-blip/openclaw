# SKILL.md — Wolf Proposal Draft

> Rascunho de propostas comerciais da Wolf Agency.

## Agent

**Nova** — especialista em estratégia e inteligência comercial.

---

## Description

Monta estrutura de propostas comerciais baseada nos dados do cliente, serviço solicitado e histórico da Wolf.
Nova puxa contexto do cliente em `shared/memory/clients.yaml` quando disponível.

---

## Catálogo de Serviços Wolf (Referência)

| Serviço | Descrição | Faixa de Investimento |
|---------|-----------|----------------------|
| Social Media | Gestão de redes, legendas, calendário | A definir |
| Tráfego Pago | Meta Ads + Google Ads, gestão e otimização | A definir |
| Branding | Identidade visual, logo, manual de marca | A definir |
| Produção de Conteúdo | Fotos, vídeos, reels | A definir |
| Estratégia Digital | Planejamento, consultoria, benchmarking | A definir |
| Site / Landing Page | Desenvolvimento web, otimização | A definir |

*(Preencher valores com Netto)*

---

## Tools

### proposal-draft

Cria rascunho de proposta comercial.

**Parameters:**
- `client`: Nome do cliente prospecto
- `service`: Serviço(s) oferecido(s) — pode ser múltiplo
- `value`: Valor estimado (se já definido, caso contrário Nova sugere range)
- `deadline`: Prazo de entrega do projeto
- `pain_points`: Dores/desafios do cliente (opcional — enriquece a proposta)
- `competitors`: Concorrentes mencionados (opcional)

**Returns:** Proposta completa estruturada segundo o template Wolf

---

## Template de Proposta

1. **Apresentação Wolf** — quem somos, diferenciais
2. **Entendimento do Desafio** — o que entendemos do problema do cliente
3. **Solução Proposta** — como vamos resolver
4. **Entregáveis** — o que será entregue, com prazos por fase
5. **Investimento** — valores, formas de pagamento
6. **Prazo** — cronograma de execução
7. **Próximos Passos** — o que precisa acontecer para começar

---

## Usage

```
"nova, rascunha uma proposta para a Empresa X — social media + tráfego pago, orçamento ~R$5.000/mês"
"alfred, proposta para novo cliente do segmento de saúde, foco em leads"
```

---

## Rules

- NUNCA enviar proposta para cliente sem aprovação explícita do Netto
- Sempre marcar valores estimados como "a confirmar" quando não definidos
- Incluir validade da proposta (sugestão: 15 dias)

---

## Activity Log

```
[TIMESTAMP] [Nova] AÇÃO: proposal-draft cliente=[client] serviço=[service] | RESULTADO: rascunho gerado
```

---

*Agente: Nova | Versão: 2.0 | Atualizado: 2026-03-04*
