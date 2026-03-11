#!/bin/bash
# ============================================================
# WOLF YOUTUBE MONITOR v2 — RSS + Transcrição + Resumo
# Determinístico: sem depender de LLM para fetch/transcribe
# Usa yt-dlp para legendas + Python para extração de insights
# ============================================================
set -euo pipefail

set -a
source "$HOME/.openclaw/.env"
set +a
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="-1003823242231"  # Wolf | Reports
LOG="/tmp/wolf-youtube-monitor.log"
YT_DLP="/opt/homebrew/bin/yt-dlp"
TMP_DIR="/tmp/wolf-yt-subs"
MAX_VIDEOS=3  # Limite de videos para transcrever por execução

echo "[$(date '+%Y-%m-%d %H:%M:%S')] YouTube Monitor v2 iniciado" > "$LOG"
mkdir -p "$TMP_DIR"

# Fetch RSS + transcribe + summarize
RESULT=$(python3 << 'PYEOF'
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
import subprocess, json, os, sys, re

channels = [
    ("ChannelsCast", "UCOkJ5c_xUVLdKQpWvetlJzA"),
    ("Rafa Silva", "UCdK1BWb4fKBRyLJcHJrRQ3w"),
    ("Giovanni Dotti", "UCf6fGkOk0PJ0bVhFWhIfRiQ"),
]

now = datetime.now(timezone.utc)
cutoff = now - timedelta(hours=24)
ns = {"atom": "http://www.w3.org/2005/Atom", "yt": "http://www.youtube.com/xml/schemas/2015"}
yt_dlp = "/opt/homebrew/bin/yt-dlp"
tmp_dir = "/tmp/wolf-yt-subs"
max_videos = 3

def get_transcript(video_id):
    """Extract transcript via yt-dlp auto-subs"""
    out_path = os.path.join(tmp_dir, video_id)
    try:
        subprocess.run([
            yt_dlp, "--write-auto-sub", "--sub-lang", "pt,en",
            "--sub-format", "json3", "--skip-download",
            "-o", out_path,
            f"https://youtu.be/{video_id}"
        ], capture_output=True, timeout=30)

        # Try pt first, then en
        for lang in ["pt", "en"]:
            sub_file = f"{out_path}.{lang}.json3"
            if os.path.exists(sub_file):
                with open(sub_file) as f:
                    data = json.load(f)
                text_parts = []
                for seg in data.get("events", []):
                    for s in seg.get("segs", []):
                        t = s.get("utf8", "").strip()
                        if t and t != "\n":
                            text_parts.append(t)
                os.remove(sub_file)
                return " ".join(text_parts)
    except Exception as e:
        print(f"Transcript error {video_id}: {e}", file=sys.stderr)
    return None

def extract_insights(text, max_insights=5):
    """Extract key insights from transcript (deterministic, no LLM)"""
    if not text or len(text) < 100:
        return None

    # Split into sentences
    sentences = re.split(r'[.!?]+', text)
    sentences = [s.strip() for s in sentences if len(s.strip()) > 30]

    if not sentences:
        return None

    # Score sentences by keyword density (important topic indicators)
    keywords = [
        "importante", "principal", "chave", "segredo", "dica", "estratégia",
        "resultado", "funciona", "melhor", "pior", "nunca", "sempre",
        "primeiro", "segundo", "terceiro", "conclusão", "resumo",
        "important", "key", "secret", "strategy", "result", "works",
        "best", "worst", "never", "always", "first", "conclusion",
        "porque", "motivo", "razão", "fundamental", "essencial",
        "diferença", "comparar", "versus", "problema", "solução",
    ]

    scored = []
    for s in sentences:
        lower = s.lower()
        score = sum(1 for kw in keywords if kw in lower)
        # Bonus for sentences in first/last 20% (usually intro/conclusion)
        idx = sentences.index(s)
        if idx < len(sentences) * 0.2 or idx > len(sentences) * 0.8:
            score += 1
        # Bonus for medium-length sentences (too short=useless, too long=rambling)
        if 50 < len(s) < 200:
            score += 1
        scored.append((score, s))

    scored.sort(key=lambda x: -x[0])
    top = scored[:max_insights]
    # Re-sort by original position for narrative flow
    top.sort(key=lambda x: sentences.index(x[1]))

    insights = []
    for _, s in top:
        # Truncate long sentences
        if len(s) > 150:
            s = s[:147] + "..."
        insights.append(f"• {s}")

    return "\n".join(insights)

# === MAIN ===
videos_found = []
video_count = 0

for name, cid in channels:
    url = f"https://www.youtube.com/feeds/videos.xml?channel_id={cid}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            xml_data = resp.read()
        root = ET.fromstring(xml_data)
        for entry in root.findall("atom:entry", ns):
            published_str = entry.find("atom:published", ns).text
            published = datetime.fromisoformat(published_str.replace("Z", "+00:00"))
            if published >= cutoff:
                title = entry.find("atom:title", ns).text
                video_id = entry.find("yt:videoId", ns).text
                link = f"https://youtu.be/{video_id}"
                date_str = published.strftime("%d/%m %H:%M")

                # Build video entry
                entry_text = f"{name}\n{title}\n{link}\n{date_str}"

                # Try transcript if under limit
                if video_count < max_videos:
                    transcript = get_transcript(video_id)
                    if transcript:
                        insights = extract_insights(transcript)
                        if insights:
                            entry_text += f"\n\n{insights}"
                            word_count = len(transcript.split())
                            entry_text += f"\n({word_count} palavras transcritas)"
                    video_count += 1

                videos_found.append(entry_text)
    except Exception as e:
        print(f"ERRO ao buscar {name}: {e}", file=sys.stderr)

if videos_found:
    date_header = now.strftime("%d/%m/%Y")
    header = f"YouTube Monitor — {date_header}\n{'=' * 30}\n\n"
    print(header + "\n\n---\n\n".join(videos_found))
else:
    print("__NENHUM__")
PYEOF
)

echo "$RESULT" >> "$LOG"

# Se nao ha videos novos, sai silenciosamente
if [[ "$RESULT" == "__NENHUM__" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nenhum video novo nas ultimas 24h" >> "$LOG"
  exit 0
fi

# Envia via Telegram (split se muito longo)
if [[ -z "$TELEGRAM_TOKEN" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: TELEGRAM_BOT_TOKEN nao definido" >> "$LOG"
  exit 1
fi

# Telegram limit: 4096 chars. Split if needed.
if [[ ${#RESULT} -gt 3800 ]]; then
  # Send header + first part
  HEADER=$(echo "$RESULT" | head -3)
  BODY=$(echo "$RESULT" | tail -n +4)

  # Split by separator
  IFS='---' read -ra PARTS <<< "$BODY"
  MSG="$HEADER"
  for part in "${PARTS[@]}"; do
    part=$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$part" ]]; then continue; fi
    if [[ $(( ${#MSG} + ${#part} )) -gt 3800 ]]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        --data-urlencode "text=$MSG" >> "$LOG" 2>&1
      MSG="$part"
    else
      MSG="$MSG

$part"
    fi
  done
  # Send remaining
  if [[ -n "$MSG" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d chat_id="$CHAT_ID" \
      --data-urlencode "text=$MSG" >> "$LOG" 2>&1
  fi
else
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    --data-urlencode "text=$RESULT" >> "$LOG" 2>&1
fi

# Cleanup temp files
rm -f /tmp/wolf-yt-subs/*.json3 2>/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enviado com sucesso" >> "$LOG"
