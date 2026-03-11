# forms.md — Pixel Sub-Skill: Formulários
# Ativa quando: "formulário", "form", "validação", "input"

---

## PADRÃO WOLF: REACT HOOK FORM + ZOD

```
STACK PADRÃO:
  React Hook Form — gerenciamento de estado e validação de formulário
  Zod            — schema de validação TypeScript-first
  shadcn/ui      — componentes de input acessíveis (se disponível no projeto)

POR QUE ESTA STACK:
  → React Hook Form: zero re-renders por keystroke, API simples, compatível com qualquer UI
  → Zod: validação type-safe, mesma schema no client e server, mensagens customizáveis
  → Integração nativa entre os dois via @hookform/resolvers

INSTALAÇÃO:
  npm install react-hook-form zod @hookform/resolvers
```

---

## ESTRUTURA PADRÃO DE FORMULÁRIO

```typescript
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

// ============================
// 1. SCHEMA ZOD (define regras e tipos)
// ============================
const createCampaignSchema = z.object({
  name: z
    .string()
    .min(1, 'Nome é obrigatório')
    .max(100, 'Nome deve ter no máximo 100 caracteres'),
  budget: z
    .number({ invalid_type_error: 'Orçamento deve ser um número' })
    .positive('Orçamento deve ser maior que zero')
    .max(1_000_000, 'Orçamento máximo é R$ 1.000.000'),
  startDate: z
    .string()
    .min(1, 'Data de início é obrigatória')
    .refine(date => new Date(date) >= new Date(), 'Data deve ser no futuro'),
  targetUrl: z
    .string()
    .url('URL inválida — inclua https://')
    .optional()
    .or(z.literal('')),
  acceptTerms: z
    .boolean()
    .refine(val => val === true, 'Você precisa aceitar os termos'),
})

// Tipo inferido do schema — sem duplicação
type CreateCampaignForm = z.infer<typeof createCampaignSchema>

// ============================
// 2. COMPONENTE DO FORMULÁRIO
// ============================
interface CreateCampaignFormProps {
  onSuccess?: (campaignId: string) => void
}

const CreateCampaignForm = ({ onSuccess }: CreateCampaignFormProps) => {
  // Estado de submissão
  type FormStatus = 'idle' | 'loading' | 'success' | 'error'
  const [status, setStatus] = useState<FormStatus>('idle')
  const [serverError, setServerError] = useState<string>('')

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
    setError,
  } = useForm<CreateCampaignForm>({
    resolver: zodResolver(createCampaignSchema),
    defaultValues: {
      name: '',
      budget: undefined,
      startDate: '',
      targetUrl: '',
      acceptTerms: false,
    },
  })

  const onSubmit = async (data: CreateCampaignForm) => {
    setStatus('loading')
    setServerError('')

    try {
      const result = await createCampaign(data)
      setStatus('success')
      reset() // limpa o form após sucesso
      onSuccess?.(result.id)
    } catch (err) {
      setStatus('error')

      // Erro de campo específico do servidor
      if (err instanceof CampaignNameTakenError) {
        setError('name', {
          type: 'server',
          message: 'Já existe uma campanha com este nome',
        })
        return
      }

      // Erro genérico de servidor
      setServerError('Erro ao criar campanha. Tente novamente.')
    }
  }

  if (status === 'success') {
    return (
      <div role="alert" className="rounded-lg bg-green-50 p-4 text-green-800">
        <p className="font-medium">Campanha criada com sucesso!</p>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      {/* Erro global de servidor */}
      {serverError && (
        <div role="alert" className="mb-4 rounded-lg bg-red-50 p-3 text-red-700 text-sm">
          {serverError}
        </div>
      )}

      <div className="space-y-4">
        {/* Campo: Nome */}
        <FormField
          label="Nome da campanha"
          htmlFor="campaign-name"
          error={errors.name?.message}
          required
        >
          <input
            id="campaign-name"
            type="text"
            {...register('name')}
            aria-invalid={!!errors.name}
            aria-describedby={errors.name ? 'campaign-name-error' : undefined}
            className={inputClassName(!!errors.name)}
            placeholder="Ex: Black Friday 2026"
          />
        </FormField>

        {/* Campo: Orçamento */}
        <FormField
          label="Orçamento (R$)"
          htmlFor="campaign-budget"
          error={errors.budget?.message}
          required
        >
          <input
            id="campaign-budget"
            type="number"
            {...register('budget', { valueAsNumber: true })}
            aria-invalid={!!errors.budget}
            aria-describedby={errors.budget ? 'campaign-budget-error' : undefined}
            className={inputClassName(!!errors.budget)}
            min={0}
            step={100}
          />
        </FormField>

        {/* Campo: Data */}
        <FormField
          label="Data de início"
          htmlFor="campaign-start-date"
          error={errors.startDate?.message}
          required
        >
          <input
            id="campaign-start-date"
            type="date"
            {...register('startDate')}
            aria-invalid={!!errors.startDate}
            aria-describedby={errors.startDate ? 'campaign-start-date-error' : undefined}
            className={inputClassName(!!errors.startDate)}
          />
        </FormField>

        {/* Campo: URL (opcional) */}
        <FormField
          label="URL de destino"
          htmlFor="campaign-url"
          error={errors.targetUrl?.message}
          hint="Opcional — URL para onde os anúncios vão direcionar"
        >
          <input
            id="campaign-url"
            type="url"
            {...register('targetUrl')}
            aria-invalid={!!errors.targetUrl}
            aria-describedby="campaign-url-hint campaign-url-error"
            className={inputClassName(!!errors.targetUrl)}
            placeholder="https://seu-site.com.br"
          />
        </FormField>

        {/* Campo: Checkbox */}
        <div className="flex gap-3">
          <input
            id="accept-terms"
            type="checkbox"
            {...register('acceptTerms')}
            aria-invalid={!!errors.acceptTerms}
            className="mt-1 h-4 w-4 rounded border-gray-300 text-blue-600"
          />
          <div>
            <label htmlFor="accept-terms" className="text-sm text-gray-700">
              Concordo com os{' '}
              <a href="/termos" className="text-blue-600 hover:underline">
                termos de serviço
              </a>
            </label>
            {errors.acceptTerms && (
              <p role="alert" className="mt-0.5 text-sm text-red-600">
                {errors.acceptTerms.message}
              </p>
            )}
          </div>
        </div>
      </div>

      <div className="mt-6 flex gap-3">
        <button
          type="submit"
          disabled={isSubmitting}
          aria-busy={isSubmitting}
          className="flex-1 rounded-lg bg-blue-600 px-4 py-2 text-white font-medium
            hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed
            transition-colors"
        >
          {isSubmitting ? 'Criando...' : 'Criar campanha'}
        </button>
        <button
          type="button"
          onClick={() => reset()}
          className="rounded-lg border px-4 py-2 text-gray-700 hover:bg-gray-50 transition-colors"
        >
          Limpar
        </button>
      </div>
    </form>
  )
}
```

---

## COMPONENTES AUXILIARES

```typescript
// ============================
// FormField — wrapper reutilizável
// ============================
interface FormFieldProps {
  label: string
  htmlFor: string
  error?: string
  hint?: string
  required?: boolean
  children: React.ReactNode
}

const FormField = ({ label, htmlFor, error, hint, required, children }: FormFieldProps) => (
  <div className="space-y-1">
    <label
      htmlFor={htmlFor}
      className="block text-sm font-medium text-gray-700"
    >
      {label}
      {required && (
        <span aria-hidden="true" className="ml-1 text-red-500">*</span>
      )}
    </label>

    {hint && (
      <p id={`${htmlFor}-hint`} className="text-sm text-gray-500">
        {hint}
      </p>
    )}

    {children}

    {error && (
      <p
        id={`${htmlFor}-error`}
        role="alert"
        className="flex items-center gap-1 text-sm text-red-600"
      >
        <span aria-hidden="true">⚠</span>
        {error}
      </p>
    )}
  </div>
)

// ============================
// Função de classe de input
// ============================
const inputClassName = (hasError: boolean) => `
  w-full rounded-lg border px-3 py-2 text-sm text-gray-900
  placeholder:text-gray-400
  focus:outline-none focus:ring-2 focus:ring-offset-0
  transition-colors
  ${hasError
    ? 'border-red-500 focus:ring-red-500 bg-red-50'
    : 'border-gray-300 focus:ring-blue-500 focus:border-blue-500'
  }
`
```

---

## VALIDAÇÕES ZOD COMUNS

```typescript
// Coleção de validações reutilizáveis no contexto Wolf

const WolfValidations = {
  // Nome genérico
  name: z.string().min(1, 'Campo obrigatório').max(100, 'Máximo 100 caracteres'),

  // Email
  email: z.string().email('Email inválido').toLowerCase(),

  // Telefone brasileiro
  phone: z
    .string()
    .regex(/^\(?[1-9]{2}\)?\s?9?\d{4}[-\s]?\d{4}$/, 'Telefone inválido'),

  // Moeda / orçamento
  budget: z
    .number({ invalid_type_error: 'Deve ser um número' })
    .positive('Deve ser maior que zero'),

  // URL opcional
  urlOptional: z.string().url('URL inválida — inclua https://').optional().or(z.literal('')),

  // Data futura
  futureDate: z
    .string()
    .min(1, 'Data obrigatória')
    .refine(d => new Date(d) >= new Date(), 'Data deve ser no futuro'),

  // CNPJ
  cnpj: z
    .string()
    .regex(/^\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}$/, 'CNPJ inválido (formato: 00.000.000/0000-00)'),

  // Senha forte
  password: z
    .string()
    .min(8, 'Mínimo 8 caracteres')
    .regex(/[A-Z]/, 'Deve ter pelo menos uma letra maiúscula')
    .regex(/[0-9]/, 'Deve ter pelo menos um número'),

  // Confirmação de senha
  passwordConfirm: (passwordField: string) =>
    z.string().min(1, 'Confirmação obrigatória'),
}

// Exemplo com confirmação de senha
const changePasswordSchema = z
  .object({
    password: WolfValidations.password,
    passwordConfirm: WolfValidations.passwordConfirm('password'),
  })
  .refine(data => data.password === data.passwordConfirm, {
    message: 'As senhas não coincidem',
    path: ['passwordConfirm'],
  })
```

---

## ESTADOS DO FORMULÁRIO

```
idle     — estado inicial, nenhuma ação iniciada
loading  — submissão em andamento (botão desabilitado, spinner)
success  — submissão bem-sucedida (mostra confirmação, reseta ou redireciona)
error    — erro de servidor ou validação server-side

REGRAS:
  → Botão de submit desabilitado durante loading
  → aria-busy="true" no botão durante loading
  → Erro de servidor mostrado acima do formulário (role="alert")
  → Erro de campo específico mostrado abaixo do campo (aria-describedby)
  → Após success: mostra confirmação antes de redirecionar (não redireciona silenciosamente)
  → Após error de campo: foco vai para o primeiro campo com erro
```

---

## ACESSIBILIDADE EM FORMS

```typescript
// Boas práticas obrigatórias:

// 1. Sempre htmlFor + id (nunca só wrap em label)
<label htmlFor="field-id">Campo</label>
<input id="field-id" />

// 2. Campos obrigatórios com aria-required
<input aria-required="true" />

// 3. Erro associado com aria-describedby
<input
  aria-invalid={!!error}
  aria-describedby={error ? 'field-error' : undefined}
/>
<p id="field-error" role="alert">{error}</p>

// 4. Grupo de opções com fieldset + legend
<fieldset>
  <legend>Tipo de campanha</legend>
  <label><input type="radio" name="type" value="awareness" /> Awareness</label>
  <label><input type="radio" name="type" value="conversion" /> Conversão</label>
</fieldset>

// 5. Autocomplete em campos pessoais
<input type="text" autoComplete="name" />
<input type="email" autoComplete="email" />
<input type="tel" autoComplete="tel" />
<input type="text" autoComplete="organization" />

// 6. font-size >= 16px em inputs (evita zoom automático no iOS)
// No Tailwind: text-base (16px) ou text-sm (14px → adiciona style para iOS)
```

---

## CHECKLIST PRÉ-ENTREGA

```
FUNCIONALIDADE:
  □ Validação client-side funciona para todos os campos
  □ Mensagens de erro são específicas e úteis (não genéricas como "Campo inválido")
  □ Estado loading: botão desabilitado + indicador visual
  □ Estado success: confirmação clara ao usuário
  □ Estado error: erro de servidor exibido e acessível
  □ Form reseta após sucesso (ou redireciona — comportamento intencional)

ACESSIBILIDADE:
  □ Todos os inputs têm label associado (htmlFor + id)
  □ Campos obrigatórios têm aria-required="true"
  □ Erros têm aria-describedby apontando para a mensagem de erro
  □ Campos obrigatórios marcados visualmente E para screen readers
  □ Funciona completamente via teclado
  □ font-size >= 16px em todos os inputs

VALIDAÇÃO:
  □ Schema Zod cobre todos os campos
  □ Mensagens de erro em português e claras
  □ Validação de campos opcionais não bloqueia submit
  □ Erros do servidor mapeados para campos específicos quando possível

QUALIDADE:
  □ Sem dependência duplicada de estado (não mistura useState + register para mesmo campo)
  □ defaultValues definidos no useForm
  □ Tipagem completa via z.infer<typeof schema>
  □ Sem console.log deixado de debug
```

---

## ACTIVITY LOG

```
[TIMESTAMP] [Pixel] AÇÃO: formulário [nome] criado/alterado | PROJETO: [nome] | RESULTADO: ok/erro/pendente
```

---

*Sub-Skill: forms.md | Agente: Pixel | Atualizado: 2026-03-04*
