# Relatórios — Módulo 04 do Guardião

## OBJETIVO

Gerar e enviar relatórios automáticos de saúde operacional do ClickUp.

---

## RELATÓRIO DIÁRIO (08h BRT — dias úteis)

**Destinatário:** [ATD] Gestão de Atendimento (`120363163709134922@g.us`)

**Conteúdo:**
1. Tarefas críticas sem higiene (sem designer/atendimento/data)
2. Tarefas paradas >48h
3. Loops de revisão ativos
4. Aging crítico (>2 dias atrasadas)
5. Resumo de ontem (throughput do time)

**Formato:**
```
🛡️ *GUARDIÃO — Relatório Diário | {DATA}*

━━━━━━━━━━━━━━━━
📋 PENDÊNCIAS CRÍTICAS
━━━━━━━━━━━━━━━━

{N} tarefas sem higiene
{N} tarefas paradas >48h
{N} loops de revisão ativos

━━━━━━━━━━━━━━━━
📊 PRODUÇÃO DE ONTEM
━━━━━━━━━━━━━━━━

{por designer: nome — X/meta (pct%)}

━━━━━━━━━━━━━━━━
⚠️ AGING CRÍTICO
━━━━━━━━━━━━━━━━

{lista de tarefas atrasadas com nome e dias}

*Sistema operando normalmente.* ✅
```

**Lógica:**
- Se não há pendências → relatório simplificado "ClickUp saudável"
- Se há itens críticos → relatório completo com detalhes

---

## RELATÓRIO SEMANAL (segunda-feira 08h BRT)

**Destinatário:** [ATD] Gestão de Atendimento (`120363163709134922@g.us`)

**Conteúdo:**
1. Throughput semanal por designer (soma dos 5 dias úteis)
2. Taxa de revisão acumulada
3. Tarefas que ficaram em loop por mais de 3x
4. Compliance geral: % de tarefas com higiene correta
5. Tendência: comparação com semana anterior (se dados disponíveis)

**Fonte de dados:** arquivos `~/.openclaw/reports/produtividade-{YYYY-MM-DD}.json` da semana

---

## RELATÓRIO ON-DEMAND (comando `/guardiao relatorio`)

Gerado imediatamente quando solicitado via Alfred no WhatsApp.

Mesmo conteúdo do relatório diário, com timestamp do momento atual.
Enviado no [ATD] Gestão de Atendimento.

---

## COMANDOS SUPORTADOS

| Comando WhatsApp | Output |
|-----------------|--------|
| `/guardiao` ou `/guardiao status` | Resumo compacto: N pendências, N loops, N paradas |
| `/guardiao relatorio` | Relatório completo on-demand |
| `/guardiao task {id}` | Análise completa de uma tarefa: status, histórico, flags |
| `/guardiao pendencias` | Lista todas as tarefas com problema aberto |
| `/guardiao designer {nome}` | Status de um designer: tarefas do dia, throughput, loops |
| `/guardiao loops` | Lista loops de revisão ativos com contagem |

---

## PERSISTÊNCIA

Relatórios diários salvos em:
```
~/.openclaw/reports/
  guardiao-daily-{YYYY-MM-DD}.json
  guardiao-weekly-{YYYY-WNN}.json
  produtividade-{YYYY-MM-DD}.json
```

Retenção: 30 dias (mais antigos são deletados automaticamente).

---

## REGRAS

- Relatório diário: só envia se houver pendências OU se for segunda-feira (sempre envia o semanal)
- On-demand via WhatsApp: sempre responde, mesmo sem pendências
- Nunca envia relatório duplicado no mesmo dia (deduplication por arquivo)
- Tom: factual, sem especulação, dados concretos com números reais
