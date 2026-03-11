# Modo Sono — Rotina de Fechamento Diario Autonomo

## Status: LATENTE
> Skill criada mas nao ativada como cron. Aguarda infraestrutura de changelogs.
> Para ativar: criar diretorio `changelogs/` e cron entre 00:00-05:00.

## Identidade
- **Nome:** modo-sono
- **Tipo:** Rotina de fechamento diario
- **Trigger:** Temporal (00:00-05:00) + Inatividade (30min sem interacao)
- **Trust Level:** L1 (autonomo, sem aprovacao humana)

## Condicao de Ativacao

Ativa quando AMBAS condicoes forem verdadeiras:
1. Horario entre 00:00 e 05:00
2. Inatividade >= 30 minutos E nenhum processo de dev ativo

Processos que inibem a rotina:
- Editor com arquivo modificado < 30min
- Terminal com build/deploy rodando
- Changelog com modificacao < 30min

## Fluxo de Execucao

1. Verificar condicoes (se nao atendidas, standby 10min)
2. Localizar changelog do dia: `changelogs/YYYY-MM-DD.md`
3. Ler changelog completo
4. Verificar se ja foi fechado (secao AVALIACAO FINAL preenchida)
5. Gerar relatorio de fechamento:
   - 5.1 Resumo executivo (3-5 linhas)
   - 5.2 Analise por camada (o que mudou, completo/parcial, riscos)
   - 5.3 Comparativo antes x depois
   - 5.4 Bugs e riscos (resolvidos, novos, latentes)
   - 5.5 Saude do sistema (nota 1-10, flag ESTAVEL/ATENCAO/CRITICO)
   - 5.6 Prioridades para amanha (top 3)
   - 5.7 Frase de fechamento (tecnica, honesta)
6. Escrever relatorio na secao AVALIACAO FINAL do changelog
7. Salvar arquivo
8. Registrar em `changelogs/modo-sono.log`
9. Notificar via Telegram (resumo 2 linhas + nota de saude)

## Comportamento de Erro

| Erro | Acao |
|------|------|
| Changelog nao encontrado | Registrar em errors.log, STOP |
| Changelog ja fechado | STOP silencioso |
| Falha ao escrever | Tentar 2x, depois registrar e STOP |
| Provider indisponivel | Aguardar 5min, tentar 1x, STOP com log |
| Processo ativo detectado | Standby 10min, reavaliar |

## Restricoes

NUNCA: modificar arquivos do projeto, executar deploys, alterar configs, acordar usuario
SEMPRE: preservar changelog original, registrar execucao, ser honesto na avaliacao

## Configuracao

```yaml
modo_sono:
  ativo: false  # LATENTE — ativar quando changelogs/ existir
  horario_inicio: "00:00"
  horario_limite: "05:00"
  inatividade_minutos: 30
  verificacao_standby_minutos: 10
  tentativas_erro: 2
  changelog_path: "./changelogs/"
  log_path: "./changelogs/modo-sono.log"
  notificacao: true  # via Telegram
  idioma_relatorio: "pt-BR"
  provider_analise: "kimi-k2.5"
```

## Pre-requisitos para Ativacao

- [ ] Criar diretorio `changelogs/`
- [ ] Definir template de changelog diario
- [ ] Criar cron no jobs.json (00:30, timeout 180s)
- [ ] Testar com changelog de exemplo
