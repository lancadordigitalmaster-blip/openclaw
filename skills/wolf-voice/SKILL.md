# SKILL.md — Wolf Voice · Transcrição de Áudio via Telegram
# Wolf Agency AI System | Versão: 1.0 | Criado: 2026-03-04

> Transcreve mensagens de voz recebidas no Telegram e processa como comandos de texto.
> Usa Groq Whisper (gratuito) — suporta português com alta precisão.

---

## Agent

**Alfred** — processa voz recebida e roteia para o agente correto após transcrição.

---

## Triggers

```
Mensagem com arquivo .ogg anexado / referência a voz
"transcrever áudio" | "o que ele disse" | "mensagem de voz"
Qualquer voice message recebida via Telegram
```

---

## Configuração necessária

```bash
# Em: /Users/thomasgirotto/.openclaw/.env
GROQ_API_KEY=gsk_...   # Obter GRÁTIS em: https://console.groq.com
```

**Modelo:** `whisper-large-v3` (Groq)
**Custo:** Gratuito (tier: 7.200 segundos/dia = 2h de áudio)
**Idioma:** Português automático (`language=pt`)

---

## Fluxo de Transcrição

```
WOLF_VOICE_PROTOCOL:

  QUANDO receber voice message no Telegram:

  1. Identificar arquivo OGG:
     → path: ~/.openclaw/media/inbound/[filename].ogg

  2. Converter para M4A (formato aceito pela Groq):
     afconvert ~/.openclaw/media/inbound/[file].ogg \
               /tmp/[file].m4a \
               -d aac -f m4af

  3. Chamar Groq Whisper API:
     curl -s https://api.groq.com/openai/v1/audio/transcriptions \
       -H "Authorization: Bearer $GROQ_API_KEY" \
       -F file="@/tmp/[file].m4a" \
       -F model="whisper-large-v3" \
       -F language="pt" \
       -F response_format="text"

  4. Processar resposta:
     → Extrair texto transcrito
     → Salvar em workspace: [filename].txt (para histórico)
     → Processar o pedido como se fosse texto do Netto

  5. Responder normalmente com base no conteúdo transcrito.
     Prefixar resposta com: 🎙️ *Transcrição:* "[texto transcrito]"
```

---

## Exemplo de uso via Bash tool

```bash
# Ler GROQ_API_KEY do .env
GROQ_KEY=$(grep GROQ_API_KEY ~/.openclaw/.env | cut -d= -f2)

# Converter OGG para M4A
afconvert ~/.openclaw/media/inbound/FILE.ogg /tmp/FILE.m4a -d aac -f m4af

# Transcrever
curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_KEY" \
  -F file="@/tmp/FILE.m4a" \
  -F model="whisper-large-v3" \
  -F language="pt" \
  -F response_format="text"

# Limpar temp
rm /tmp/FILE.m4a
```

---

## Daemon Automático (opcional)

Se quiser transcrição automática sem Alfred intervir manualmente:

```bash
# Script: ~/.openclaw/scripts/wolf-voice-transcriber.py
# LaunchAgent: ai.openclaw.wolf-voice.plist
# Monitora media/inbound/*.ogg novos → transcreve → envia de volta ao Telegram
# Status: PENDENTE — instalar após obter GROQ_API_KEY
```

---

## Outputs

```
🎙️ Transcrição: "o que o Netto disse no áudio"

[Processamento normal do pedido]

✅ Feito: [ação]
```

---

## Activity Log

```
[TIMESTAMP] [Alfred/WolfVoice] AÇÃO: transcribe | ARQUIVO: [uuid].ogg | RESULTADO: ok | CHARS: N
```

---

*Skill: wolf-voice | Versão: 1.0 | Criado: 2026-03-04*
