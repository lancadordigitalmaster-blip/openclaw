#!/usr/bin/env python3
"""
Skills Trend Monitor — Wolf Agency
Monitora skills.sh diariamente, compara com snapshot anterior,
identifica top 10 em alta (maior crescimento 24h) e novas skills.
Envia relatório via Telegram.

Uso: python3 skills-trend-monitor.py
Cron: 09:00 BRT diário
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# === Config ===
DATA_DIR = Path.home() / ".openclaw" / "workspace" / "memory" / "skills-trends"
SNAPSHOT_FILE = DATA_DIR / "snapshot.json"
HISTORY_FILE = DATA_DIR / "history.json"
LOG_FILE = DATA_DIR / "monitor.log"
INSTALLED_SKILLS_DIR = Path.home() / ".openclaw" / "workspace" / "skills"

# Telegram config
ENV_FILE = Path.home() / ".openclaw" / ".env"
CHAT_ID = "789352357"

# Categories relevant to Wolf Agency (marketing digital)
WOLF_CATEGORIES = [
    "marketing", "seo", "copywriting", "social", "email", "ads", "content",
    "design", "brand", "analytics", "pricing", "sales", "proposal",
    "pdf", "pptx", "docx", "xlsx", "office",
    "video", "image", "ai-image", "ai-video",
    "automation", "workflow", "n8n",
    "whatsapp", "telegram", "instagram", "facebook", "tiktok",
    "scraping", "browser", "search",
    "agent", "self-improving", "brainstorming",
]


def log(msg):
    """Log to file."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}] {msg}\n")


def load_env():
    """Load .env vars."""
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                key, _, val = line.partition("=")
                env[key.strip()] = val.strip()
    return env


def send_telegram(msg):
    """Send via Telegram."""
    env = load_env()
    token = env.get("TELEGRAM_BOT_TOKEN", "")
    if not token:
        log("ERRO: TELEGRAM_BOT_TOKEN não encontrado")
        return False
    try:
        payload = json.dumps({"chat_id": CHAT_ID, "text": msg, "parse_mode": "Markdown"})
        subprocess.run(
            ["curl", "-s", "-X", "POST",
             f"https://api.telegram.org/bot{token}/sendMessage",
             "-H", "Content-Type: application/json",
             "-d", payload],
            capture_output=True, timeout=15
        )
        return True
    except Exception as e:
        log(f"ERRO Telegram: {e}")
        return False


def fetch_skills_page():
    """Fetch skills.sh and extract skill data from SSR payload."""
    try:
        result = subprocess.run(
            ["curl", "-s", "-L", "--max-time", "30",
             "-H", "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
             "https://skills.sh/"],
            capture_output=True, text=True, timeout=45
        )
        html = result.stdout
        if not html or len(html) < 1000:
            log(f"ERRO: HTML muito curto ({len(html)} chars)")
            return []

        skills = []
        seen = set()

        # HTML structure per skill entry:
        # href="/owner/repo/skill-name">...<h3>skill-name</h3>
        # ...<p>owner/repo</p>...<span>534.7K</span>
        # Extract: href, skill name, source, install count
        pattern = (
            r'href="/([^"]+/([a-zA-Z][a-zA-Z0-9_-]+))"[^>]*>'  # href with skill name
            r'.*?<h3[^>]*>([^<]+)</h3>'                          # h3 = display name
            r'.*?<p[^>]*>([^<]+)</p>'                             # p = source (owner/repo)
            r'.*?<span[^>]*font-mono[^>]*>([\d,.]+[KMkm]?)</span>'  # span = install count
        )
        matches = re.findall(pattern, html, re.DOTALL)

        for href, slug, display_name, source, count_str in matches:
            name = display_name.strip()
            if name not in seen:
                count = parse_count(count_str)
                if count > 0:
                    seen.add(name)
                    skills.append({
                        "name": name,
                        "source": source.strip(),
                        "installs": count,
                    })

        skills.sort(key=lambda x: x["installs"], reverse=True)
        log(f"Extraídas {len(skills)} skills do skills.sh")
        return skills

    except Exception as e:
        log(f"ERRO fetch: {e}")
        return []


def parse_count(s):
    """Parse '134.5K' or '2.5M' to integer."""
    s = s.strip().replace(",", "")
    multiplier = 1
    if s.upper().endswith("K"):
        multiplier = 1000
        s = s[:-1]
    elif s.upper().endswith("M"):
        multiplier = 1_000_000
        s = s[:-1]
    try:
        return int(float(s) * multiplier)
    except ValueError:
        return 0


def get_installed_skills():
    """List currently installed Wolf skills."""
    installed = set()
    if INSTALLED_SKILLS_DIR.exists():
        for d in INSTALLED_SKILLS_DIR.iterdir():
            if d.is_dir() and not d.name.startswith(("_", ".")):
                installed.add(d.name)
    return installed


def is_wolf_relevant(skill_name):
    """Check if skill is relevant to Wolf Agency (marketing digital)."""
    name_lower = skill_name.lower()
    # Skip Azure, infrastructure, and pure dev tools
    skip_patterns = ["azure", "entra", "appinsights", "kusto", "terraform",
                     "kubernetes", "k8s", "docker", "helm", "rust", "golang",
                     "swift", "kotlin", "flutter", "ionic"]
    for skip in skip_patterns:
        if skip in name_lower:
            return False
    # Check for relevant categories
    for cat in WOLF_CATEGORIES:
        if cat in name_lower:
            return True
    return False


def analyze_trends(current, previous):
    """Compare current vs previous snapshot, find trends."""
    prev_map = {s["name"]: s["installs"] for s in previous}
    curr_map = {s["name"]: s["installs"] for s in current}

    # Calculate growth
    growth = []
    for s in current:
        name = s["name"]
        prev_count = prev_map.get(name, 0)
        curr_count = s["installs"]
        if prev_count > 0:
            diff = curr_count - prev_count
            pct = (diff / prev_count) * 100 if prev_count > 0 else 0
            if diff > 0:
                growth.append({
                    "name": name,
                    "installs": curr_count,
                    "growth": diff,
                    "growth_pct": pct,
                    "relevant": is_wolf_relevant(name),
                })

    # New skills (not in previous snapshot)
    new_skills = []
    for s in current:
        if s["name"] not in prev_map and s["installs"] > 50:
            new_skills.append({
                "name": s["name"],
                "installs": s["installs"],
                "relevant": is_wolf_relevant(s["name"]),
            })

    # Sort by growth percentage (bigger movers first)
    growth.sort(key=lambda x: x["growth_pct"], reverse=True)
    new_skills.sort(key=lambda x: x["installs"], reverse=True)

    return growth, new_skills


def format_count(n):
    """Format 134500 as '134.5K'."""
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n/1_000:.1f}K"
    return str(n)


def build_report(growth, new_skills, current, installed):
    """Build Telegram report message."""
    now = datetime.now().strftime("%d/%m/%Y %H:%M")
    lines = [f"*Skills Trend Monitor* — {now}\n"]

    # Top 10 em alta (maior crescimento %)
    top_growth = [g for g in growth if g["growth"] > 0][:10]
    if top_growth:
        lines.append("*Top 10 em Alta (24h):*")
        for i, g in enumerate(top_growth, 1):
            star = " ⭐" if g["relevant"] else ""
            installed_tag = " ✅" if g["name"] in installed else ""
            lines.append(
                f"{i}. `{g['name']}` — {format_count(g['installs'])} "
                f"(+{format_count(g['growth'])}, +{g['growth_pct']:.1f}%)"
                f"{star}{installed_tag}"
            )
        lines.append("")

    # Top 10 Wolf-relevant em alta
    wolf_growth = [g for g in growth if g["relevant"] and g["growth"] > 0][:10]
    if wolf_growth:
        lines.append("*Relevantes p/ Wolf Agency:*")
        for g in wolf_growth:
            installed_tag = " ✅" if g["name"] in installed else ""
            lines.append(
                f"• `{g['name']}` — {format_count(g['installs'])} "
                f"(+{g['growth_pct']:.1f}%){installed_tag}"
            )
        lines.append("")

    # New skills
    relevant_new = [s for s in new_skills if s["relevant"]][:5]
    if relevant_new:
        lines.append("*Novas Skills (relevantes):*")
        for s in relevant_new:
            lines.append(f"• `{s['name']}` — {format_count(s['installs'])} installs")
        lines.append("")

    # Not installed recommendations
    candidates = [g for g in wolf_growth if g["name"] not in installed][:5]
    if candidates:
        lines.append("*Sugestão de instalação:*")
        for c in candidates:
            lines.append(f"→ `clawhub install {c['name']}`")
        lines.append("")

    # Stats
    total_skills = len(current)
    total_installed = len(installed)
    lines.append(f"_Ecossistema: {total_skills} skills | Wolf: {total_installed} instaladas_")
    lines.append("_⭐ = relevante p/ marketing | ✅ = já instalada_")

    return "\n".join(lines)


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    log("=== Início do monitoramento ===")

    # Fetch current data
    current = fetch_skills_page()
    if not current:
        log("ERRO: Nenhuma skill extraída — abortando")
        return

    # Load previous snapshot
    previous = []
    if SNAPSHOT_FILE.exists():
        try:
            previous = json.loads(SNAPSHOT_FILE.read_text())
        except Exception:
            previous = []

    # Get installed skills
    installed = get_installed_skills()

    if previous:
        # Analyze trends
        growth, new_skills = analyze_trends(current, previous)
        report = build_report(growth, new_skills, current, installed)
        log(f"Relatório: {len(growth)} com crescimento, {len(new_skills)} novas")

        # Send report only if there's something to report
        if growth or new_skills:
            send_telegram(report)
            log("Relatório enviado via Telegram")
        else:
            log("Sem mudanças significativas — relatório não enviado")
    else:
        log("Primeiro snapshot — sem comparação ainda")
        msg = (
            f"*Skills Trend Monitor* — Primeiro snapshot\n\n"
            f"Capturadas {len(current)} skills do skills.sh\n"
            f"Wolf tem {len(installed)} skills instaladas\n\n"
            f"A partir de amanhã, o relatório diário de tendências será enviado às 09h."
        )
        send_telegram(msg)

    # Save current snapshot
    SNAPSHOT_FILE.write_text(json.dumps(current, indent=2))
    log(f"Snapshot salvo: {len(current)} skills")

    # Append to history (keep last 30 days)
    history = []
    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text())
        except Exception:
            history = []
    history.append({
        "date": datetime.now().strftime("%Y-%m-%d"),
        "total_skills": len(current),
        "top_10": [{"name": s["name"], "installs": s["installs"]} for s in current[:10]],
    })
    # Keep last 30 entries
    history = history[-30:]
    HISTORY_FILE.write_text(json.dumps(history, indent=2))
    log("Histórico atualizado")
    log("=== Fim do monitoramento ===")


if __name__ == "__main__":
    main()
