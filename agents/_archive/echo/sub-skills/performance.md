# performance.md — ECHO Sub-Skill: Performance Mobile
# Ativa quando: "performance", "lento no celular", "FPS", "memória"

---

## DIAGNÓSTICO ANTES DE OTIMIZAR

Antes de qualquer mudança, meça. Performance sem métricas é achismo.

```bash
# Habilitar modo performance no Metro
npx expo start --no-dev

# Ou rodar build de release local
npx expo run:android --variant release
npx expo run:ios --configuration Release
```

Ferramentas de profiling:
- **React DevTools Profiler** — identifica componentes com re-renders excessivos
- **Flipper** — CPU, memória, rede, logs nativos
- **Xcode Instruments** — profiling nativo iOS (leaks de memória, CPU)
- **Android Studio Profiler** — equivalente Android

---

## FLASHLIST VS FLATLIST

FlashList da Shopify é 10x mais performática que FlatList para listas longas. Substitua diretamente.

```bash
npx expo install @shopify/flash-list
```

```tsx
// ANTES: FlatList (ruim para listas > 100 itens)
import { FlatList } from "react-native";

<FlatList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <ItemCard item={item} />}
/>

// DEPOIS: FlashList (10x mais rápido, menor uso de memória)
import { FlashList } from "@shopify/flash-list";

<FlashList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <ItemCard item={item} />}
  estimatedItemSize={80}  // altura estimada de cada item em px — OBRIGATÓRIO
/>
```

**estimatedItemSize** é crítico para a performance do FlashList. Se itens têm tamanhos diferentes, use o tamanho médio. Um valor impreciso degrada a performance.

```tsx
// Para itens de tamanho variável, calcule a média:
// - Cards de texto: ~60-80px
// - Cards com imagem: ~120-160px
// - Rows de lista simples: ~48-56px
```

---

## REANIMATED 3 — ANIMAÇÕES NA THREAD NATIVA

Animações com `Animated` da RN rodam na thread JS e causam drops de FPS. Reanimated executa na thread nativa, mantendo 60fps mesmo sob carga.

```bash
npx expo install react-native-reanimated
```

```tsx
// Exemplo: fade in ao montar componente
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  withSpring,
  FadeIn,
  SlideInRight,
  ZoomIn
} from "react-native-reanimated";

// Forma 1: Entering/Exiting animations (mais simples)
function Card({ item }: { item: Item }) {
  return (
    <Animated.View entering={FadeIn.duration(300)} style={styles.card}>
      <Text>{item.title}</Text>
    </Animated.View>
  );
}

// Forma 2: useSharedValue + useAnimatedStyle (mais controle)
function AnimatedButton({ onPress }: { onPress: () => void }) {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }]
  }));

  return (
    <Animated.View style={animatedStyle}>
      <TouchableOpacity
        onPressIn={() => { scale.value = withSpring(0.95); }}
        onPressOut={() => { scale.value = withSpring(1); }}
        onPress={onPress}
      >
        <Text>Pressione</Text>
      </TouchableOpacity>
    </Animated.View>
  );
}
```

**Regra:** toda animação visível ao usuário deve usar Reanimated. Nunca use `Animated` da RN para animações de UI.

---

## REACT.MEMO, USEMEMO, USECALLBACK NO MOBILE

No mobile, re-renders custam mais que no web. A thread JS é compartilhada com animações e gestos.

### React.memo — evitar re-render de componentes filhos

```tsx
// Sem memo: re-renderiza toda vez que o pai re-renderiza
function ItemCard({ item, onPress }: { item: Item; onPress: (id: string) => void }) {
  return (
    <TouchableOpacity onPress={() => onPress(item.id)}>
      <Text>{item.title}</Text>
    </TouchableOpacity>
  );
}

// Com memo: só re-renderiza se props mudarem
const ItemCard = React.memo(function ItemCard({
  item,
  onPress
}: {
  item: Item;
  onPress: (id: string) => void;
}) {
  return (
    <TouchableOpacity onPress={() => onPress(item.id)}>
      <Text>{item.title}</Text>
    </TouchableOpacity>
  );
});
```

### useCallback — estabilizar referências de funções

```tsx
// PROBLEMA: função recriada a cada render → React.memo não funciona
function ListScreen() {
  const [items, setItems] = useState<Item[]>([]);

  // SEM useCallback: onPress é nova referência a cada render
  const handlePress = (id: string) => {
    router.push(`/item/${id}`);
  };

  // COM useCallback: onPress é estável entre renders
  const handlePress = useCallback((id: string) => {
    router.push(`/item/${id}`);
  }, []); // deps vazias = nunca recria

  return (
    <FlashList
      data={items}
      renderItem={({ item }) => (
        <ItemCard item={item} onPress={handlePress} />
      )}
      estimatedItemSize={80}
    />
  );
}
```

### useMemo — cálculos pesados

```tsx
// Filtro pesado de lista não deve rodar a cada render
const filteredItems = useMemo(
  () => items.filter(item =>
    item.title.toLowerCase().includes(searchQuery.toLowerCase())
  ),
  [items, searchQuery] // só recalcula quando items ou searchQuery mudam
);
```

**Regra de ouro:** não adicione memo/useMemo/useCallback preventivamente. Meça primeiro, otimize onde há evidência de problema.

---

## IMAGENS COM EXPO-IMAGE

`expo-image` é 2-5x mais rápido que `Image` do React Native. Suporta lazy loading, cache, blurhash placeholder.

```bash
npx expo install expo-image
```

```tsx
import { Image } from "expo-image";

// Básico com cache e lazy loading
<Image
  source={{ uri: "https://example.com/photo.jpg" }}
  style={{ width: 200, height: 200, borderRadius: 8 }}
  contentFit="cover"
  transition={200}                // fade in ao carregar
  cachePolicy="memory-disk"       // cache em memória + disco
/>

// Com blurhash placeholder (evita layout shift, melhor UX)
<Image
  source={{ uri: imageUrl }}
  placeholder={{ blurhash: item.blurhash }}
  style={{ width: "100%", height: 200 }}
  contentFit="cover"
  transition={300}
/>
```

### Gerar blurhash no backend

```typescript
// backend: gerar blurhash ao fazer upload de imagem
import { encode } from "blurhash";
import sharp from "sharp";

async function generateBlurhash(imagePath: string): Promise<string> {
  const { data, info } = await sharp(imagePath)
    .raw()
    .ensureAlpha()
    .resize(32, 32, { fit: "inside" })
    .toBuffer({ resolveWithObject: true });

  return encode(
    new Uint8ClampedArray(data),
    info.width,
    info.height,
    4, // componentes X
    3  // componentes Y
  );
}
```

---

## EVITAR RE-RENDERS DESNECESSÁRIOS

### Diagnóstico com React DevTools

```bash
# Instalar React DevTools standalone
npm install -g react-devtools

# Rodar junto com o app
react-devtools
```

No profiler, ative "Highlight updates when components render". Componentes piscando em laranja/vermelho = re-renders.

### Padrões de problema e solução

```tsx
// PROBLEMA 1: objeto inline como prop (nova referência a cada render)
<Component style={{ flex: 1, padding: 16 }} />

// SOLUÇÃO: StyleSheet ou useMemo
const styles = StyleSheet.create({ container: { flex: 1, padding: 16 } });
<Component style={styles.container} />

// PROBLEMA 2: array inline como prop
<FlashList data={[...items]} />

// SOLUÇÃO: estado ou useMemo
const [items, setItems] = useState<Item[]>([]);
<FlashList data={items} />

// PROBLEMA 3: context que muda muito causando re-render global
const ThemeContext = createContext({ color: "blue", size: 14 });

// SOLUÇÃO: separar contexts por domínio de mudança
const ThemeColorContext = createContext("blue");
const ThemeSizeContext = createContext(14);
```

---

## CHECKLIST DE PERFORMANCE

### Listas
- [ ] FlatList substituída por FlashList (listas > 50 itens)
- [ ] `estimatedItemSize` definido com valor próximo da realidade
- [ ] Componente de item memoizado com `React.memo`
- [ ] `onPress` e callbacks estabilizados com `useCallback`

### Imagens
- [ ] `expo-image` usado em vez de `Image` nativo
- [ ] Blurhash ou placeholder configurado
- [ ] Imagens grandes redimensionadas no backend antes de servir

### Animações
- [ ] Animações visíveis usam Reanimated 3
- [ ] Sem `Animated` legado do React Native em código novo

### Geral
- [ ] Build de release testada (não dev) para medir performance real
- [ ] FPS medido no Flipper (meta: 60fps constante)
- [ ] Sem `console.log` em hot path (impacto real em produção)
- [ ] Imagens servidas com CDN e cache-control adequado
