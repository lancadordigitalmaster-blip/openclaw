# MEMORIA PERSISTENTE — Estrutura em 3 Camadas

## Camada 1 — Estado vivo (reescrito semanalmente por memory-refresh.sh)

| Arquivo | Função |
|---------|--------|
| `memory/state.md` | Estado atual do sistema (infra, crons, clientes, saúde) |
| `memory/agenda.md` | Objetivos da semana + pendências + concluídos |
| `memory/boot-context.md` | Snapshot auto (wolf-monitor, 30min) — NÃO editar manualmente |

**Regra:** Sempre reflete a realidade. Se está errado, memory-refresh.sh corrige na próxima segunda.

## Camada 2 — Aprendizado acumulado (append + deduplica)

| Arquivo | Função |
|---------|--------|
| `memory/lessons.md` | Lições confirmadas (acertos e erros) |
| `memory/decisions-log.md` | Decisões com impacto (formato tabela) |
| `memory/patterns.md` | Padrões detectados (falhas recorrentes, acertos consistentes) |
| `memory/errors.md` | Log de erros bruto (deduplicado semanalmente) |

**Regras:**
- Append-only, com deduplicação automática (memory-hygiene.sh domingo 23h)
- Se mesma lição aparece 3x em patterns.md → propor regra no SOUL.md
- errors.md: registrar 1x por tipo de erro + contagem. NÃO repetir mesma entrada.

## Camada 3 — Diário compactado (auto-arquiva)

| Arquivo | Função |
|---------|--------|
| `memory/today.md` ou `memory/YYYY-MM-DD.md` | Nota do dia |
| `memory/weekly/W{NUM}-{ANO}.md` | Resumo semanal (compactado do diário) |
| `memory/archive/` | Consolidados mensais + notas antigas |

**Regras:**
- Notas >7 dias → compactadas em weekly/ pelo memory-hygiene.sh
- Weekly >30 dias → movido para archive/
- Nunca deletar — sempre arquivar

## Manutenção Automática

| Script | Quando | O que faz | Custo |
|--------|--------|-----------|-------|
| `memory-hygiene.sh` | Domingo 23h | Compacta, deduplica, arquiva | $0 (bash) |
| `memory-refresh.sh` | Segunda 07h | Reescreve state.md, verifica pendências, extrai padrões | ~$0.01 |

## Consulta obrigatória de conhecimento

Antes de dizer "não sei": buscar em memory/, shared/memory/, content-analysis/, knowledge-digest/.
Se não encontrar: "não encontrei registro em memory/". NUNCA "não tenho acesso" sem buscar.

## Regra fundamental

**Se não gravou em memory/ = não aconteceu.**
