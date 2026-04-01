#!/bin/bash
# Auto-Optimizer para Alfred
# Monitora tempo de resposta e alterna LLM quando necessário

LOG_FILE="/Users/thomasgirotto/.openclaw/workspace/logs/alfred-performance.log"
THRESHOLD_WARNING=5000    # 5 segundos (ms)
THRESHOLD_SWITCH=10000    # 10 segundos (ms)
MODEL_FAST="groq/llama-3.1-8b-instant"
MODEL_BALANCED="groq/llama-3.3-70b-versatile"
MODEL_QUALITY="moonshot/kimi-k2.5"

echo "$(date): Alfred Auto-Optimizer iniciado" >> "$LOG_FILE"

# Função para verificar tempo de resposta da API
check_response_time() {
    local start_time=$(date +%s%N)
    
    # Teste simples de ping na API
    curl -s -o /dev/null -w "%{time_total}" https://api.groq.com/openai/v1/models \
        -H "Authorization: Bearer $GROQ_API_KEY" 2>/dev/null || echo "0"
}

# Função para alternar modelo
switch_model() {
    local new_model="$1"
    echo "$(date): Alternando para modelo: $new_model" >> "$LOG_FILE"
    
    # Atualiza o modelo na sessão
    # Nota: Isso requer integração com o gateway OpenClaw
    curl -s -X POST http://localhost:18789/api/v1/sessions/model \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$new_model\"}" 2>/dev/null || true
}

# Função principal de monitoramento
monitor_performance() {
    while true; do
        response_time=$(check_response_time)
        response_time_ms=$(echo "$response_time * 1000" | bc | cut -d. -f1)
        
        if [ "$response_time_ms" -gt "$THRESHOLD_SWITCH" ]; then
            echo "$(date): ALERTA - Tempo de resposta alto: ${response_time_ms}ms" >> "$LOG_FILE"
            switch_model "$MODEL_FAST"
            
        elif [ "$response_time_ms" -gt "$THRESHOLD_WARNING" ]; then
            echo "$(date): AVISO - Tempo de resposta elevado: ${response_time_ms}ms" >> "$LOG_FILE"
        fi
        
        # Verifica a cada 30 segundos
        sleep 30
    done
}

# Inicia monitoramento em background se não estiver rodando
if ! pgrep -f "alfred-auto-optimizer" > /dev/null; then
    monitor_performance &
    echo $! > /tmp/alfred-auto-optimizer.pid
    echo "$(date): Monitor iniciado em background (PID: $!)" >> "$LOG_FILE"
fi