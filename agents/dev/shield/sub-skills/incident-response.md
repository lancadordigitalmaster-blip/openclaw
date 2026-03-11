# incident-response.md — SHIELD Sub-Skill: Incident Response
# Ativa quando: "incident", "incidente", "brecha", "foi comprometido"

---

## Classificação de Incidente

Antes de acionar o playbook, classifica:

| Nível | Critério | Resposta |
|-------|---------|---------|
| P1 — Crítico | Dados de clientes expostos, sistema fora do ar, acesso não autorizado ativo | Equipe imediata, 24/7 |
| P2 — Alto | Possível comprometimento, serviço degradado, secret exposto | Resposta em 4h |
| P3 — Médio | Vulnerabilidade descoberta sem exploração confirmada | Resposta em 24h |
| P4 — Baixo | Melhoria de segurança, finding de auditoria | Backlog |

---

## Playbook Completo Wolf

### T+0 — Contenção Imediata (primeiros 30 minutos)

```
AÇÃO 1: Isolar o sistema comprometido
  → Desativar accounts suspeitas
  → Revogar tokens/secrets expostos
  → Bloquear IPs de origem do ataque (se identificados)
  → Tirar sistema do ar SE necessário para conter

AÇÃO 2: Preservar evidências (ANTES de remediar)
  → Tirar screenshot do painel/logs
  → Exportar logs de acesso
  → Anotar timestamp exato de cada ação
  → Não apagar logs nem sobrescrever dados

AÇÃO 3: Notificar internamente
  → Líder técnico imediatamente
  → CEO/Diretoria se P1/P2
  → Definir responsável pelo incidente (Incident Commander)
```

### T+1h — Avaliação

```
PERGUNTAS A RESPONDER:
  1. O que foi comprometido? (sistemas, dados, acessos)
  2. Qual o vetor de entrada? (como o atacante entrou)
  3. Há quanto tempo o ataque estava ativo? (blast radius)
  4. Quais dados pessoais foram afetados? (LGPD)
  5. O ataque está contido ou ainda em andamento?
```

### T+4h — Remediação

```
  → Corrigir a vulnerabilidade explorada
  → Aplicar patch ou configuração corretiva
  → Fazer novo deploy limpo se necessário
  → Resetar todos os acessos suspeitos
  → Monitorar ativamente nas próximas 24h
```

### T+24h — Post-Mortem

```
  → Relatório completo do incidente
  → Timeline exato dos eventos
  → Causa raiz identificada
  → Ações corretivas implementadas
  → Ações preventivas planejadas
  → Notificação à ANPD se dados pessoais afetados (< 72h do incidente)
```

---

## Checklist de Contenção Imediata

```bash
# SISTEMA COMPROMETIDO — executar nesta ordem

# 1. Revogar acessos suspeitos
# AWS
aws iam update-access-key --access-key-id AKIA... --status Inactive

# GitHub
gh api -X DELETE /repos/ORG/REPO/deployments/DEPLOYMENT_ID

# Banco de dados — matar sessões ativas
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'usuario_suspeito';

# 2. Exportar logs ANTES de qualquer alteração
# Nginx
cp /var/log/nginx/access.log /tmp/incident_$(date +%Y%m%d_%H%M%S)_nginx.log

# CloudWatch
aws logs get-log-events --log-group /app/production \
  --start-time $(date -d '24 hours ago' +%s000) \
  > /tmp/incident_cloudwatch.json

# 3. Bloquear IP de origem (se identificado)
# iptables
iptables -A INPUT -s IP_ATACANTE -j DROP

# Nginx
echo "deny IP_ATACANTE;" >> /etc/nginx/conf.d/blocked.conf
nginx -s reload

# 4. Invalidar todos os tokens de sessão
# Dependendo do sistema — trocar JWT_SECRET invalida tudo
```

---

## Preservação de Evidências

**Regra:** Não mexa no que não precisa. Cada ação modifica o ambiente.

```python
import hashlib
import json
from datetime import datetime
from pathlib import Path

def preserve_evidence(source_path: str, incident_id: str) -> dict:
    """
    Cria cópia forense de arquivo de log/evidência.
    Calcula hash para verificação de integridade.
    """
    evidence_dir = Path(f"/secure/incidents/{incident_id}/evidence")
    evidence_dir.mkdir(parents=True, exist_ok=True)

    source = Path(source_path)
    dest = evidence_dir / f"{source.name}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"

    # Copiar arquivo
    dest.write_bytes(source.read_bytes())

    # Calcular hash SHA-256
    sha256 = hashlib.sha256(dest.read_bytes()).hexdigest()

    metadata = {
        "original_path": str(source_path),
        "preserved_at": datetime.utcnow().isoformat(),
        "sha256": sha256,
        "size_bytes": dest.stat().st_size,
        "incident_id": incident_id,
    }

    # Salvar metadata
    (evidence_dir / f"{dest.name}.metadata.json").write_text(
        json.dumps(metadata, indent=2)
    )

    return metadata

# Log de cada ação durante o incidente
def log_incident_action(incident_id: str, action: str, actor: str, detail: str):
    log_file = Path(f"/secure/incidents/{incident_id}/timeline.jsonl")
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "actor": actor,
        "action": action,
        "detail": detail,
    }
    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")
```

---

## Template de Comunicação de Incidente

### Comunicação Interna (imediata)
```
ASSUNTO: [P1/P2] Incidente de Segurança — [sistema] — [data]

RESUMO: [1 frase do que aconteceu]

STATUS ATUAL: Em andamento / Contido / Remediado

IMPACTO: [o que foi afetado]

AÇÕES EM ANDAMENTO:
- [ação 1]
- [ação 2]

INCIDENT COMMANDER: [nome]
PRÓXIMA ATUALIZAÇÃO: [horário]
```

### Comunicação para Cliente Afetado
```
Prezado [nome],

Identificamos um incidente de segurança que pode ter afetado [dados específicos].

O que aconteceu:
[Descrição clara e objetiva, sem jargão técnico]

Quando aconteceu:
[Período estimado]

O que fizemos:
[Medidas tomadas para conter e remediar]

O que você deve fazer:
[Ações recomendadas, se houver]

Pedimos desculpas pelo ocorrido e estamos à disposição.
[Contato do DPO/responsável]
```

---

## Template de Post-Mortem

```markdown
# Post-Mortem — Incidente [ID]

**Data do incidente:** [data]
**Duração:** [de T+0 até remediação]
**Severidade:** P[1/2/3]
**Incident Commander:** [nome]
**Participantes da resposta:** [nomes]

## Resumo Executivo
[2-3 frases: o que aconteceu, impacto, como foi resolvido]

## Timeline
| Horário | Evento |
|---------|--------|
| HH:MM | Detectado por [quem/como] |
| HH:MM | Contenção inicial |
| HH:MM | Causa raiz identificada |
| HH:MM | Remediação aplicada |
| HH:MM | Incidente encerrado |

## Causa Raiz
[O que causou o incidente. Seja honesto.]

## Impacto
- Sistemas afetados: [lista]
- Dados afetados: [tipos e volume]
- Titulares afetados: [quantidade, se dados pessoais]
- Downtime: [duração]

## O que foi bem
- [ponto positivo 1]

## O que pode melhorar
- [ponto de melhoria 1]

## Ações Corretivas
| Ação | Responsável | Prazo | Status |
|------|-------------|-------|--------|
| [ação] | [nome] | [data] | Pendente |

## Notificações Legais
- ANPD notificada: [Sim/Não/N/A] — [data se sim]
- Clientes notificados: [Sim/Não] — [data se sim]
```

---

## Contatos de Emergência Wolf

Manter atualizado em local seguro (não no repo):
- Incident Commander de plantão
- Responsável pelo sistema afetado
- DPO / Responsável LGPD
- ANPD — notificação de incidente: [peticionamento.anpd.gov.br]
- Hosting/Cloud suporte técnico
- Jurídico (se dados de clientes afetados)
