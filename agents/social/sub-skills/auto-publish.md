# AUTO-PUBLISH — LUNA · Sub-skill
# Wolf Agency | Versão: 2.0

## TRIGGER
publicar, agendar post, auto-publish, postar agora, enviar para o Post Bridge, agendar nas redes

## PROTOCOLO
1. Receber: conteúdo aprovado (texto + mídia), plataformas alvo, horário de publicação
2. Verificar status de aprovação: conteúdo deve ter flag "aprovado" no calendário ou confirmação explícita do operador
3. Validar mídia por plataforma:
   - Instagram Feed: JPG/PNG (máx 30MB), vídeo MP4 (máx 100MB, 60s feed / 90s Reels)
   - TikTok: MP4/MOV (máx 500MB, até 10min)
   - LinkedIn: PNG/JPG (máx 5MB), MP4 (máx 200MB)
   - Twitter/X: JPG/PNG/GIF (máx 5MB), MP4 (máx 512MB, 2min20s)
4. Validar texto: contar caracteres por plataforma e alertar se ultrapassar limite
5. Validar hashtags: máximo por plataforma (Instagram: 30 | TikTok: 5-10 | LinkedIn: 5 | Twitter: 3-5)
6. Agendar via Post Bridge API: endpoint /schedule com payload {content, media_url, platforms, publish_at}
7. Verificar resposta da API: status 200 = sucesso | erro = tentar 1x e escalar para operador se persistir
8. Capturar ID de agendamento retornado pela API
9. Confirmar agendamento: hora, plataforma, ID de referência
10. Registrar em activity.log: {cliente, plataformas, horário, ID_agendamento, status}

## OUTPUT
```
AUTO-PUBLISH — [CLIENTE] — [DATA HH:MM]

AGENDAMENTO CONFIRMADO
- Plataforma: [Instagram | TikTok | LinkedIn]
- Publicação: [DD/MM HH:MM]
- Post Bridge ID: #XXXXX
- Preview: "[primeiros 80 chars da legenda]..."
- Mídia: [nome_arquivo] — Validada: OK

LOG: activity.log atualizado
```

## NUNCA
- Nunca publicar conteúdo sem status de aprovação confirmado
- Nunca ignorar erros de validação de mídia — corrigir antes de agendar
- Nunca agendar sem registrar o ID do Post Bridge no log (necessário para rastreabilidade)

---
*Sub-skill de: LUNA | Versão: 2.0 | Atualizado: 2026-03-04*
