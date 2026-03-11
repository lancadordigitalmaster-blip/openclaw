# Templates de Relatório

## Template: Relatório Diário de Demanda

```
📊 RELATÓRIO DE DEMANDA – DESIGNERS
📅 {{data}}
⏰ Atualização: {{hora}}

───

{{#designers}}
👤 {{nome}} — {{atual}}/{{meta}} {{indicador}}
{{#tarefas}}
  • {{status_emoji}} {{titulo}} ({{tempo}})
{{/tarefas}}

{{/designers}}

───

📈 RESUMO
• Total de tarefas: {{total}}
• Média por designer: {{media}}
• 🟢 Disponíveis: {{disponiveis}}
• ⚖️ No limite: {{limite}}
• 🔴 Sobrecarregados: {{sobrecarregados}}

📝 OBSERVAÇÕES:
{{#observacoes}}
• {{.}}
{{/observacoes}}

───
Próxima atualização: {{proxima_atualizacao}}
```

---

## Template: Alertas de SLA

```
🚨 ALERTAS DE SLA — {{data}}

{{#criticos}}
🔴 CRÍTICO — {{tempo}} sem ação
   {{descricao}}
   👤 Responsável: {{responsavel}}
   🔗 {{link}}

{{/criticos}}

{{#atencao}}
🟡 ATENÇÃO — {{tempo}}
   {{descricao}}
   👤 Responsável: {{responsavel}}
   🔗 {{link}}

{{/atencao}}

{{^alertas}}
✅ Nenhum alerta ativo. Fluxo saudável!
{{/alertas}}
```

---

## Template: Métricas de Fluxo

```
📈 MÉTRICAS DE FLUXO — {{periodo}}
📅 {{data_inicio}} a {{data_fim}}

───

🔄 WIP (Em andamento)
{{#wip}}
• {{designer}}: {{count}} tarefa(s)
{{/wip}}

⏱️ Aging (Sem atualização)
{{#aging}}
• {{designer}}: {{dias}} dias — {{tarefa}}
{{/aging}}

✅ Throughput (Concluídas)
• Total: {{throughput}} tarefas
• Média/dia: {{throughput_diario}}

📎 Evidence Coverage
• {{evidence_coverage}}% com evidência

⏰ Cycle Time Médio
• {{cycle_time}} dias

───

{{#recomendacoes}}
💡 {{.}}
{{/recomendacoes}}
```

---

## Template: Validação de Tarefas

```
🔍 VALIDAÇÃO DE TAREFAS — {{data}}

{{#problemas}}
{{severidade}} {{problema}}
   Tarefa: {{titulo}}
   Status: {{status}}
   {{#campo}}Campo: {{campo}}{{/campo}}
   🔗 {{link}}

{{/problemas}}

{{^problemas}}
✅ Todas as tarefas validadas. Nenhum problema encontrado!
{{/problemas}}

───

📊 ESTATÍSTICAS
• Total verificado: {{total}}
• Com problemas: {{com_problemas}}
• Índice de saúde: {{saude}}%
```
