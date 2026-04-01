# native-features.md — ECHO Sub-Skill: Native Features & Permissões
# Ativa quando: "câmera", "localização", "sensor", "permissão"

---

## GERENCIAMENTO DE PERMISSÕES — PADRÃO WOLF

### Princípios
1. Solicite permissão no momento de uso (contextual), não ao abrir o app
2. Explique POR QUE antes de solicitar (aumenta taxa de concessão)
3. Nunca quebre o app se permissão for negada — degrade graciosamente
4. Se negada permanentemente, direcione para configurações do sistema

### Hook Universal de Permissão

```typescript
// src/hooks/usePermission.ts
import { useState, useCallback } from "react";
import { Alert, Linking, Platform } from "react-native";
import * as IntentLauncher from "expo-intent-launcher";

type PermissionStatus = "undetermined" | "granted" | "denied";

interface UsePermissionOptions {
  featureName: string;          // "câmera", "localização"
  rationaleMessage: string;     // Por que o app precisa desta permissão
  requestFn: () => Promise<{ status: string }>;
  checkFn: () => Promise<{ status: string }>;
}

export function usePermission(options: UsePermissionOptions) {
  const { featureName, rationaleMessage, requestFn, checkFn } = options;
  const [status, setStatus] = useState<PermissionStatus>("undetermined");

  const openSettings = useCallback(() => {
    if (Platform.OS === "ios") {
      Linking.openURL("app-settings:");
    } else {
      IntentLauncher.startActivityAsync(
        IntentLauncher.ActivityAction.APPLICATION_DETAILS_SETTINGS
      );
    }
  }, []);

  const requestPermission = useCallback(async (): Promise<boolean> => {
    // Verificar status atual
    const { status: currentStatus } = await checkFn();

    if (currentStatus === "granted") {
      setStatus("granted");
      return true;
    }

    if (currentStatus === "denied") {
      // Já negou antes — explicar e enviar para configurações
      Alert.alert(
        `Permissão de ${featureName}`,
        `Para usar esta funcionalidade, ative o acesso à ${featureName} nas configurações do seu dispositivo.\n\n${rationaleMessage}`,
        [
          { text: "Cancelar", style: "cancel" },
          { text: "Abrir Configurações", onPress: openSettings }
        ]
      );
      setStatus("denied");
      return false;
    }

    // Primeira solicitação
    const { status: newStatus } = await requestFn();
    const granted = newStatus === "granted";
    setStatus(granted ? "granted" : "denied");
    return granted;
  }, [checkFn, requestFn, featureName, rationaleMessage, openSettings]);

  return { status, requestPermission };
}
```

---

## EXPO CAMERA

### Instalação

```bash
npx expo install expo-camera expo-media-library
```

### Configuração (app.json)

```json
{
  "expo": {
    "plugins": [
      [
        "expo-camera",
        {
          "cameraPermission": "Precisamos da câmera para tirar fotos do seu documento.",
          "microphonePermission": "Precisamos do microfone para gravar vídeos."
        }
      ],
      [
        "expo-media-library",
        {
          "photosPermission": "Precisamos acessar suas fotos para salvar imagens.",
          "savePhotosPermission": "Precisamos salvar fotos na sua galeria."
        }
      ]
    ]
  }
}
```

### Componente de Câmera Completo

```tsx
// src/components/Camera.tsx
import React, { useState, useRef, useCallback } from "react";
import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import {
  CameraView,
  CameraType,
  useCameraPermissions,
  BarcodeScanningResult
} from "expo-camera";
import * as MediaLibrary from "expo-media-library";

interface CameraProps {
  mode?: "photo" | "qrcode";
  onCapture?: (uri: string) => void;
  onQRCodeScanned?: (data: string) => void;
}

export function Camera({ mode = "photo", onCapture, onQRCodeScanned }: CameraProps) {
  const cameraRef = useRef<CameraView>(null);
  const [facing, setFacing] = useState<CameraType>("back");
  const [isCapturing, setIsCapturing] = useState(false);

  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [mediaPermission, requestMediaPermission] = MediaLibrary.usePermissions();

  // Solicitar permissões se necessário
  if (!cameraPermission?.granted) {
    return (
      <View style={styles.centered}>
        <Text style={styles.message}>
          Precisamos da câmera para capturar imagens do seu documento.
        </Text>
        <TouchableOpacity style={styles.button} onPress={requestCameraPermission}>
          <Text style={styles.buttonText}>Permitir câmera</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const handleTakePhoto = useCallback(async () => {
    if (!cameraRef.current || isCapturing) return;

    setIsCapturing(true);
    try {
      const photo = await cameraRef.current.takePictureAsync({
        quality: 0.8,
        base64: false,
        exif: false
      });

      if (photo) {
        // Salvar na galeria se tiver permissão
        if (mediaPermission?.granted) {
          await MediaLibrary.saveToLibraryAsync(photo.uri);
        }
        onCapture?.(photo.uri);
      }
    } catch (error) {
      console.error("Failed to take photo:", error);
    } finally {
      setIsCapturing(false);
    }
  }, [isCapturing, mediaPermission, onCapture]);

  const handleQRCodeScanned = useCallback(
    ({ data }: BarcodeScanningResult) => {
      onQRCodeScanned?.(data);
    },
    [onQRCodeScanned]
  );

  return (
    <View style={styles.container}>
      <CameraView
        ref={cameraRef}
        style={styles.camera}
        facing={facing}
        barcodeScannerSettings={
          mode === "qrcode"
            ? { barcodeTypes: ["qr", "ean13", "ean8", "code128"] }
            : undefined
        }
        onBarcodeScanned={mode === "qrcode" ? handleQRCodeScanned : undefined}
      >
        <View style={styles.controls}>
          <TouchableOpacity
            style={styles.flipButton}
            onPress={() => setFacing(f => (f === "back" ? "front" : "back"))}
          >
            <Text style={styles.flipText}>Virar</Text>
          </TouchableOpacity>

          {mode === "photo" && (
            <TouchableOpacity
              style={[styles.captureButton, isCapturing && styles.captureButtonDisabled]}
              onPress={handleTakePhoto}
              disabled={isCapturing}
            />
          )}
        </View>
      </CameraView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  camera: { flex: 1 },
  centered: { flex: 1, justifyContent: "center", alignItems: "center", padding: 24 },
  message: { fontSize: 16, textAlign: "center", marginBottom: 20, color: "#333" },
  controls: {
    position: "absolute",
    bottom: 40,
    left: 0,
    right: 0,
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 40
  },
  flipButton: { padding: 12 },
  flipText: { color: "#FFF", fontSize: 16, fontWeight: "600" },
  captureButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: "#FFF",
    borderWidth: 4,
    borderColor: "rgba(255,255,255,0.5)"
  },
  captureButtonDisabled: { opacity: 0.5 },
  button: { backgroundColor: "#0066FF", padding: 14, borderRadius: 8 },
  buttonText: { color: "#FFF", fontWeight: "600" }
});
```

---

## EXPO LOCATION

### Instalação

```bash
npx expo install expo-location
```

### Configuração (app.json)

```json
{
  "expo": {
    "plugins": [
      [
        "expo-location",
        {
          "locationAlwaysAndWhenInUsePermission": "Usamos sua localização para mostrar serviços próximos a você.",
          "locationWhenInUsePermission": "Usamos sua localização para mostrar serviços próximos a você.",
          "isIosBackgroundLocationEnabled": false
        }
      ]
    ]
  }
}
```

### Uso com Padrão Wolf de Permissão

```typescript
// src/hooks/useLocation.ts
import { useState, useCallback } from "react";
import * as Location from "expo-location";

interface LocationCoords {
  latitude: number;
  longitude: number;
  accuracy: number | null;
}

export function useLocation() {
  const [location, setLocation] = useState<LocationCoords | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getCurrentLocation = useCallback(async (): Promise<LocationCoords | null> => {
    setLoading(true);
    setError(null);

    try {
      // Verificar e solicitar permissão
      const { status } = await Location.requestForegroundPermissionsAsync();

      if (status !== "granted") {
        setError("Permissão de localização negada");
        return null;
      }

      // Obter posição atual
      const position = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced
      });

      const coords = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy
      };

      setLocation(coords);
      return coords;
    } catch (err) {
      const message = err instanceof Error ? err.message : "Erro ao obter localização";
      setError(message);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  return { location, loading, error, getCurrentLocation };
}
```

### Geofencing (alertar quando usuário entra/sai de área)

```typescript
// src/notifications/geofencing.ts
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";

const GEOFENCE_TASK = "geofence-task";

// Definir task em nível de módulo (fora de componente)
TaskManager.defineTask(GEOFENCE_TASK, ({ data, error }) => {
  if (error) {
    console.error("Geofencing error:", error);
    return;
  }

  const { eventType, region } = data as {
    eventType: Location.GeofencingEventType;
    region: Location.LocationRegion;
  };

  if (eventType === Location.GeofencingEventType.Enter) {
    console.log(`Entered region: ${region.identifier}`);
    // Disparar notificação local ou evento de analytics
  } else if (eventType === Location.GeofencingEventType.Exit) {
    console.log(`Exited region: ${region.identifier}`);
  }
});

export async function startGeofencing(regions: Location.LocationRegion[]) {
  const { status } = await Location.requestBackgroundPermissionsAsync();
  if (status !== "granted") {
    console.warn("Background location permission required for geofencing");
    return;
  }

  await Location.startGeofencingAsync(GEOFENCE_TASK, regions);
}

// Exemplo de uso:
// startGeofencing([{
//   identifier: "wolf-office",
//   latitude: -23.5505,
//   longitude: -46.6333,
//   radius: 200  // metros
// }]);
```

---

## EXPO BARCODE SCANNER

```tsx
// Scanner de QR Code simples (usa CameraView com barcodeScannerSettings)
// Ver componente Camera acima — suporte a QR nativo via expo-camera

// Para scanning standalone (sem UI de câmera customizada):
import { CameraView, useCameraPermissions } from "expo-camera";

function QRScanner({ onScan }: { onScan: (data: string) => void }) {
  const [scanned, setScanned] = useState(false);
  const [permission, requestPermission] = useCameraPermissions();

  if (!permission?.granted) {
    return (
      <TouchableOpacity onPress={requestPermission}>
        <Text>Permitir câmera para escanear QR Code</Text>
      </TouchableOpacity>
    );
  }

  return (
    <CameraView
      style={{ flex: 1 }}
      barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
      onBarcodeScanned={scanned ? undefined : ({ data }) => {
        setScanned(true);
        onScan(data);
        // Reset após 2s para permitir novo scan
        setTimeout(() => setScanned(false), 2000);
      }}
    />
  );
}
```

---

## CHECKLIST DE NATIVE FEATURES

### Permissões
- [ ] Todas as permissões descritas no `app.json` com mensagem explicativa
- [ ] Permissão solicitada no contexto de uso (não no onboarding genérico)
- [ ] Fallback implementado quando permissão é negada
- [ ] Usuário redirecionado para configurações se negou permanentemente

### Câmera
- [ ] Permissão de câmera solicitada com contexto claro
- [ ] Estados de loading durante captura tratados (disabled + feedback visual)
- [ ] Imagem capturada comprimida (quality: 0.8 é suficiente para maioria dos casos)
- [ ] Testado em iOS e Android (comportamento de câmera difere)

### Localização
- [ ] Foreground permission para uso em tempo real
- [ ] Background permission solicitada apenas se geofencing é necessário
- [ ] `accuracy: Balanced` para localização casual (economiza bateria)
- [ ] `accuracy: High` apenas quando GPS preciso é crítico (navegação)
- [ ] Erro de permissão negada retorna mensagem clara para o usuário

### Geral
- [ ] Módulos nativos adicionados ao `app.json` plugins
- [ ] Novo build gerado após adicionar módulo nativo (OTA não é suficiente)
- [ ] Testado em device físico (simulador não suporta câmera, GPS real)
