# notifications.md — ECHO Sub-Skill: Push Notifications Mobile
# Ativa quando: "notificação", "push", "FCM", "Expo notifications"

---

## EXPO NOTIFICATIONS — SETUP COMPLETO

### Instalação

```bash
npx expo install expo-notifications expo-device expo-constants
```

### Configuração no app.json / app.config.ts

```json
{
  "expo": {
    "plugins": [
      [
        "expo-notifications",
        {
          "icon": "./assets/notification-icon.png",
          "color": "#0066FF",
          "sounds": ["./assets/notification-sound.wav"],
          "mode": "production"
        }
      ]
    ],
    "android": {
      "googleServicesFile": "./google-services.json"
    },
    "ios": {
      "bundleIdentifier": "com.wolfagency.app"
    }
  }
}
```

---

## PERMISSÕES E TOKEN

```typescript
// src/notifications/setup.ts
import * as Notifications from "expo-notifications";
import * as Device from "expo-device";
import Constants from "expo-constants";
import { Platform } from "react-native";

// Configurar comportamento de notificação quando app está em foreground
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true
  })
});

export async function registerForPushNotifications(): Promise<string | null> {
  // Notificações só funcionam em dispositivo real (não simulador)
  if (!Device.isDevice) {
    console.warn("Push notifications require a physical device");
    return null;
  }

  // Verificar permissão atual
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  // Solicitar permissão se não foi concedida
  if (existingStatus !== "granted") {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== "granted") {
    console.warn("Push notification permission denied");
    return null;
  }

  // Configuração específica Android
  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "default",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: "#0066FF"
    });
  }

  // Obter token Expo Push
  const projectId = Constants.expoConfig?.extra?.eas?.projectId;
  if (!projectId) throw new Error("Missing EAS project ID in app.config");

  const token = await Notifications.getExpoPushTokenAsync({ projectId });
  return token.data;
}
```

### Hook de Setup no App

```typescript
// src/hooks/useNotifications.ts
import { useEffect, useRef } from "react";
import * as Notifications from "expo-notifications";
import { router } from "expo-router";
import { registerForPushNotifications } from "../notifications/setup";

export function useNotifications() {
  const notificationListener = useRef<Notifications.Subscription>();
  const responseListener = useRef<Notifications.Subscription>();

  useEffect(() => {
    // Registrar device e obter token
    registerForPushNotifications().then((token) => {
      if (token) {
        // Salvar token no backend
        savePushToken(token);
      }
    });

    // Listener: notificação recebida com app aberto
    notificationListener.current = Notifications.addNotificationReceivedListener(
      (notification) => {
        console.log("Notification received:", notification);
      }
    );

    // Listener: usuário tocou na notificação
    responseListener.current = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        const data = response.notification.request.content.data;
        // Deep link baseado nos dados da notificação
        if (data?.screen) {
          router.push(data.screen as string);
        }
      }
    );

    return () => {
      notificationListener.current?.remove();
      responseListener.current?.remove();
    };
  }, []);
}

async function savePushToken(token: string): Promise<void> {
  await fetch("/api/push-tokens", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, platform: Platform.OS })
  });
}
```

---

## NOTIFICAÇÕES LOCAIS VS PUSH REMOTO

| Tipo         | Quando usar                                    | Como funciona              |
|--------------|------------------------------------------------|----------------------------|
| Local        | Lembretes, alarmes, timers locais              | Agendado no próprio device |
| Push remoto  | Eventos do servidor, mensagens de outros usuários | FCM/APNs → Expo → device |

### Notificação Local

```typescript
// Agendamento de notificação local
import * as Notifications from "expo-notifications";

// Imediata
async function sendLocalNotification(title: string, body: string, data = {}) {
  await Notifications.scheduleNotificationAsync({
    content: {
      title,
      body,
      data,
      sound: true,
      badge: 1
    },
    trigger: null // null = imediata
  });
}

// Agendada por data
async function scheduleNotification(
  title: string,
  body: string,
  date: Date,
  data = {}
) {
  await Notifications.scheduleNotificationAsync({
    content: { title, body, data, sound: true },
    trigger: {
      date,
      type: Notifications.SchedulableTriggerInputTypes.DATE
    }
  });
}

// Agendada por intervalo (ex: lembrete diário às 9h)
async function scheduleDailyReminder() {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "Não esqueça de verificar suas tarefas",
      body: "Você tem itens pendentes"
    },
    trigger: {
      hour: 9,
      minute: 0,
      repeats: true,
      type: Notifications.SchedulableTriggerInputTypes.DAILY
    }
  });
}

// Cancelar todas as notificações agendadas
async function cancelAllNotifications() {
  await Notifications.cancelAllScheduledNotificationsAsync();
}
```

---

## FIREBASE FCM PARA PRODUÇÃO

FCM (Firebase Cloud Messaging) é o canal de transporte para push em produção. O Expo Push Service é intermediário que facilita o envio.

### Fluxo de envio

```
Seu servidor → Expo Push API → FCM/APNs → Device
```

### Enviar push via Expo API (backend Node.js)

```typescript
// backend/src/notifications/push.ts
import { Expo, ExpoPushMessage, ExpoPushTicket } from "expo-server-sdk";

const expo = new Expo({
  accessToken: process.env.EXPO_ACCESS_TOKEN
});

interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, unknown>;
  badge?: number;
}

export async function sendPushNotifications(
  tokens: string[],
  payload: PushPayload
): Promise<void> {
  // Filtrar tokens válidos
  const validTokens = tokens.filter(token => Expo.isExpoPushToken(token));

  if (validTokens.length === 0) {
    console.warn("No valid Expo push tokens");
    return;
  }

  // Criar messages
  const messages: ExpoPushMessage[] = validTokens.map(token => ({
    to: token,
    title: payload.title,
    body: payload.body,
    data: payload.data ?? {},
    badge: payload.badge ?? 1,
    sound: "default",
    priority: "high"
  }));

  // Enviar em chunks (Expo limita 100 por request)
  const chunks = expo.chunkPushNotifications(messages);

  for (const chunk of chunks) {
    try {
      const tickets: ExpoPushTicket[] = await expo.sendPushNotificationsAsync(chunk);

      // Verificar tickets com erro
      for (const ticket of tickets) {
        if (ticket.status === "error") {
          console.error("Push error:", ticket.message, ticket.details);

          // Token inválido: remover do banco
          if (ticket.details?.error === "DeviceNotRegistered") {
            // invalidateToken(token)
          }
        }
      }
    } catch (error) {
      console.error("Failed to send push chunk:", error);
    }
  }
}
```

---

## DEEP LINKING COM NOTIFICAÇÃO

O usuário toca na notificação e é levado para uma tela específica.

```typescript
// Ao enviar a notificação do backend, incluir dados de deep link:
const message = {
  to: pushToken,
  title: "Nova mensagem de João",
  body: "Oi, precisamos conversar sobre o projeto",
  data: {
    screen: "/messages/chat/123",  // Rota Expo Router
    userId: "user_456"
  }
};

// No listener de resposta (useNotifications hook já faz isso):
responseListener.current = Notifications.addNotificationResponseReceivedListener(
  (response) => {
    const { screen } = response.notification.request.content.data as {
      screen?: string;
    };

    if (screen) {
      router.push(screen);
    }
  }
);

// Tratar notificação que abriu o app do estado fechado:
useEffect(() => {
  Notifications.getLastNotificationResponseAsync().then((response) => {
    if (response?.notification.request.content.data?.screen) {
      const screen = response.notification.request.content.data.screen as string;
      router.push(screen);
    }
  });
}, []);
```

---

## CHECKLIST DE PUSH NOTIFICATIONS

### Setup
- [ ] `expo-notifications` instalado e configurado no `app.json`
- [ ] `google-services.json` (Android) e APNs key (iOS) configurados no EAS
- [ ] Canal Android criado com importância MAX para notificações críticas
- [ ] Token salvo no backend com identificação de plataforma (ios/android)

### UX de Permissão
- [ ] Permissão solicitada com contexto (explique por que o app precisa)
- [ ] Fallback claro se usuário nega (funcionalidade degradada, não quebrada)
- [ ] Opção de reativar nas configurações do app

### Envio
- [ ] Tokens inválidos (`DeviceNotRegistered`) são removidos do banco automaticamente
- [ ] Envio em chunks de 100 (limite Expo)
- [ ] Logs de erros de envio por token

### Deep Linking
- [ ] Notificação com `data.screen` navega para rota correta
- [ ] Funciona quando app está fechado (cold start) e em background
- [ ] Testado em iOS e Android
