# pwa.md — ECHO Sub-Skill: Progressive Web App
# Ativa quando: "PWA", "service worker", "offline", "manifest"

---

## O QUE FAZ UM PWA

Um PWA é um site que se comporta como app nativo: instalável na tela inicial, funciona offline, recebe push notifications, carrega rápido. É a alternativa quando não vale o investimento em app nativo.

**Quando escolher PWA:**
- Produto já web-first e precisa de presença mobile
- Time sem experiência React Native
- Budget não comporta dois apps (iOS + Android)
- Funcionalidades necessárias não exigem acesso a hardware avançado

**Quando NÃO escolher PWA:**
- Precisa de câmera/GPS com alto nível de controle
- Performance gráfica crítica (jogos, AR/VR)
- App Store / Play Store são canais de aquisição essenciais
- Notificações push em iOS são prioridade (suporte PWA é limitado no Safari)

---

## WEB APP MANIFEST COMPLETO

```json
// public/manifest.json
{
  "name": "Wolf App",
  "short_name": "Wolf",
  "description": "Descrição clara do que o app faz",
  "start_url": "/",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#FFFFFF",
  "theme_color": "#0066FF",
  "lang": "pt-BR",
  "scope": "/",
  "categories": ["productivity", "business"],
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-96x96.png",
      "sizes": "96x96",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable any"
    }
  ],
  "screenshots": [
    {
      "src": "/screenshots/desktop.png",
      "sizes": "1280x720",
      "type": "image/png",
      "form_factor": "wide"
    },
    {
      "src": "/screenshots/mobile.png",
      "sizes": "390x844",
      "type": "image/png",
      "form_factor": "narrow"
    }
  ],
  "shortcuts": [
    {
      "name": "Nova Tarefa",
      "short_name": "Tarefa",
      "description": "Criar nova tarefa",
      "url": "/tasks/new",
      "icons": [{ "src": "/icons/shortcut-task.png", "sizes": "96x96" }]
    }
  ]
}
```

### Vincular no HTML

```html
<!-- public/index.html ou app/layout.tsx -->
<link rel="manifest" href="/manifest.json" />
<meta name="theme-color" content="#0066FF" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<meta name="apple-mobile-web-app-title" content="Wolf App" />
<link rel="apple-touch-icon" href="/icons/icon-192x192.png" />
```

---

## SERVICE WORKER COM WORKBOX

### Instalação

```bash
npm install workbox-precaching workbox-routing workbox-strategies workbox-expiration
```

### Service Worker (public/sw.js)

```javascript
// public/sw.js
import { precacheAndRoute, cleanupOutdatedCaches } from "workbox-precaching";
import { registerRoute } from "workbox-routing";
import {
  NetworkFirst,
  CacheFirst,
  StaleWhileRevalidate
} from "workbox-strategies";
import { ExpirationPlugin } from "workbox-expiration";

// Limpar caches antigos em novas versões
cleanupOutdatedCaches();

// Precache de assets estáticos (gerado pelo build)
precacheAndRoute(self.__WB_MANIFEST ?? []);

// Estratégia: Network First para chamadas de API
// - Tenta rede primeiro, fallback para cache se offline
registerRoute(
  ({ url }) => url.pathname.startsWith("/api/"),
  new NetworkFirst({
    cacheName: "api-cache",
    plugins: [
      new ExpirationPlugin({
        maxEntries: 50,
        maxAgeSeconds: 5 * 60 // 5 minutos
      })
    ]
  })
);

// Estratégia: Cache First para imagens
// - Serve do cache imediatamente, atualiza em background
registerRoute(
  ({ request }) => request.destination === "image",
  new CacheFirst({
    cacheName: "image-cache",
    plugins: [
      new ExpirationPlugin({
        maxEntries: 100,
        maxAgeSeconds: 30 * 24 * 60 * 60 // 30 dias
      })
    ]
  })
);

// Estratégia: Stale While Revalidate para fontes e CSS
registerRoute(
  ({ request }) =>
    request.destination === "style" ||
    request.destination === "font",
  new StaleWhileRevalidate({
    cacheName: "static-resources"
  })
);

// Push notification handler
self.addEventListener("push", (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(
    self.registration.showNotification(data.title ?? "Nova notificação", {
      body: data.body ?? "",
      icon: "/icons/icon-192x192.png",
      badge: "/icons/badge-72x72.png",
      data: { url: data.url ?? "/" }
    })
  );
});

// Click em notificação → abre URL
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data?.url ?? "/")
  );
});
```

### Registrar SW no App (Next.js)

```typescript
// app/layout.tsx ou pages/_app.tsx
"use client";

import { useEffect } from "react";

export function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", async () => {
      try {
        const registration = await navigator.serviceWorker.register("/sw.js");
        console.log("SW registered:", registration.scope);
      } catch (error) {
        console.error("SW registration failed:", error);
      }
    });
  }
}

// Componente para detectar atualização disponível
export function useServiceWorkerUpdate() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;

    navigator.serviceWorker.ready.then((registration) => {
      registration.addEventListener("updatefound", () => {
        const newWorker = registration.installing;
        newWorker?.addEventListener("statechange", () => {
          if (
            newWorker.state === "installed" &&
            navigator.serviceWorker.controller
          ) {
            // Nova versão disponível — mostrar banner de atualização
            console.log("New version available! Reload to update.");
          }
        });
      });
    });
  }, []);
}
```

---

## OFFLINE FALLBACK

```javascript
// Adicionar no service worker
import { setCatchHandler } from "workbox-routing";
import { matchPrecache } from "workbox-precaching";

// Fallback para navegação offline
setCatchHandler(async ({ request }) => {
  if (request.destination === "document") {
    return matchPrecache("/offline.html") ?? Response.error();
  }
  return Response.error();
});
```

```html
<!-- public/offline.html -->
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Sem conexão</title>
  <style>
    body { font-family: system-ui; display: flex; flex-direction: column;
           align-items: center; justify-content: center; min-height: 100vh;
           margin: 0; background: #fff; color: #1a1a1a; }
    h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
    p { color: #666; text-align: center; max-width: 300px; }
  </style>
</head>
<body>
  <h1>Sem conexão</h1>
  <p>Verifique sua conexão e tente novamente.</p>
</body>
</html>
```

---

## PUSH NOTIFICATIONS VIA WEB PUSH API

```typescript
// src/push-notifications.ts

const PUBLIC_VAPID_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!;

export async function subscribeToPushNotifications(): Promise<PushSubscription | null> {
  if (!("PushManager" in window)) {
    console.warn("Push notifications not supported");
    return null;
  }

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return null;

  const registration = await navigator.serviceWorker.ready;

  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(PUBLIC_VAPID_KEY)
  });

  // Salvar subscription no backend
  await fetch("/api/push/subscribe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(subscription)
  });

  return subscription;
}

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding)
    .replace(/-/g, "+")
    .replace(/_/g, "/");
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}
```

```typescript
// Backend: enviar push notification
// api/push/send.ts (Next.js API route)
import webpush from "web-push";

webpush.setVapidDetails(
  "mailto:tech@wolfagency.com",
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

export async function sendPushNotification(
  subscription: webpush.PushSubscription,
  payload: { title: string; body: string; url?: string }
): Promise<void> {
  await webpush.sendNotification(subscription, JSON.stringify(payload));
}
```

---

## CHECKLIST PWA

### Installable
- [ ] `manifest.json` com todos campos obrigatórios
- [ ] Ícone 192x192 e 512x512 com `purpose: "maskable any"`
- [ ] HTTPS configurado (obrigatório para SW)
- [ ] Service Worker registrado e ativo
- [ ] `start_url` válida e acessível offline

### Offline
- [ ] Rota offline fallback configurada (`/offline.html`)
- [ ] Assets críticos precacheados
- [ ] Estratégia de cache definida por tipo de recurso

### Fast (Core Web Vitals)
- [ ] LCP < 2.5s
- [ ] FID / INP < 200ms
- [ ] CLS < 0.1
- [ ] Verificar via `npx lighthouse https://seu-site.com --view`

### Lighthouse PWA Score
```bash
# Gerar relatório Lighthouse local
npx lighthouse https://seu-app.com \
  --output=html \
  --output-path=./lighthouse-report.html \
  --only-categories=pwa,performance \
  --view
```

Meta Wolf: score PWA >= 90, Performance >= 85.
