# state.md — Pixel Sub-Skill: Gerenciamento de Estado
# Ativa quando: "estado", "state", "dados", "cache", "fetch"

---

## MATRIZ DE DECISÃO — QUAL FERRAMENTA USAR

```
PERGUNTA 1: O dado vem do servidor?
  SIM → TanStack Query
  NÃO → continua para pergunta 2

PERGUNTA 2: O estado é local a um componente ou pequena árvore?
  SIM → useState / useReducer
  NÃO → continua para pergunta 3

PERGUNTA 3: Múltiplos componentes distantes precisam deste estado?
  SIM, é estado de UI global → Zustand
  SIM, é autenticação/tema/i18n → Context API

REGRA: Começa pelo mais simples que funciona.
  useState → useContext → Zustand → TanStack Query
  Não pula etapas sem razão concreta.
```

```yaml
quando_usar_cada_um:
  useState:
    para: "estado local de UI, toggle de modal, valor de input não controlado"
    nao_usar_para: "dados do servidor, estado compartilhado entre páginas"
    exemplo: "isMenuOpen, selectedTab, count, inputValue"

  useReducer:
    para: "estado complexo com múltiplas transições relacionadas"
    quando: "useState com mais de 3-4 campos relacionados, lógica de estado non-trivial"
    exemplo: "wizard de múltiplos passos, estado de filtros complexo"

  Context API:
    para: "estado que precisa ser acessado em toda a árvore sem ser server state"
    cuidado: "qualquer update no Context re-renderiza TODOS os consumidores"
    exemplo: "tema, locale, dados do usuário logado (session)"
    nao_usar_para: "estado que muda frequentemente (causa re-render em tudo)"

  Zustand:
    para: "estado global de cliente que muda com frequência ou tem lógica complexa"
    exemplo: "carrinho de compras, filtros aplicados, preferências do usuário"
    vantagem: "seletores evitam re-renders desnecessários, fora do React"

  TanStack Query:
    para: "qualquer dado que vem do servidor: fetch, mutation, paginação, cache"
    regra: "se tem await/fetch: usa TanStack Query"
    vantagem: "cache automático, retry, stale-while-revalidate, loading/error state grátis"
```

---

## TANSTACK QUERY — Server State

### Setup

```typescript
// providers.tsx — configura QueryClient uma vez
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,      // 5 min — dado considerado fresco
      gcTime: 1000 * 60 * 10,         // 10 min — tempo no cache após unmount
      retry: 2,                        // tenta 2x antes de declarar erro
      refetchOnWindowFocus: true,      // revalida ao voltar para a aba
    },
    mutations: {
      retry: 0,                        // mutations não fazem retry automático
    },
  },
})

export function Providers({ children }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}
```

### Padrão de Query (leitura)

```typescript
// hooks/use-campaigns.ts — encapsula a query
import { useQuery, useQueryClient } from '@tanstack/react-query'

// Chaves de query centralizadas (evita typos e facilita invalidação)
export const campaignKeys = {
  all: ['campaigns'] as const,
  lists: () => [...campaignKeys.all, 'list'] as const,
  list: (filters: CampaignFilters) => [...campaignKeys.lists(), filters] as const,
  details: () => [...campaignKeys.all, 'detail'] as const,
  detail: (id: string) => [...campaignKeys.details(), id] as const,
}

// Hook de listagem
export const useCampaigns = (filters: CampaignFilters) => {
  return useQuery({
    queryKey: campaignKeys.list(filters),
    queryFn: () => campaignApi.list(filters),
    placeholderData: keepPreviousData, // evita flash de loading na paginação
  })
}

// Hook de detalhe
export const useCampaign = (id: string) => {
  return useQuery({
    queryKey: campaignKeys.detail(id),
    queryFn: () => campaignApi.getById(id),
    enabled: !!id, // não executa se id for undefined/null
  })
}

// Uso no componente
const CampaignList = ({ filters }) => {
  const { data, isLoading, isError, error } = useCampaigns(filters)

  if (isLoading) return <CampaignListSkeleton />
  if (isError) return <ErrorMessage message={error.message} />
  if (!data?.length) return <EmptyState message="Nenhuma campanha encontrada" />

  return (
    <ul>
      {data.map(campaign => (
        <CampaignRow key={campaign.id} campaign={campaign} />
      ))}
    </ul>
  )
}
```

### Padrão de Mutation (escrita)

```typescript
// hooks/use-create-campaign.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'

export const useCreateCampaign = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (input: CreateCampaignInput) => campaignApi.create(input),

    // Otimistic update — atualiza UI antes da resposta do servidor
    onMutate: async (newCampaign) => {
      // Cancela queries em andamento para não sobrescrever o otimista
      await queryClient.cancelQueries({ queryKey: campaignKeys.lists() })

      // Snapshot do estado anterior (para rollback)
      const previousCampaigns = queryClient.getQueryData(campaignKeys.list({}))

      // Update otimista
      queryClient.setQueryData(campaignKeys.list({}), (old: Campaign[]) => [
        ...old,
        { ...newCampaign, id: 'temp-' + Date.now(), status: 'active' },
      ])

      return { previousCampaigns }
    },

    // Se erro: reverte o otimista
    onError: (_err, _newCampaign, context) => {
      queryClient.setQueryData(campaignKeys.list({}), context?.previousCampaigns)
    },

    // Sempre: invalida a query para revalidar do servidor
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
    },
  })
}

// Uso no componente de formulário
const CreateCampaignForm = () => {
  const { mutate, isPending, isError, error } = useCreateCampaign()

  const handleSubmit = (data: CreateCampaignInput) => {
    mutate(data, {
      onSuccess: () => {
        toast.success('Campanha criada!')
        router.push('/campaigns')
      },
      onError: (err) => {
        toast.error(err.message)
      },
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* campos */}
      <button type="submit" disabled={isPending}>
        {isPending ? 'Criando...' : 'Criar campanha'}
      </button>
    </form>
  )
}
```

---

## ZUSTAND — Client State Global

```typescript
// stores/use-campaign-filters.ts
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface CampaignFiltersState {
  // Estado
  status: 'all' | 'active' | 'paused' | 'ended'
  search: string
  sortBy: 'name' | 'budget' | 'spent' | 'created_at'
  sortOrder: 'asc' | 'desc'

  // Actions
  setStatus: (status: CampaignFiltersState['status']) => void
  setSearch: (search: string) => void
  setSortBy: (field: CampaignFiltersState['sortBy']) => void
  toggleSortOrder: () => void
  resetFilters: () => void
}

const defaultFilters = {
  status: 'all' as const,
  search: '',
  sortBy: 'created_at' as const,
  sortOrder: 'desc' as const,
}

export const useCampaignFilters = create<CampaignFiltersState>()(
  persist(
    (set) => ({
      ...defaultFilters,

      setStatus: (status) => set({ status }),
      setSearch: (search) => set({ search }),
      setSortBy: (sortBy) => set({ sortBy }),
      toggleSortOrder: () =>
        set(state => ({ sortOrder: state.sortOrder === 'asc' ? 'desc' : 'asc' })),
      resetFilters: () => set(defaultFilters),
    }),
    {
      name: 'campaign-filters', // chave no localStorage
      storage: createJSONStorage(() => sessionStorage), // sessão, não persiste entre abas
      partialize: (state) => ({ status: state.status, sortBy: state.sortBy }), // persiste só estes campos
    }
  )
)

// Uso com seletor (evita re-render por campos não usados)
const FilterBar = () => {
  // Seletor específico — só re-renderiza quando 'status' muda
  const status = useCampaignFilters(state => state.status)
  const setStatus = useCampaignFilters(state => state.setStatus)

  return (
    <select value={status} onChange={e => setStatus(e.target.value as any)}>
      <option value="all">Todas</option>
      <option value="active">Ativas</option>
      <option value="paused">Pausadas</option>
    </select>
  )
}

// Uso da store fora de componente (ex: action, utils)
const { status, setStatus } = useCampaignFilters.getState()
```

---

## CONTEXT API — Quando Usar

```typescript
// ✅ Context para dados de sessão / autenticação (muda raramente)
interface AuthContextType {
  user: User | null
  isLoading: boolean
  signOut: () => void
}

const AuthContext = createContext<AuthContextType | null>(null)

export const AuthProvider = ({ children }) => {
  const { data: user, isLoading } = useQuery({
    queryKey: ['auth', 'session'],
    queryFn: authApi.getSession,
    staleTime: Infinity, // não revalida automaticamente
  })

  const { mutate: signOut } = useMutation({
    mutationFn: authApi.signOut,
    onSuccess: () => queryClient.clear(),
  })

  return (
    <AuthContext.Provider value={{ user: user ?? null, isLoading, signOut }}>
      {children}
    </AuthContext.Provider>
  )
}

// Hook tipado com validação
export const useAuth = () => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth deve ser usado dentro de AuthProvider')
  }
  return context
}

// ❌ Context para estado que muda frequentemente = performance ruim
// Use Zustand nesse caso
const CartContext = createContext(null) // ← se cart muda a cada adicionar item: Zustand
```

---

## PADRÃO: useState LOCAL

```typescript
// ✅ Estado simples e local — useState é perfeito aqui
const ToggleFilter = () => {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div>
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        aria-expanded={isOpen}
      >
        Filtros
      </button>
      {isOpen && <FilterPanel />}
    </div>
  )
}

// ✅ useReducer para estado com múltiplas transições
type WizardState = {
  step: 1 | 2 | 3
  name: string
  budget: number
  audience: string
}

type WizardAction =
  | { type: 'NEXT_STEP' }
  | { type: 'PREV_STEP' }
  | { type: 'SET_NAME'; name: string }
  | { type: 'SET_BUDGET'; budget: number }
  | { type: 'RESET' }

function wizardReducer(state: WizardState, action: WizardAction): WizardState {
  switch (action.type) {
    case 'NEXT_STEP':
      return { ...state, step: Math.min(state.step + 1, 3) as WizardState['step'] }
    case 'PREV_STEP':
      return { ...state, step: Math.max(state.step - 1, 1) as WizardState['step'] }
    case 'SET_NAME':
      return { ...state, name: action.name }
    case 'RESET':
      return initialWizardState
    default:
      return state
  }
}
```

---

## CHECKLIST DE ESTADO

```
ANTES DE IMPLEMENTAR:
  □ Qual a natureza do dado? (server vs client)
  □ Qual o escopo? (local vs global vs entre páginas)
  □ Com que frequência muda? (raro vs frequente)
  □ Precisa persistir entre navegações ou sessões?

TANSTACK QUERY:
  □ queryKey único e descritivo por recurso
  □ staleTime configurado adequadamente (não default 0 se não necessário)
  □ enabled={false} para queries condicionais
  □ placeholderData em listas paginadas
  □ invalidateQueries após mutations bem-sucedidas
  □ Todos os estados tratados: isLoading, isError, data vazio

ZUSTAND:
  □ Actions separadas do estado (não inline no componente)
  □ Seletores específicos no componente (não desestrutura toda a store)
  □ persist só para dados que realmente precisam persistir
  □ getState() para acesso fora de componentes

CONTEXT:
  □ Usado apenas para dados que mudam raramente (auth, tema, locale)
  □ Considerar memoização do value com useMemo se o provider re-renderiza
  □ Hook customizado (useAuth, useTheme) em vez de useContext direto
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: estado [tipo: query/store/context] em [componente/feature] | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: state.md | Agente: Pixel | Atualizado: 2026-03-04*
