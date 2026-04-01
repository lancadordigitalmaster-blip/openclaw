# Higiene de Tarefas — Módulo 01 do Guardião

## OBJETIVO

Garantir que toda tarefa nas listas monitoradas esteja com todos os campos obrigatórios preenchidos corretamente.

---

## CAMPOS OBRIGATÓRIOS

| Campo | Field ID | Válido quando |
|-------|----------|---------------|
| Designer | `b9b3676c-f119-48cf-851d-8ebd83e5011f` | `value` não é null |
| Atendimento | `00e6513e-ef48-4262-aa2f-1288f8ebed72` | `value` não é null |
| Data de vencimento | `due_date` | campo preenchido (não null) |
| Status | `status.status` | dentro do fluxo esperado |

---

## FLUXO DE STATUS VÁLIDO

```
para fazer → produzindo → conferência interna → enviado ao cliente → finalizada
                                    ↑
                     em alteração ──┘
                     formatos ──────┘
```

**Status válidos:** `para fazer`, `produzindo`, `conferência interna`, `em alteração`, `formatos`, `enviado ao cliente`, `finalizada`

---

## PROTOCOLO DE DETECÇÃO

Para cada tarefa verificada:

```
1. Buscar tarefa via GET /api/v2/task/{task_id}?custom_fields=true
2. Verificar custom_fields: se DESIGN_FIELD.value == null → FLAG designer_ausente
3. Verificar custom_fields: se ATD_FIELD.value == null → FLAG atendimento_ausente
4. Verificar due_date: se null → FLAG data_ausente
5. Verificar status: se não no fluxo válido → FLAG status_invalido
```

---

## AÇÃO POR FLAG

**Nível 1 (1ª ocorrência):**
- Postar comentário no ClickUp na tarefa flagada
- @mention do atendimento responsável (se identificado) OU @equipe-atendimento
- Notificar grupo [ATD] individual do atendimento (ou [ATD] Gestão como fallback)

**Formato do comentário ClickUp:**
```
🔍 *Higiene de Tarefa — Guardião*

Esta tarefa está com campos incompletos:
{lista de flags}

Por favor corrija para manter o fluxo de produção. ✅
```

**Formato da mensagem WhatsApp [ATD]:**
```
⚠️ *Tarefa sem higiene detectada*

Tarefa: {nome}
{flags com orientação}

Corrija no ClickUp para manter o pipeline funcionando.
```

---

## ORIENTAÇÃO POR FLAG

| Flag | Orientação |
|------|-----------|
| `designer_ausente` | Preencha o campo Designer com o responsável pela produção |
| `atendimento_ausente` | Preencha o campo Atendimento com o responsável pelo cliente |
| `data_ausente` | Defina a data de vencimento conforme prazo combinado com o cliente |
| `status_invalido` | Corrija o status para refletir a etapa atual da tarefa |

---

## REGRAS

- NUNCA cobrar o designer diretamente
- NUNCA editar campos — apenas comentar
- Se atendimento não identificado → notificar [ATD] Gestão de Atendimento
- Verificação roda a cada 15 min junto com o poll principal
