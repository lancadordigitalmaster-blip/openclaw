---

## Agent

**Alfred** — orquestrador central

---
name: wolf-learning-engine
description: Sistema de aprendizado contínuo da Wolf. Analisa conteúdo histórico, extrai padrões, cria style guides por cliente e mantém base de conhecimento de frameworks validados.
---

# Wolf Learning Engine 🧠

Sistema de aprendizado e melhoria contínua para a Wolf Agency.

## Componentes

### 1. Pattern Analyzer (`analyze-content`)
Analisa produção de conteúdo histórica e extrai padrões.

**Uso:**
```bash
./scripts/wolf-analyze-content.sh --client="Nome Cliente" --folder="/caminho/posts/"
```

**Output:**
- `memory/clients/[cliente]/style-guide.md`
- `memory/clients/[cliente]/patterns.json`
- `memory/clients/[cliente]/tone-of-voice.md`

### 2. Feedback Collector (`collect-feedback`)
Registra feedback sobre recomendações e atualiza regras.

**Uso:**
Após qualquer recomendação, Alfred pergunta automaticamente:
> "Essa recomendação funcionou? ⭐ ⚠️ ❌"

Ou manualmente:
```bash
./scripts/wolf-feedback.sh --recommendation-id="abc123" --rating="5" --comment="Funcionou perfeito"
```

### 3. Knowledge Base (`knowledge-base`)
Base central de padrões que funcionam.

**Local:** `memory/wolf-knowledge-base/`

**Estrutura:**
```
wolf-knowledge-base/
├── frameworks/
│   ├── copy-persuasiva.md
│   ├── hooks-virais.md
│   └── estruturas-carrossel.md
├── niches/
│   ├── estetica/
│   ├── ecommerce/
│   └── servicos/
└── patterns/
    ├── emojis-por-nicho.json
    ├── ctas-efetivas.json
    └── tamanhos-ideais.json
```

## Como funciona o aprendizado

### Ciclo completo:

```
1. ENTRADA
   ↓
   Usuário manda conteúdo histórico ou faz pergunta
   
2. ANÁLISE (Pattern Analyzer)
   ↓
   - Extrai tom de voz
   - Identifica estruturas repetidas
   - Mapeia padrões visuais
   - Cataloga hooks que funcionam
   
3. ARMAZENAMENTO
   ↓
   - Salva style guide do cliente
   - Atualiza knowledge base geral
   - Indexa por nicho/categoria
   
4. APLICAÇÃO
   ↓
   - Usa padrões em novas recomendações
   - Adapta ao contexto específico
   - Mantém consistência de marca
   
5. FEEDBACK (Feedback Collector)
   ↓
   - Pergunta se funcionou
   - Registra resultado
   - Ajusta peso dos padrões
   
6. EVOLUÇÃO
   ↓
   - Padrões que funcionam = mais usados
   - Padrões que falham = menos usados
   - Novos padrões = testados
```

## Comandos disponíveis

### Analisar conteúdo
```bash
wolf-analyze --client="Cliente X" --folder="./conteudo/"
```

### Ver style guide
```bash
wolf-style --client="Cliente X"
```

### Dar feedback
```bash
wolf-feedback --id="rec-123" --rating="5"
```

### Ver knowledge base
```bash
wolf-knowledge --topic="hooks"
```

## Integração com agentes

### Luna (Social Media)
- Antes de criar conteúdo → consulta style guide do cliente
- Usa padrões validados → maior chance de sucesso
- Adapta tom de voz → consistência de marca

### Gabi (Tráfego)
- Analisa criativos que converteram → replica padrões
- Identifica hooks de alta performance
- Aprende com campanhas anteriores

### Sage (SEO)
- Extrai keywords que funcionaram
- Identifica estruturas de artigo com melhor ranking
- Aprende com conteúdo que gerou tráfego

## Atualização automática

O Learning Engine atualiza automaticamente quando:
- Novo conteúdo é analisado
- Feedback é recebido
- Padrões são validados por uso repetido

## Métricas de aprendizado

| Métrica | Descrição |
|---------|-----------|
| Pattern Confidence | Quão confiável é um padrão (0-100%) |
| Success Rate | % de vezes que uma recomendação funcionou |
| Usage Count | Quantas vezes um padrão foi usado |
| Last Updated | Quando o padrão foi atualizado |

---

*Versão: 1.0 | Criado: 2026-03-05*