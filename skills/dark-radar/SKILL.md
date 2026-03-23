# Dark Radar — Inteligencia de Mercado

## Descricao
Sistema de inteligencia competitiva para canais dark no YouTube. Monitora concorrentes, analisa tendencias, descobre canais novos e gera estrategias de conteudo.

## Trigger
- "radar", "concorrente", "mercado", "monitorar canal", "inteligencia competitiva"
- "quem esta crescendo", "tendencias do nicho", "descobrir canais"

## Comandos

### Via bash wrapper
```bash
bash scripts/dark-radar.sh add <url> --type concorrente --nicho historia
bash scripts/dark-radar.sh list
bash scripts/dark-radar.sh remove <handle>
bash scripts/dark-radar.sh collect
bash scripts/dark-radar.sh analyze
bash scripts/dark-radar.sh cycle          # coleta + analise + discovery
bash scripts/dark-radar.sh insights
bash scripts/dark-radar.sh discovery
bash scripts/dark-radar.sh strategy
bash scripts/dark-radar.sh score <handle>
bash scripts/dark-radar.sh health
```

### Via API (porta 8898)
```
GET  /api/radar/channels     — lista canais com scores
GET  /api/radar/channel?id=X — detalhes de um canal
GET  /api/radar/metrics      — visao geral do mercado
GET  /api/radar/insights     — insights IA
GET  /api/radar/trends       — temas em alta
GET  /api/radar/discovery    — canais novos detectados
GET  /api/radar/health       — health check
POST /api/radar/channels     — adicionar canal {url, type, nicho}
POST /api/radar/collect      — disparar coleta
POST /api/radar/analyze      — disparar analise IA
POST /api/radar/cycle        — ciclo completo
POST /api/radar/strategy     — gerar estrategia {topic}
```

## Arquivos
- `scripts/radar-engine.py` — motor principal (coleta, score, analise, discovery)
- `scripts/radar-server.py` — API HTTP (porta 8898)
- `scripts/dark-radar.sh` — wrapper bash (padrao OpenClaw)
- `radar/` — dados (channels, market, discovery, memory)

## Dependencias
- python3, yt-dlp, requests
- GOOGLE_API_KEY ou YOUTUBE_API_KEY (opcional, para discovery e enrichment)
- GEMINI_API_KEY ou GOOGLE_API_KEY (para analise IA)

## Agente responsavel
Scout (descoberta) + Sage (estrategia)

## Crons recomendados
- Coleta diaria: `0 4 * * * bash scripts/dark-radar.sh collect`
- Analise diaria: `30 4 * * * bash scripts/dark-radar.sh analyze`
- Ciclo completo semanal: `0 3 * * 0 bash scripts/dark-radar.sh cycle`
- Discovery semanal: `0 5 * * 3 bash scripts/dark-radar.sh discovery`
- Insights semanal: `0 6 * * 1 bash scripts/dark-radar.sh insights`
