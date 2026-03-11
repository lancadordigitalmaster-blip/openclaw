# Export Presets — Video Editor Pro

> Configurações de export para cada plataforma e uso

---

## Presets por Plataforma

### Instagram Reels / Stories

```yaml
Resolução: 1080 x 1920 (9:16)
Frame Rate: 30fps
Codec: H.264
Bitrate: 10–16 Mbps
Áudio: AAC, 320 kbps, 48kHz
Formato: .mp4
Tamanho Máx: 100MB (Reels), 15MB (Stories foto)
Duração: 15s–90s (Reels), 15s (Stories)
```

**Configuração Premiere:**
- Format: H.264
- Preset: Match Source – High Bitrate (ajustar)
- Target Bitrate: 12 Mbps
- Maximum Bitrate: 16 Mbps
- Profile: High
- Level: 4.2

---

### TikTok

```yaml
Resolução: 1080 x 1920 (9:16)
Frame Rate: 30fps (ou 60fps para motion)
Codec: H.264
Bitrate: 8–12 Mbps
Áudio: AAC, 320 kbps, 48kHz
Formato: .mp4
Tamanho Máx: 287MB (iOS), 72MB (Android)
Duração: 15s–10min
```

**Dicas:**
- TikTok recompressiona — exportar em alta qualidade
- Usar 60fps para conteúdo com muito movimento

---

### YouTube (VSL, Conteúdo Longo)

```yaml
Resolução: 1920 x 1080 (Full HD) ou 3840 x 2160 (4K)
Frame Rate: 24fps (cinematic) ou 30fps (padrão)
Codec: H.264 (HD) ou H.265/ProRes (4K)
Bitrate: 
  - 1080p: 8–12 Mbps
  - 4K: 35–45 Mbps
Áudio: AAC, 320 kbps, 48kHz
Formato: .mp4
```

**Configuração Premiere (1080p):**
- Format: H.264
- Preset: YouTube 1080p Full HD
- Target Bitrate: 10 Mbps
- Maximum Bitrate: 12 Mbps

**Configuração Premiere (4K):**
- Format: H.264
- Preset: YouTube 4K Ultra HD
- Target Bitrate: 40 Mbps
- Maximum Bitrate: 50 Mbps

---

### Facebook Ads

```yaml
Resolução: 1080 x 1080 (1:1) ou 1080 x 1920 (9:16)
Frame Rate: 30fps
Codec: H.264
Bitrate: 6–10 Mbps
Áudio: AAC, 128 kbps, 48kHz
Formato: .mp4
Tamanho Máx: 4GB
Duração: 1s–240min
```

**Especificações Técnicas:**
- Video Codec: H.264, VP9
- Audio Codec: AAC, MP3
- Sample Rate: 44.1 kHz ou 48 kHz

---

### Master (Arquivo de Arquivo)

```yaml
Resolução: Conforme projeto original
Frame Rate: Conforme projeto
Codec: ProRes 422 HQ ou DNxHR HQX
Bitrate: Variável (alta qualidade)
Áudio: PCM, 24-bit, 48kHz
Formato: .mov
```

**Quando usar:**
- Arquivo final para arquivo
- Reedição futura
- Entrega para broadcast
- Backup de máxima qualidade

---

## Pacote de Entregas

### Entrega Padrão (Short-form)

```
projeto_final/
├── master/
│   └── projeto_master_1080x1920.mp4
├── review/
│   └── projeto_review_1080x1920.mp4 (compactado)
├── derivados/
│   ├── projeto_15s.mp4
│   ├── projeto_30s.mp4
│   ├── projeto_45s.mp4
│   └── projeto_60s.mp4
├── thumbnail/
│   └── projeto_thumbnail.jpg
└── specs.txt (especificações técnicas)
```

### Entrega Padrão (VSL)

```
projeto_final/
├── master/
│   ├── projeto_master_1080p.mp4
│   └── projeto_master_4k.mp4 (se aplicável)
├── review/
│   └── projeto_review_1080p.mp4
├── cortes/
│   ├── projeto_corte1_hook.mp4
│   ├── projeto_corte2_prova.mp4
│   └── projeto_corte3_cta.mp4
├── legendas/
│   ├── projeto_legendas.srt
│   └── projeto_legendas_sem_fundo.mov
└── specs.txt
```

---

## Configurações Rápidas

### Premiere Pro — Presets Personalizados

**Wolf_Reels_1080x1920:**
```
Format: H.264
Resolution: 1080x1920
Frame Rate: 30fps
Target Bitrate: 12 Mbps
Maximum Bitrate: 16 Mbps
Audio: AAC, 320 kbps
```

**Wolf_VSL_1080p:**
```
Format: H.264
Resolution: 1920x1080
Frame Rate: 30fps
Target Bitrate: 10 Mbps
Maximum Bitrate: 12 Mbps
Audio: AAC, 320 kbps
```

**Wolf_Master_ProRes:**
```
Format: QuickTime
Codec: Apple ProRes 422 HQ
Resolution: Conforme sequência
Audio: PCM, 24-bit
```

### After Effects — Render Queue

**Wolf_AE_Web:**
```
Format: H.264
Output Module: H.264
Audio Output: AAC, 320 kbps
```

**Wolf_AE_Master:**
```
Format: QuickTime
Output Module: ProRes 422 HQ
Audio Output: PCM, 48kHz
```

---

## Checklist de Export

- [ ] Resolução correta verificada
- [ ] Frame rate consistente
- [ ] Áudio incluído e sincronizado
- [ ] Início e fim cortados corretamente
- [ ] Nome do arquivo padronizado
- [ ] Tamanho dentro do limite
- [ ] Teste de reprodução realizado
- [ ] Cópia de backup no _archive/

---

*Export Presets v1.0 — Video Editor Pro*
