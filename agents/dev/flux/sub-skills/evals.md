# evals.md — FLUX Sub-Skill: Evals & Benchmarking de Prompts
# Ativa quando: "avalia", "benchmark", "qual modelo", "compara modelos", "testa prompt"

---

## POR QUE EVALS SÃO OBRIGATÓRIOS

Um prompt em produção sem eval é um sistema sem testes. Qualquer mudança de prompt, modelo ou parâmetro pode degradar qualidade silenciosamente.

**Quando rodar evals:**
- Antes de mudar um prompt em produção
- Ao trocar de modelo (ex: Opus → Sonnet para reduzir custo)
- Ao adicionar novos exemplos no few-shot
- Ao refinar instruções de formato ou restrições
- Mensalmente em sistemas críticos (drift de qualidade)

---

## FRAMEWORK DE EVALS WOLF: PROMPTFOO

Promptfoo é a ferramenta padrão Wolf para avaliação sistemática de prompts.

```bash
# Instalar
npm install -g promptfoo

# Inicializar projeto de eval
npx promptfoo init

# Rodar eval
npx promptfoo eval

# Ver resultados em UI
npx promptfoo view
```

---

## DIRETÓRIO DE EVALS WOLF

```
workspace/
└── flux/
    └── evals/
        ├── [feature-name]/
        │   ├── promptfooconfig.yaml    # Configuração do eval
        │   ├── prompts/
        │   │   ├── v1.txt              # Versão atual do prompt
        │   │   └── v2.txt              # Nova versão sendo testada
        │   └── test-cases.csv          # Casos de teste (opcional)
        └── README.md                   # Índice dos evals
```

```bash
# Criar estrutura de eval para nova feature
mkdir -p workspace/flux/evals/[feature-name]/prompts
```

---

## ESTRUTURA DE EVAL YAML

### Eval Básico (comparação de prompts)

```yaml
# workspace/flux/evals/lead-classifier/promptfooconfig.yaml

description: "Lead classifier prompt - v1 vs v2"

prompts:
  - id: v1
    file: prompts/v1.txt
  - id: v2
    file: prompts/v2.txt

providers:
  - id: anthropic:claude-sonnet-4-6
  - id: anthropic:claude-haiku-3-5    # Teste de modelo mais barato

tests:
  - vars:
      lead_data: |
        Name: João Silva
        Company: TechStartup (50 employees)
        Role: CTO
        Message: "Preciso de um sistema de automação para nossa equipe de vendas.
                  Orçamento disponível de R$100k. Quer agendar uma call?"
    assert:
      - type: contains
        value: "hot"
      - type: not-contains
        value: "cold"
      - type: javascript
        value: |
          const parsed = JSON.parse(output);
          return parsed.icp_match_score > 70;

  - vars:
      lead_data: |
        Name: Maria Santos
        Company: Freelancer
        Role: Designer
        Message: "Vi vocês no LinkedIn. O que vocês fazem mesmo?"
    assert:
      - type: contains
        value: "cold"
      - type: not-contains
        value: "hot"

  - vars:
      lead_data: |
        Name: Pedro Alves
        Company: E-commerce (200 employees)
        Role: Head of Product
        Message: "Precisamos de uma solução de IA mas não sei se têm budget aprovado ainda."
    assert:
      - type: contains-any
        values: ["warm", "cold"]
      - type: javascript
        value: |
          const parsed = JSON.parse(output);
          return parsed.disqualifiers && parsed.disqualifiers.length > 0;
```

### Eval com Similaridade Semântica

```yaml
# workspace/flux/evals/support-responses/promptfooconfig.yaml

description: "Customer support response quality"

prompts:
  - file: prompts/support-v1.txt

providers:
  - anthropic:claude-sonnet-4-6

defaultTest:
  options:
    provider: anthropic:claude-sonnet-4-6  # Modelo para eval de similaridade

tests:
  - vars:
      user_message: "Minha cobrança foi duplicada esse mês."
    assert:
      - type: llm-rubric
        value: |
          A resposta deve:
          1. Reconhecer o problema com empatia
          2. Pedir informações para verificar (email, data da cobrança)
          3. Dar prazo claro para resolução
          4. Não prometer estorno sem verificar
        threshold: 0.8

      - type: not-contains
        value: "não posso ajudar"

      - type: javascript
        value: "output.length > 50 && output.length < 500"

  - vars:
      user_message: "Como cancelo minha assinatura?"
    assert:
      - type: contains-any
        values: ["configurações", "conta", "cancelar", "assinatura"]
      - type: llm-rubric
        value: "A resposta deve conter passos claros para cancelamento ou direcionamento para onde fazer isso."
        threshold: 0.75
```

### Eval de Comparação de Modelos

```yaml
# workspace/flux/evals/model-comparison/promptfooconfig.yaml

description: "Opus vs Sonnet vs Haiku para classificação de suporte"

prompts:
  - id: classifier
    file: prompts/classifier.txt

providers:
  - id: opus
    label: claude-opus-4-6
    config:
      model: claude-opus-4-6
  - id: sonnet
    label: claude-sonnet-4-6
    config:
      model: claude-sonnet-4-6
  - id: haiku
    label: claude-haiku-3-5
    config:
      model: claude-haiku-3-5

tests:
  # [lista de casos de teste]

outputPath: results/model-comparison-2026-03.json
```

---

## MÉTRICAS DE AVALIAÇÃO

### Métricas Disponíveis no Promptfoo

| Metric              | Uso                                               |
|---------------------|---------------------------------------------------|
| `contains`          | Output contém string exata                        |
| `not-contains`      | Output NÃO contém string                          |
| `contains-any`      | Output contém pelo menos uma das strings          |
| `contains-all`      | Output contém todas as strings                    |
| `equals`            | Output é exatamente igual ao esperado             |
| `starts-with`       | Output começa com string                          |
| `regex`             | Output corresponde a regex                        |
| `javascript`        | Função JS customizada retorna true/false          |
| `llm-rubric`        | LLM avalia output com critérios em prosa          |
| `semantic-similarity`| Similaridade semântica com string esperada      |
| `cost`              | Custo do request abaixo de threshold              |
| `latency`           | Latência abaixo de threshold (ms)                 |

### Exemplo de javascript assert (o mais flexível)

```yaml
assert:
  - type: javascript
    value: |
      // output é a string de resposta do modelo
      try {
        const parsed = JSON.parse(output);
        return (
          ["hot", "warm", "cold"].includes(parsed.temperature) &&
          typeof parsed.confidence === "number" &&
          parsed.confidence >= 0 &&
          parsed.confidence <= 1 &&
          typeof parsed.reasoning === "string"
        );
      } catch {
        return false; // JSON inválido = falha
      }
```

---

## INTERPRETANDO RESULTADOS

### Output do CLI

```
┌─────────────────────────────────────────────────────┐
│ Eval Results                                         │
├──────────┬────────┬──────────┬──────────┬──────────┤
│ Prompt   │ Model  │ Pass     │ Fail     │ Score    │
├──────────┼────────┼──────────┼──────────┼──────────┤
│ v1       │ sonnet │ 8/10     │ 2/10     │ 80%      │
│ v2       │ sonnet │ 10/10    │ 0/10     │ 100%     │
│ v1       │ haiku  │ 6/10     │ 4/10     │ 60%      │
│ v2       │ haiku  │ 9/10     │ 1/10     │ 90%      │
└──────────┴────────┴──────────┴──────────┴──────────┘
```

### Decisão baseada em resultados

```
v2 Sonnet: 100% → candidato a produção
v2 Haiku:  90%  → avaliar se 10% de falha é aceitável (e custo justifica)

Se Haiku com v2 tem 90% de acurácia vs Sonnet com v2 em 100%:
- Task crítica (classificação de pagamento): use Sonnet
- Task não-crítica (categorização de feedback): use Haiku (7x mais barato)
```

---

## WORKFLOW COMPLETO DE EVAL

```bash
# 1. Criar diretório de eval
mkdir -p workspace/flux/evals/[feature]/prompts

# 2. Salvar prompt atual como v1
cp current-prompt.txt workspace/flux/evals/[feature]/prompts/v1.txt

# 3. Escrever nova versão
cp workspace/flux/evals/[feature]/prompts/v1.txt \
   workspace/flux/evals/[feature]/prompts/v2.txt
# Editar v2.txt com as mudanças

# 4. Criar promptfooconfig.yaml (veja templates acima)

# 5. Rodar eval
cd workspace/flux/evals/[feature]
npx promptfoo eval

# 6. Ver resultados detalhados
npx promptfoo view

# 7. Documentar decisão
echo "v2 escolhida. Score: v1=75%, v2=95%. Deploy: 2026-03-04" >> DECISION.md
```

---

## CHECKLIST DE EVAL ANTES DE DEPLOY

- [ ] Mínimo 10 casos de teste cobertos (incluindo edge cases)
- [ ] Casos de teste incluem exemplos reais de produção (não só casos fáceis)
- [ ] Testado com modelo atual E com modelo candidato a substituição
- [ ] Score >= 90% para tasks críticas (pagamento, segurança, dados sensíveis)
- [ ] Score >= 80% para tasks não-críticas
- [ ] Resultados salvos em `workspace/flux/evals/[feature]/results/`
- [ ] Decisão documentada (qual versão foi escolhida e por quê)
- [ ] Custo comparativo calculado entre versões/modelos testados
