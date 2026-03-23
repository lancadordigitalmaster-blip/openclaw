#!/usr/bin/env python3
"""
Dark Radar Engine — Coleta, análise e inteligência de mercado dark channels.
Integrado ao ecossistema OpenClaw/Alfred + DarkFactory.

Componentes:
  - Collector: puxa dados via yt-dlp (sem API key) + YouTube Data API (com key)
  - Scorer: calcula health score 0-100 por canal
  - Analyzer: Gemini analisa patterns, títulos, oportunidades
  - Discovery: encontra canais dark novos automaticamente
  - InsightGen: gera briefing semanal com IA
"""

import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import requests

# ═══════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════

RADAR_DIR = Path(os.getenv("RADAR_DIR", os.path.expanduser("~/.openclaw/workspace/radar")))
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY", os.getenv("GOOGLE_API_KEY", ""))
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", os.getenv("GOOGLE_API_KEY", ""))
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

# Cria estrutura de pastas
for d in ["channels", "market", "market/briefings", "discovery"]:
    (RADAR_DIR / d).mkdir(parents=True, exist_ok=True)


def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [radar] [{level}] {msg}", flush=True)


# ═══════════════════════════════════════════════════════════════
# CHANNEL REGISTRY
# ═══════════════════════════════════════════════════════════════

def channels_path() -> Path:
    return RADAR_DIR / "channels.json"


def load_channels() -> list:
    p = channels_path()
    if p.exists():
        with open(p) as f:
            return json.load(f)
    return []


def save_channels(channels: list):
    with open(channels_path(), "w") as f:
        json.dump(channels, f, indent=2, ensure_ascii=False)


def add_channel(url: str, channel_type: str = "concorrente", nicho: str = "geral") -> dict:
    """Adiciona canal ao registry. Faz coleta inicial."""
    channels = load_channels()

    # Extrai handle/id da URL
    handle = extract_handle(url)
    if not handle:
        return {"ok": False, "error": "URL invalida"}

    # Checa duplicata
    if any(c.get("handle") == handle for c in channels):
        return {"ok": False, "error": "Canal ja monitorado"}

    # Coleta inicial via yt-dlp
    meta = collect_channel_meta(url)
    if not meta:
        return {"ok": False, "error": "Nao conseguiu coletar dados do canal"}

    channel = {
        "id": meta.get("channel_id", handle),
        "handle": handle,
        "url": url,
        "name": meta.get("channel", handle),
        "type": channel_type,  # principal, concorrente, referencia, tendencia
        "nicho": nicho,
        "subscribers": meta.get("channel_follower_count", 0),
        "added_at": datetime.now().isoformat(),
        "last_collected": None,
        "last_analyzed": None,
    }

    channels.append(channel)
    save_channels(channels)

    # Coleta videos iniciais
    collect_channel_videos(channel)

    log(f"Canal adicionado: {channel['name']} ({handle})")
    return {"ok": True, "channel": channel}


def remove_channel(handle: str) -> dict:
    channels = load_channels()
    channels = [c for c in channels if c.get("handle") != handle]
    save_channels(channels)
    return {"ok": True}


def extract_handle(url: str) -> Optional[str]:
    """Extrai handle (@user) ou channel ID de uma URL do YouTube."""
    patterns = [
        r"youtube\.com/@([^/?\s]+)",
        r"youtube\.com/channel/([^/?\s]+)",
        r"youtube\.com/c/([^/?\s]+)",
        r"youtube\.com/user/([^/?\s]+)",
    ]
    for p in patterns:
        m = re.search(p, url)
        if m:
            return m.group(1)
    # Se é só um handle
    if url.startswith("@"):
        return url[1:]
    return None


# ═══════════════════════════════════════════════════════════════
# COLLECTOR — yt-dlp (sem API key necessária)
# ═══════════════════════════════════════════════════════════════

def collect_channel_meta(url: str) -> Optional[dict]:
    """Coleta metadata do canal via yt-dlp."""
    try:
        cmd = [
            "yt-dlp", "--dump-json", "--playlist-items", "1",
            "--no-download", "--no-warnings", "--quiet",
            url
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout.strip().split("\n")[0])
            return data
    except Exception as e:
        log(f"yt-dlp meta erro: {e}", "WARN")
    return None


def collect_channel_videos(channel: dict, max_videos: int = 30) -> list:
    """Coleta últimos N vídeos do canal via yt-dlp."""
    url = channel.get("url", f"https://www.youtube.com/@{channel['handle']}")
    videos = []

    try:
        cmd = [
            "yt-dlp", "--dump-json", "--flat-playlist",
            "--playlist-items", f"1:{max_videos}",
            "--no-download", "--no-warnings", "--quiet",
            f"{url}/videos"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                if line.strip():
                    try:
                        data = json.loads(line)
                        video = {
                            "id": data.get("id", ""),
                            "title": data.get("title", ""),
                            "url": data.get("url", f"https://www.youtube.com/watch?v={data.get('id', '')}"),
                            "duration": data.get("duration", 0),
                            "view_count": data.get("view_count", 0),
                            "like_count": data.get("like_count", 0),
                            "upload_date": data.get("upload_date", ""),
                            "description": (data.get("description", "") or "")[:500],
                            "tags": data.get("tags", [])[:10] if data.get("tags") else [],
                            "collected_at": datetime.now().isoformat(),
                        }
                        videos.append(video)
                    except json.JSONDecodeError:
                        continue

    except Exception as e:
        log(f"yt-dlp videos erro ({channel.get('name', '?')}): {e}", "WARN")

    # Coleta detalhada dos top 10 (com mais metadados)
    for v in videos[:10]:
        if v["view_count"] == 0:
            detail = collect_video_detail(v["id"])
            if detail:
                v.update(detail)

    # Salva
    ch_dir = RADAR_DIR / "channels" / channel["id"]
    ch_dir.mkdir(parents=True, exist_ok=True)
    with open(ch_dir / "videos.json", "w") as f:
        json.dump(videos, f, indent=2, ensure_ascii=False)

    # Snapshot histórico
    hist_dir = ch_dir / "history"
    hist_dir.mkdir(exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    with open(hist_dir / f"{today}.json", "w") as f:
        json.dump({
            "date": today,
            "subscribers": channel.get("subscribers", 0),
            "video_count": len(videos),
            "total_views": sum(v.get("view_count", 0) for v in videos),
        }, f, indent=2)

    log(f"Coletados {len(videos)} videos de {channel.get('name', '?')}")
    return videos


def collect_video_detail(video_id: str) -> Optional[dict]:
    """Coleta detalhes de um vídeo específico."""
    try:
        cmd = [
            "yt-dlp", "--dump-json", "--no-download",
            "--no-warnings", "--quiet",
            f"https://www.youtube.com/watch?v={video_id}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout.strip())
            return {
                "view_count": data.get("view_count", 0),
                "like_count": data.get("like_count", 0),
                "comment_count": data.get("comment_count", 0),
                "duration": data.get("duration", 0),
                "tags": data.get("tags", [])[:10] if data.get("tags") else [],
                "categories": data.get("categories", []),
            }
    except Exception:
        pass
    return None


# ═══════════════════════════════════════════════════════════════
# YOUTUBE DATA API (opcional, enriquece dados)
# ═══════════════════════════════════════════════════════════════

def youtube_api_search(query: str, max_results: int = 10) -> list:
    """Busca canais no YouTube via Data API v3."""
    if not YOUTUBE_API_KEY:
        log("YouTube API key nao configurada — Discovery limitado ao yt-dlp", "WARN")
        return []

    try:
        r = requests.get("https://www.googleapis.com/youtube/v3/search", params={
            "part": "snippet",
            "q": query,
            "type": "channel",
            "maxResults": max_results,
            "key": YOUTUBE_API_KEY,
        }, timeout=15)
        r.raise_for_status()
        results = []
        for item in r.json().get("items", []):
            results.append({
                "channel_id": item["snippet"]["channelId"],
                "name": item["snippet"]["channelTitle"],
                "description": item["snippet"].get("description", ""),
                "url": f"https://www.youtube.com/channel/{item['snippet']['channelId']}",
            })
        return results
    except Exception as e:
        log(f"YouTube API search erro: {e}", "WARN")
        return []


def youtube_api_channel_stats(channel_ids: list) -> dict:
    """Busca stats de canais via YouTube Data API v3."""
    if not YOUTUBE_API_KEY or not channel_ids:
        return {}

    try:
        r = requests.get("https://www.googleapis.com/youtube/v3/channels", params={
            "part": "statistics,snippet,contentDetails",
            "id": ",".join(channel_ids[:50]),
            "key": YOUTUBE_API_KEY,
        }, timeout=15)
        r.raise_for_status()
        stats = {}
        for item in r.json().get("items", []):
            s = item.get("statistics", {})
            stats[item["id"]] = {
                "subscribers": int(s.get("subscriberCount", 0)),
                "total_views": int(s.get("viewCount", 0)),
                "video_count": int(s.get("videoCount", 0)),
                "created_at": item.get("snippet", {}).get("publishedAt", ""),
            }
        return stats
    except Exception as e:
        log(f"YouTube API stats erro: {e}", "WARN")
        return {}


# ═══════════════════════════════════════════════════════════════
# SCORER — calcula health score 0-100
# ═══════════════════════════════════════════════════════════════

def calculate_score(channel: dict, videos: list) -> dict:
    """Calcula health score do canal baseado em múltiplos fatores."""
    if not videos:
        return {"score": 0, "status": "sem_dados", "factors": {}}

    now = datetime.now()
    recent_videos = []
    for v in videos:
        upload = v.get("upload_date", "")
        if upload:
            try:
                dt = datetime.strptime(upload, "%Y%m%d")
                days_ago = (now - dt).days
                if days_ago <= 30:
                    recent_videos.append({**v, "_days_ago": days_ago})
            except ValueError:
                pass

    total_views = sum(v.get("view_count", 0) for v in videos)
    avg_views = total_views / max(len(videos), 1)

    recent_views = sum(v.get("view_count", 0) for v in recent_videos) if recent_videos else 0
    recent_avg = recent_views / max(len(recent_videos), 1)

    # Fatores (cada um 0-20, total max 100)
    factors = {}

    # 1. Crescimento (views recentes vs historico)
    if avg_views > 0 and recent_avg > 0:
        growth_ratio = recent_avg / avg_views
        factors["crescimento"] = min(20, int(growth_ratio * 10))
    else:
        factors["crescimento"] = 0

    # 2. Frequencia (videos por semana nos ultimos 30 dias)
    freq = len(recent_videos) / 4.3 if recent_videos else 0
    factors["frequencia"] = min(20, int(freq * 5))

    # 3. Engajamento (likes/views ratio)
    total_likes = sum(v.get("like_count", 0) for v in videos)
    if total_views > 0:
        engagement = (total_likes / total_views) * 100
        factors["engajamento"] = min(20, int(engagement * 5))
    else:
        factors["engajamento"] = 0

    # 4. Momentum (ultimos 7d vs 30d)
    week_videos = [v for v in recent_videos if v.get("_days_ago", 99) <= 7]
    month_videos = [v for v in recent_videos if v.get("_days_ago", 99) <= 30]
    if month_videos:
        week_avg = sum(v.get("view_count", 0) for v in week_videos) / max(len(week_videos), 1)
        month_avg = sum(v.get("view_count", 0) for v in month_videos) / max(len(month_videos), 1)
        if month_avg > 0:
            momentum = week_avg / month_avg
            factors["momentum"] = min(20, int(momentum * 10))
        else:
            factors["momentum"] = 5
    else:
        factors["momentum"] = 0

    # 5. Consistencia (desvio padrao da frequencia)
    if len(recent_videos) >= 3:
        factors["consistencia"] = 15  # tem pelo menos 3 videos no mes
    elif len(recent_videos) >= 1:
        factors["consistencia"] = 8
    else:
        factors["consistencia"] = 0

    score = sum(factors.values())

    # Status baseado no score + tendencia
    if score >= 85:
        status = "escalando"
    elif score >= 65:
        status = "estavel"
    elif score >= 40:
        status = "atencao"
    else:
        status = "declinio"

    # Override: canal novo (< 90 dias) com crescimento alto
    subs = channel.get("subscribers", 0)
    if subs < 10000 and factors.get("crescimento", 0) >= 15:
        status = "novo_promissor"

    # Override: viral (1 video com 5x a media)
    if recent_videos:
        max_views = max(v.get("view_count", 0) for v in recent_videos)
        if recent_avg > 0 and max_views > recent_avg * 5:
            status = "viral"

    return {
        "score": min(100, score),
        "status": status,
        "factors": factors,
        "stats": {
            "total_views": total_views,
            "avg_views": int(avg_views),
            "recent_avg": int(recent_avg),
            "videos_30d": len(recent_videos),
            "freq_per_week": round(freq, 1),
        }
    }


# ═══════════════════════════════════════════════════════════════
# ANALYZER — Gemini analisa patterns
# ═══════════════════════════════════════════════════════════════

def gemini_call(prompt: str, max_tokens: int = 2000) -> Optional[str]:
    """Chama Gemini API."""
    if not GEMINI_API_KEY:
        log("Gemini API key nao configurada", "WARN")
        return None

    try:
        r = requests.post(
            f"{GEMINI_URL}?key={GEMINI_API_KEY}",
            json={
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"maxOutputTokens": max_tokens, "temperature": 0.3},
            },
            timeout=60,
        )
        r.raise_for_status()
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as e:
        log(f"Gemini erro: {e}", "WARN")
        return None


def analyze_channel(channel: dict) -> dict:
    """Analisa um canal com Gemini e retorna insights."""
    ch_dir = RADAR_DIR / "channels" / channel["id"]
    videos_path = ch_dir / "videos.json"
    if not videos_path.exists():
        return {"error": "sem videos coletados"}

    with open(videos_path) as f:
        videos = json.load(f)

    # Prepara contexto
    video_list = ""
    for v in videos[:20]:
        views = v.get("view_count", 0)
        dur = v.get("duration", 0)
        dur_min = f"{dur // 60}min" if dur else "?"
        video_list += f"- \"{v.get('title', '?')}\" | {views:,} views | {dur_min}\n"

    prompt = f"""Analise este canal dark (faceless) do YouTube e retorne APENAS JSON valido:

Canal: {channel.get('name', '?')}
Nicho: {channel.get('nicho', '?')}
Subscribers: {channel.get('subscribers', 0):,}

Ultimos {len(videos[:20])} videos:
{video_list}

Retorne JSON com esta estrutura exata:
{{
  "title_patterns": ["pattern 1", "pattern 2", "pattern 3"],
  "best_format": "descricao do formato que mais funciona",
  "ideal_duration": "faixa de duracao ideal em minutos",
  "content_themes": ["tema 1", "tema 2", "tema 3"],
  "strengths": ["ponto forte 1", "ponto forte 2"],
  "weaknesses": ["ponto fraco 1", "ponto fraco 2"],
  "opportunities": ["oportunidade 1", "oportunidade 2"],
  "title_formula": "formula de titulo que mais performa neste canal",
  "frequency_recommendation": "frequencia ideal de publicacao",
  "summary": "resumo de 2-3 frases sobre o canal"
}}

Responda SOMENTE com o JSON, sem markdown, sem explicacao."""

    raw = gemini_call(prompt)
    if not raw:
        return {"error": "gemini indisponivel"}

    try:
        # Limpa possíveis backticks
        clean = raw.strip()
        if clean.startswith("```"):
            clean = re.sub(r"```json?\n?", "", clean)
            clean = clean.rstrip("`").strip()
        analysis = json.loads(clean)
    except json.JSONDecodeError:
        analysis = {"raw_response": raw[:500], "error": "parse_failed"}

    analysis["analyzed_at"] = datetime.now().isoformat()

    # Salva
    with open(ch_dir / "analysis.json", "w") as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)

    log(f"Analise concluida: {channel.get('name', '?')}")
    return analysis


# ═══════════════════════════════════════════════════════════════
# DISCOVERY — encontra canais dark novos
# ═══════════════════════════════════════════════════════════════

DISCOVERY_QUERIES = [
    "canal dark historia brasil",
    "canal dark misterio faceless",
    "canal dark ciencia universo",
    "canal dark financas investimento",
    "canal dark curiosidades fatos",
    "canal dark terror horror",
    "canal dark motivacional mindset",
    "dark channel faceless portuguese",
    "canal youtube sem aparecer historia",
    "canal narrado sem rosto youtube",
]


def run_discovery() -> list:
    """Busca canais dark novos e pontua os mais promissores."""
    log("Discovery: iniciando busca...")
    candidates = []
    monitored_ids = {c.get("id") for c in load_channels()}

    for query in DISCOVERY_QUERIES:
        results = youtube_api_search(query, max_results=5)
        for r in results:
            if r["channel_id"] not in monitored_ids:
                candidates.append({
                    **r,
                    "query": query,
                    "discovered_at": datetime.now().isoformat(),
                })
        time.sleep(1)  # Rate limiting

    # Deduplica
    seen = set()
    unique = []
    for c in candidates:
        if c["channel_id"] not in seen:
            seen.add(c["channel_id"])
            unique.append(c)

    # Enriquece com stats
    if unique:
        ids = [c["channel_id"] for c in unique]
        stats = youtube_api_channel_stats(ids)
        for c in unique:
            s = stats.get(c["channel_id"], {})
            c["subscribers"] = s.get("subscribers", 0)
            c["total_views"] = s.get("total_views", 0)
            c["video_count"] = s.get("video_count", 0)
            c["created_at"] = s.get("created_at", "")

    # Filtra: canais com pelo menos 5 videos e < 500k subs (provavelmente dark)
    filtered = [
        c for c in unique
        if c.get("video_count", 0) >= 5 and c.get("subscribers", 0) < 500000
    ]

    # Salva
    with open(RADAR_DIR / "discovery" / "candidates.json", "w") as f:
        json.dump(filtered, f, indent=2, ensure_ascii=False)

    log(f"Discovery: {len(filtered)} candidatos encontrados")
    return filtered


# ═══════════════════════════════════════════════════════════════
# INSIGHT GENERATOR — briefing semanal com IA
# ═══════════════════════════════════════════════════════════════

def generate_market_insights() -> dict:
    """Gera insights de mercado baseado em todos os canais monitorados."""
    channels = load_channels()
    all_data = []

    for ch in channels:
        ch_dir = RADAR_DIR / "channels" / ch["id"]
        videos_path = ch_dir / "videos.json"
        if videos_path.exists():
            with open(videos_path) as f:
                videos = json.load(f)
            score_data = calculate_score(ch, videos)
            all_data.append({
                "name": ch.get("name", "?"),
                "type": ch.get("type", "?"),
                "nicho": ch.get("nicho", "?"),
                "score": score_data["score"],
                "status": score_data["status"],
                "stats": score_data["stats"],
                "top_videos": [
                    {"title": v.get("title", ""), "views": v.get("view_count", 0)}
                    for v in sorted(videos, key=lambda x: x.get("view_count", 0), reverse=True)[:5]
                ]
            })

    if not all_data:
        return {"error": "sem dados para gerar insights"}

    context = json.dumps(all_data, ensure_ascii=False, indent=1)

    prompt = f"""Voce e um analista de mercado de canais dark (faceless) no YouTube.
Baseado nos dados abaixo, gere um briefing de inteligencia.

Dados dos canais monitorados:
{context[:4000]}

Retorne APENAS JSON valido com esta estrutura:
{{
  "market_summary": "resumo do mercado em 2-3 frases",
  "insights": [
    {{"type": "trend|opportunity|alert|benchmark", "title": "titulo curto", "text": "descricao detalhada", "priority": "alta|media|baixa"}},
  ],
  "trending_topics": [
    {{"topic": "nome do tema", "video_count": N, "avg_views": N, "heat": 1-5}}
  ],
  "suggestions": [
    {{"title": "titulo do video sugerido", "reason": "por que fazer este video", "score": 0-100, "based_on": "dados que suportam"}}
  ],
  "weekly_stats": {{
    "total_channels": N,
    "scaling_channels": N,
    "total_views_market": N,
    "top_performer": "nome do canal",
    "biggest_growth": "nome do canal"
  }}
}}

Responda SOMENTE com o JSON."""

    raw = gemini_call(prompt, max_tokens=3000)
    if not raw:
        return {"error": "gemini indisponivel"}

    try:
        clean = raw.strip()
        if clean.startswith("```"):
            clean = re.sub(r"```json?\n?", "", clean)
            clean = clean.rstrip("`").strip()
        insights = json.loads(clean)
    except json.JSONDecodeError:
        insights = {"raw_response": raw[:500], "error": "parse_failed"}

    insights["generated_at"] = datetime.now().isoformat()

    # Salva
    with open(RADAR_DIR / "market" / "insights.json", "w") as f:
        json.dump(insights, f, indent=2, ensure_ascii=False)

    # Salva briefing semanal
    week = datetime.now().strftime("%Y-W%W")
    with open(RADAR_DIR / "market" / "briefings" / f"{week}.json", "w") as f:
        json.dump(insights, f, indent=2, ensure_ascii=False)

    log("Insights de mercado gerados")
    return insights


def generate_strategy(topic: str = None) -> dict:
    """Gera estratégia baseada nos dados do radar."""
    channels = load_channels()
    market_path = RADAR_DIR / "market" / "insights.json"

    context_parts = []
    for ch in channels[:10]:
        ch_dir = RADAR_DIR / "channels" / ch["id"]
        analysis_path = ch_dir / "analysis.json"
        if analysis_path.exists():
            with open(analysis_path) as f:
                analysis = json.load(f)
            context_parts.append(f"Canal: {ch.get('name', '?')}\nAnalise: {json.dumps(analysis, ensure_ascii=False)[:500]}")

    market_context = ""
    if market_path.exists():
        with open(market_path) as f:
            market_context = json.dumps(json.load(f), ensure_ascii=False)[:2000]

    topic_filter = f"\nFoco especifico: {topic}" if topic else ""

    prompt = f"""Voce e um estrategista de canais dark YouTube.
Baseado nos dados de mercado e analise de canais, sugira estrategias.

Canais analisados:
{chr(10).join(context_parts[:5])}

Mercado:
{market_context[:2000]}
{topic_filter}

Retorne APENAS JSON valido:
{{
  "new_channel_ideas": [
    {{"nicho": "X", "sub_nicho": "Y", "reason": "por que", "potential_views_month": N, "competition": "baixa|media|alta", "difficulty": "facil|medio|dificil"}}
  ],
  "content_ideas": [
    {{"title": "titulo do video", "nicho": "X", "format": "tipo", "estimated_views": N, "reason": "por que vai funcionar"}}
  ],
  "optimization_tips": [
    {{"area": "titulos|thumbnails|duracao|frequencia|nicho", "tip": "dica", "based_on": "dado que suporta"}}
  ]
}}

Responda SOMENTE com o JSON."""

    raw = gemini_call(prompt, max_tokens=2500)
    if not raw:
        return {"error": "gemini indisponivel"}

    try:
        clean = raw.strip()
        if clean.startswith("```"):
            clean = re.sub(r"```json?\n?", "", clean)
            clean = clean.rstrip("`").strip()
        strategy = json.loads(clean)
    except json.JSONDecodeError:
        strategy = {"raw_response": raw[:500], "error": "parse_failed"}

    strategy["generated_at"] = datetime.now().isoformat()
    return strategy


# ═══════════════════════════════════════════════════════════════
# COLLECT ALL — ciclo completo de coleta
# ═══════════════════════════════════════════════════════════════

def collect_all():
    """Roda coleta de todos os canais monitorados."""
    channels = load_channels()
    log(f"Coleta iniciada: {len(channels)} canais")

    for ch in channels:
        try:
            # Atualiza meta
            meta = collect_channel_meta(ch.get("url", ""))
            if meta:
                ch["subscribers"] = meta.get("channel_follower_count", ch.get("subscribers", 0))
                ch["name"] = meta.get("channel", ch.get("name", ""))

            # Coleta videos
            collect_channel_videos(ch)

            # Calcula score
            ch_dir = RADAR_DIR / "channels" / ch["id"]
            videos_path = ch_dir / "videos.json"
            if videos_path.exists():
                with open(videos_path) as f:
                    videos = json.load(f)
                score_data = calculate_score(ch, videos)
                ch["score"] = score_data["score"]
                ch["status"] = score_data["status"]
                ch["stats"] = score_data["stats"]

                # Salva score
                with open(ch_dir / "score.json", "w") as f:
                    json.dump(score_data, f, indent=2)

            ch["last_collected"] = datetime.now().isoformat()
            time.sleep(3)  # Rate limiting entre canais

        except Exception as e:
            log(f"Erro ao coletar {ch.get('name', '?')}: {e}", "ERROR")

    save_channels(channels)
    log("Coleta completa")


def analyze_all():
    """Roda análise IA de todos os canais."""
    channels = load_channels()
    log(f"Analise iniciada: {len(channels)} canais")

    for ch in channels:
        try:
            analyze_channel(ch)
            ch["last_analyzed"] = datetime.now().isoformat()
            time.sleep(5)  # Rate limiting Gemini
        except Exception as e:
            log(f"Erro ao analisar {ch.get('name', '?')}: {e}", "ERROR")

    save_channels(channels)
    generate_market_insights()
    log("Analise completa")


def full_cycle():
    """Ciclo completo: coleta + analise + insights + discovery."""
    log("=== CICLO COMPLETO INICIADO ===")
    collect_all()
    analyze_all()
    if YOUTUBE_API_KEY:
        run_discovery()
    log("=== CICLO COMPLETO FINALIZADO ===")


# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Dark Radar Engine")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("add", help="Adicionar canal")
    p.add_argument("url")
    p.add_argument("--type", default="concorrente", choices=["principal", "concorrente", "referencia", "tendencia"])
    p.add_argument("--nicho", default="geral")

    sub.add_parser("list", help="Listar canais monitorados")

    p = sub.add_parser("remove", help="Remover canal")
    p.add_argument("handle")

    sub.add_parser("collect", help="Coletar dados de todos os canais")
    sub.add_parser("analyze", help="Rodar analise IA de todos os canais")
    sub.add_parser("cycle", help="Ciclo completo (coleta + analise + discovery)")
    sub.add_parser("insights", help="Gerar insights de mercado")
    sub.add_parser("discovery", help="Descobrir canais novos")

    p = sub.add_parser("strategy", help="Gerar estrategia")
    p.add_argument("--topic", default=None)

    p = sub.add_parser("score", help="Ver score de um canal")
    p.add_argument("handle")

    sub.add_parser("health", help="Health check")

    args = parser.parse_args()

    if args.cmd == "add":
        result = add_channel(args.url, args.type, args.nicho)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "list":
        for ch in load_channels():
            score = ch.get("score", "?")
            status = ch.get("status", "?")
            print(f"  [{score:>3}] {ch.get('name', '?'):30s} @{ch.get('handle', '?'):20s} {status:12s} {ch.get('type', '?')}")

    elif args.cmd == "remove":
        print(json.dumps(remove_channel(args.handle), indent=2))

    elif args.cmd == "collect":
        collect_all()

    elif args.cmd == "analyze":
        analyze_all()

    elif args.cmd == "cycle":
        full_cycle()

    elif args.cmd == "insights":
        result = generate_market_insights()
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "discovery":
        result = run_discovery()
        print(f"{len(result)} canais encontrados")
        for c in result[:10]:
            print(f"  {c.get('name', '?'):30s} {c.get('subscribers', 0):>8,} subs  {c.get('video_count', 0):>4} videos")

    elif args.cmd == "strategy":
        result = generate_strategy(args.topic)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "score":
        channels = load_channels()
        ch = next((c for c in channels if c.get("handle") == args.handle), None)
        if not ch:
            print(f"Canal @{args.handle} nao encontrado")
            sys.exit(1)
        ch_dir = RADAR_DIR / "channels" / ch["id"]
        videos_path = ch_dir / "videos.json"
        if videos_path.exists():
            with open(videos_path) as f:
                videos = json.load(f)
            result = calculate_score(ch, videos)
            print(json.dumps(result, indent=2))
        else:
            print("Sem videos coletados. Rode: radar-engine.py collect")

    elif args.cmd == "health":
        print("=== Dark Radar Health ===")
        print(f"  Dir: {RADAR_DIR}")
        print(f"  YouTube API: {'configurada' if YOUTUBE_API_KEY else 'NAO CONFIGURADA'}")
        print(f"  Gemini API: {'configurada' if GEMINI_API_KEY else 'NAO CONFIGURADA'}")
        channels = load_channels()
        print(f"  Canais: {len(channels)}")
        yt_dlp = subprocess.run(["which", "yt-dlp"], capture_output=True)
        print(f"  yt-dlp: {'instalado' if yt_dlp.returncode == 0 else 'NAO INSTALADO'}")


if __name__ == "__main__":
    main()
