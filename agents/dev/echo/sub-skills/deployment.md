# deployment.md — ECHO Sub-Skill: Build, Deploy & Store
# Ativa quando: "build", "deploy", "store", "EAS", "publicar"

---

## EAS BUILD — VISÃO GERAL

EAS (Expo Application Services) é o serviço de build e deploy Wolf para React Native. Gera binários nativos (.ipa para iOS, .apk/.aab para Android) na nuvem, sem precisar de Mac para iOS.

```bash
# Instalar EAS CLI
npm install -g eas-cli

# Login
eas login

# Configurar projeto (primeira vez)
eas build:configure
```

---

## EAS.JSON — CONFIGURAÇÃO COMPLETA

```json
// eas.json
{
  "cli": {
    "version": ">= 10.0.0",
    "appVersionSource": "remote"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "android": {
        "buildType": "apk",
        "gradleCommand": ":app:assembleDebug"
      },
      "ios": {
        "simulator": true
      },
      "env": {
        "APP_ENV": "development",
        "API_URL": "http://localhost:3000"
      }
    },
    "preview": {
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      },
      "ios": {
        "simulator": false
      },
      "channel": "preview",
      "env": {
        "APP_ENV": "staging",
        "API_URL": "https://api.staging.wolfagency.com"
      }
    },
    "production": {
      "distribution": "store",
      "android": {
        "buildType": "app-bundle"  // AAB para Play Store
      },
      "channel": "production",
      "env": {
        "APP_ENV": "production",
        "API_URL": "https://api.wolfagency.com"
      },
      "autoIncrement": true  // incrementa versionCode/buildNumber automaticamente
    }
  },
  "submit": {
    "production": {
      "android": {
        "serviceAccountKeyPath": "./keys/play-store-service-account.json",
        "track": "internal"
      },
      "ios": {
        "appleId": "dev@wolfagency.com",
        "ascAppId": "1234567890",
        "appleTeamId": "ABCDEF1234"
      }
    }
  }
}
```

---

## PROFILES DE BUILD

### Development — para desenvolvimento diário

```bash
# Build para simulador iOS (sem certificados)
eas build --profile development --platform ios

# Build APK Android para device físico
eas build --profile development --platform android

# Usar expo-dev-client para hot reload com módulos nativos
npx expo install expo-dev-client
```

### Preview — para testes internos e QA

```bash
# Build para distribuição interna (link de download)
eas build --profile preview --platform all

# Compartilhar link com time de QA
# EAS retorna URL de download após build
```

### Production — para stores

```bash
# Build de produção (AAB para Android, IPA para iOS)
eas build --profile production --platform all

# Acompanhar status do build
eas build:list

# Ver logs de um build específico
eas build:view [BUILD_ID]
```

---

## EAS SUBMIT — APP STORE E GOOGLE PLAY

```bash
# Submit após build de produção
eas submit --platform android
eas submit --platform ios

# Submit de build específico (por ID)
eas submit --platform android --id [BUILD_ID]

# Build + Submit em sequência
eas build --profile production --platform all --auto-submit
```

### Pré-requisitos para Submit

**Android:**
1. Conta Google Play Console ativa
2. Service account JSON com permissões de Release Manager
3. App criado manualmente na Play Console (primeira vez)
4. Política de privacidade configurada

**iOS:**
1. Conta Apple Developer Program ($99/ano)
2. App criado no App Store Connect
3. Bundle ID correspondente ao `app.json`
4. Política de privacidade URL configurada

---

## OTA UPDATES — EXPO UPDATES

OTA (Over-the-Air) permite publicar atualizações de JavaScript sem passar pela store. Crítico para correções urgentes.

### O que PODE ser atualizado por OTA:
- Código JavaScript/TypeScript
- Assets bundleados (imagens em assets/)
- Lógica de negócio, UI, navegação
- Textos, cores, layouts

### O que NÃO PODE ser atualizado por OTA:
- Módulos nativos novos (exige novo build)
- Permissões novas no `app.json`
- Mudanças no `app.json` / `app.config.ts`
- Versão mínima de iOS/Android
- Splash screen e ícone do app

### Configuração

```json
// app.json
{
  "expo": {
    "updates": {
      "url": "https://u.expo.dev/[PROJECT_ID]",
      "checkAutomatically": "ON_LOAD",
      "fallbackToCacheTimeout": 0
    },
    "runtimeVersion": {
      "policy": "appVersion"
    }
  }
}
```

### Publicar update OTA

```bash
# Publicar para canal de produção
eas update --branch production --message "Fix: crash na tela de pagamento"

# Publicar para canal de staging
eas update --branch preview --message "Feature: novo filtro de busca"

# Ver histórico de updates
eas update:list
```

### Controle de update no app

```typescript
// src/hooks/useOTAUpdate.ts
import * as Updates from "expo-updates";
import { useEffect } from "react";
import { Alert } from "react-native";

export function useOTAUpdate() {
  useEffect(() => {
    async function checkForUpdate() {
      if (__DEV__) return; // Não verificar em desenvolvimento

      try {
        const update = await Updates.checkForUpdateAsync();
        if (update.isAvailable) {
          await Updates.fetchUpdateAsync();
          Alert.alert(
            "Atualização disponível",
            "Uma nova versão foi baixada. Reiniciar agora?",
            [
              { text: "Depois", style: "cancel" },
              {
                text: "Reiniciar",
                onPress: () => Updates.reloadAsync()
              }
            ]
          );
        }
      } catch (error) {
        console.error("OTA check failed:", error);
      }
    }

    checkForUpdate();
  }, []);
}
```

---

## CHECKLIST DE SUBMISSÃO PARA STORE

### Antes do Build de Produção
- [ ] `version` no `app.json` atualizada (semver: major.minor.patch)
- [ ] Changelog escrito para a versão
- [ ] Todos os testes passando
- [ ] Build de release testada em device físico (iOS e Android)
- [ ] Sem `console.log` ou logs de debug no código
- [ ] Variáveis de ambiente de produção configuradas

### App Store (iOS)
- [ ] Screenshots para iPhone 6.5" e 6.7" (obrigatório)
- [ ] Screenshots para iPad (se suporta iPad)
- [ ] Descrição do app revisada
- [ ] Palavras-chave (keywords) otimizadas para ASO
- [ ] Política de privacidade URL válida
- [ ] Classificação etária configurada
- [ ] Informações de revisão: conta de teste se o app requer login
- [ ] Resposta para "Does this app use encryption?" preparada (geralmente: "Standard HTTPS")

### Google Play
- [ ] Screenshots: mínimo 2 por formfactor
- [ ] Ícone feature graphic (1024x500) criado
- [ ] Descrição curta (80 chars) e longa revisadas
- [ ] Classificação de conteúdo preenchida
- [ ] Formulário de declaração de segurança de dados preenchido
- [ ] Track de distribuição: internal → alpha → production (nunca vai direto para production)

### Pós-Submit
- [ ] Monitor de crashes configurado (Sentry ou similar)
- [ ] Push notifications de produção testadas
- [ ] Analytics de produção verificados
- [ ] Canal de OTA de produção ativo
