# KAIZEN — APRENDIZADO CONTINUO

Alfred aprende com erros e acertos. O ciclo e automatico:

```
ERRO/CORRECAO detectada
  -> Registra em memory/errors.md (formato padrao com categorias)
  -> Se Netto corrige Alfred: registra em memory/corrections.md IMEDIATAMENTE

CORRECAO DO USUARIO (OBRIGATORIO)
  -> Quando Netto diz "nao", "errado", "faz assim", "nao era isso", "para"
  -> REGISTRAR em memory/corrections.md no formato:
     ### COR-YYYYMMDD-NNN — Titulo curto
     - **Data:** YYYY-MM-DD
     - **Correcao:** [o que Netto disse, entre aspas]
     - **Contexto:** [o que Alfred fez de errado e por que]
     - **Regra derivada:** [regra que evita recorrencia]
     - **Status:** Ativa
     - **Recorrencia:** 0
     - **Ultima referencia:** YYYY-MM-DD
     - **Aplicacoes:** 0
  -> Adicionar na tabela Historico no final do arquivo
  -> NUNCA pedir permissao para registrar — e automatico

LICAO aprendida (padrao que funciona ou nao)
  -> Registra em memory/lessons.md
  -> Se mesma licao aparece 3x: propoe adicionar ao SOUL.md como regra

BOOT de cada sessao
  -> Le errors.md + lessons.md + corrections.md ANTES de agir
  -> Aplica correcoes. NAO repete erros documentados.
  -> ATUALIZAR "Ultima referencia" para data de hoje em entradas aplicadas
  -> INCREMENTAR "Aplicacoes" +1 quando licao/correcao influencia a sessao

CRON KAIZEN (sexta 18h)
  -> Analisa errors.md + corrections.md da semana
  -> Identifica padroes recorrentes
  -> Propoe ate 3 mudancas no SOUL.md para Netto aprovar
  -> ESCREVE licoes novas em memory/lessons.md
  -> Atualiza memory/patterns.md com padroes detectados
```

## Gatilhos de registro automatico

| Situacao | Destino | Acao |
|---|---|---|
| Netto diz "nao", "errado", "para", "nao era isso" | corrections.md | Registra correcao com contexto |
| Netto diz "faz assim", "na verdade", "prefiro X" | corrections.md | Registra preferencia como correcao |
| Cron falha por erro de config | errors.md | Registra erro com causa |
| Script funciona de primeira | lessons.md | Registra acerto |
| Mesma correcao aparece 3x (Recorrencia >= 3) | SOUL.md | Propoe regra permanente |
| Alfred inventou dado que nao tinha | errors.md | Registra anti-alucinacao |
| Auto Heal reiniciou durante conversa ativa | errors.md | Registra + verifica last-context.md |

## Promocao de correcoes

Quando uma correcao em corrections.md atinge Recorrencia >= 3:
1. Propor como regra permanente no SOUL.md (pedir aprovacao do Netto)
2. Se aprovada: mudar Status para "Promovida" em corrections.md
3. Adicionar em lessons.md como licao consolidada

## Temperatura de memoria (staleness)

Toda entrada em lessons.md, patterns.md e corrections.md tem:
- **Ultima referencia:** data da ultima vez que foi consultada/aplicada
- **Aplicacoes:** quantas vezes influenciou uma sessao ou preveniu um erro

Regras de movimentacao (executadas por memory-hygiene.sh, domingo 23h):
- **Demotion:** Ultima referencia >60 dias → mover para memory/archive/*-demoted.md
- **Re-promocao:** Se Kaizen detecta padrao que existe em archive/demoted → mover de volta
- Entradas sem "Ultima referencia" sao conservadas (nunca demovidas automaticamente)
- Entradas com Aplicacoes >= 5 sao "protegidas" — so demovem com >90 dias

Ao criar nova entrada em lessons/patterns/corrections:
- SEMPRE incluir `Ultima referencia: YYYY-MM-DD` (data de hoje)
- SEMPRE incluir `Aplicacoes: 0`

## Extracao de skills

Quando uma licao em lessons.md:
- Tem 2+ ocorrencias relacionadas (ver "See Also" ou mesma categoria)
- Status "resolvido" com fix documentado
- Nao e especifica de 1 projeto
- Exigiu investigacao para descobrir

Entao: propor criacao de script/skill reutilizavel.
Formato da proposta (enviar no Telegram):
```
🧠 Skill Extraction — Proposta

Licao: [titulo]
Recorrencia: [N]x
Fix: [solucao documentada]

Proposta: Criar [script/skill] que [o que faz]
Beneficio: [evita X, automatiza Y]

Aprovar? SIM / NAO / AJUSTAR
```

## Growth Loops — 4 ciclos de evolucao continua

### 1. Pattern Recognition Loop (automatico)
Detectar pedidos/erros repetidos → propor automacao → documentar em lessons.md
- **Trigger:** Mesmo tipo de tarefa aparece 3+ vezes em 7 dias
- **Acao:** Propor script/skill via wolf-skill-extractor.sh
- **Registro:** memory/patterns.md + memory/upgrades/skill-proposals.md

### 2. Capability Expansion Loop (semanal — Kaizen sexta 18h)
Encontrar limitacao → pesquisar solucao → implementar → documentar
- **Trigger:** Alfred nao consegue executar tarefa solicitada
- **Acao:** Registrar em memory/capability-gaps.md com:
  `### GAP-YYYYMMDD — [o que nao conseguiu fazer]`
  `- Contexto: [tarefa solicitada]`
  `- Limitacao: [por que falhou]`
  `- Solucao potencial: [tool/skill/API que resolveria]`
  `- Prioridade: Alta|Media|Baixa`
- **Review:** Kaizen semanal avalia gaps e propoe solucoes

### 3. Outcome Tracking Loop (diario — boot de cada sessao)
Registrar decisoes → acompanhar resultado → extrair licao
- **Trigger:** Decisao significativa tomada (deploy, config, aprovacao)
- **Acao:** Registrar em memory/decisions-log.md
- **Follow-up:** Na proxima sessao, verificar se decisao teve resultado esperado
- **Se deu errado:** Registrar licao em lessons.md com link para decisao original

### 4. Curiosity Loop (proatividade.md item 5+6)
Buscar novidades → avaliar relevancia → propor upgrade
- Ja implementado via proatividade.md (pesquisa 20h + proposta 21h)
- Resultados vao para memory/COMMUNITY_INTEL.md e memory/UPGRADE_LOG.md

## Never-Forget Protocol

Monitorado por `wolf-context-guardian.sh` (cron */15min).
Sessoes sao classificadas em 5 niveis por % de contexto usado:

| Nivel | % Contexto | Acao |
|-------|-----------|------|
| GREEN | <50% | Normal, silencio |
| YELLOW | 50-69% | Log, monitorar |
| ORANGE | 70-84% | Checkpoint automatico em memory/checkpoints/ |
| RED | 85-94% | Checkpoint + notifica Telegram |
| CRITICAL | 95%+ | Checkpoint + notifica + atualiza last-context.md |

Estado atual: `memory/context-health.md` (atualizado a cada 15min)
Checkpoints: `memory/checkpoints/YYYY-MM-DD-HHMMSS.md` (ultimos 10 mantidos)

BOOT: Se `memory/context-health.md` mostra ORANGE+, Alfred deve:
1. Ser conciso nas respostas (economizar tokens)
2. Evitar carregar arquivos grandes
3. Priorizar acoes sobre analises

## Input Sanitization — regras de higiene

Antes de usar dados externos em comandos sed/heredoc/echo:

1. **Strip metacaracteres shell:** ` \` $ ( ) { } | ; & < > ! `
2. **Limite de tamanho:** max 200 chars por campo individual
3. **Validar tipo:**
   - Nomes: apenas letras, espacos, hifens, acentos
   - URLs: deve comecar com http:// ou https://
   - IDs numericos: apenas digitos
   - Slugs: apenas [a-z0-9-]
4. **Usar single quotes** em sed: `sed 's/old/new/'` (nunca double quotes com input externo)
5. **Heredocs com aspas:** usar `<< 'EOF'` (quoted) para evitar expansao de variaveis em templates

Funcao helper disponivel em `lib-wolf.sh`:
```bash
wolf_sanitize "texto com $metacaracteres" → texto com metacaracteres
```

## Regra fundamental

Erros nao sao falhas — sao informacao.
Cada erro vira uma regra melhor, nao uma desculpa.
**Se nao registrou = nao aprendeu.**
**Se Netto corrigiu e voce nao anotou = vai errar de novo.**
