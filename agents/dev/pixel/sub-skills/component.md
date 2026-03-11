# component.md — Pixel Sub-Skill: Desenvolvimento de Componente
# Ativa quando: "componente", "component", "UI", "interface", "tela", "página"

---

## PROTOCOLO DE CRIAÇÃO DE COMPONENTE

```
ANTES DE ESCREVER UMA LINHA DE CÓDIGO:
  □ Qual o comportamento esperado? (não o visual — o comportamento)
  □ Quais estados existem? (loading, error, empty, success, disabled)
  □ É reutilizável ou específico para uma página?
  □ Tem dados externos? (define estratégia de fetch/estado)
  □ Quais as props? (o contrato do componente)
  □ Funciona sem JavaScript? (graceful degradation)

REGRA DE OURO:
  Componente pequeno > componente grande
  Se tem mais de 150 linhas: divide em sub-componentes
  Se tem mais de 3 props opcionais complexas: avalia se é um componente só
```

---

## ESTRUTURA PADRÃO DE COMPONENTE

```typescript
// Ordem obrigatória no arquivo:
//  1. Imports
//  2. Types/Interfaces
//  3. Componente principal
//  4. Sub-componentes (se precisar)
//  5. Export

// ============================
// 1. IMPORTS
// ============================
import { useState, useCallback, memo } from 'react'
import type { FC } from 'react'

// ============================
// 2. TYPES (sempre antes do componente)
// ============================
interface CampaignCardProps {
  campaign: {
    id: string
    name: string
    status: 'active' | 'paused' | 'ended'
    budget: number
    spent: number
  }
  onPause?: (id: string) => void
  onActivate?: (id: string) => void
  isLoading?: boolean
  className?: string
}

// ============================
// 3. COMPONENTE PRINCIPAL
// ============================
const CampaignCard: FC<CampaignCardProps> = ({
  campaign,
  onPause,
  onActivate,
  isLoading = false,
  className,
}) => {
  // HOOKS — sempre no topo, nesta ordem:
  // state → derived state → refs → effects → handlers

  // State
  const [isExpanded, setIsExpanded] = useState(false)

  // Derived state (computed, sem useState)
  const spentPercentage = Math.min((campaign.spent / campaign.budget) * 100, 100)
  const isOverBudget = campaign.spent > campaign.budget

  // Handlers
  const handleTogglePause = useCallback(() => {
    if (campaign.status === 'active') {
      onPause?.(campaign.id)
    } else {
      onActivate?.(campaign.id)
    }
  }, [campaign.id, campaign.status, onPause, onActivate])

  // Loading state primeiro — evita renderizar lógica desnecessária
  if (isLoading) {
    return <CampaignCardSkeleton className={className} />
  }

  // Return — JSX limpo, sem lógica pesada inline
  return (
    <article
      className={`rounded-lg border p-4 ${className ?? ''}`}
      aria-label={`Campanha ${campaign.name}`}
    >
      <div className="flex items-center justify-between">
        <h3 className="font-medium text-gray-900">{campaign.name}</h3>
        <CampaignStatusBadge status={campaign.status} />
      </div>

      <BudgetProgress
        spent={campaign.spent}
        budget={campaign.budget}
        percentage={spentPercentage}
        isOver={isOverBudget}
      />

      {isExpanded && (
        <CampaignDetails campaign={campaign} />
      )}

      <div className="mt-3 flex gap-2">
        <button
          type="button"
          onClick={() => setIsExpanded(!isExpanded)}
          aria-expanded={isExpanded}
        >
          {isExpanded ? 'Recolher' : 'Ver detalhes'}
        </button>

        <button
          type="button"
          onClick={handleTogglePause}
          aria-label={campaign.status === 'active' ? 'Pausar campanha' : 'Ativar campanha'}
        >
          {campaign.status === 'active' ? 'Pausar' : 'Ativar'}
        </button>
      </div>
    </article>
  )
}

// ============================
// 4. SUB-COMPONENTES (arquivo local, sem export)
// ============================
const CampaignCardSkeleton: FC<{ className?: string }> = ({ className }) => (
  <div className={`animate-pulse rounded-lg border p-4 ${className ?? ''}`}>
    <div className="h-4 w-1/2 rounded bg-gray-200" />
    <div className="mt-2 h-2 w-full rounded bg-gray-200" />
  </div>
)

// ============================
// 5. EXPORT (memoiza se recebe props estáveis)
// ============================
export default memo(CampaignCard)
```

---

## ANTI-PATTERNS — NUNCA FAÇA

```typescript
// ❌ Lógica complexa inline no JSX
return (
  <div>
    {data?.user?.campaigns?.filter(c => c.status === 'active' && c.budget > 0)
      .map(c => c.metrics?.reduce((a, b) => a + b.value, 0) / c.metrics?.length)
      .join(', ')}
  </div>
)

// ✅ Extrai para variável ou função
const activeCampaignAverages = useMemo(
  () => calculateActiveCampaignAverages(data?.user?.campaigns),
  [data?.user?.campaigns]
)
return <div>{activeCampaignAverages}</div>

// ❌ Sem tratamento de estado vazio
const CampaignList = ({ campaigns }) => (
  <ul>
    {campaigns.map(c => <li key={c.id}>{c.name}</li>)}
  </ul>
)

// ✅ Todos os estados tratados
const CampaignList = ({ campaigns, isLoading, error }) => {
  if (isLoading) return <ListSkeleton />
  if (error) return <ErrorMessage message={error.message} />
  if (!campaigns.length) return <EmptyState message="Nenhuma campanha encontrada" />

  return (
    <ul>
      {campaigns.map(c => <li key={c.id}>{c.name}</li>)}
    </ul>
  )
}

// ❌ Props sem tipagem, "any" em tudo
const Card = ({ data, fn, x }) => { ... }

// ✅ Interface explícita
interface CardProps {
  campaign: Campaign
  onAction: (id: string) => void
  variant?: 'compact' | 'full'
}
const Card = ({ campaign, onAction, variant = 'full' }: CardProps) => { ... }
```

---

## ESTADOS OBRIGATÓRIOS (checklist de completude)

```
Todo componente que carrega dados DEVE tratar:
  □ loading    — skeleton ou spinner enquanto carrega
  □ error      — mensagem de erro com opção de retry
  □ empty      — estado quando não há dados (não mostra div vazio)
  □ success    — o estado "normal" com dados

Todo componente interativo DEVE tratar:
  □ hover      — feedback visual de interação (cursor, cor)
  □ focus      — visível para usuários de teclado
  □ disabled   — visual + cursor + aria-disabled quando inativo
  □ loading    — botão desabilitado + spinner durante ação async

Exemplo de componente com todos os estados:
```

```typescript
interface ActionButtonProps {
  label: string
  onClick: () => Promise<void>
  disabled?: boolean
}

const ActionButton: FC<ActionButtonProps> = ({ label, onClick, disabled = false }) => {
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')

  const handleClick = async () => {
    setStatus('loading')
    try {
      await onClick()
      setStatus('success')
      setTimeout(() => setStatus('idle'), 2000) // reset após feedback
    } catch {
      setStatus('error')
      setTimeout(() => setStatus('idle'), 3000)
    }
  }

  const isDisabled = disabled || status === 'loading'

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={isDisabled}
      aria-busy={status === 'loading'}
      aria-disabled={isDisabled}
      className={`
        px-4 py-2 rounded font-medium transition-colors
        ${status === 'success' ? 'bg-green-500 text-white' : ''}
        ${status === 'error' ? 'bg-red-500 text-white' : ''}
        ${status === 'loading' ? 'bg-gray-400 cursor-not-allowed' : ''}
        ${status === 'idle' && !disabled ? 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer' : ''}
        ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
      `}
    >
      {status === 'loading' && <Spinner className="mr-2" />}
      {status === 'success' ? 'Feito!' : status === 'error' ? 'Erro — tente de novo' : label}
    </button>
  )
}
```

---

## CHECKLIST PRÉ-ENTREGA

```
ESTADOS E COMPORTAMENTO:
  □ Estado loading implementado (skeleton ou spinner)
  □ Estado de erro implementado com mensagem útil
  □ Estado vazio implementado (não renderiza nada vazio)
  □ Ações assíncronas desabilitam o botão durante execução

MOBILE E RESPONSIVO:
  □ Funciona em 320px (menor iPhone)
  □ Elementos tocáveis têm pelo menos 44x44px de área
  □ Sem overflow horizontal inesperado
  □ Testado em 375px, 768px, 1280px

ACESSIBILIDADE BÁSICA:
  □ Botões e links têm aria-label quando texto não é descritivo
  □ Imagens têm alt text
  □ Formulários têm labels associados
  □ Funciona com Tab e Enter no teclado
  □ Focus visível em todos os elementos interativos

QUALIDADE DE CÓDIGO:
  □ Sem console.log esquecido
  □ Props com nomes semânticos (não: d, val, fn, x)
  □ Interface TypeScript definida para todas as props
  □ Nenhum 'any' desnecessário
  □ Comentário onde lógica não é óbvia
  □ Componente < 150 linhas (se maior: divide)

PERFORMANCE:
  □ useCallback em handlers passados para filhos
  □ useMemo em cálculos caros
  □ memo() no export se recebe props estáveis
  □ Sem re-renders desnecessários por referências instáveis
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: componente [nome] criado/alterado | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: component.md | Agente: Pixel | Atualizado: 2026-03-04*
