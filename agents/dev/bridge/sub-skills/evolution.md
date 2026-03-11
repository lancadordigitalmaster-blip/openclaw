# evolution.md — Bridge Sub-Skill: Evolution API (WhatsApp)
# Ativa quando: "WhatsApp", "Evolution API", "instância", "mensagem"

## Propósito

Integração WhatsApp via Evolution API para automações Wolf: notificações de campanha, alertas de sistema, respostas automáticas, relatórios. Cobertura completa de setup, envio, webhooks e reconexão automática.

---

## Configuração Evolution API Wolf

### Docker Compose

```yaml
# docker-compose.yml
services:
  evolution-api:
    image: atendai/evolution-api:v2
    ports:
      - "8080:8080"
    environment:
      SERVER_URL: https://evolution.wolf.agency
      AUTHENTICATION_API_KEY: ${EVOLUTION_API_KEY}
      AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES: true
      DATABASE_PROVIDER: postgresql
      DATABASE_CONNECTION_URI: ${DATABASE_URL}
      REDIS_URI: ${REDIS_URL}
      LOG_LEVEL: ERROR
      DEL_INSTANCE: false  # Não deleta instâncias offline
      QRCODE_LIMIT: 30
      WEBHOOK_GLOBAL_URL: https://wolf.agency/webhooks/evolution
      WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS: true
    volumes:
      - evolution_data:/evolution/instances
```

---

## Criação e Gestão de Instâncias

```typescript
const evolutionClient = axios.create({
  baseURL: process.env.EVOLUTION_API_URL,
  headers: { apikey: process.env.EVOLUTION_API_KEY },
});

// Criar nova instância
async function createInstance(instanceName: string): Promise<{ qrCode: string }> {
  const { data } = await evolutionClient.post('/instance/create', {
    instanceName,
    qrcode: true,
    integration: 'WHATSAPP-BAILEYS',
    webhook: {
      url: `${process.env.BASE_URL}/webhooks/evolution`,
      byEvents: true,
      events: ['MESSAGES_UPSERT', 'CONNECTION_UPDATE', 'QRCODE_UPDATED'],
    },
  });
  return { qrCode: data.qrcode?.base64 };
}

// Verificar status da conexão
async function getInstanceStatus(instanceName: string): Promise<'open' | 'close' | 'connecting'> {
  const { data } = await evolutionClient.get(`/instance/connectionState/${instanceName}`);
  return data.instance?.state;
}

// Listar todas as instâncias
async function listInstances() {
  const { data } = await evolutionClient.get('/instance/fetchInstances');
  return data;
}

// Deletar instância
async function deleteInstance(instanceName: string) {
  await evolutionClient.delete(`/instance/delete/${instanceName}`);
}
```

---

## Formato de Número

**Regra crítica:** Sempre usar formato internacional sem + e sem caracteres especiais.

| Entrada | Formato correto |
|---------|----------------|
| `(11) 99999-9999` | `5511999999999` |
| `+55 11 99999-9999` | `5511999999999` |
| `11999999999` | `5511999999999` |
| `999999999` (SP) | `5511999999999` |

```typescript
function formatWhatsAppNumber(rawNumber: string): string {
  // Remove tudo que não é dígito
  const digits = rawNumber.replace(/\D/g, '');

  // Adiciona DDI Brasil se não tiver
  if (digits.startsWith('55') && digits.length >= 12) {
    return digits;
  }
  if (digits.length === 11) {
    return `55${digits}`;
  }
  if (digits.length === 10) {
    // Celular sem o 9 — adiciona
    const ddd = digits.substring(0, 2);
    const number = digits.substring(2);
    return `55${ddd}9${number}`;
  }
  throw new Error(`Número inválido: ${rawNumber}`);
}

// Sufixo obrigatório para WhatsApp
const recipient = `${formatWhatsAppNumber(phone)}@s.whatsapp.net`;
```

---

## Envio de Mensagens

### Texto

```typescript
async function sendText(instanceName: string, phone: string, text: string) {
  const { data } = await evolutionClient.post(`/message/sendText/${instanceName}`, {
    number: formatWhatsAppNumber(phone),
    text,
    delay: 500, // ms antes de enviar (simula digitação)
  });
  return data;
}
```

### Mídia (imagem, vídeo, áudio)

```typescript
async function sendMedia(
  instanceName: string,
  phone: string,
  options: {
    mediatype: 'image' | 'video' | 'audio' | 'document';
    media: string;    // URL pública ou base64
    caption?: string;
    fileName?: string;
  }
) {
  const { data } = await evolutionClient.post(`/message/sendMedia/${instanceName}`, {
    number: formatWhatsAppNumber(phone),
    ...options,
  });
  return data;
}
```

### Documento

```typescript
async function sendDocument(instanceName: string, phone: string, pdfUrl: string, fileName: string) {
  return sendMedia(instanceName, phone, {
    mediatype: 'document',
    media: pdfUrl,
    fileName,
    caption: `Relatório: ${fileName}`,
  });
}
```

### Botões interativos

```typescript
async function sendButtons(instanceName: string, phone: string) {
  const { data } = await evolutionClient.post(`/message/sendButtons/${instanceName}`, {
    number: formatWhatsAppNumber(phone),
    title: 'Relatório Semanal',
    description: 'Suas campanhas da semana estão prontas.',
    footer: 'Wolf Agency',
    buttons: [
      { buttonId: 'view_report', buttonText: { displayText: 'Ver Relatório' } },
      { buttonId: 'talk_to_team', buttonText: { displayText: 'Falar com Time' } },
    ],
  });
  return data;
}
```

---

## Webhooks de Mensagem Recebida

```typescript
// src/api/webhooks/evolution.webhook.ts
app.post('/webhooks/evolution', async (req, res) => {
  const event = req.body;

  res.status(200).send('ok'); // Confirma imediatamente

  switch (event.event) {
    case 'MESSAGES_UPSERT':
      await handleIncomingMessage(event);
      break;
    case 'CONNECTION_UPDATE':
      await handleConnectionUpdate(event);
      break;
    case 'QRCODE_UPDATED':
      await handleQRCodeUpdate(event);
      break;
  }
});

async function handleIncomingMessage(event: any) {
  const message = event.data?.messages?.[0];
  if (!message || message.key.fromMe) return; // Ignora mensagens enviadas pelo bot

  const phone = message.key.remoteJid.replace('@s.whatsapp.net', '');
  const text = message.message?.conversation ||
               message.message?.extendedTextMessage?.text || '';

  logger.info({ phone, text }, 'Mensagem recebida via WhatsApp');

  // Enfileirar para processamento
  await messageQueue.add('whatsapp-incoming', { phone, text, instanceName: event.instance });
}

async function handleConnectionUpdate(event: any) {
  const { state, instance } = event.data;
  await db.whatsappInstances.update({ name: instance }, { status: state });

  if (state === 'close') {
    logger.warn({ instance }, 'Instância WhatsApp desconectada');
    await scheduleReconnection(instance);
  }
}
```

---

## Reconexão Automática

```typescript
// Monitorar e reconectar instâncias offline
async function scheduleReconnection(instanceName: string, attempt = 1) {
  const MAX_ATTEMPTS = 5;
  const DELAY_MS = Math.min(1000 * Math.pow(2, attempt), 30000); // Max 30s

  if (attempt > MAX_ATTEMPTS) {
    logger.error({ instanceName }, 'Instância não reconectou após 5 tentativas');
    await notifyOpsTeam(instanceName); // Alertar time
    return;
  }

  setTimeout(async () => {
    const status = await getInstanceStatus(instanceName);

    if (status === 'open') {
      logger.info({ instanceName }, 'Instância reconectada');
      return;
    }

    // Tentar reconectar
    try {
      await evolutionClient.get(`/instance/connect/${instanceName}`);
      logger.info({ instanceName, attempt }, 'Tentativa de reconexão enviada');
    } catch {
      logger.warn({ instanceName, attempt }, 'Falha na tentativa de reconexão');
    }

    await scheduleReconnection(instanceName, attempt + 1);
  }, DELAY_MS);
}

// Verificação periódica (cron a cada 5 minutos)
async function checkAllInstances() {
  const instances = await listInstances();
  for (const instance of instances) {
    if (instance.connectionStatus !== 'open') {
      await scheduleReconnection(instance.name);
    }
  }
}
```

---

## Casos de Uso Wolf

### Notificação de Alerta

```typescript
async function notifyAlert(phone: string, alert: {
  type: 'campaign_paused' | 'budget_low' | 'high_cpa';
  details: string;
}) {
  const messages = {
    campaign_paused: `⚠️ Campanha pausada automaticamente.\n${alert.details}`,
    budget_low: `💰 Budget crítico atingido.\n${alert.details}`,
    high_cpa: `📈 CPA acima do target.\n${alert.details}`,
  };

  await sendText('wolf-alerts', phone, messages[alert.type]);
}
```

### Relatório Semanal

```typescript
async function sendWeeklyReport(clientPhone: string, reportUrl: string) {
  await sendText('wolf-reports', clientPhone,
    `Olá! Seu relatório semanal de campanhas está pronto. 📊\n\n` +
    `Acesse em: ${reportUrl}\n\n` +
    `Dúvidas? Responda aqui ou fale com seu analista.`
  );
}
```

---

## Checklist de Integração Evolution

- [ ] EVOLUTION_API_KEY em variável de ambiente
- [ ] Formatação de número testada para BR (com e sem 9)
- [ ] Webhook configurado na criação da instância
- [ ] Resposta 200 imediata no webhook handler
- [ ] Processamento assíncrono via fila
- [ ] Reconexão automática implementada com backoff
- [ ] Ignora mensagens fromMe (evita loop)
- [ ] Health check de instâncias a cada 5 minutos
- [ ] Logs com instanceName para rastreamento
- [ ] Alertas quando instância fica offline > 10 minutos
