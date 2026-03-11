---

## Agent

**Luna** — social media e conteudo

---
name: youtube-transcript
description: Extrai transcricoes e resumos de videos do YouTube usando browser built-in do gateway. Abre o video, clica em "Mostrar transcricao" e captura o texto completo com timestamps. Use quando o usuario enviar um link do YouTube e quiser resumo, transcricao ou analise. Triggers: URL do YouTube, "resuma esse video", "transcreva", "o que fala nesse video".
user-invokable: true
metadata: {"openclaw":{"emoji":"YT","requires":{"bins":["python3"]}}}
---

# YouTube Transcript & Summary

## Metodo 1: Browser Built-in do Gateway (PREFERIDO - use SEMPRE este primeiro)

O gateway tem um browser embutido com a tool `browser`. Fluxo completo TESTADO E FUNCIONANDO:

### Passo a passo:

1. **Abrir o video:**
```
browser open "URL_DO_YOUTUBE"
```

2. **Expandir descricao para revelar botao de transcricao:**
```
browser snapshot -i
```
Procurar por botao "...mais" ou "Show more" e clicar nele.

3. **Clicar em "Mostrar transcricao" (ou "Show transcript"):**
```
browser snapshot -i
```
Procurar botao "Mostrar transcricao" ou "Show transcript" e clicar.

4. **Capturar a transcricao completa:**
```
browser snapshot
```
A transcricao aparece como lista de botoes com timestamps e texto, ex:
- button "0 segundos We're no strangers to love..."
- button "4 segundos You know the rules and so do I..."

5. **Extrair o texto** de todos os botoes com timestamps para montar a transcricao.

6. **Fechar browser:**
```
browser close
```

### IMPORTANTE - Erros comuns:
- Se receber `tab not found`: abra uma NOVA aba com `browser open "URL"` (restarts do gateway fecham abas)
- Se receber `ref not found`: faca novo `browser snapshot -i` para obter refs atualizados
- O botao "Mostrar transcricao" so aparece DEPOIS de expandir a descricao (clicar "...mais")

## Metodo 2: Script yt-dlp + Gemini (ALTERNATIVO - 100% gratuito)

Quando o browser nao funcionar ou para gerar resumo automatico:

```bash
bash workspace/scripts/yt-summary.sh "VIDEO_URL"
```

Faz tudo automaticamente:
1. Extrai transcricao com yt-dlp (gratis)
2. Limpa o texto (remove timestamps, duplicatas, tags HTML)
3. Envia para Gemini 2.5 Flash (gratis, usa GOOGLE_API_KEY do .env)
4. Retorna resumo estruturado em portugues

## Metodo 3: Summarize CLI

```bash
/opt/homebrew/bin/summarize "VIDEO_URL" --youtube auto
```

## Metodo 4: yt-dlp direto (apenas transcricao crua)

```bash
/opt/homebrew/bin/yt-dlp --write-auto-sub --sub-lang pt --sub-format srt --skip-download -o "/tmp/yt-%(id)s" "VIDEO_URL" 2>/dev/null
```

Limpar SRT:
```bash
python3 -c "
import re
seen, lines = set(), []
for line in open('/tmp/yt-VIDEO_ID.pt.srt'):
    line = re.sub(r'<[^>]+>', '', line.strip())
    if not line or line.isdigit() or '-->' in line: continue
    if line not in seen:
        seen.add(line)
        lines.append(line)
print(' '.join(lines))
"
```

## Ferramentas

| Ferramenta | Funcao | Custo |
|---|---|---|
| Browser (built-in gateway) | Abre YouTube, clica transcricao, captura texto | Gratis |
| yt-dlp (/opt/homebrew/bin/) | Extrai legendas/transcricao sem browser | Gratis |
| Gemini 2.5 Flash | Resume transcricao (via GOOGLE_API_KEY) | Gratis |
| summarize CLI | Alternativa all-in-one | Gratis |

Tudo 100% gratuito. Nenhuma API paga.
