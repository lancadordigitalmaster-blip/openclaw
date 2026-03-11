# screens.md — ECHO Sub-Skill: Screens React Native
# Ativa quando: "tela", "screen", "componente mobile", "UI nativa"

---

## ESTRUTURA DE SCREEN EM EXPO ROUTER

### Hierarquia de Arquivos

```
app/
├── (tabs)/
│   ├── _layout.tsx      # Tab navigator config
│   ├── index.tsx        # Tab 1 (home)
│   └── profile.tsx      # Tab 2
├── (auth)/
│   ├── _layout.tsx      # Auth stack config
│   ├── login.tsx
│   └── register.tsx
├── item/
│   └── [id].tsx         # Dynamic route: /item/123
├── modal.tsx            # Modal screen
└── _layout.tsx          # Root layout (providers)
```

### Template de Screen Completa

```tsx
// app/(tabs)/index.tsx
import React, { useState, useEffect, useCallback } from "react";
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
  StyleSheet
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { StatusBar } from "expo-status-bar";

interface Item {
  id: string;
  title: string;
  description: string;
}

export default function HomeScreen() {
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchItems = useCallback(async () => {
    try {
      setError(null);
      const response = await fetch("https://api.example.com/items");
      if (!response.ok) throw new Error("Failed to fetch items");
      const data = await response.json();
      setItems(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  const handleRefresh = useCallback(() => {
    setRefreshing(true);
    fetchItems();
  }, [fetchItems]);

  // State: Loading
  if (loading) {
    return (
      <SafeAreaView style={styles.centered}>
        <ActivityIndicator size="large" color="#0066FF" />
      </SafeAreaView>
    );
  }

  // State: Error
  if (error) {
    return (
      <SafeAreaView style={styles.centered}>
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={styles.button} onPress={fetchItems}>
          <Text style={styles.buttonText}>Tentar novamente</Text>
        </TouchableOpacity>
      </SafeAreaView>
    );
  }

  // State: Empty
  if (items.length === 0) {
    return (
      <SafeAreaView style={styles.centered}>
        <Text style={styles.emptyText}>Nenhum item encontrado</Text>
      </SafeAreaView>
    );
  }

  // State: Content
  return (
    <SafeAreaView style={styles.container} edges={["top"]}>
      <StatusBar style="dark" />

      <View style={styles.header}>
        <Text style={styles.title}>Home</Text>
      </View>

      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.card}
            onPress={() => router.push(`/item/${item.id}`)}
            activeOpacity={0.7}
          >
            <Text style={styles.cardTitle}>{item.title}</Text>
            <Text style={styles.cardDescription} numberOfLines={2}>
              {item.description}
            </Text>
          </TouchableOpacity>
        )}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
        contentContainerStyle={styles.list}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF"
  },
  centered: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#FFFFFF",
    padding: 24
  },
  header: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#F0F0F0"
  },
  title: {
    fontSize: 24,
    fontWeight: "700",
    color: "#1A1A1A"
  },
  list: {
    padding: 16
  },
  card: {
    backgroundColor: "#F8F8F8",
    borderRadius: 12,
    padding: 16
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 4
  },
  cardDescription: {
    fontSize: 14,
    color: "#666666",
    lineHeight: 20
  },
  separator: {
    height: 12
  },
  errorText: {
    fontSize: 16,
    color: "#E53E3E",
    textAlign: "center",
    marginBottom: 16
  },
  emptyText: {
    fontSize: 16,
    color: "#999999",
    textAlign: "center"
  },
  button: {
    backgroundColor: "#0066FF",
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600"
  }
});
```

---

## NATIVEWIND (ESTILIZAÇÃO)

NativeWind traz Tailwind CSS para React Native. Use quando o projeto já tem NativeWind configurado.

```tsx
// Equivalente ao StyleSheet acima com NativeWind
import { View, Text, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function HomeScreen() {
  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <View className="px-5 py-4 border-b border-gray-100">
        <Text className="text-2xl font-bold text-gray-900">Home</Text>
      </View>

      <TouchableOpacity
        className="bg-gray-50 rounded-xl p-4 mx-4 mt-3 active:opacity-70"
        onPress={() => {}}
      >
        <Text className="text-base font-semibold text-gray-900 mb-1">
          Título do card
        </Text>
        <Text className="text-sm text-gray-500 leading-5" numberOfLines={2}>
          Descrição do card
        </Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}
```

---

## COMPONENTES NATIVOS VS WEB

| Web           | React Native Equivalente  | Observação                              |
|---------------|---------------------------|-----------------------------------------|
| `div`         | `View`                    | Container sem semântica                 |
| `p`, `span`   | `Text`                    | TODO texto deve estar em `Text`         |
| `button`      | `TouchableOpacity`        | ou `Pressable` para mais controle       |
| `input`       | `TextInput`               | teclado virtual controlado              |
| `img`         | `Image`                   | necessita `width` e `height` explícitos |
| `ul / li`     | `FlatList`                | virtualizado, não `ScrollView` + map    |
| `a`           | `Link` (Expo Router)      | ou `router.push()`                      |
| `form`        | `View` + lógica manual    | sem `onSubmit` nativo                   |

**Erro comum:** usar `map()` em ScrollView para listas longas. Use sempre `FlatList` ou `FlashList`.

---

## SAFEAREAVIEW E INSETS

```tsx
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";

// Opção 1: SafeAreaView com edges seletivos
function Screen() {
  return (
    // edges: aplica padding apenas no top e bottom (não nas laterais)
    <SafeAreaView style={{ flex: 1 }} edges={["top", "bottom"]}>
      {/* conteúdo */}
    </SafeAreaView>
  );
}

// Opção 2: insets manuais (mais controle)
function ScreenWithManualInsets() {
  const insets = useSafeAreaInsets();
  return (
    <View
      style={{
        flex: 1,
        paddingTop: insets.top,
        paddingBottom: insets.bottom
      }}
    >
      {/* conteúdo */}
    </View>
  );
}
```

**Regra:** sempre use `SafeAreaView` ou `useSafeAreaInsets` em screens. Nunca hardcode valores de padding para notch/home indicator.

---

## NAVEGAÇÃO COM EXPO ROUTER

### Navegar entre telas

```tsx
import { router, Link } from "expo-router";

// Programático
router.push("/profile");
router.push(`/item/${id}`);
router.replace("/login");        // substitui, sem voltar
router.back();                   // equivalente ao botão voltar

// Declarativo
<Link href="/profile">Ver perfil</Link>
<Link href={`/item/${id}`} asChild>
  <TouchableOpacity>
    <Text>Ver item</Text>
  </TouchableOpacity>
</Link>
```

### Passar parâmetros

```tsx
// Enviar
router.push({ pathname: "/item/[id]", params: { id: "123", tab: "details" } });

// Receber
import { useLocalSearchParams } from "expo-router";

function ItemScreen() {
  const { id, tab } = useLocalSearchParams<{ id: string; tab: string }>();
  return <Text>Item {id}, tab: {tab}</Text>;
}
```

### Layout de Stack (root)

```tsx
// app/_layout.tsx
import { Stack } from "expo-router";

export default function RootLayout() {
  return (
    <Stack>
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      <Stack.Screen
        name="modal"
        options={{
          presentation: "modal",
          title: "Modal Title"
        }}
      />
    </Stack>
  );
}
```

---

## CHECKLIST DE SCREEN PRONTA

- [ ] Três estados implementados: loading, error, content
- [ ] Estado empty tratado (lista vazia tem mensagem explicativa)
- [ ] `SafeAreaView` com edges corretos
- [ ] Listas usam `FlatList` ou `FlashList` (nunca `ScrollView + map`)
- [ ] `TouchableOpacity` tem `activeOpacity` configurado (padrão: 0.7)
- [ ] Navegação usa `router.push/replace` — sem `navigation` legado
- [ ] Fontes e cores seguem o design system do projeto
- [ ] `StatusBar` configurado (claro/escuro)
- [ ] Testado em iOS e Android (diferenças de padding, shadow)
