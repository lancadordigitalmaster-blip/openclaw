#!/bin/bash
# Wolf WhatsApp Bridge — Re-sync histórico
# Deleta auth_state para forçar full history sync na próxima conexão
# Sessions de conversa são preservadas
#
# IMPORTANTE: Após executar, precisa re-escanear QR Code no celular!
# O QR aparece no log: ~/.openclaw/logs/whatsapp-bridge.log
#
# Uso: ./resync-history.sh

set -e

BRIDGE_DIR="/Users/thomasgirotto/openclaw/whatsapp-bridge"
AUTH_DIR="$BRIDGE_DIR/auth_state"
BACKUP_DIR="$BRIDGE_DIR/auth_state_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/Users/thomasgirotto/.openclaw/logs/whatsapp-bridge.log"

echo "=== Wolf WhatsApp History Re-Sync ==="
echo ""

# Backup auth_state
if [ -d "$AUTH_DIR" ]; then
    echo "1. Fazendo backup de auth_state..."
    cp -r "$AUTH_DIR" "$BACKUP_DIR"
    echo "   Backup: $BACKUP_DIR"
else
    echo "1. auth_state não encontrado — nada a fazer"
    exit 1
fi

# Stop bridge
echo "2. Parando bridge..."
launchctl bootout gui/$(id -u)/ai.openclaw.whatsapp-bridge 2>/dev/null || true
sleep 2

# Delete auth_state (sessions de conversa ficam intactas em sessions/)
echo "3. Deletando auth_state (forçar re-autenticação)..."
rm -rf "$AUTH_DIR"

# Restart bridge
echo "4. Reiniciando bridge..."
launchctl bootstrap gui/$(id -u) /Users/thomasgirotto/Library/LaunchAgents/ai.openclaw.whatsapp-bridge.plist 2>/dev/null || true
sleep 3

echo ""
echo "=== AÇÃO NECESSÁRIA ==="
echo "Abra o WhatsApp no celular → Dispositivos conectados → Conectar dispositivo"
echo "Escaneie o QR Code que aparecerá no log:"
echo "  tail -f $LOG_FILE"
echo ""
echo "Após conectar, o WhatsApp enviará o histórico completo automaticamente."
echo "Verifique com: grep 'history' $LOG_FILE"
