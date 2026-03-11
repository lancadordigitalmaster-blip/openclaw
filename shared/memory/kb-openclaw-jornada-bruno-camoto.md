# Base de Conhecimento: Jornada OpenClaw — Do Zero ao Multi-Agente

**Fonte:** YouTube — Bruno Camoto (empreendedor, +12 anos, nao-dev)
**URL:** https://www.youtube.com/watch?v=L-SQ0HyRVo8
**Duracao:** ~50 minutos
**Data de extracao:** 2026-03-06

---

## 1. Contexto do Autor

- Bruno Camoto, empreendedor ha 12 anos, NAO programador/dev
- Dono de 2 micro-SaaS: My Group Matrix e Metricas
- Usava Claude Code desde outubro/2025 — revolucionou produtividade mas tinha limitacoes:
  - Sempre iniciava conversa do zero
  - Precisava salvar/resgatar projetos constantemente
  - Alternava entre IAs (Gemini, ChatGPT) para tarefas diferentes
  - So funcionava com computador ligado
- Migrou para OpenClaw — construiu sistema multi-agente avancado em 2 semanas

---

## 2. Framework de Implementacao (6 Etapas)

### Etapa 1 — Instalacao e Canal de Comunicacao

**Decisao:** VPS (servidor Linux sem interface) em vez de hardware local
- Motivo: nao gastar dinheiro para testar se era hype
- Docker descartado: muito tecnico, isolacao excessiva, 1 dia perdido tentando configurar
- Instalacao direta na VPS funcionou melhor

**Canal: Telegram (NAO WhatsApp)**
- Telegram permite multiplos grupos com topicos = multiplas sessoes independentes
- WhatsApp tem conversa unica = sobrecarrega contexto com informacoes misturadas
- Cada topico no Telegram e uma nova sessao limpa

**Desafios iniciais:**
- Configuracao de skills na VPS (diferente do local)
- Conexao com browser
- Acesso SSH (que depois descobriu ser "ridiculamente facil")
- Solucao: Claude Code ao lado + navegador = IA guiando o processo

### Etapa 2 — Identidade do Assistente

**Arquivos fundamentais:**
- `soul.md` — personalidade, valores, tom, responsabilidades
- `agents.md` — como o agente funciona, regras
- `user.md` — informacoes sobre o usuario
- `tools.md` — ferramentas disponiveis

**Como criar:**
- Pedir para o agente: "Me faca perguntas para construirmos o Soul juntos"
- O agente pergunta, voce responde, ele constroi os documentos
- No inicio, usar padrao recomendado — depois vai atualizando

**Exemplo da Amora (assistente do Bruno):**
- Nome: Amora, 37 anos, CEO do Bruno
- Personalidade definida com valores e tom
- Manual de funcionamento: ao iniciar sessao le soul, user, memoria recente
- Regras claras: o que pode fazer sozinha vs. o que precisa perguntar

**Dica importante:** importar claude.md existente — ja tem interpretacao do usuario, regras, preferencias

**Tratar como pessoa, nao robo:**
- Email proprio (assistente.camoto@gmail.com)
- Login/senha proprios
- Cofre compartilhado no 1Password
- Forward de emails
- Alimentar com contexto pessoal/profissional continuamente
- "Trata como Tamagotchi — alimenta, conversa, da carinho — ela vai ficando cada vez mais inteligente"

### Etapa 3 — Sistema de Memoria

**Problema:** Modelos de IA nao tem memoria entre sessoes = "Alzheimer Reset"

**Solucao: Memoria em Camadas**

1. **Memoria por sessao (compactacao)**
   - Compacta com 160.000 tokens, reserva 30.000 tokens
   - Reserva garante que IA conclua raciocinio antes de compactar
   - ANTES de compactar, extrair OBRIGATORIAMENTE:
     - Decisoes tomadas
     - Licoes aprendidas
     - Projetos atualizados
     - Pessoas mencionadas
     - Pendencias

2. **Notas diarias**
   - Todo dia a meia-noite, compacta e salva nota do dia
   - Sempre revisita notas dos 2 dias anteriores ao iniciar

3. **Consolidacao periodica (a cada 15 dias)**
   - Revisa TODAS as notas diarias
   - Re-extrai decisoes/licoes/projetos/pessoas/pendencias
   - Motivo: IA as vezes esquece de extrair na compactacao, mesmo sendo "regra inviolavel"
   - Garante que nada se perde

4. **memory.md**
   - Sumario executivo de tudo
   - Estado dos projetos, links
   - NAO pode ser muito grande — quebrar em categorias:
     - memoria de projetos
     - memoria de decisions
     - memoria de lessons
     - notas diarias
     - pendencias
     - pessoas (quem faz o que)

### Etapa 4 — Ferramentas, APIs e Skills

**ORDEM IMPORTA:** so instalar ferramentas DEPOIS de identidade + memoria estarem solidas
- "Calma, jovem Padawan" — primeiro arruma a fundacao
- Senao o agente se perde, esquece coisas

**Como instalar skills:**
- Copiar link do diretorio do GitHub
- Falar: "Aprenda essa habilidade"
- O agente aprende sozinho — "parece magica"

**Seguranca de credenciais:**
- Todas as APIs e senhas salvas no 1Password (cofre compartilhado)
- Nunca hardcode em arquivos
- Agente tem cofre proprio

**Skills e integrações instaladas pelo Bruno:**
- 1Password (gerenciamento de senhas)
- OpenAI API (audio)
- Auto-updator (autoatualizacao)
- Circle API (comunidade de 20.000 pessoas)
- YouTube API (metricas)
- LinkedIn (login proprio)
- Instagram API
- Twitter/X API
- Google Drive, Sheets, Gmail
- Excalidraw (desenhos)
- Brave Browser + Perplexity (Deep Research)
- Customer Success/Suporte (identificar padroes em tickets)
- Frontend skills

**Self-Updates (automacoesesdo agente):**
- Sincroniza dados com GitHub
- Auto-update diario
- Daily config review (o que esta parado, o que excluir)
- Auditoria dos arquivos soul/tools/agents
- Revisao de seguranca diaria (testa portas, verifica vazamentos)

### Etapa 5 — Heartbeats e Crons (Proatividade)

**Heartbeats:** automacoes condicionais (se X acontecer, fazer Y)
- Checklist de compromissos e pendencias
- Troca de modelo para economizar tokens (ex: Haiku)

**Crons diarios:**
- Digest de conteudo (Reddit, YouTube, newsletters)
- Auto-update (ultima versao do GitHub + skills)
- Config review + safety check
- Daily report de redes sociais

**Crons semanais:**
- Metricas do SaaS
- Videos de concorrentes (ideias de conteudo)
- Revisao de projetos parados (5+ dias sem atividade)
- Audit de seguranca profundo

**Dica:** para criar audit de seguranca, usar canal de Deep Research:
- "Pesquisa papers e conteudos sobre seguranca do OpenClaw"
- "Crie um processo de revisao de seguranca"

**Comandos uteis:**
- `openclaw security audit` — identifica problemas
- `openclaw doctor fix` — corrige automaticamente

### Etapa 6 — Multi-Agentes (Equipe)

**Agente criador de agentes (Orchestrator):**
- Cria soul, agents, usuario, estrutura de memoria para novos agentes
- Faz perguntas para definir personalidade e nivel
- Pode criar, pausar, deletar agentes

**4 niveis de agentes:**
1. Observador
2. Advisor
3. Operador
4. Autonomo

**Agentes podem ser promovidos ou rebaixados** baseado em performance

**7 arquivos sagrados por agente:**
1. Identidade
2. Soul
3. Agent
4. User
5. Tools
6. Memory
7. Heartbeat + Working

**Contexto compartilhado:**
- Arquivo `team` — todos agentes sabem quem faz o que, nivel, modelo, canal
- Outputs compartilhados
- Licoes aprendidas compartilhadas (seletivamente)
- Agentes simples (scraper, executor) NAO precisam de licoes aprendidas

**Performance Review (semanal pela Amora):**
- Quality score
- Velocidade
- Proatividade
- Aderencia
- Custo-beneficio
- Decide: promover, manter ou rebaixar

**Comunicacao entre agentes:**
- Um agente menciona outro
- Active feed de tudo feito no dia
- Notificacoes em tempo real
- Dados salvos no Supabase (cards, tarefas, comentarios)

**Equipe do Bruno:**
- Amora (CEO/assistente principal)
- Scraper
- Criador de conteudo
- Planejador (Master Planner)
- Dev
- QA

**Preferencia pessoal:** Bruno gosta de aprovar tudo manualmente
- Nao deixa agentes executarem sem interacao humana
- Tudo passa por ele

---

## 3. Custos

- Assinatura Claude Code: plano pago (nunca estourou)
- VPS: custo variavel (nao especificado)
- Custo mensal estimado da Amora: ~$45
- Dica: documento de economia de tokens criado (video futuro prometido)

---

## 4. Resultados Praticos

- Brainstorm com IA constantemente
- Producao de conteudo automatizada
- Scrapping de multiplas fontes
- Dados de todas as ferramentas centralizados
- Monitoramento de suporte (padroes em tickets)
- Metricas de YouTube, LinkedIn, Instagram, X
- Roadmap de desenvolvimento acompanhado
- Notion da empresa integrado
- Deep Research sob demanda
- Autoatualizacoes e evolucao continua
- "Ceu e o limite"

---

## 5. Licoes-Chave

1. **NAO precisa ser dev** — perguntas certas + IA guiando = suficiente
2. **Ordem importa:** instalacao → identidade → memoria → ferramentas → crons → multi-agentes
3. **Telegram > WhatsApp** para sessoes multiplas
4. **Docker complicou** para nao-devs — instalacao direta na VPS foi mais facil
5. **Tratar IA como pessoa/funcionaria** — treinar, dar contexto, alimentar continuamente
6. **Memoria e critica** — sem ela, toda sessao e "Alzheimer Reset"
7. **Consolidacao periodica** — IA esquece de extrair mesmo com regras inviolaveis
8. **Nao apressar ferramentas** — fundacao (identidade + memoria) primeiro
9. **Skills do GitHub** — copiar link e pedir para aprender = funciona
10. **Seguranca nao e opcional** — audits diarios + semanais
