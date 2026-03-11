# 🐺 WOLF REPORTS
## Configuração do Grupo de Relatórios

---

## 📋 INFORMAÇÕES DO GRUPO

**Nome:** Wolf Reports
**Propósito:** Centralizar todos os relatórios operacionais da Wolf Agency
**Criado em:** {{DATA_CRIACAO}}
**ID do Grupo:** {{GROUP_ID}}

---

## 📊 RELATÓRIOS ENVIADOS

### 1. Daily Briefing (Automático — 9h)
**Conteúdo:**
- Resumo do dia anterior
- Campanhas que precisam de atenção
- Tarefas com prazo hoje
- Alertas de SLA

**Frequência:** Diário, 9h da manhã

---

### 2. Relatório de Tráfego — Meta Ads
**Conteúdo:**
- Performance por campanha
- CPA, ROAS, CTR
- Criativos validados/pausados
- Recomendações da Gabi

**Frequência:** Sob demanda ou semanal

**Templates disponíveis:**
- Alcance (brand awareness)
- Visitas (tráfego)
- Engajamento
- Leads
- Vendas

---

### 3. Relatório de Designer — Workload
**Conteúdo:**
- Carga de trabalho por designer
- Tarefas em andamento
- Metas vs realidade
- Alertas de sobrecarga

**Frequência:** Diário (8h) ou sob demanda

---

### 4. SLA Alert Report
**Conteúdo:**
- Tarefas com violação de SLA
- Prioridade de ação
- Responsáveis

**Frequência:** Diário ou quando houver alertas

---

### 5. Resumo de Reuniões
**Conteúdo:**
- Pontos principais discutidos
- Decisões tomadas
- Próximos passos
- Responsáveis

**Frequência:** Após cada reunião

---

### 6. Análises de Performance
**Conteúdo:**
- Análise profunda de campanha/cliente
- Benchmarks
- Recomendações estratégicas

**Frequência:** Mensal ou sob demanda

---

## 👥 MEMBROS DO GRUPO

| Nome | Papel | Notificações |
|------|-------|--------------|
| Netto | Dono | Todas |
| Gabi | Gestora de Tráfego | Relatórios de tráfego |
| Mi | Social Media | Relatórios de conteúdo |
| Mirelli | Gestora | Todos os relatórios |
| Alfred | Sistema | Envio automático |

---

## ⚙️ CONFIGURAÇÃO TÉCNICA

### Regras do Grupo
- `requireMention: false` — Alfred responde sem @menção
- `autoReports: true` — Relatórios automáticos ativados

### Integrações
- ClickUp API (tarefas, metas)
- Meta Ads API (campanhas, métricas)
- W.O.L.F. (equipe, SLA)

---

## 📝 COMANDOS DISPONÍVEIS

```
/relatorio diario — Gera daily briefing
/relatorio trafego — Gera relatório de Meta Ads
/relatorio designer — Gera workload dos designers
/relatorio sla — Gera alertas de SLA
/relatorio semanal — Gera resumo da semana
```

---

*Configuração Wolf Reports | Wolf Agency*
*Criado: 2026-03-05*
