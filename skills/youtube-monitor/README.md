# 🎬 YOUTUBE MONITOR — Wolf Agency
## Sistema de Avaliação de Canais
> Monitoramento diário de postagens e análise de performance

---

## 📺 CANAIS MONITORADOS

| Canal | Inscritos | Vídeos | Tipo de Conteúdo |
|-------|-----------|--------|------------------|
| @ChannelsCast | 25,1K | 171 | Canal Dark, Cases |
| @canalrafasilva | 184K | 543 | Canal Dark, Tutoriais |
| @giovannidottidotti1 | 20,6K | 189 | Canal Dark, Mentoria |

---

## 🔄 WORKFLOW DE MONITORAMENTO

### 1. Detecção de Novos Vídeos (Cron: A cada 6h)
```
Verificar feeds RSS dos canais
↓
Identificar vídeos novos (< 24h)
↓
Extrair metadados (título, views, likes, comentários)
↓
Notificar no grupo Wolf Reports
```

### 2. Análise de Performance (24h após postagem)
```
Coletar métricas:
- Visualizações (views)
- Curtidas (likes)
- Comentários
- Taxa de engajamento
- Duração do vídeo
↓
Classificar nível da aula:
🥉 Bronze — < 1K views
🥈 Prata — 1K-5K views  
🥇 Ouro — 5K-20K views
💎 Diamante — > 20K views
```

### 3. Documentação da Aula
```
Para cada vídeo analisado:
- Título completo
- Link do vídeo
- Resumo do conteúdo (transcrição/LLM)
- Pontos-chave aprendidos
- Aplicabilidade para Wolf
- Nível de dificuldade
- Recomendação de ação
```

### 4. Relatório Diário (19h)
```
Enviar no grupo Wolf Reports:
- Vídeos novos detectados
- Análise de performance
- Documentos das aulas
- Recomendações estratégicas
```

---

## 📊 MÉTRICAS DE AVALIAÇÃO

### Nível do Conteúdo (Automático)
| Critério | Peso | Métrica |
|----------|------|---------|
| Views | 40% | Alcance do vídeo |
| Likes | 30% | Qualidade do conteúdo |
| Comentários | 20% | Engajamento |
| Duração | 10% | Profundidade |

### Classificação Final
```
Score = (Views × 0.4) + (Likes × 0.3) + (Comentários × 0.2) + (Duração × 0.1)

Score < 1000: 🥉 Bronze — Conteúdo básico
Score 1000-5000: 🥈 Prata — Conteúdo intermediário
Score 5000-20000: 🥇 Ouro — Conteúdo avançado
Score > 20000: 💎 Diamante — Conteúdo premium
```

---

## 🛠️ IMPLEMENTAÇÃO TÉCNICA

### APIs Necessárias
1. **YouTube Data API v3**
   - Buscar vídeos novos
   - Extrair métricas
   - Acesso a comentários

2. **Groq/OpenAI**
   - Transcrição de áudio
   - Resumo de conteúdo
   - Análise de sentimento

3. **Telegram Bot API**
   - Notificações no grupo
   - Envio de documentos

### Estrutura de Dados
```json
{
  "canal": "@ChannelsCast",
  "video_id": "yQl4xVMmAAc",
  "titulo": "Primeiro Milhão em 9 Meses...",
  "publicado_em": "2026-03-04T10:00:00Z",
  "metricas": {
    "views": 1000,
    "likes": 150,
    "comentarios": 45,
    "duracao": 6968
  },
  "score": 1250,
  "nivel": "🥈 Prata",
  "analise": {
    "resumo": "...",
    "pontos_chave": ["...", "..."],
    "aplicabilidade": "...",
    "recomendacao": "..."
  },
  "documento_url": "..."
}
```

---

## 📁 ESTRUTURA DE ARQUIVOS

```
youtube-monitor/
├── config/
│   └── canais.json
├── scripts/
│   ├── check_new_videos.py
│   ├── analyze_performance.py
│   ├── generate_report.py
│   └── notify_telegram.py
├── data/
│   ├── videos/
│   └── reports/
└── docs/
    └── aulas/
```

---

## ⏰ CRON JOBS

```bash
# Verificar novos vídeos (a cada 6h)
0 */6 * * * /scripts/check_new_videos.py

# Análise de performance (19h diário)
0 19 * * * /scripts/analyze_performance.py

# Relatório completo (19h30 diário)
30 19 * * * /scripts/generate_report.py
```

---

## 🎯 PRÓXIMOS PASSOS

1. **Configurar YouTube API Key**
2. **Criar scripts de monitoramento**
3. **Testar detecção de vídeos**
4. **Configurar notificações no Telegram**
5. **Criar template de documentação**

---

*Sistema YouTube Monitor | Wolf Agency*
*Criado: 2026-03-05*
