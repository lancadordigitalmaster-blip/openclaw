# NOMENCLATURA DE ARQUIVOS

## Regras Gerais

1. **Sempre use minúsculas**
2. **Sem espaços** (use hífen ou underscore)
3. **Sem caracteres especiais** (ç, ã, @, #, etc.)
4. **Data no formato ISO:** YYYY-MM-DD
5. **Versão com 2 dígitos:** v01, v02, v03...

---

## Padrões por Tipo

### Projetos de Edição
```
[projeto]_[etapa]_v[##]_[estado].[ext]

campanha-q1_05-edicao_v01_rough.prproj
campanha-q1_05-edicao_v02_fine.prproj
campanha-q1_05-edicao_v03_color.prproj
campanha-q1_05-edicao_v04_final.prproj
```

### Vídeos para Revisão
```
[projeto]_[etapa]_v[##]_[destino]_[data].[ext]

campanha-q1_06-revisao_v01_interna_2026-03-05.mp4
campanha-q1_06-revisao_v02_cliente_2026-03-06.mp4
campanha-q1_06-revisao_v03_aprovado_2026-03-07.mp4
```

### Footage Bruto
```
[projeto]_cena[##]_take[##]_[data].[ext]

campanha-q1_cena01_take01_2026-03-05.mov
campanha-q1_cena01_take02_2026-03-05.mov
campanha-q1_cena02_take01_2026-03-05.mov
```

### Assets
```
[tipo]_[descricao]_[versao].[ext]

musica_background_v01.mp3
musica_background_v02_licenciada.mp3
logo_cliente_v03.png
fonte_titulos_montserrat.otf
luta_corporativo_v01.cube
```

### Exports Finais
```
[projeto]_final_[plataforma]_[especificacao].[ext]

campanha-q1_final_instagram-feed_1080x1080.mp4
campanha-q1_final_instagram-reels_1080x1920.mp4
campanha-q1_final_youtube_1920x1080.mp4
campanha-q1_final_stories_1080x1920_15s.mp4
```

---

## Estados Comuns

| Estado | Significado | Uso |
|--------|-------------|-----|
| `rough` | Corte inicial/bruto | Primeira montagem |
| `fine` | Corte refinado | Timing ajustado |
| `color` | Com color grading | Pós-cor finalizada |
| `mix` | Com áudio mixado | Áudio finalizado |
| `review` | Para revisão | Enviar para feedback |
| `approved` | Aprovado | Versão aceita |
| `final` | Versão final | Master |
| `archive` | Arquivado | Backup/histórico |

---

## Exemplos Completos

### Projeto: "Lançamento Curso Online"

```
lançamento-curso/
├── 00-briefing/
│   └── briefing_v01_aprovado_2026-03-01.md
├── 02-roteiro/
│   ├── roteiro_v01_rascunho.md
│   ├── roteiro_v02_revisao.md
│   └── roteiro_v03_aprovado.md
├── 04-gravacao/
│   ├── cena01-intro/
│   │   ├── curso_cena01_take01_2026-03-05.mov
│   │   ├── curso_cena01_take02_2026-03-05.mov
│   │   └── _selecionado/
│   │       └── curso_cena01_take02_selecionado.mov
│   └── cena02-depoimento/
├── 05-edicao/
│   ├── curso_05-edicao_v01_rough.prproj
│   ├── curso_05-edicao_v02_fine.prproj
│   ├── curso_05-edicao_v03_color.prproj
│   └── curso_05-edicao_v04_final.prproj
├── 06-revisao/
│   ├── curso_06-revisao_v01_interna.mp4
│   ├── curso_06-revisao_v02_cliente.mp4
│   └── curso_06-revisao_v03_aprovado.mp4
├── 07-final/
│   └── curso_07-final_master_4k.mp4
└── 08-entrega/
    ├── curso_final_youtube_1920x1080.mp4
    ├── curso_final_instagram-feed_1080x1080.mp4
    ├── curso_final_reels_1080x1920.mp4
    └── curso_thumbnail_youtube.jpg
```

---

## ⚠️ NUNCA Faça Isso

❌ `Vídeo Final versão 3.mp4`  
❌ `projeto(2).prproj`  
❌ `edit v1 FINAL FINAL.mp4`  
❌ `VID_20260305_143022.mov` (nome da câmera)  
❌ `Copy of projeto.prproj`

✅ Sempre use o padrão definido acima!
