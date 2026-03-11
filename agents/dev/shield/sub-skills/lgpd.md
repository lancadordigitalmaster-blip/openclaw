# lgpd.md — SHIELD Sub-Skill: LGPD & Privacidade
# Ativa quando: "LGPD", "dados pessoais", "compliance", "privacidade"

---

## Dados Pessoais no Contexto Wolf

### O que é dado pessoal (LGPD Art. 5, I)
Qualquer informação que identifique ou permita identificar uma pessoa natural.

### Dados que a Wolf trata

| Categoria | Exemplos | Base legal típica | Sensível? |
|-----------|---------|------------------|-----------|
| Leads de clientes | Nome, e-mail, telefone, empresa | Legítimo interesse / Consentimento | Não |
| Clientes Wolf | Nome, CPF/CNPJ, e-mail, histórico de pagamentos | Execução de contrato | Não |
| Colaboradores | CPF, endereço, dados bancários | Obrigação legal | Não |
| Visitantes de sites | IP, cookies, comportamento | Consentimento | Não |
| Dados de conversão | Evento de compra, valor, origem | Legítimo interesse | Não |

**Dados que Wolf nunca deve coletar sem necessidade:** saúde, religião, posição política, origem racial.

---

## Bases Legais Wolf (Art. 7 LGPD)

### Consentimento
- Quando usar: coleta de newsletter, cookies de tracking
- Requisito: específico, livre, informado, inequívoco
- Prova: registrar timestamp, versão da política, texto aceito
- Revogação: deve ser tão fácil quanto dar o consentimento

```python
# Registrar consentimento corretamente
def record_consent(
    user_id: str,
    purpose: str,     # "newsletter", "tracking_cookies", etc.
    consent_text: str,
    policy_version: str,
) -> dict:
    return {
        "user_id": user_id,
        "purpose": purpose,
        "consented": True,
        "timestamp": datetime.utcnow().isoformat(),
        "policy_version": policy_version,
        "consent_text_hash": hashlib.sha256(consent_text.encode()).hexdigest(),
        "ip_address": "anonimizar ou não armazenar",
    }
```

### Legítimo Interesse
- Quando usar: análise de performance de campanhas (dado do cliente), prevenção de fraude
- Requisito: interesse legítimo + necessidade + balanceamento (não prejudica o titular)
- Documentar no RoPA (Registro de Atividades de Tratamento)

### Execução de Contrato
- Quando usar: dados necessários para prestar o serviço contratado
- Não requer consentimento adicional
- Exemplos: e-mail e telefone do cliente para comunicação do projeto

---

## Direitos dos Titulares (Art. 18 LGPD)

| Direito | O que significa | SLA Wolf |
|---------|----------------|---------|
| Acesso | Saber quais dados temos | 15 dias |
| Retificação | Corrigir dados incorretos | 15 dias |
| Eliminação | Deletar dados (quando não há obrigação legal de guardar) | 15 dias |
| Portabilidade | Receber os dados em formato estruturado | 15 dias |
| Informação sobre compartilhamento | Com quem compartilhamos | Imediato na política |
| Oposição | Opor-se a tratamento com base em legítimo interesse | Avaliar caso a caso |
| Revogação do consentimento | Retirar consentimento a qualquer tempo | Imediato |

### Implementação do "Direito ao Esquecimento"
```python
def delete_personal_data(user_id: str, reason: str = "user_request") -> dict:
    """
    Deleta ou anonimiza dados pessoais de um usuário.
    Mantém apenas dados necessários para obrigações legais.
    """
    actions_taken = []

    # 1. Anonimizar dados pessoais identificáveis
    db.users.update(
        {"id": user_id},
        {
            "name": f"Usuario Removido {user_id[:8]}",
            "email": f"removed_{user_id[:8]}@deleted.wolf",
            "phone": None,
            "document": None,
            "deleted_at": datetime.utcnow(),
            "deletion_reason": reason,
        }
    )
    actions_taken.append("PII anonimizado")

    # 2. Manter dados financeiros (obrigação legal: 5 anos)
    # Não deletar registros de pagamento, NF, contratos

    # 3. Remover de listas de marketing
    email_marketing.unsubscribe(user_id)
    actions_taken.append("Removido de listas de marketing")

    # 4. Registrar ação de exclusão (accountability)
    audit_log.record({
        "action": "data_deletion",
        "user_id": user_id,
        "reason": reason,
        "timestamp": datetime.utcnow().isoformat(),
        "actions": actions_taken,
    })

    return {"status": "completed", "actions": actions_taken}
```

---

## Política de Retenção de Dados

| Tipo de Dado | Retenção | Base Legal |
|-------------|---------|-----------|
| Leads não convertidos | 2 anos após coleta | Legítimo interesse |
| Dados de clientes ativos | Durante vigência do contrato + 5 anos | Obrigação legal |
| Dados financeiros (NF, contratos) | 5 anos | Código Tributário |
| Logs de acesso | 6 meses | Boas práticas |
| Cookies de tracking | Até revogação de consentimento ou 12 meses | Consentimento |
| Dados de colaboradores | Durante vigência + 5 anos | Obrigação trabalhista |

---

## Notificação de Incidente à ANPD

**Prazo:** Até 72 horas após ciência do incidente (Art. 48 LGPD).

### Checklist de Notificação
```
T+0: Detectar e conter o incidente
T+4h: Avaliar se há dados pessoais afetados
T+8h: Notificar internamente o DPO/responsável
T+24h: Avaliar risco e necessidade de notificação à ANPD
T+48h: Preparar notificação com todas as informações
T+72h: Enviar notificação à ANPD se confirmar dados pessoais afetados
```

### Template de Notificação ANPD
```markdown
## Notificação de Incidente de Segurança — ANPD

**Data do incidente:** [data]
**Data da descoberta:** [data]
**Data desta notificação:** [data]

**Controlador:** Wolf Agency Comunicação Digital
**DPO/Responsável:** [nome e contato]

**Descrição do incidente:**
[O que aconteceu, como foi detectado]

**Natureza dos dados afetados:**
[Tipos de dados pessoais expostos]

**Titulares afetados:**
[Número estimado e categorias de titulares]

**Medidas adotadas:**
[Contenção, remediação, comunicação]

**Medidas futuras:**
[O que será feito para prevenir recorrência]
```

---

## Checklist de Conformidade LGPD Wolf

**Governança:**
- [ ] DPO (Encarregado) nomeado e publicado
- [ ] Política de Privacidade atualizada e acessível
- [ ] RoPA (Registro de Atividades de Tratamento) atualizado
- [ ] Canal de atendimento ao titular funcional (email de privacidade)

**Coleta:**
- [ ] Consentimento coletado e registrado onde aplicável
- [ ] Finalidade explícita para cada dado coletado
- [ ] Princípio da minimização: coletar apenas o necessário
- [ ] Cookie banner com opções reais (não apenas "aceitar")

**Armazenamento:**
- [ ] Política de retenção implementada
- [ ] Dados pessoais criptografados em repouso
- [ ] Acesso restrito por função (RBAC)
- [ ] Backups também com acesso controlado

**Terceiros:**
- [ ] Contratos com operadores (fornecedores que processam dados) assinados
- [ ] Google Analytics / Meta Pixel configurados em conformidade
- [ ] Transferência internacional de dados mapeada

**Resposta:**
- [ ] Processo de atendimento a titulares documentado
- [ ] Playbook de incidente com passo de notificação à ANPD
- [ ] Treinamento de equipe em LGPD realizado

**Penalidades ANPD:** Até 2% do faturamento, limitado a R$ 50 milhões por infração. Reputação em jogo.
