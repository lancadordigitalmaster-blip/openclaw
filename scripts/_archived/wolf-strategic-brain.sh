#!/bin/bash
# wolf-strategic-brain.sh — Strategic Brain (Thinking Time)
# Coleta contexto para os crons LLM de Morning Think (06h30) e Evening Think (19h30)
# Arg: "morning" ou "evening"
# O script NÃO usa LLM — apenas coleta e organiza dados para o cron processar

set -eo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-wolf.sh"

MODE="${1:-morning}"
TODAY=$(date +%Y-%m-%d)
BRAIN_DIR="$WOLF_WORKSPACE/memory/brain"
mkdir -p "$BRAIN_DIR"

wolf_log "strategic-brain" "Coletando contexto: $MODE"

case "$MODE" in
  morning)
    OUTPUT="$BRAIN_DIR/morning-context-$TODAY.md"
    {
      echo "# Morning Context — $TODAY"
      echo ""

      # 1. Health cards de clientes
      echo "## Client Health Cards"
      for hf in "$WOLF_WORKSPACE"/memory/clients/*/health.yaml; do
        [ -f "$hf" ] && { echo ""; echo "### $(basename "$(dirname "$hf")")"; cat "$hf"; }
      done 2>/dev/null || echo "_Nenhum health card encontrado_"
      echo ""

      # 2. Últimas lições (últimas 30 linhas)
      echo "## Lições Recentes"
      tail -30 "$WOLF_WORKSPACE/memory/lessons.md" 2>/dev/null || echo "_Sem lições_"
      echo ""

      # 3. Padrões identificados
      echo "## Padrões"
      cat "$WOLF_WORKSPACE/memory/patterns.md" 2>/dev/null || echo "_Sem padrões_"
      echo ""

      # 4. Alertas ativos (Gabi)
      echo "## Alertas Gabi (últimos)"
      tail -10 "$WOLF_WORKSPACE/memory/gabi/alerts-log.md" 2>/dev/null || echo "_Sem alertas_"
      echo ""

      # 5. Improvement log (últimas 20 linhas)
      echo "## Melhorias Recentes"
      tail -20 "$WOLF_WORKSPACE/memory/improvement-log.md" 2>/dev/null || echo "_Sem melhorias_"
      echo ""

      # 6. Erros ativos
      echo "## Erros Ativos"
      cat "$WOLF_WORKSPACE/memory/errors.md" 2>/dev/null || echo "_Sem erros_"
      echo ""

      # 7. Pending improvements
      echo "## Melhorias Pendentes de Aprovação"
      cat "$BRAIN_DIR/pending-improvements.md" 2>/dev/null || echo "_Nenhuma_"

    } > "$OUTPUT"

    wolf_log "strategic-brain" "Morning context salvo: $OUTPUT ($(wc -l < "$OUTPUT") linhas)"
    ;;

  evening)
    OUTPUT="$BRAIN_DIR/evening-context-$TODAY.md"
    {
      echo "# Evening Context — $TODAY"
      echo ""

      # 1. Erros do dia
      echo "## Erros do Dia"
      grep "$TODAY" "$WOLF_WORKSPACE/memory/errors.md" 2>/dev/null || echo "_Nenhum erro hoje_"
      echo ""

      # 2. Brain morning insights
      echo "## Insights da Manhã"
      cat "$BRAIN_DIR/insight-morning-$TODAY.md" 2>/dev/null || echo "_Morning Think não rodou hoje_"
      echo ""

      # 3. Ações autônomas do dia
      echo "## Ações Autônomas do Dia"
      cat "$BRAIN_DIR/actions-$TODAY.md" 2>/dev/null || echo "_Nenhuma ação autônoma_"
      echo ""

      # 4. Melhorias implementadas hoje
      echo "## Melhorias Implementadas Hoje"
      grep -A5 "\[$TODAY\]" "$WOLF_WORKSPACE/memory/improvement-log.md" 2>/dev/null || echo "_Nenhuma melhoria hoje_"
      echo ""

      # 5. Gateway log resumido (últimas 30 linhas com tool_use ou message)
      echo "## Atividade do Gateway (resumo)"
      tail -100 "$HOME/.openclaw/logs/gateway.log" 2>/dev/null | grep -i "message\|tool_use\|error\|warn" | tail -20 || echo "_Sem atividade relevante_"
      echo ""

      # 6. Alertas Gabi do dia
      echo "## Alertas de Tráfego Hoje"
      grep "$TODAY" "$WOLF_WORKSPACE/memory/gabi/alerts-log.md" 2>/dev/null || echo "_Nenhum alerta_"

    } > "$OUTPUT"

    wolf_log "strategic-brain" "Evening context salvo: $OUTPUT ($(wc -l < "$OUTPUT") linhas)"
    ;;

  *)
    echo "Uso: $0 [morning|evening]"
    exit 1
    ;;
esac

echo "OK: wolf-strategic-brain $MODE completed at $(date '+%Y-%m-%d %H:%M:%S')"
