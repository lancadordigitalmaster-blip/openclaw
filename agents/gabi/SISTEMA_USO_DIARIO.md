# 🎯 SISTEMA NEWTON — USO DIÁRIO
## Organização Prática | Agente Gabi | Wolf Agency

---

## 📁 ESTRUTURA DE ARQUIVOS

```
agents/gabi/
├── 📄 GUIA_DE_BOLSO.md          → Referência rápida (1 página)
├── 📄 SKILL.md                   → System prompt + knowledge base v4.0 (auto-loaded)
├── 📄 TEMPLATES/
│   ├── analise_diaria.md
│   ├── analise_semanal.md
│   ├── planejamento_teste.md
│   └── decisao_escala.md
├── 📄 CHECKLISTS/
│   ├── checklist_diario.md
│   ├── checklist_semanal.md
│   └── checklist_lancamento.md
└── 📄 PLAYBOOKS/
    ├── cpa_explodiu.md
    ├── roas_baixo.md
    └── frequencia_alta.md
```

---

## 🌅 ROTINA DIÁRIA (15 min)

### Template: Análise Diária
```markdown
## Análise Diária — [DATA]

### Cliente: [NOME]

#### Métricas 24h
- Gasto: R$ [X]
- CPA: R$ [X] (meta: R$ [X])
- ROAS: [X]x
- CTR: [X]%
- Frequência: [X]

#### Campanhas Pausadas (regras automáticas)
- [ ] Nenhuma
- [ ] [Campanha] — Motivo: [X]

#### Decisões
| Campanha | Ação | Motivo |
|----------|------|--------|
| [Nome] | [Escala/Otimiza/Pausa] | [Motivo] |

#### Ações Hoje
- [ ] [Tarefa 1]
- [ ] [Tarefa 2]

#### Alertas
- [ ] Frequência subindo em [campanha]
- [ ] CPA fora da meta em [campanha]
```

### Checklist Diário
```markdown
## ☀️ Checklist Diário — [DATA]

### Análise Rápida (5 min)
- [ ] Campanhas pausadas por regras automáticas
- [ ] CPA últimas 24h vs meta (por cliente)
- [ ] Frequência conjuntos ativos (>2.5 = alerta)

### Gestão (5 min)
- [ ] Comentários nos anúncios (responder/limpar negativos)
- [ ] Anomalias documentadas

### Planejamento (5 min)
- [ ] Priorizar ações do dia
- [ ] Verificar prazos de testes em andamento
```

---

## 📅 ROTINA SEMANAL (1h)

### Template: Análise Semanal
```markdown
## Análise Semanal — Semana [X] | [DATA]

### Performance Geral
| Cliente | Gasto | CPA | ROAS | vs Meta |
|---------|-------|-----|------|---------|
| [A] | R$ | R$ | x | % |
| [B] | R$ | R$ | x | % |

### Criativos
#### Validados (escalar)
- [Criativo 1] — CTR: [X]% | CPA: R$ [X]
- [Criativo 2] — CTR: [X]% | CPA: R$ [X]

#### Pausados
- [Criativo 3] — Motivo: [CTR baixo/CPA alto]

#### Em Teste
- [Criativo 4] — Status: [Aguardando validação]

### Ângulos Testados
| Ângulo | CTR | CPA | Resultado |
|--------|-----|-----|-----------|
| [Emocional] | [X]% | R$ [X] | [Validado/Pausado] |
| [Racional] | [X]% | R$ [X] | [Validado/Pausado] |

### Produção — Próxima Semana
- [ ] [Quantidade] criativos novos
- [ ] Foco: [Ganchos/Ângulos/Formatos]
- [ ] Responsável: [Nome]
- [ ] Prazo: [Data]

### Concorrência
- Novos ganchos identificados: [X]
- Tendências: [Observações]

### Aprendizados da Semana
1. [O que funcionou]
2. [O que não funcionou]
3. [O que testar próxima semana]
```

### Checklist Semanal
```markdown
## 📊 Checklist Semanal

### Análise de Performance
- [ ] Consolidar métricas de todos os clientes
- [ ] Identificar top/bottom performers
- [ ] Analisar tendências (CPA subindo/descendo)

### Criativos
- [ ] Revisar todos os criativos ativos
- [ ] Decidir: escalar / pausar / manter
- [ ] Documentar ângulos validados
- [ ] Planejar produção da próxima semana

### Testes
- [ ] Revisar testes em andamento
- [ ] Validar resultados (atingiram volume mínimo?)
- [ ] Documentar aprendizados
- [ ] Planejar novos testes

### Estratégia
- [ ] Análise de concorrência (novos ganchos)
- [ ] Revisar benchmarks por cliente
- [ ] Ajustar metas se necessário
- [ ] Atualizar regras automáticas
```

---

## 🚀 LANÇAMENTO DE CAMPANHA

### Template: Planejamento de Teste
```markdown
## 🧪 Planejamento de Teste

### Hipótese
**Se** [fizermos X], **então** [esperamos Y] **porque** [lógica].

### Variável Testada
[Elemento específico: gancho/ângulo/formato]

### Variações
| Variação | Descrição | Status |
|----------|-----------|--------|
| Controle | [Atual] | [Ativo] |
| A | [Descrição] | [Ativo] |
| B | [Descrição] | [Ativo] |
| C | [Descrição] | [Ativo] |

### Métrica de Sucesso
[CTR/CPA/ROAS — qual métrica define sucesso?]

### Critério de Valaliação
- [ ] 3.000 impressões
- [ ] 1x CPA meta em gasto
- [ ] 48-72h de tempo

### Budget
- Total: R$ [X]
- Por variação: R$ [X]

### Período
- Início: [Data]
- Fim previsto: [Data]

### Resultado Esperado
- Melhor: [X]
- Provável: [X]
- Pior: [X]

### Aprendizado Esperado
[O que vamos aprender independente do resultado]
```

### Checklist de Lançamento
```markdown
## 🚀 Checklist — Lançamento de Campanha

### Antes de Ativar
- [ ] Hipótese definida
- [ ] Métrica de sucesso clara
- [ ] Mínimo 3 variações de gancho
- [ ] Regras automáticas configuradas
- [ ] Post ID configurado (se aplicável)
- [ ] Tracking funcionando (pixel, eventos)
- [ ] Landing page testada (velocidade, mobile)

### Primeiras 24h
- [ ] Campanha aprovada (sem rejeições)
- [ ] Impressões começaram
- [ ] CTR dentro do esperado (>0.8%)
- [ ] Nenhum alerta crítico

### Validação (48-72h)
- [ ] Atingiu 3.000 impressões
- [ ] Atingiu 1x CPA em gasto
- [ ] CTR > 1%?
- [ ] CPA dentro da meta?

### Decisão
- [ ] ESCALA — CTR > 1% + CPA OK
- [ ] OTIMIZA — CTR > 1% + CPA alto
- [ ] PAUSA — CTR < 1% ou CPA 2x meta
```

---

## 📈 ESCALA

### Template: Decisão de Escala
```markdown
## 📈 Decisão de Escala

### Campanha: [NOME]

#### Histórico de Performance
| Período | CPA | ROAS | Frequência |
|---------|-----|------|------------|
| 7 dias | R$ [X] | [X]x | [X] |
| 3 dias | R$ [X] | [X]x | [X] |
| Ontem | R$ [X] | [X]x | [X] |

#### Sinais de Satura
- [ ] Frequência > 2.5
- [ ] CPM subindo > 30%
- [ ] CTR caindo > 20%
- [ ] CPA subindo > 20%

**Sinais presentes:** [X de 4]

#### Decisão
**Tipo de Escala:** [Vertical/Horizontal/Criativo]

**Ação:**
- [ ] Aumentar budget 20% (de R$ [X] para R$ [X])
- [ ] Novo lookalike [X%]
- [ ] Novas variações de criativo

**Monitoramento:**
- Reavaliar em: [48h]
- Critério de pausa: [CPA > 1.5x ou ROAS < X]
```

---

## 🚨 PLAYBOOKS DE EMERGÊNCIA

### Playbook: CPA Explodiu
```markdown
## 🚨 CPA Explodiu — [DATA/HORA]

### Campanha: [NOME]
### CPA Atual: R$ [X] (Meta: R$ [X])
### Variação: [X]x acima da meta

#### Diagnóstico Rápido (5 min)
| Métrica | Valor | Status |
|---------|-------|--------|
| CPM | R$ [X] | [OK/Alto >40] |
| CTR | [X]% | [OK/Baixo <0.8] |
| CPC | R$ [X] | [OK/Alto >5] |
| Conv. | [X]% | [OK/Baixa] |

#### Causa Identificada
- [ ] Público saturado (CPM alto)
- [ ] Gancho fraco (CTR baixo)
- [ ] Relevância baixa (CPC alto)
- [ ] Landing/oferta (conv. baixa)

#### Ação Imediata
- [ ] PAUSAR conjuntos CPA 2x acima
- [ ] MANTER conjuntos até 1.5x (monitorar)
- [ ] TESTAR novo gancho em 24h
- [ ] VERIFICAR frequência

#### Próximos Passos
- [ ] [Tarefa]
- [ ] [Tarefa]
```

### Playbook: ROAS Abaixo do Breakeven
```markdown
## 🚨 ROAS Baixo — [DATA/HORA]

### Campanha: [NOME]
### ROAS Atual: [X]x (Breakeven: [X]x)

#### Diagnóstico
| Métrica | Valor | Status |
|---------|-------|--------|
| CPA | R$ [X] | [OK/Alto] |
| Ticket | R$ [X] | [OK/Baixo] |
| Conv. | [X]% | [OK/Baixa] |

#### Causa Identificada
- [ ] CPA alto (ver playbook CPA)
- [ ] Ticket baixo (oferta/página)
- [ ] Conv. baixa (landing/objeções)

#### Ação
- [ ] PAUSAR se < breakeven 48h
- [ ] ANALISAR funil completo
- [ ] TESTAR novo ângulo
- [ ] REVISAR landing page
```

### Playbook: Frequência Alta
```markdown
## 🚨 Frequência Alta — [DATA/HORA]

### Campanha: [NOME]
### Frequência: [X] em 7 dias

#### Sinais
- [ ] Frequência > 3.0
- [ ] CPM subindo
- [ ] CTR caindo
- [ ] CPA subindo

#### Ação Imediata
- [ ] PAUSAR conjunto imediatamente
- [ ] CRIAR novo lookalike
- [ ] TESTAR novo gancho
- [ ] MUDAR ângulo

#### Prevenção
- [ ] Monitorar frequência desde início
- [ ] Pausar em 2.5 (não esperar 3.0)
- [ ] Ter criativos de reserva prontos
```

---

## 📊 RELATÓRIOS

### Template: Relatório Semanal para Cliente
```markdown
## 📊 Relatório Semanal — [CLIENTE]
### Período: [DATA] a [DATA]

---

### 📈 Resumo Executivo
- **Gasto:** R$ [X]
- **Receita:** R$ [X]
- **ROAS:** [X]x
- **CPA:** R$ [X] (meta: R$ [X])
- **Status:** [Dentro meta/Atenção/Crítico]

---

### 🎯 Performance por Campanha
| Campanha | Gasto | CPA | ROAS | Status |
|----------|-------|-----|------|--------|
| [A] | R$ | R$ | x | ✅ |
| [B] | R$ | R$ | x | ⚠️ |
| [C] | R$ | R$ | x | ❌ |

---

### 🎨 Criativos
**Top Performers:**
- [Criativo 1] — CTR: [X]% | CPA: R$ [X]
- [Criativo 2] — CTR: [X]% | CPA: R$ [X]

**Pausados:**
- [Criativo 3] — Motivo: [CTR baixo/CPA alto]

**Em Teste:**
- [Criativo 4] — Resultado em: [Data]

---

### 📋 Ações da Semana
✅ **Concluídas:**
- [Ação 1]
- [Ação 2]

🔧 **Em Andamento:**
- [Ação 3]

📅 **Próxima Semana:**
- [Ação 4]
- [Ação 5]

---

### 💡 Recomendações
1. [Recomendação 1]
2. [Recomendação 2]

---

*Relatório gerado por Gabi | Wolf Agency*
```

---

## 🎯 COMO USAR

### Dia a Dia
1. **Manhã:** Checklist Diário (15 min)
2. **Durante o dia:** Usar Guia de Bolso para decisões rápidas
3. **Problema:** Consultar Playbook específico
4. **Fim de semana:** Análise Semanal (1h)

### Novo Projeto
1. Planejamento de Teste (template)
2. Checklist de Lançamento
3. Acompanhar validação
4. Decisão de escala

### Emergência
1. Identificar problema (CPA/ROAS/Frequência)
2. Abrir Playbook correspondente
3. Executar passo a passo
4. Documentar resultado

---

*Sistema Newton Organizado | Agente Gabi | Wolf Agency*
*Atualizado: 2026-03-05*
