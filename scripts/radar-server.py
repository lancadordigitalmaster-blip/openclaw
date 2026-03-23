#!/usr/bin/env python3
"""
Dark Radar API Server — Serve dados pro dashboard.
Roda em localhost:8898 ao lado do DarkFactory (8899).
"""

import json
import os
import sys
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Load .env if available (for LaunchAgent which doesn't source shell profile)
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

# Lazy import do engine pra evitar circular
engine = None
def get_engine():
    global engine
    if engine is None:
        import importlib.util
        spec = importlib.util.spec_from_file_location("radar_engine",
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "radar-engine.py"))
        engine = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(engine)
    return engine

RADAR_DIR = Path(os.getenv("RADAR_DIR", os.path.expanduser("~/.openclaw/workspace/radar")))
PORT = int(os.getenv("RADAR_PORT", "8898"))


class RadarHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Silencia logs HTTP

    def _json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False, default=str).encode())

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length:
            return json.loads(self.rfile.read(length))
        return {}

    def do_OPTIONS(self):
        self._json({})

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)

        # GET /api/radar/channels — lista todos os canais com scores
        if path == "/api/radar/channels":
            eng = get_engine()
            channels = eng.load_channels()
            # Enriquece com scores e stats
            for ch in channels:
                ch_dir = RADAR_DIR / "channels" / ch.get("id", "")
                score_path = ch_dir / "score.json"
                if score_path.exists():
                    with open(score_path) as f:
                        score_data = json.load(f)
                    ch["score"] = score_data.get("score", 0)
                    ch["status"] = score_data.get("status", "?")
                    ch["stats"] = score_data.get("stats", {})
                    ch["factors"] = score_data.get("factors", {})
            return self._json({"ok": True, "channels": channels})

        # GET /api/radar/channel?id=X — detalhes de um canal
        if path == "/api/radar/channel":
            ch_id = params.get("id", [None])[0]
            if not ch_id:
                return self._json({"ok": False, "error": "id required"}, 400)

            eng = get_engine()
            channels = eng.load_channels()
            ch = next((c for c in channels if c.get("id") == ch_id or c.get("handle") == ch_id), None)
            if not ch:
                return self._json({"ok": False, "error": "canal nao encontrado"}, 404)

            ch_dir = RADAR_DIR / "channels" / ch["id"]
            result = {"ok": True, "channel": ch}

            # Videos
            videos_path = ch_dir / "videos.json"
            if videos_path.exists():
                with open(videos_path) as f:
                    result["videos"] = json.load(f)

            # Analysis
            analysis_path = ch_dir / "analysis.json"
            if analysis_path.exists():
                with open(analysis_path) as f:
                    result["analysis"] = json.load(f)

            # Score
            score_path = ch_dir / "score.json"
            if score_path.exists():
                with open(score_path) as f:
                    result["score"] = json.load(f)

            # History
            hist_dir = ch_dir / "history"
            if hist_dir.exists():
                history = []
                for fp in sorted(hist_dir.glob("*.json"))[-30:]:
                    with open(fp) as f:
                        history.append(json.load(f))
                result["history"] = history

            return self._json(result)

        # GET /api/radar/metrics — visao geral do mercado
        if path == "/api/radar/metrics":
            eng = get_engine()
            channels = eng.load_channels()
            total = len(channels)
            scaling = sum(1 for c in channels if c.get("status") == "escalando")
            declining = sum(1 for c in channels if c.get("status") == "declinio")
            total_views = sum(c.get("stats", {}).get("total_views", 0) for c in channels)

            # Discovery count
            disc_path = RADAR_DIR / "discovery" / "candidates.json"
            discovery_count = 0
            if disc_path.exists():
                with open(disc_path) as f:
                    discovery_count = len(json.load(f))

            return self._json({
                "ok": True,
                "metrics": {
                    "total_channels": total,
                    "scaling": scaling,
                    "declining": declining,
                    "discovery_count": discovery_count,
                    "total_views_market": total_views,
                    "last_updated": datetime.now().isoformat(),
                }
            })

        # GET /api/radar/insights — insights IA
        if path == "/api/radar/insights":
            insights_path = RADAR_DIR / "market" / "insights.json"
            if insights_path.exists():
                with open(insights_path) as f:
                    return self._json({"ok": True, **json.load(f)})
            return self._json({"ok": True, "insights": [], "message": "nenhum insight gerado ainda"})

        # GET /api/radar/trends — temas em alta
        if path == "/api/radar/trends":
            insights_path = RADAR_DIR / "market" / "insights.json"
            if insights_path.exists():
                with open(insights_path) as f:
                    data = json.load(f)
                return self._json({"ok": True, "trends": data.get("trending_topics", [])})
            return self._json({"ok": True, "trends": []})

        # GET /api/radar/suggestions — sugestoes de videos
        if path == "/api/radar/suggestions":
            insights_path = RADAR_DIR / "market" / "insights.json"
            if insights_path.exists():
                with open(insights_path) as f:
                    data = json.load(f)
                return self._json({"ok": True, "suggestions": data.get("suggestions", [])})
            return self._json({"ok": True, "suggestions": []})

        # GET /api/radar/discovery — canais novos detectados
        if path == "/api/radar/discovery":
            disc_path = RADAR_DIR / "discovery" / "candidates.json"
            if disc_path.exists():
                with open(disc_path) as f:
                    return self._json({"ok": True, "candidates": json.load(f)})
            return self._json({"ok": True, "candidates": []})

        # GET /api/radar/briefing — briefing semanal
        if path == "/api/radar/briefing":
            week = params.get("week", [datetime.now().strftime("%Y-W%W")])[0]
            bp = RADAR_DIR / "market" / "briefings" / f"{week}.json"
            if bp.exists():
                with open(bp) as f:
                    return self._json({"ok": True, "week": week, **json.load(f)})
            return self._json({"ok": True, "week": week, "message": "briefing nao encontrado"})

        # GET /api/radar/health
        if path == "/api/radar/health":
            eng = get_engine()
            channels = eng.load_channels()
            return self._json({
                "ok": True,
                "status": "online",
                "channels": len(channels),
                "youtube_api": bool(os.getenv("YOUTUBE_API_KEY") or os.getenv("GOOGLE_API_KEY")),
                "gemini_api": bool(os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")),
                "radar_dir": str(RADAR_DIR),
            })

        self._json({"ok": False, "error": "rota nao encontrada"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        body = self._read_body()

        # POST /api/radar/channels — adicionar canal
        if path == "/api/radar/channels":
            url = body.get("url", "")
            ch_type = body.get("type", "concorrente")
            nicho = body.get("nicho", "geral")
            if not url:
                return self._json({"ok": False, "error": "url required"}, 400)
            eng = get_engine()
            result = eng.add_channel(url, ch_type, nicho)
            return self._json(result)

        # POST /api/radar/collect — disparar coleta manual
        if path == "/api/radar/collect":
            import threading
            eng = get_engine()
            t = threading.Thread(target=eng.collect_all, daemon=True)
            t.start()
            return self._json({"ok": True, "message": "coleta iniciada em background"})

        # POST /api/radar/analyze — disparar analise manual
        if path == "/api/radar/analyze":
            import threading
            eng = get_engine()
            t = threading.Thread(target=eng.analyze_all, daemon=True)
            t.start()
            return self._json({"ok": True, "message": "analise iniciada em background"})

        # POST /api/radar/cycle — ciclo completo
        if path == "/api/radar/cycle":
            import threading
            eng = get_engine()
            t = threading.Thread(target=eng.full_cycle, daemon=True)
            t.start()
            return self._json({"ok": True, "message": "ciclo completo iniciado"})

        # POST /api/radar/strategy — gerar estrategia
        if path == "/api/radar/strategy":
            eng = get_engine()
            topic = body.get("topic", None)
            result = eng.generate_strategy(topic)
            return self._json({"ok": True, **result})

        # POST /api/radar/analyze-channel — analisar canal especifico
        if path == "/api/radar/analyze-channel":
            ch_id = body.get("id", "")
            if not ch_id:
                return self._json({"ok": False, "error": "id required"}, 400)
            eng = get_engine()
            channels = eng.load_channels()
            ch = next((c for c in channels if c.get("id") == ch_id or c.get("handle") == ch_id), None)
            if not ch:
                return self._json({"ok": False, "error": "canal nao encontrado"}, 404)
            result = eng.analyze_channel(ch)
            return self._json({"ok": True, **result})

        # POST /api/radar/discovery — rodar discovery
        if path == "/api/radar/discovery":
            eng = get_engine()
            result = eng.run_discovery()
            return self._json({"ok": True, "candidates": result})

        self._json({"ok": False, "error": "rota nao encontrada"}, 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)

        # DELETE /api/radar/channels?handle=X
        if path == "/api/radar/channels":
            handle = params.get("handle", [None])[0]
            if not handle:
                return self._json({"ok": False, "error": "handle required"}, 400)
            eng = get_engine()
            result = eng.remove_channel(handle)
            return self._json(result)

        self._json({"ok": False, "error": "rota nao encontrada"}, 404)


def main():
    server = HTTPServer(("0.0.0.0", PORT), RadarHandler)
    print(f"Dark Radar API server rodando em http://localhost:{PORT}")
    print(f"Radar dir: {RADAR_DIR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado")
        server.server_close()


if __name__ == "__main__":
    main()
