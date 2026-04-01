#!/bin/bash
# save-context.sh — Salva contexto da conversa ativa antes de restart
# Extrai as ultimas mensagens da sessao ativa e grava em last-context.md

export PATH="/opt/homebrew/bin:$PATH"

SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
CONTEXT_FILE="$HOME/.openclaw/workspace/memory/last-context.md"

# Find the most recently modified session file (by content, not .bak/.deleted)
LATEST_SESSION=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | grep -v '.bak\|.deleted' | head -1)

if [ -z "$LATEST_SESSION" ]; then
  echo "NO_SESSION"
  exit 0
fi

CONTEXT=$(python3 << PYEOF
import json, sys

session_file = "$LATEST_SESSION"
messages = []
try:
    with open(session_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("type") != "message":
                continue
            msg = d.get("message", {})
            role = msg.get("role", "unknown")
            content = msg.get("content", "")

            if isinstance(content, list):
                text_parts = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        text_parts.append(part["text"])
                    elif isinstance(part, dict) and part.get("type") == "tool_use":
                        text_parts.append(f"[tool: {part.get('name','')}]")
                content = " ".join(text_parts)

            if isinstance(content, str) and content.strip():
                # Remove Telegram metadata prefix
                clean = content
                if "Conversation info (untrusted metadata)" in clean:
                    parts = clean.split("\n\n", 2)
                    clean = parts[-1] if len(parts) > 1 else clean

                if len(clean) > 500:
                    clean = clean[:500] + "..."
                messages.append(f"**{role}:** {clean}")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(0)

# Last 10 meaningful messages
for m in messages[-10:]:
    print(m)
    print()
PYEOF
)

if [ -z "$CONTEXT" ]; then
  echo "NO_CONTEXT"
  exit 0
fi

mkdir -p "$(dirname "$CONTEXT_FILE")"

cat > "$CONTEXT_FILE" << EOF
# Ultimo Contexto Salvo (Auto-Heal Recovery)

**Salvo em:** $(date '+%Y-%m-%d %H:%M:%S BRT')
**Motivo:** Auto-heal detectou problema e salvou contexto antes de reiniciar
**Sessao:** $(basename "$LATEST_SESSION" .jsonl)

---

## Ultimas mensagens da conversa:

$CONTEXT

---

**INSTRUCAO:** Ao iniciar nova sessao, retome o contexto acima.
Informe o usuario que houve interrupcao e continue de onde parou.
Apos retomar, renomeie este arquivo para last-context-LIDO.md.
EOF

echo "SAVED: $CONTEXT_FILE"
