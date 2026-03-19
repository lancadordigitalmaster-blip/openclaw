#!/bin/bash
# session-end.sh — Wolf Agency Session End Hook
# Adaptado do ECC everything-claude-code para arquitetura OpenClaw
# Extrai resumo da sessão ativa e persiste em memory/sessions/
# Roda via cron (a cada 30min) ou manualmente

export PATH="/opt/homebrew/bin:$PATH"

WORKSPACE="$HOME/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
SESSIONS_DIR="$MEMORY_DIR/sessions"
AGENT_SESSIONS="$HOME/.openclaw/agents/main/sessions"

mkdir -p "$SESSIONS_DIR"

TODAY=$(date '+%Y-%m-%d')
SESSION_SHORT=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_lowercase+string.digits,k=8)))")
SESSION_FILE="$SESSIONS_DIR/${TODAY}-${SESSION_SHORT}-session.md"

# Encontrar a sessão mais recente
LATEST_SESSION=$(ls -t "$AGENT_SESSIONS"/*.jsonl 2>/dev/null | grep -v '.bak\|.deleted' | head -1)

if [ -z "$LATEST_SESSION" ]; then
  echo "[SessionEnd] Nenhuma sessão ativa encontrada."
  exit 0
fi

# Extrair resumo da sessão via Python
SUMMARY_FILE=$(mktemp)
python3 /dev/stdin "$LATEST_SESSION" > "$SUMMARY_FILE" << 'PYEOF'
import json, sys, re

session_file = sys.argv[1]
user_messages = []
tools_used = set()
files_modified = set()
parse_errors = 0

try:
    with open(session_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except:
                parse_errors += 1
                continue

            if d.get("type") != "message":
                continue

            msg = d.get("message", {})
            role = msg.get("role", "")
            content = msg.get("content", [])

            # User messages — limpar metadados do Telegram
            if role == "user" and isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        text = part.get("text", "").strip()
                        # Remover blocos de metadado Telegram
                        clean = re.sub(r'Conversation info.*?```\n', '', text, flags=re.DOTALL)
                        clean = re.sub(r'Sender \(untrusted.*?```\n', '', clean, flags=re.DOTALL)
                        clean = clean.strip()
                        if clean and len(clean) > 2:
                            user_messages.append(clean[:200].replace("\n", " "))

            # Assistant tool calls (OpenClaw usa "toolCall", ECC usa "tool_use")
            if role == "assistant" and isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") in ("tool_use", "toolCall"):
                        tool_name = part.get("name", "") or part.get("toolName", "")
                        if tool_name:
                            tools_used.add(tool_name)
                        inp = part.get("input", {}) or part.get("arguments", {}) or part.get("toolInput", {}) or {}
                        fpath = inp.get("file_path", inp.get("path", ""))
                        if fpath and tool_name.lower() in ("write", "edit"):
                            files_modified.add(fpath)

except Exception as e:
    print(f"# Erro: {e}", file=sys.stderr)
    sys.exit(0)

print(f"TOTAL_MSGS={len(user_messages)}")
print(f"TOTAL_TOOLS={len(tools_used)}")

print("---USER_MESSAGES---")
for m in user_messages[-8:]:
    print(f"- {m}")

print("---TOOLS---")
for t in sorted(tools_used)[:15]:
    print(f"- {t}")

print("---FILES---")
for f in sorted(files_modified)[:20]:
    print(f"- {f}")

if parse_errors > 0:
    print(f"WARN: {parse_errors} linhas não parseáveis")
PYEOF

if [ ! -s "$SUMMARY_FILE" ]; then
  echo "[SessionEnd] Sem dados para salvar."
  rm -f "$SUMMARY_FILE"
  exit 0
fi

# Verificar se já existe arquivo de sessão do dia — atualizar em vez de criar novo
EXISTING=$(find "$SESSIONS_DIR" -name "${TODAY}-*-session.md" 2>/dev/null | head -1)
if [ -n "$EXISTING" ]; then
  SESSION_FILE="$EXISTING"
fi

# Extrair seções
USER_MSGS=$(awk '/---USER_MESSAGES---/{flag=1;next}/---[A-Z]/{flag=0}flag' "$SUMMARY_FILE")
TOOLS=$(awk '/---TOOLS---/{flag=1;next}/---[A-Z]/{flag=0}flag' "$SUMMARY_FILE")
FILES=$(awk '/---FILES---/{flag=1;next}/---[A-Z]/{flag=0}flag' "$SUMMARY_FILE")
TOTAL_MSGS=$(grep "TOTAL_MSGS=" "$SUMMARY_FILE" | cut -d= -f2)

rm -f "$SUMMARY_FILE"

# Gravar arquivo de sessão
cat > "$SESSION_FILE" << SESSIONEOF
# Sessão Wolf Agency — $TODAY
**Atualizado em:** $(date '+%Y-%m-%d %H:%M:%S BRT')
**Arquivo de origem:** $(basename "$LATEST_SESSION")

---

## Tarefas (Mensagens do Usuário)
$USER_MSGS

## Arquivos Modificados
$FILES

## Ferramentas Utilizadas
$TOOLS

## Stats
- Total mensagens do usuário: $TOTAL_MSGS

---

### Notas para Próxima Sessão
-

### Contexto a Carregar
\`\`\`
memory/state.md
memory/last-context.md (se existir)
\`\`\`
SESSIONEOF

echo "[SessionEnd] Sessão salva: $(basename $SESSION_FILE)"

# Log de histórico
echo "[SessionEnd] $(date '+%Y-%m-%d %H:%M:%S') — Sessão persistida: $(basename $SESSION_FILE)" >> "$MEMORY_DIR/session-history.log"

exit 0
