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
import math
import os
import re
import subprocess
import sys
import time
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import requests

# ═══════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════

# Load .env (for CLI and LaunchAgent usage)
_env_path = os.path.expanduser("~/.openclaw/.env")
if os.path.exists(_env_path):
    with open(_env_path) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _, _v = _line.partition("=")
                _k, _v = _k.strip(), _v.strip().strip('"').strip("'")
                if _k and _k not in os.environ:
                    os.environ[_k] = _v

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

    channel_id = meta.get("channel_id", handle)

    # Enrich with YouTube API data if available
    channel_age_days = 0
    country = ""
    created_at = ""
    if YOUTUBE_API_KEY and channel_id:
        api_stats = youtube_api_channel_stats([channel_id])
        if channel_id in api_stats:
            s = api_stats[channel_id]
            channel_age_days = s.get("channel_age_days", 0)
            country = s.get("country", "")
            created_at = s.get("created_at", "")

    channel = {
        "id": channel_id,
        "handle": handle,
        "url": url,
        "name": meta.get("channel", handle),
        "type": channel_type,  # principal, concorrente, referencia, tendencia
        "nicho": nicho,
        "subscribers": meta.get("channel_follower_count", 0),
        "channel_age_days": channel_age_days,
        "country": country,
        "created_at": created_at,
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
            "yt-dlp", "--dump-json",
            "--playlist-items", f"1:{max_videos}",
            "--no-download", "--no-warnings", "--quiet",
            "--skip-download", "--ignore-errors",
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
                            "comment_count": data.get("comment_count", 0),
                            "thumbnail": data.get("thumbnail", ""),
                            "upload_date": data.get("upload_date", ""),
                            "description": (data.get("description", "") or "")[:500],
                            "tags": data.get("tags", [])[:30] if data.get("tags") else [],
                            "is_short": (data.get("duration", 0) or 0) < 62,
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
                "tags": data.get("tags", [])[:30] if data.get("tags") else [],
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
            "part": "statistics,snippet,contentDetails,brandingSettings",
            "id": ",".join(channel_ids[:50]),
            "key": YOUTUBE_API_KEY,
        }, timeout=15)
        r.raise_for_status()
        stats = {}
        for item in r.json().get("items", []):
            s = item.get("statistics", {})
            snippet = item.get("snippet", {})
            branding = item.get("brandingSettings", {}).get("channel", {})
            published_at = snippet.get("publishedAt", "")
            channel_age_days = 0
            if published_at:
                try:
                    created_dt = datetime.fromisoformat(published_at.replace("Z", "+00:00")).replace(tzinfo=None)
                    channel_age_days = (datetime.now() - created_dt).days
                except (ValueError, TypeError):
                    pass
            stats[item["id"]] = {
                "subscribers": int(s.get("subscriberCount", 0)),
                "total_views": int(s.get("viewCount", 0)),
                "video_count": int(s.get("videoCount", 0)),
                "created_at": published_at,
                "channel_age_days": channel_age_days,
                "country": branding.get("country", snippet.get("country", "")),
            }
        return stats
    except Exception as e:
        log(f"YouTube API stats erro: {e}", "WARN")
        return {}


# ═══════════════════════════════════════════════════════════════
# REVENUE ESTIMATION
# ═══════════════════════════════════════════════════════════════

CPM_BY_NICHE = {
    "historia": 3.0, "financas": 10.0, "ciencia": 4.5,
    "misterio": 4.0, "terror": 3.0, "tecnologia": 7.0,
    "motivacional": 5.0, "cultura pop": 2.5, "geral": 3.0,
}


def estimate_revenue(channel: dict, videos: list) -> dict:
    """Estima receita mensal baseada em CPM por nicho."""
    nicho = channel.get("nicho", "geral").lower()
    cpm = CPM_BY_NICHE.get(nicho, CPM_BY_NICHE["geral"])

    now = datetime.now()
    views_30d = 0
    for v in videos:
        upload = v.get("upload_date", "")
        if upload:
            try:
                dt = datetime.strptime(upload, "%Y%m%d")
                if (now - dt).days <= 30:
                    views_30d += v.get("view_count", 0)
            except ValueError:
                pass

    monthly_revenue_low = (views_30d / 1000) * cpm * 0.5
    monthly_revenue_high = (views_30d / 1000) * cpm * 1.5

    return {
        "nicho": nicho,
        "cpm": cpm,
        "views_30d": views_30d,
        "monthly_revenue_low": round(monthly_revenue_low, 2),
        "monthly_revenue_high": round(monthly_revenue_high, 2),
        "currency": "USD",
    }


# ═══════════════════════════════════════════════════════════════
# GRADE (Social Blade style)
# ═══════════════════════════════════════════════════════════════

def calculate_grade(score: float) -> str:
    """Retorna grade estilo Social Blade baseado no score 0-100."""
    if score >= 95:
        return "A+"
    elif score >= 85:
        return "A"
    elif score >= 80:
        return "A-"
    elif score >= 75:
        return "B+"
    elif score >= 65:
        return "B"
    elif score >= 55:
        return "B-"
    elif score >= 45:
        return "C+"
    elif score >= 35:
        return "C"
    elif score >= 25:
        return "C-"
    else:
        return "D"


# ═══════════════════════════════════════════════════════════════
# GROWTH PROJECTION
# ═══════════════════════════════════════════════════════════════

def project_growth(channel: dict) -> dict:
    """Projeta crescimento de subscribers baseado em snapshots historicos."""
    ch_dir = RADAR_DIR / "channels" / channel.get("id", "")
    hist_dir = ch_dir / "history"

    snapshots = []
    if hist_dir.exists():
        for f in sorted(hist_dir.glob("*.json")):
            try:
                with open(f) as fp:
                    snap = json.load(fp)
                snapshots.append({
                    "date": snap.get("date", f.stem),
                    "subscribers": snap.get("subscribers", 0),
                })
            except (json.JSONDecodeError, KeyError):
                continue

    current_subs = channel.get("subscribers", 0)

    if len(snapshots) < 2:
        return {
            "current_subscribers": current_subs,
            "daily_growth_rate": 0,
            "milestones": {},
            "note": "insuficiente — precisa de pelo menos 2 snapshots",
        }

    # Calculate daily growth rate from first to last snapshot
    first = snapshots[0]
    last = snapshots[-1]
    try:
        d1 = datetime.strptime(first["date"], "%Y-%m-%d")
        d2 = datetime.strptime(last["date"], "%Y-%m-%d")
        days_span = (d2 - d1).days
    except ValueError:
        days_span = 0

    if days_span <= 0 or last["subscribers"] <= first["subscribers"]:
        return {
            "current_subscribers": current_subs,
            "daily_growth_rate": 0,
            "milestones": {},
            "note": "sem crescimento detectado ou dados insuficientes",
        }

    daily_growth = (last["subscribers"] - first["subscribers"]) / days_span

    # Project milestones
    milestones_targets = [1000, 5000, 10000, 50000, 100000, 500000, 1000000]
    milestones = {}
    for target in milestones_targets:
        if target > current_subs and daily_growth > 0:
            days_to = math.ceil((target - current_subs) / daily_growth)
            eta = (datetime.now() + timedelta(days=days_to)).strftime("%Y-%m-%d")
            milestones[f"{target:,}"] = {"days": days_to, "eta": eta}

    return {
        "current_subscribers": current_subs,
        "daily_growth_rate": round(daily_growth, 1),
        "data_points": len(snapshots),
        "data_span_days": days_span,
        "milestones": milestones,
    }


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

    # 3. Engajamento (likes+comments/views ratio)
    total_likes = sum(v.get("like_count", 0) for v in videos)
    total_comments = sum(v.get("comment_count", 0) for v in videos)
    if total_views > 0:
        engagement = ((total_likes + total_comments) / total_views) * 100
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

    # 5. Consistencia (desvio padrao real dos intervalos entre uploads)
    upload_dates_sorted = []
    for v in videos:
        ud = v.get("upload_date", "")
        if ud:
            try:
                upload_dates_sorted.append(datetime.strptime(ud, "%Y%m%d"))
            except ValueError:
                pass
    upload_dates_sorted.sort()

    if len(upload_dates_sorted) >= 3:
        intervals = [(upload_dates_sorted[i+1] - upload_dates_sorted[i]).days
                      for i in range(len(upload_dates_sorted) - 1)]
        mean_interval = sum(intervals) / len(intervals)
        variance = sum((x - mean_interval) ** 2 for x in intervals) / len(intervals)
        std_dev = math.sqrt(variance)
        # Lower std_dev = more consistent. Score: 20 if std_dev=0, decreasing
        if mean_interval > 0:
            cv = std_dev / mean_interval  # coefficient of variation
            factors["consistencia"] = max(0, min(20, int(20 - cv * 15)))
        else:
            factors["consistencia"] = 15
    elif len(upload_dates_sorted) >= 1:
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

    # --- New computed metrics ---

    # Engagement rate (likes + comments / views)
    engagement_rate = ((total_likes + total_comments) / total_views * 100) if total_views > 0 else 0.0

    # Views per subscriber
    subs = channel.get("subscribers", 0)
    views_per_subscriber = (total_views / subs) if subs > 0 else 0.0

    # Shorts detection
    shorts_count = sum(1 for v in videos if v.get("is_short", (v.get("duration", 0) or 0) < 62))
    long_count = len(videos) - shorts_count
    shorts_ratio = (shorts_count / len(videos) * 100) if videos else 0.0

    # Upload pattern (day of week distribution)
    day_names = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    day_counter = Counter()
    for dt in upload_dates_sorted:
        day_counter[day_names[dt.weekday()]] += 1
    upload_pattern = {d: day_counter.get(d, 0) for d in day_names}

    # Channel age
    channel_age_days = channel.get("channel_age_days", 0)

    # Revenue estimate
    revenue = estimate_revenue(channel, videos)

    # Grade
    final_score = min(100, score)
    grade = calculate_grade(final_score)

    # Growth projection
    growth = project_growth(channel)

    return {
        "score": final_score,
        "grade": grade,
        "status": status,
        "factors": factors,
        "stats": {
            "total_views": total_views,
            "avg_views": int(avg_views),
            "recent_avg": int(recent_avg),
            "videos_30d": len(recent_videos),
            "freq_per_week": round(freq, 1),
            "engagement_rate": round(engagement_rate, 2),
            "views_per_subscriber": round(views_per_subscriber, 1),
            "shorts_ratio": round(shorts_ratio, 1),
            "shorts_count": shorts_count,
            "long_count": long_count,
            "upload_pattern": upload_pattern,
            "channel_age_days": channel_age_days,
        },
        "revenue_estimate": revenue,
        "growth_projection": growth,
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
            c["channel_age_days"] = s.get("channel_age_days", 0)
            c["country"] = s.get("country", "")

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

            # Enrich with API data (channel_age_days, country, created_at)
            if YOUTUBE_API_KEY and ch.get("id"):
                api_stats = youtube_api_channel_stats([ch["id"]])
                if ch["id"] in api_stats:
                    s = api_stats[ch["id"]]
                    ch["channel_age_days"] = s.get("channel_age_days", ch.get("channel_age_days", 0))
                    ch["country"] = s.get("country", ch.get("country", ""))
                    ch["created_at"] = s.get("created_at", ch.get("created_at", ""))

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
# SEO SCORE (per video)
# ═══════════════════════════════════════════════════════════════

# Emotional trigger words (pt-BR + en)
_SEO_TRIGGERS = {
    "incrível", "chocante", "revelado", "segredo", "verdade", "nunca", "jamais",
    "ninguém", "proibido", "escondido", "misterioso", "assustador", "impressionante",
    "surpreendente", "urgente", "agora", "finalmente", "descubra", "cuidado",
    "perigo", "shocking", "secret", "truth", "hidden", "forbidden", "revealed",
    "incredible", "amazing", "terrifying", "mysterious", "dangerous",
}


def calculate_seo_score(video: dict) -> dict:
    """Calcula SEO score 0-100 de um vídeo individual."""
    score = 0
    breakdown = {}

    title = video.get("title", "")
    description = video.get("description", "")
    tags = video.get("tags", []) or []
    thumbnail = video.get("thumbnail", "")
    views = video.get("view_count", 0)
    likes = video.get("like_count", 0)

    # 1. Title (0-20)
    title_score = 0
    tlen = len(title)
    if 40 <= tlen <= 65:
        title_score += 6  # ideal length
    elif 30 <= tlen <= 80:
        title_score += 3  # acceptable
    # Has numbers
    if any(c.isdigit() for c in title):
        title_score += 4
    # Emotional triggers
    title_lower = title.lower()
    trigger_count = sum(1 for t in _SEO_TRIGGERS if t in title_lower)
    title_score += min(5, trigger_count * 2)
    # Not all caps (YouTube penalizes)
    if title != title.upper():
        title_score += 2
    # Starts with keyword (first 5 words have substance)
    if tlen > 10:
        title_score += 3
    breakdown["titulo"] = min(20, title_score)
    score += breakdown["titulo"]

    # 2. Description (0-20)
    desc_score = 0
    desc_words = len(description.split()) if description else 0
    if desc_words >= 200:
        desc_score += 7
    elif desc_words >= 100:
        desc_score += 4
    elif desc_words >= 30:
        desc_score += 2
    # Has links
    if "http" in description:
        desc_score += 3
    # Has timestamps (00:00 pattern)
    if re.search(r'\d{1,2}:\d{2}', description):
        desc_score += 5
    # Has hashtags
    if "#" in description:
        desc_score += 2
    # Has keywords from title in description
    title_words = set(w.lower() for w in title.split() if len(w) > 3)
    desc_lower = description.lower()
    matching = sum(1 for w in title_words if w in desc_lower)
    desc_score += min(3, matching)
    breakdown["descricao"] = min(20, desc_score)
    score += breakdown["descricao"]

    # 3. Tags (0-20)
    tag_score = 0
    tag_count = len(tags)
    if 5 <= tag_count <= 15:
        tag_score += 8  # ideal range
    elif tag_count > 0:
        tag_score += 4
    # Tag relevance (tags matching title words)
    if tags:
        tags_lower = [t.lower() for t in tags]
        tag_match = sum(1 for w in title_words if any(w in t for t in tags_lower))
        tag_score += min(7, tag_match * 2)
    # Tag diversity (long-tail keywords)
    long_tags = sum(1 for t in tags if len(t.split()) >= 3)
    tag_score += min(5, long_tags)
    breakdown["tags"] = min(20, tag_score)
    score += breakdown["tags"]

    # 4. Thumbnail (0-20)
    thumb_score = 0
    if thumbnail:
        thumb_score += 10  # has thumbnail
        # High-res indicator (maxresdefault)
        if "maxres" in thumbnail or "hqdefault" in thumbnail:
            thumb_score += 5
        # Custom thumbnail (not auto-generated)
        if "custom" not in thumbnail.lower():
            thumb_score += 5
    breakdown["thumbnail"] = min(20, thumb_score)
    score += breakdown["thumbnail"]

    # 5. Engagement proxy (0-20)
    eng_score = 0
    if views > 0:
        ratio = (likes / views) * 100
        if ratio >= 5:
            eng_score += 10
        elif ratio >= 3:
            eng_score += 7
        elif ratio >= 1:
            eng_score += 4
        # View count thresholds
        if views >= 100000:
            eng_score += 10
        elif views >= 10000:
            eng_score += 7
        elif views >= 1000:
            eng_score += 4
        elif views >= 100:
            eng_score += 2
    breakdown["engajamento"] = min(20, eng_score)
    score += breakdown["engajamento"]

    final = min(100, score)
    return {
        "seo_score": final,
        "seo_grade": calculate_grade(final),
        "breakdown": breakdown,
    }


# ═══════════════════════════════════════════════════════════════
# OUTLIER DETECTION
# ═══════════════════════════════════════════════════════════════

def detect_outliers(videos: list, threshold: float = 3.0) -> list:
    """Detecta vídeos outlier (views > threshold x média do canal)."""
    if not videos:
        return []
    avg_views = sum(v.get("view_count", 0) for v in videos) / len(videos)
    if avg_views <= 0:
        return []

    outliers = []
    for v in videos:
        views = v.get("view_count", 0)
        ratio = views / avg_views
        if ratio >= threshold:
            outliers.append({
                "id": v.get("id", ""),
                "title": v.get("title", ""),
                "views": views,
                "outlier_score": round(ratio, 1),
                "avg_views": int(avg_views),
            })
    outliers.sort(key=lambda x: x["outlier_score"], reverse=True)
    return outliers


# ═══════════════════════════════════════════════════════════════
# BEST TIME TO POST
# ═══════════════════════════════════════════════════════════════

def best_posting_time(channels: list = None) -> dict:
    """Analisa horários de upload dos top performers e recomenda janelas ótimas."""
    if channels is None:
        channels = load_channels()

    day_names = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    day_labels = {"mon": "Segunda", "tue": "Terça", "wed": "Quarta", "thu": "Quinta",
                  "fri": "Sexta", "sat": "Sábado", "sun": "Domingo"}

    # Aggregate: day -> {count, total_views, avg_views}
    day_data = {d: {"count": 0, "total_views": 0} for d in day_names}
    hour_data = {h: {"count": 0, "total_views": 0} for h in range(24)}
    niche_data = {}  # nicho -> day -> {count, total_views}

    for ch in channels:
        ch_dir = RADAR_DIR / "channels" / ch.get("id", "")
        videos_path = ch_dir / "videos.json"
        if not videos_path.exists():
            continue
        with open(videos_path) as f:
            videos = json.load(f)

        nicho = ch.get("nicho", "geral")
        if nicho not in niche_data:
            niche_data[nicho] = {d: {"count": 0, "total_views": 0} for d in day_names}

        for v in videos:
            upload = v.get("upload_date", "")
            views = v.get("view_count", 0)
            if not upload:
                continue
            try:
                dt = datetime.strptime(upload, "%Y%m%d")
                day = day_names[dt.weekday()]
                day_data[day]["count"] += 1
                day_data[day]["total_views"] += views
                niche_data[nicho][day]["count"] += 1
                niche_data[nicho][day]["total_views"] += views
            except ValueError:
                pass

    # Calculate averages
    for d in day_names:
        c = day_data[d]["count"]
        day_data[d]["avg_views"] = int(day_data[d]["total_views"] / c) if c > 0 else 0

    for nicho in niche_data:
        for d in day_names:
            c = niche_data[nicho][d]["count"]
            niche_data[nicho][d]["avg_views"] = int(niche_data[nicho][d]["total_views"] / c) if c > 0 else 0

    # Best days overall (top 3 by avg views)
    ranked = sorted(day_names, key=lambda d: day_data[d]["avg_views"], reverse=True)
    best_days = [{"day": d, "label": day_labels[d], "avg_views": day_data[d]["avg_views"],
                  "uploads": day_data[d]["count"]} for d in ranked[:3]]

    # Best days per niche
    niche_best = {}
    for nicho, data in niche_data.items():
        ranked_n = sorted(day_names, key=lambda d: data[d]["avg_views"], reverse=True)
        niche_best[nicho] = [{"day": d, "label": day_labels[d],
                              "avg_views": data[d]["avg_views"]} for d in ranked_n[:3]]

    return {
        "heatmap": {d: {"count": day_data[d]["count"], "avg_views": day_data[d]["avg_views"]}
                    for d in day_names},
        "best_days": best_days,
        "niche_best": niche_best,
        "total_videos_analyzed": sum(day_data[d]["count"] for d in day_names),
    }


# ═══════════════════════════════════════════════════════════════
# TAG SUGGESTIONS
# ═══════════════════════════════════════════════════════════════

def suggest_tags(topic: str = None, nicho: str = None) -> dict:
    """Sugere tags baseado nos top performers do nicho."""
    channels = load_channels()
    all_tags = Counter()
    top_video_tags = Counter()  # tags de vídeos com muitas views

    for ch in channels:
        if nicho and ch.get("nicho", "").lower() != nicho.lower():
            continue
        ch_dir = RADAR_DIR / "channels" / ch.get("id", "")
        videos_path = ch_dir / "videos.json"
        if not videos_path.exists():
            continue
        with open(videos_path) as f:
            videos = json.load(f)

        avg_views = sum(v.get("view_count", 0) for v in videos) / max(len(videos), 1)

        for v in videos:
            tags = v.get("tags", []) or []
            # Filter by topic if given
            if topic:
                title = v.get("title", "").lower()
                if topic.lower() not in title:
                    continue
            for t in tags:
                all_tags[t.lower()] += 1
                if v.get("view_count", 0) > avg_views * 1.5:
                    top_video_tags[t.lower()] += 1

    # Most common tags overall
    common = [{"tag": t, "count": c} for t, c in all_tags.most_common(30)]
    # Tags from top-performing videos
    top_tags = [{"tag": t, "count": c} for t, c in top_video_tags.most_common(20)]
    # Rising tags (appear in top videos more than average)
    rising = []
    for t, c in top_video_tags.most_common(50):
        total = all_tags.get(t, 1)
        ratio = c / total
        if ratio > 0.5 and c >= 2:
            rising.append({"tag": t, "top_ratio": round(ratio, 2), "top_count": c, "total_count": total})
    rising.sort(key=lambda x: x["top_ratio"], reverse=True)

    return {
        "common_tags": common,
        "top_performer_tags": top_tags,
        "rising_tags": rising[:15],
        "total_tags_analyzed": sum(all_tags.values()),
        "filter": {"topic": topic, "nicho": nicho},
    }


# ═══════════════════════════════════════════════════════════════
# KEYWORD RESEARCH
# ═══════════════════════════════════════════════════════════════

def keyword_research(keyword: str) -> dict:
    """Pesquisa keyword no YouTube via yt-dlp search, analisa competição e demanda."""
    log(f"Keyword research: '{keyword}'")

    # Search YouTube for top results
    videos = []
    try:
        cmd = [
            "yt-dlp", "--dump-json",
            "--playlist-items", "1:50",
            "--no-download", "--no-warnings", "--quiet",
            "--skip-download", "--ignore-errors",
            f"ytsearch50:{keyword}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                if line.strip():
                    try:
                        data = json.loads(line)
                        videos.append({
                            "id": data.get("id", ""),
                            "title": data.get("title", ""),
                            "channel": data.get("uploader", ""),
                            "channel_id": data.get("channel_id", ""),
                            "view_count": data.get("view_count", 0),
                            "like_count": data.get("like_count", 0),
                            "comment_count": data.get("comment_count", 0),
                            "duration": data.get("duration", 0),
                            "upload_date": data.get("upload_date", ""),
                            "tags": data.get("tags", [])[:30] if data.get("tags") else [],
                            "description": (data.get("description", "") or "")[:300],
                            "thumbnail": data.get("thumbnail", ""),
                            "is_short": (data.get("duration", 0) or 0) < 62,
                        })
                    except json.JSONDecodeError:
                        continue
    except Exception as e:
        log(f"Keyword research erro: {e}", "WARN")

    if not videos:
        return {"keyword": keyword, "error": "Nenhum resultado encontrado"}

    # Competition metrics
    total_results = len(videos)
    total_views = sum(v["view_count"] for v in videos)
    avg_views = total_views / total_results
    top10_avg = sum(v["view_count"] for v in videos[:10]) / min(10, len(videos))
    max_views = max(v["view_count"] for v in videos) if videos else 0

    # Demand score (0-100): based on avg views of top 10
    if top10_avg >= 1000000:
        demand = 100
    elif top10_avg >= 100000:
        demand = 80 + (top10_avg - 100000) / 900000 * 20
    elif top10_avg >= 10000:
        demand = 50 + (top10_avg - 10000) / 90000 * 30
    elif top10_avg >= 1000:
        demand = 20 + (top10_avg - 1000) / 9000 * 30
    else:
        demand = max(1, top10_avg / 1000 * 20)

    # Competition score (0-100): how hard to rank
    # Based on: avg subscriber count of top channels, video quality
    channels_seen = set()
    for v in videos[:20]:
        channels_seen.add(v.get("channel_id", ""))
    competition = min(100, len(channels_seen) * 5)  # more unique channels = more competition

    # Overall score (higher = better opportunity)
    opportunity_score = max(0, min(100, int(demand - competition * 0.5 + 25)))

    # Related keywords from tags
    all_tags = Counter()
    for v in videos:
        for t in (v.get("tags") or []):
            t_low = t.lower().strip()
            if t_low and t_low != keyword.lower():
                all_tags[t_low] += 1
    related = [{"keyword": t, "frequency": c} for t, c in all_tags.most_common(20)]

    # Top channels in this keyword
    ch_counter = Counter()
    ch_views = {}
    for v in videos:
        ch = v.get("channel", "unknown")
        ch_counter[ch] += 1
        ch_views[ch] = ch_views.get(ch, 0) + v["view_count"]
    top_channels = [{"name": ch, "videos": c, "total_views": ch_views[ch]}
                    for ch, c in ch_counter.most_common(10)]

    # Recent vs old content
    now = datetime.now()
    recent_count = 0
    for v in videos:
        try:
            dt = datetime.strptime(v.get("upload_date", ""), "%Y%m%d")
            if (now - dt).days <= 90:
                recent_count += 1
        except ValueError:
            pass
    freshness = round(recent_count / total_results * 100, 1) if total_results > 0 else 0

    research = {
        "keyword": keyword,
        "total_results": total_results,
        "demand_score": round(demand),
        "competition_score": round(competition),
        "opportunity_score": opportunity_score,
        "avg_views": int(avg_views),
        "top10_avg_views": int(top10_avg),
        "max_views": max_views,
        "freshness_pct": freshness,
        "related_keywords": related,
        "top_channels": top_channels,
        "top_videos": [{
            "title": v["title"], "channel": v["channel"],
            "views": v["view_count"], "duration": v["duration"],
            "upload_date": v["upload_date"], "thumbnail": v["thumbnail"],
        } for v in videos[:10]],
        "researched_at": datetime.now().isoformat(),
    }

    # Save to disk
    kw_dir = RADAR_DIR / "keywords"
    kw_dir.mkdir(parents=True, exist_ok=True)
    safe_name = re.sub(r'[^\w\s-]', '', keyword).strip().replace(' ', '-')[:50]
    with open(kw_dir / f"{safe_name}.json", "w") as f:
        json.dump(research, f, indent=2, ensure_ascii=False)

    log(f"Keyword research: '{keyword}' → demand={round(demand)} competition={round(competition)} opportunity={opportunity_score}")
    return research


def list_keyword_research() -> list:
    """Lista todas as pesquisas de keyword salvas."""
    kw_dir = RADAR_DIR / "keywords"
    if not kw_dir.exists():
        return []
    results = []
    for f in sorted(kw_dir.glob("*.json"), key=lambda x: x.stat().st_mtime, reverse=True):
        with open(f) as fh:
            data = json.load(fh)
            results.append({
                "keyword": data.get("keyword", ""),
                "demand_score": data.get("demand_score", 0),
                "competition_score": data.get("competition_score", 0),
                "opportunity_score": data.get("opportunity_score", 0),
                "avg_views": data.get("avg_views", 0),
                "researched_at": data.get("researched_at", ""),
            })
    return results


# ═══════════════════════════════════════════════════════════════
# TITLE/DESCRIPTION GENERATOR
# ═══════════════════════════════════════════════════════════════

def generate_seo_content(topic: str, nicho: str = "geral", style: str = "dark") -> dict:
    """Gera títulos, descrição e tags otimizados para SEO usando Gemini ou análise estatística."""

    # Collect reference data from top performers
    channels = load_channels()
    ref_titles = []
    ref_tags = Counter()
    for ch in channels:
        if nicho != "geral" and ch.get("nicho", "").lower() != nicho.lower():
            continue
        ch_dir = RADAR_DIR / "channels" / ch.get("id", "")
        vp = ch_dir / "videos.json"
        if not vp.exists():
            continue
        with open(vp) as f:
            videos = json.load(f)
        top_vids = sorted(videos, key=lambda v: v.get("view_count", 0), reverse=True)[:5]
        for v in top_vids:
            ref_titles.append(v.get("title", ""))
            for t in (v.get("tags") or []):
                ref_tags[t.lower()] += 1

    # Try Gemini first
    prompt = f"""Você é um especialista em SEO para YouTube, especializado em canais dark/faceless.

Tema do vídeo: "{topic}"
Nicho: {nicho}
Estilo: {style}

Títulos de referência (top performers do nicho):
{chr(10).join(f'- {t}' for t in ref_titles[:10])}

Gere exatamente este JSON (sem markdown, sem ```):
{{
  "titles": ["titulo1", "titulo2", "titulo3", "titulo4", "titulo5"],
  "description": "descricao SEO completa com 200+ palavras, timestamps placeholder, hashtags",
  "tags": ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "tag8", "tag9", "tag10", "tag11", "tag12", "tag13", "tag14", "tag15"]
}}

Regras:
- Títulos: 40-65 caracteres, gatilhos emocionais (curiosidade, urgência, revelação, números, superlativos)
- Descrição: inclua keywords, timestamps (00:00), links placeholder, hashtags
- Tags: mix de short-tail e long-tail, relevantes ao tema e nicho"""

    gemini_result = gemini_call(prompt, max_tokens=2000)
    if gemini_result:
        try:
            # Clean markdown code blocks if present
            cleaned = gemini_result.strip()
            if cleaned.startswith("```"):
                cleaned = re.sub(r'^```\w*\n?', '', cleaned)
                cleaned = re.sub(r'\n?```$', '', cleaned)
            data = json.loads(cleaned)
            data["source"] = "gemini"
            data["topic"] = topic
            data["nicho"] = nicho
            return data
        except (json.JSONDecodeError, KeyError):
            log("Gemini retornou JSON invalido, usando fallback estatístico", "WARN")

    # Fallback: statistical generation
    trigger_words = ["Revelado", "A Verdade Sobre", "O Segredo de", "Ninguém Conta Sobre",
                     "O Que Aconteceu com", "A História Proibida de", "Por Que", "Como"]
    titles = []
    for i, trigger in enumerate(trigger_words[:5]):
        title = f"{trigger} {topic}"
        if len(title) > 65:
            title = title[:62] + "..."
        titles.append(title)

    top_tags = [t for t, _ in ref_tags.most_common(15)]
    if len(top_tags) < 15:
        # Pad with generated tags
        base_words = topic.lower().split()
        for w in base_words:
            if w not in top_tags:
                top_tags.append(w)
        top_tags.append(nicho)
        top_tags.append(f"{nicho} {topic.split()[0]}" if topic.split() else nicho)

    return {
        "titles": titles[:5],
        "description": f"{topic} — um mergulho profundo no universo de {nicho}.\n\n⏱️ Timestamps:\n00:00 Introdução\n01:00 Contexto\n03:00 Desenvolvimento\n07:00 Revelação\n10:00 Conclusão\n\n🔔 Inscreva-se e ative o sino!\n\n#{'#'.join(topic.split()[:3])} #{nicho}",
        "tags": top_tags[:15],
        "source": "statistical",
        "topic": topic,
        "nicho": nicho,
    }


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

    p = sub.add_parser("keyword", help="Keyword research")
    p.add_argument("kw", help="Keyword to research")

    sub.add_parser("keywords", help="Listar keyword research salvas")

    p = sub.add_parser("seo", help="SEO score de videos de um canal")
    p.add_argument("handle")

    sub.add_parser("best-time", help="Melhor horario para postar")

    p = sub.add_parser("tags", help="Sugerir tags")
    p.add_argument("--topic", default=None)
    p.add_argument("--nicho", default=None)

    p = sub.add_parser("generate", help="Gerar titulo/descricao SEO")
    p.add_argument("topic", help="Tema do video")
    p.add_argument("--nicho", default="geral")

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

    elif args.cmd == "keyword":
        result = keyword_research(args.kw)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "keywords":
        for kw in list_keyword_research():
            print(f"  [{kw['opportunity_score']:>3}] {kw['keyword']:30s} demand={kw['demand_score']} comp={kw['competition_score']} avg={kw['avg_views']:,}")

    elif args.cmd == "seo":
        channels = load_channels()
        ch = next((c for c in channels if c.get("handle") == args.handle), None)
        if not ch:
            print(f"Canal @{args.handle} nao encontrado"); sys.exit(1)
        ch_dir = RADAR_DIR / "channels" / ch["id"]
        vp = ch_dir / "videos.json"
        if vp.exists():
            with open(vp) as f:
                videos = json.load(f)
            for v in videos[:10]:
                seo = calculate_seo_score(v)
                print(f"  [{seo['seo_score']:>3}] {seo['seo_grade']:3s} {v['title'][:60]}")
        else:
            print("Sem videos. Rode: radar-engine.py collect")

    elif args.cmd == "best-time":
        result = best_posting_time()
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "tags":
        result = suggest_tags(args.topic, args.nicho)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "generate":
        result = generate_seo_content(args.topic, args.nicho)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.cmd == "health":
        print("=== Dark Radar Health ===")
        print(f"  Dir: {RADAR_DIR}")
        print(f"  YouTube API: {'configurada' if YOUTUBE_API_KEY else 'NAO CONFIGURADA'}")
        print(f"  Gemini API: {'configurada' if GEMINI_API_KEY else 'NAO CONFIGURADA'}")
        channels = load_channels()
        print(f"  Canais: {len(channels)}")
        yt_dlp = subprocess.run(["which", "yt-dlp"], capture_output=True)
        print(f"  yt-dlp: {'instalado' if yt_dlp.returncode == 0 else 'NAO INSTALADO'}")
        print(f"  Metricas por video: 12 (id, title, url, duration, view_count, like_count, comment_count, thumbnail, upload_date, description, tags[30], is_short)")
        print(f"  Metricas por canal: 15 (score, grade, status, engagement_rate, views_per_subscriber, shorts_ratio, shorts_count, long_count, upload_pattern, channel_age_days, revenue_estimate, growth_projection, consistencia_stddev, country, created_at)")
        print(f"  Nichos CPM: {len(CPM_BY_NICHE)} ({', '.join(CPM_BY_NICHE.keys())})")


if __name__ == "__main__":
    main()
