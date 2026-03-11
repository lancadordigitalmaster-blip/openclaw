#!/bin/bash
# Transcrição de áudio usando Groq API
# Uso: ./transcribe.sh <arquivo_de_audio>

API_KEY="${GROQ_API_KEY}"

if [ -z "$API_KEY" ]; then
    echo "Erro: GROQ_API_KEY não configurada"
    echo "Adicione ao .env: GROQ_API_KEY=sua_chave_aqui"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Uso: $0 <arquivo_de_audio>"
    exit 1
fi

AUDIO_FILE="$1"

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Erro: Arquivo não encontrado: $AUDIO_FILE"
    exit 1
fi

echo "🎙️ Transcrevendo com Groq..."

curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: multipart/form-data" \
    -F "file=@$AUDIO_FILE" \
    -F "model=whisper-large-v3" \
    -F "language=pt" \
    -F "response_format=text"

echo ""
