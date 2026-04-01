---
name: "sovereign-brand-voice-writer"
description: "When the user wants to generate content in a client's brand voice, create posts, threads, newsletters, blog posts or video scripts. Triggers: 'gera conteúdo', 'escreve no tom de voz', 'cria post no estilo de', 'batch de conteúdo', 'conteúdo da marca', 'escreve como [cliente]', 'thread no estilo', 'newsletter', 'roteiro de vídeo', 'post para [cliente]'."
---

# Brand Voice Writer — Wolf Agency

Gera conteúdo no tom de voz exato de cada cliente Wolf. Cada cliente tem seu perfil salvo em `shared/memory/brand-voices/[cliente-slug].json`.

**Fluxo:**
1. Identifica o cliente na mensagem
2. Lê perfil em `shared/memory/brand-voices/[cliente-slug].json`
3. Se não existir → cria o perfil coletando informações do usuário
4. Gera o conteúdo no formato solicitado
5. Passa pelo ai-humanizer antes de entregar (quando disponível)

## Brand Voice Loading

Antes de escrever qualquer coisa, lê o perfil de marca do cliente. O perfil contém:

- **Tone**: formal/casual/witty/provocative/educational
- **Vocabulary**: words they use often, words they never use
- **Sentence structure**: short and punchy vs long and flowing
- **Personality traits**: funny, serious, data-driven, story-teller, etc.
- **Content themes**: topics they always come back to
- **Forbidden phrases**: things that sound too "AI" or off-brand
- **Example posts**: 10+ examples of their real writing to learn from

## Content Generation Pipeline

### Step 1: Read Trend Report
Load the latest `data/trend-report-{date}.json` from the Content Scraper skill.

### Step 2: Match Topics to Brand
Filter trending topics through the brand voice profile. Only create content on topics that fit the brand's themes and audience.

### Step 3: Generate Content

For each content type, follow these formats:

#### Twitter Posts (5-8 per batch)
- Single tweets: max 280 chars, punchy, with a hook
- Use the brand's natural language patterns
- Include 1-2 relevant hashtags max
- End with a CTA or question when appropriate

#### Twitter Threads (1-2 per batch)
- 5-12 tweets long
- Opening tweet must be a HOOK (curiosity gap, bold claim, or question)
- Each tweet should be standalone-valuable
- Final tweet: summary + CTA
- Thread format: numbered or connected narrative

#### Newsletter Draft (1 per week)
- Subject line: curiosity-driven, 6-10 words
- Opening: personal anecdote or provocative statement
- Body: 3-5 key insights with examples
- Closing: actionable takeaway + CTA
- Length: 500-800 words

#### Article/Blog Post (1-2 per week)
- SEO-optimized title and meta description
- H2/H3 structure for scannability
- 1000-2000 words
- Include data, examples, and personal takes
- CTA at end

#### Video Script (1 per week)
- Hook (first 5 seconds)
- Problem statement
- Solution/insight
- Examples/proof
- CTA
- Length: 3-5 minutes when spoken

### Step 4: Quality Check
Before saving, verify each piece:
- Does it sound like the brand? Read it in their voice.
- Is it genuinely useful or entertaining?
- Would you share this if you saw it in your feed?
- Is the CTA clear and natural?

### Step 5: Save Output
Save to `shared/memory/brand-voices/content-batches/[cliente-slug]-{date}.json`:

```json
{
  "date": "2026-02-23",
  "brand": "profile-name",
  "content": [
    {
      "type": "tweet",
      "text": "Content here",
      "hashtags": ["tag1"],
      "scheduled_for": "2026-02-24T09:00:00",
      "status": "draft"
    }
  ]
}
```

## Guidelines
- NEVER start tweets with "I" — vary opening words
- NEVER use phrases like "Here's the thing", "Let me explain", "In today's world"
- Use contractions (don't, can't, won't) for casual tone
- Break up long sentences — short hits harder
- Always favor specifics over generics ("37% increase" beats "significant growth")

## Uso no Telegram (Wolf Agency)

- `"escreve 5 posts pro [Cliente] sobre [tema]"` → batch de posts
- `"cria thread no estilo do [Cliente] sobre [assunto]"` → thread
- `"gera newsletter do [Cliente] — semana de [data]"` → newsletter
- `"qual o tom de voz do [Cliente]?"` → mostra perfil salvo
- `"cria perfil de marca do [Cliente]"` → coleta infos e salva perfil novo
- `"atualiza tom de voz do [Cliente]"` → edita perfil existente
