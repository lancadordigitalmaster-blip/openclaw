---

## Agent

**Alfred** — orquestrador central

---
name: wolf-self-heal
description: Auto-diagnóstico e recuperação do sistema Alfred/OpenClaw. Ative quando o usuário reportar que o Alfred não responde, fica digitando sem enviar, ou perguntar sobre o status do gateway. Também ativa com frases como "você está bem?", "se auto-diagnostique", "você tá travado", "status do sistema", "reseta você mesmo".
---

# wolf-self-heal — Auto-Diagnóstico e Recuperação Wolf

## QUANDO ATIVAR

Ativa automaticamente quando o usuário disser:
- "você não tá respondendo", "tava travado", "ficou mudo"
- "se auto-diagnostique", "como você tá?", "você está bem?"
- "status do sistema", "checar gateway", "reseta você mesmo"
- Qualquer relato de timeout ou bot sem resposta

---

## PROTOCOLO DE DIAGNÓSTICO

### Passo 1 — Coletar evidências

```bash
# Estado do gateway
launchctl list | grep openclaw

# Últimos erros
tail -30 ~/.openclaw/logs/gateway.err.log

# Tamanho das sessões
du -sh ~/.openclaw/agents/main/sessions/*.jsonl 2>/dev/null

# Log do watchdog (auto-heals anteriores)
tail -20 ~/.openclaw/logs/watchdog.log 2>/dev/null
```

### Passo 2 — Identificar o problema

| Sintoma no log | Causa | Ação |
|----------------|-------|------|
| `embedded run timeout: timeoutMs=600000` | Sessão cresceu demais, compaction falhou | Reset de sessão |
| `Summarization failed: 429` | LLM sobrecarregado durante compaction | Reset + aguardar |
| `getUpdates conflict: 409` | Dois processos rodando | Kill + restart único |
| `API rate limit reached` | Quota do modelo esgotada | Aguardar ou trocar modelo |
| `Config invalid` | openclaw.json corrompido | Verificar config |
| Nenhum erro + PID vazio | Gateway crashou | Restart simples |

### Passo 3 — Executar o fix

```bash
# Diagnóstico + reset automático (recomendado)
bash ~/.openclaw/scripts/alfred-emergency-reset.sh

# Ou reset silencioso (para cron/watchdog)
bash ~/.openclaw/scripts/alfred-emergency-reset.sh --silent

# Reset simples sem limpeza (se sessão < 800KB)
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

---

## RESPOSTA PADRÃO AO USUÁRIO

Quando executar o auto-diagnóstico, responda neste formato:

```
🔍 Auto-diagnóstico executado:

• Gateway: [rodando / crashado]
• Sessão: [tamanho] — [OK / muito grande - limpei]
• Erros recentes: [nenhum / X timeouts / conflito 409]
• Ação tomada: [restart simples / reset de sessão / nenhuma]

Status: [✅ Tudo normal | ⚠ Reiniciei para corrigir | ❌ Problema persiste]

[Se reiniciou]: Comecei uma sessão limpa. Me diga o que você precisava!
```

---

## MÉTRICAS DE SAÚDE

| Métrica | Saudável | Atenção | Crítico |
|---------|----------|---------|---------|
| Sessão principal | < 300KB | 300-800KB | > 800KB |
| Tokens totais | < 100K | 100-300K | > 300K |
| Compaction timeouts | 0 | 1 | ≥ 2 |
| Processos openclaw | 1 | — | 0 ou > 1 |

---

## PREVENÇÃO — SISTEMAS ATIVOS

O sistema Wolf tem proteções automáticas:

1. **Watchdog a cada 5 min** — detecta sessão > 800KB ou 2+ timeouts → reset automático
2. **Restart diário 05:00 BRT** — limpa acúmulo antes do dia
3. **Compaction mode: default** — compacta mais cedo que "safeguard"

Para verificar se os sistemas estão ativos:
```bash
crontab -l | grep -E "watchdog|openclaw"
cat ~/.openclaw/logs/watchdog.log | tail -10
```

---

## REFERÊNCIA RÁPIDA — LOGS

```bash
# Erros runtime
tail -50 ~/.openclaw/logs/gateway.err.log

# Log principal (detalhado)
tail -30 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log 2>/dev/null

# Auto-heals realizados
cat ~/.openclaw/logs/watchdog.log
```
