# debug.md — Titan Sub-Skill: Diagnóstico e Debugging
# Ativa quando: erro, bug, exception, crash, "não funciona", "quebrou"

---

## PROTOCOLO COMPLETO DE DEBUG

```
REGRA #1: Nunca assuma. Leia o erro completo.
REGRA #2: Reproduza antes de tentar corrigir.
REGRA #3: Mude uma coisa de cada vez ao testar hipóteses.

CHECKLIST DE INFORMAÇÕES (pede tudo antes de começar):
  □ Erro completo (stack trace, não só a mensagem final)
  □ Ambiente: dev / staging / produção?
  □ Frequência: sempre / às vezes / só uma vez?
  □ Quando começou: data/hora (ou "sempre foi assim")
  □ O que mudou: último deploy, dependência, dado novo, config
  □ Como reproduzir: passo a passo se possível

PROCESSO DE DIAGNÓSTICO:

  PASSO 1 — LEITURA DO ERRO
    → Lê da última linha do stack trace para cima (onde está o código seu)
    → Identifica: tipo do erro, arquivo, linha, função
    → Separa: código nosso vs biblioteca de terceiro
    → Se erro em biblioteca de terceiro: o que chamamos que causou?

  PASSO 2 — LINHA DO TEMPO
    → Quando funcionava?
    → O que mudou entre "funcionava" e "não funciona"?
    → Cria hipóteses baseadas nessa diferença

  PASSO 3 — HIPÓTESES (rankeadas)
    Para cada hipótese:
    - Como testar em 5 minutos?
    - Se for verdade, qual o fix?
    → Testa mais rápida primeiro

  PASSO 4 — ISOLAMENTO
    Reduz o problema ao menor caso possível:
    → Comentar código até isolar onde falha
    → Testar função isolada (unit test manual)
    → Verificar com dados simplificados

  PASSO 5 — FIX
    Firefighter (urgente):
      Menor mudança que resolve agora
      Documenta como TODO o fix permanente

    Engineer (não urgente):
      Solução correta
      Trata o caso raiz, não o sintoma
      Adiciona teste para prevenir regressão

  PASSO 6 — VERIFICAÇÃO
    "Como sei que funcionou?" — define antes de aplicar o fix
    Smoke test: sequência mínima para confirmar que o bug sumiu
    Regression check: nada que funcionava antes quebrou?
```

---

## ERROS COMUNS POR TIPO

```yaml
javascript_typescript:
  "Cannot read properties of undefined":
    causa: "acessando propriedade de objeto null/undefined"
    debug: "adiciona console.log da variável uma linha acima"
    fix: "optional chaining (?.) ou verificação explícita"

  "Promise rejected / UnhandledPromiseRejection":
    causa: "await sem try/catch ou .catch()"
    debug: "procura todos os await sem tratamento de erro"
    fix: "envolve em try/catch, adiciona .catch() na chain"

  "CORS error":
    causa: "backend não está aceitando origin do frontend"
    debug: "verifica headers de resposta no Network tab"
    fix: "configura cors() no backend com a origin correta"

  "Module not found":
    causa: "path errado ou dependência não instalada"
    debug: "verifica se arquivo existe, se npm install foi rodado"
    fix: "corrige path ou instala dependência"

python:
  "KeyError":
    causa: "chave não existe no dict"
    debug: "print(dict.keys()) antes do acesso"
    fix: "dict.get('chave', default) em vez de dict['chave']"

  "IndentationError":
    causa: "mistura de tabs e espaços"
    fix: "configura editor para usar só espaços, roda: autopep8"

  "ImportError / ModuleNotFoundError":
    causa: "módulo não instalado ou virtual env errado"
    debug: "pip list | grep [module], verifica se venv está ativo"
    fix: "pip install [module] --break-system-packages"

postgres_supabase:
  "relation does not exist":
    causa: "tabela não criada ou migration não rodou"
    debug: "\\dt no psql para listar tabelas existentes"
    fix: "roda migration, cria tabela"

  "duplicate key violates unique constraint":
    causa: "inserindo registro com PK/unique já existente"
    debug: "verifica se upsert é o comportamento desejado"
    fix: "INSERT ... ON CONFLICT DO UPDATE"

  "too many connections":
    causa: "pool de conexões esgotado"
    debug: "SELECT count(*) FROM pg_stat_activity;"
    fix: "configura connection pooling (PgBouncer), fecha conexões ociosas"

evolution_api_whatsapp:
  "Instance not connected":
    causa: "QR code expirou ou sessão perdida"
    fix: "GET /instance/connect/{instance} para novo QR code"

  "Message not sent":
    causa: "número inválido, formatação incorreta, ou rate limit"
    debug: "número deve ser: 5511999999999@s.whatsapp.net (sem +)"
    fix: "valida formato do número antes de enviar"

openclaw_mcp:
  "MCP server not responding":
    causa: "servidor MCP não iniciou ou credencial inválida"
    debug: "openclaw plugins status"
    fix: "openclaw plugins restart [nome]"

  "Tool not found":
    causa: "skill não carregada ou nome errado de tool"
    debug: "verifica se SKILL.md está no diretório correto"
    fix: "recarrega skills: openclaw reload"
```
