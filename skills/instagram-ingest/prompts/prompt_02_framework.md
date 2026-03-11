# PROMPT 02 — Framework Executavel
> Stage 6B do pipeline - Extracao de metodologia acionavel de transcricoes

---

## Metadados

| Campo | Valor |
|---|---|
| **Arquivo** | `prompt_02_framework.md` |
| **Usado em** | `pipeline.py` -> funcao `synthesize_framework()` |
| **Modelo** | `claude-sonnet-4-20250514` |
| **Max tokens** | `1000` |
| **Output** | JSON puro |

---

## Variaveis de Entrada

| Variavel | Tipo | Descricao |
|---|---|---|
| `{uploader}` | string | Nome do criador do Reel |
| `{title}` | string | Titulo extraido pelo yt-dlp |
| `{transcript}` | string | Transcricao completa gerada pelo Whisper |

---

## Prompt

```
Voce e um especialista em modelagem de processos e frameworks.

Analise a transcricao abaixo e extraia um FRAMEWORK EXECUTAVEL.

METADADOS:
- Criador: {uploader}
- Titulo: {title}

TRANSCRICAO:
{transcript}

Extraia um framework estruturado e responda APENAS com JSON valido:

{
  "nome_framework": "nome descritivo do framework",
  "objetivo": "o que esse framework resolve ou entrega",
  "quando_usar": "gatilhos e situacoes ideais para aplicar",
  "premissas": ["premissa 1", "premissa 2"],
  "passos": [
    {
      "numero": 1,
      "nome": "nome curto do passo",
      "descricao": "o que fazer neste passo",
      "inputs": ["o que e necessario para executar"],
      "outputs": ["o que e produzido ao final"],
      "dicas": ["dica pratica de execucao"]
    }
  ],
  "metricas_sucesso": ["como saber que o framework funcionou"],
  "erros_comuns": ["armadilha 1", "armadilha 2"],
  "variacoes": ["versao simplificada", "versao avancada"],
  "ferramentas_sugeridas": ["ferramenta 1", "ferramenta 2"],
  "nivel_complexidade": "basico|intermediario|avancado",
  "tempo_estimado": "estimativa de tempo para executar o framework completo",
  "aplicavel_a": ["contexto ou segmento 1", "contexto ou segmento 2"]
}
```

---

## Notas de Implementacao

- Se o conteudo **nao contiver metodologia clara**, o modelo deve retornar um framework de nivel basico com os elementos que conseguir inferir - nunca retornar erro ou campo vazio.
- O array `passos` deve ter **no minimo 2 e no maximo 7 passos** para ser acionavel.
- `inputs` e `outputs` por passo tornam o framework **encadeavel** - output do passo N e input do passo N+1.
- `erros_comuns` e o campo mais valioso para treinar o agente a evitar falhas recorrentes.
- O campo `quando_usar` funciona como **gatilho de ativacao** - o agente usa isso para decidir quando recomendar este framework.

---

## Exemplo de Output Esperado

```json
{
  "nome_framework": "Metodo 3C de Hook",
  "objetivo": "Criar os primeiros 3 segundos de um Reel que maximizam retencao e watch-time",
  "quando_usar": "Ao produzir qualquer video curto (Reels, TikTok, Shorts) com objetivo de alcance organico",
  "premissas": [
    "O algoritmo prioriza videos com alta taxa de conclusao",
    "A atencao do usuario e decidida nos primeiros 3 segundos"
  ],
  "passos": [
    {
      "numero": 1,
      "nome": "Definir a Curiosidade",
      "descricao": "Escreva uma pergunta ou afirmacao que crie um gap de informacao na mente do espectador",
      "inputs": ["Tema central do video", "Publico-alvo definido"],
      "outputs": ["Frase de abertura com gap de curiosidade"],
      "dicas": ["Use 'Voce sabia que...' ou 'O erro que 90% comete e...'"]
    },
    {
      "numero": 2,
      "nome": "Introduzir o Conflito",
      "descricao": "Apresente o problema ou tensao que o video vai resolver",
      "inputs": ["Frase de abertura do passo 1"],
      "outputs": ["Frase de conflito ou dor"],
      "dicas": ["Seja especifico - 'perder seguidores' e vago; 'cair 40% no alcance apos o update' e concreto"]
    },
    {
      "numero": 3,
      "nome": "Inserir o CTA Implicito",
      "descricao": "Prometa a solucao que vem a seguir, sem entrega-la ainda",
      "inputs": ["Frase de conflito do passo 2"],
      "outputs": ["Hook completo de 3 segundos"],
      "dicas": ["'Eu vou te mostrar...' cria antecipacao sem revelar a resposta"]
    }
  ],
  "metricas_sucesso": [
    "Taxa de retencao acima de 60% nos primeiros 5 segundos",
    "Watch-time medio superior a 50% da duracao do video"
  ],
  "erros_comuns": [
    "Comecar com 'Ola, tudo bem?' - desperdicio dos 3 segundos criticos",
    "Hook que promete mais do que o video entrega - aumenta saida precoce"
  ],
  "variacoes": [
    "Versao simplificada: apenas Curiosidade + CTA (2 elementos)",
    "Versao avancada: adicionar prova social nos 3 segundos ('Esse metodo gerou 1M de views')"
  ],
  "ferramentas_sugeridas": ["CapCut", "Notion (banco de hooks)", "ChatGPT para variacoes"],
  "nivel_complexidade": "basico",
  "tempo_estimado": "10-15 minutos para escrever e gravar o hook",
  "aplicavel_a": ["Criadores de conteudo", "Social media managers", "Profissionais de marketing"]
}
```

---

## Variacoes Recomendadas

### Quando o conteudo e um processo de negocios
Adicione ao prompt antes do JSON:
```
Foco especial em: etapas sequenciais com responsaveis, pontos de decisao (if/else),
criterios de aprovacao entre etapas e SLAs estimados.
```

### Quando o conteudo e um metodo de vendas
Adicione ao prompt antes do JSON:
```
Foco especial em: objecoes por etapa do funil, gatilhos de avanco,
sinais de compra do lead e script recomendado por passo.
```

### Quando o conteudo e um metodo criativo
Adicione ao prompt antes do JSON:
```
Foco especial em: fontes de inspiracao por etapa, criterios esteticos,
referencias de qualidade e checklist de revisao.
```

---

## Logica de Ativacao no Agente

O agente deve preferir o **modo framework** quando a transcricao contiver qualquer um desses sinais:

- Palavras como: *metodo*, *processo*, *passo a passo*, *como fazer*, *framework*, *sistema*, *estrategia*
- Estrutura sequencial detectavel: *primeiro... segundo... terceiro...*
- Verbos no imperativo: *faca*, *escreva*, *defina*, *evite*
- Numeros de etapas: *3 passos*, *5 principios*, *7 erros*
