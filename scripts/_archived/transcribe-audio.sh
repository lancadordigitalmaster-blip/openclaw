#!/bin/bash
# Transcreve áudio usando Whisper CLI
# Uso: ./transcribe-audio.sh /caminho/do/audio.ogg

AUDIO_FILE="$1"

if [ -z "$AUDIO_FILE" ]; then
    echo "Uso: $0 <arquivo-de-audio>"
    exit 1
fi

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Erro: Arquivo não encontrado: $AUDIO_FILE"
    exit 1
fi

# Criar diretório temporário
TEMP_DIR=$(mktemp -d)

# Transcrever com Whisper (modelo medium para melhor precisão em PT-BR)
echo "🎙️ Transcrevendo áudio..."
whisper "$AUDIO_FILE" --model medium --language Portuguese --output_format txt --output_dir "$TEMP_DIR" --fp16 False 2>&1 | grep -E "^\[" || true

# Extrair o texto
TRANSCRIPTION=$(cat "$TEMP_DIR"/*.txt 2>/dev/null)

# Limpar
rm -rf "$TEMP_DIR"

if [ -n "$TRANSCRIPTION" ]; then
    echo "$TRANSCRIPTION"
else
    echo "Erro: Não foi possível transcrever o áudio"
    exit 1
fi