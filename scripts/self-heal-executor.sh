#!/bin/bash
# Executor chamado pelo cron de self-heal
# Simplesmente dispara o script e reporta resultado

WORKSPACE="/Users/thomasgirotto/.openclaw/workspace"
SCRIPT="$WORKSPACE/scripts/self-heal.sh"

# Executa self-heal
bash "$SCRIPT"
RESULT=$?

# Se falhou: escreve arquivo de alerta para Alfred ler
if [ $RESULT -gt 0 ]; then
  # Alfred vai ler memory/.self-heal-alert e notificar Netto
  echo "Self-heal detectou problema e tentou corrigir"
fi

exit $RESULT
