# PROMPT 01 — Knowledge Card
> Stage 6A do pipeline - Extracao de conhecimento estruturado de transcricoes

---

## Metadados

| Campo | Valor |
|---|---|
| **Arquivo** | `prompt_01_knowledge_card.md` |
| **Usado em** | `pipeline.py` -> funcao `synthesize_knowledge()` |
| **Modelo** | `claude-sonnet-4-20250514` |
| **Max tokens** | `1000` |
| **Output** | JSON puro |

---

## Variaveis de Entrada

| Variavel | Tipo | Descricao |
|---|---|---|
| `{uploader}` | string | Nome do criador do Reel |
| `{title}` | string | Titulo extraido pelo yt-dlp |
| `{duration}` | int | Duracao em segundos |
| `{transcript}` | string | Transcricao completa gerada pelo Whisper |

---

## Prompt

```
Voce e um estrategista de conteudo e analista de conhecimento.

Analise a transcricao abaixo de um Reel do Instagram e extraia conhecimento estruturado.

METADADOS:
- Criador: {uploader}
- Titulo: {title}
- Duracao: {duration}s

TRANSCRICAO:
{transcript}

Responda APENAS com JSON valido (sem markdown, sem backticks), seguindo exatamente esta estrutura:

{
  "resumo": "resumo conciso em 2-3 frases",
  "topicos_principais": ["topico 1", "topico 2", "topico 3"],
  "insights_chave": ["insight acionavel 1", "insight acionavel 2", "insight acionavel 3"],
  "tipo_conteudo": "educativo|entretenimento|motivacional|tutorial|opiniao|marketing|outro",
  "tom": "formal|informal|inspiracional|tecnico|humoristico",
  "publico_alvo": "descricao do publico ideal",
  "palavras_chave": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"],
  "entidades": {
    "pessoas": [],
    "marcas": [],
    "ferramentas": [],
    "conceitos": []
  },
  "aplicabilidade": "como esse conhecimento pode ser aplicado na pratica",
  "nivel_relevancia": "alto|medio|baixo"
}
```

---

## Notas de Implementacao

- O modelo deve retornar **JSON puro** - sem ```json, sem texto antes ou depois.
- Se o modelo insistir em adicionar backticks, o pipeline remove automaticamente com:
  ```python
  if raw.startswith("```"):
      raw = raw.split("```")[1]
      if raw.startswith("json"):
          raw = raw[4:]
  ```
- O campo `nivel_relevancia` e usado para priorizar chunks no RAG.
- Os `insights_chave` devem ser **acionaveis** - nao descritivos.
- `entidades` alimenta o grafo de conhecimento nas versoes futuras.

---

## Exemplo de Output Esperado

```json
{
  "resumo": "O criador explica o metodo 3C para criar hooks de alto impacto no inicio de videos curtos, focando em curiosidade, conflito e chamada a acao imediata.",
  "topicos_principais": ["copywriting", "hooks para reels", "metodo 3C"],
  "insights_chave": [
    "Os primeiros 3 segundos determinam 80% da retencao do video",
    "Iniciar com uma pergunta que cria gap de curiosidade aumenta o watch-time",
    "O hook deve prometer transformacao, nao apenas informacao"
  ],
  "tipo_conteudo": "educativo",
  "tom": "informal",
  "publico_alvo": "Criadores de conteudo e profissionais de marketing digital",
  "palavras_chave": ["hook", "reels", "copywriting", "retencao", "metodo 3C"],
  "entidades": {
    "pessoas": ["Gary Halbert"],
    "marcas": ["Instagram"],
    "ferramentas": ["CapCut"],
    "conceitos": ["metodo 3C", "gap de curiosidade", "watch-time"]
  },
  "aplicabilidade": "Aplicar o metodo 3C nos primeiros 3 segundos de qualquer Reel ou TikTok para aumentar retencao e alcance organico.",
  "nivel_relevancia": "alto"
}
```

---

## Variacoes Recomendadas

### Para conteudo de vendas/marketing
Adicione ao prompt antes do JSON:
```
Priorize extrair: gatilhos de persuasao utilizados, estrutura de oferta,
objecoes tratadas e CTAs identificados.
```

### Para conteudo tecnico/tutorial
Adicione ao prompt antes do JSON:
```
Priorize extrair: pre-requisitos, ferramentas necessarias, passos identificados
e nivel de expertise exigido do leitor.
```

### Para conteudo motivacional/comportamental
Adicione ao prompt antes do JSON:
```
Priorize extrair: crenca central comunicada, historia ou analogia usada,
transformacao prometida e chamada a acao emocional.
```
