#!/usr/bin/env python3
"""
Wolf Shorts Factory v2 — Fundo desfocado + legendas queimadas
Uso: python3 make_short_v2.py <source.mp4> <start_sec> <end_sec> <output.mp4> [srt_file]
"""

import sys, subprocess, os, re, tempfile

SOURCE   = sys.argv[1]
START    = float(sys.argv[2])
END      = float(sys.argv[3])
OUTPUT   = sys.argv[4]
SRT_FILE = sys.argv[5] if len(sys.argv) > 5 else None

TMP = tempfile.mkdtemp()
RAW   = f"{TMP}/raw.mp4"
FINAL = OUTPUT

def run(cmd, label=""):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"❌ {label}: {r.stderr[-300:]}")
        return False
    return True

print(f"✂️  Cortando {START:.0f}s → {END:.0f}s...")
run(f'ffmpeg -y -ss {START} -to {END} -i "{SOURCE}" -c:v libx264 -c:a aac -preset fast "{RAW}"', "corte")

# Verificar dimensões originais
result = subprocess.run(
    f'ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "{RAW}"',
    shell=True, capture_output=True, text=True
)
dims = result.stdout.strip().split(',')
W, H = int(dims[0]), int(dims[1])
print(f"   Original: {W}x{H}")

# Duração
result = subprocess.run(
    f'ffprobe -v quiet -show_entries format=duration -of csv=p=0 "{RAW}"',
    shell=True, capture_output=True, text=True
)
DUR = float(result.stdout.strip())
FADE_OUT = max(0, DUR - 1.0)

print("📐 Convertendo para 9:16 com fundo desfocado...")

# TARGET: 1080x1920
TW, TH = 1080, 1920

# Calcular escala do vídeo overlay (fit width = 1080, height proporcional)
scale_w = TW
scale_h = int(H * TW / W)

# Posição vertical centralizada
overlay_y = (TH - scale_h) // 2

BLUR_CMD = (
    f'ffmpeg -y -i "{RAW}" -filter_complex '
    f'"[0:v]scale={TW}:{TH}:force_original_aspect_ratio=increase,'
    f'crop={TW}:{TH},boxblur=20:20[bg];'
    f'[0:v]scale={scale_w}:{scale_h}[fg];'
    f'[bg][fg]overlay=0:{overlay_y},'
    f'fade=t=in:st=0:d=0.4,fade=t=out:st={FADE_OUT:.1f}:d=0.8[v];'
    f'[0:a]afade=t=in:st=0:d=0.4,afade=t=out:st={FADE_OUT:.1f}:d=0.8[a]" '
    f'-map "[v]" -map "[a]" '
    f'-c:v libx264 -c:a aac -preset fast "{FINAL}"'
)

if not run(BLUR_CMD, "blur+overlay"):
    print("⚠️  Tentando fallback simples...")
    SIMPLE = (
        f'ffmpeg -y -i "{RAW}" '
        f'-vf "crop=ih*9/16:ih,scale={TW}:{TH},'
        f'fade=t=in:st=0:d=0.4,fade=t=out:st={FADE_OUT:.1f}:d=0.8" '
        f'-af "afade=t=in:st=0:d=0.4,afade=t=out:st={FADE_OUT:.1f}:d=0.8" '
        f'-c:v libx264 -c:a aac -preset fast "{FINAL}"'
    )
    run(SIMPLE, "fallback")

# Legendas via drawtext se SRT disponível
if SRT_FILE and os.path.exists(SRT_FILE):
    print("💬 Adicionando legendas via drawtext...")
    
    # Parse SRT
    with open(SRT_FILE) as f:
        content = f.read()

    def ts_to_sec(ts):
        ts = ts.replace(',', '.')
        h, m, s = ts.split(':')
        return int(h)*3600 + int(m)*60 + float(s)

    blocks = re.split(r'\n\n+', content.strip())
    subtitles = []
    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) < 3:
            continue
        m = re.match(r'(\S+) --> (\S+)', lines[1])
        if m:
            s_in  = ts_to_sec(m.group(1))
            s_out = ts_to_sec(m.group(2))
            text  = ' '.join(lines[2:]).strip()
            text  = re.sub(r'<[^>]+>', '', text)
            text  = text.replace("'", "\\'").replace(':', '\\:')
            subtitles.append((s_in, s_out, text))

    # Gerar filtro drawtext encadeado
    WITH_SUBS = f"{TMP}/with_subs.mp4"
    drawtext_filters = []
    for s_in, s_out, text in subtitles:
        f = (
            f"drawtext=text='{text}'"
            f":fontsize=52:fontcolor=white:borderw=3:bordercolor=black"
            f":x=(w-text_w)/2:y=h-200"
            f":font='Arial Black'"
            f":enable='between(t,{s_in:.2f},{s_out:.2f})'"
        )
        drawtext_filters.append(f)

    vf = ",".join(drawtext_filters)
    SUBS_CMD = f'ffmpeg -y -i "{FINAL}" -vf "{vf}" -c:v libx264 -c:a copy -preset fast "{WITH_SUBS}"'
    
    if run(SUBS_CMD, "drawtext"):
        os.replace(WITH_SUBS, FINAL)
        print("✅ Legendas queimadas!")
    else:
        print("⚠️  Legendas falharam, mantendo sem legenda")

size_mb = os.path.getsize(FINAL) / 1024 / 1024
print(f"\n✅ PRONTO: {OUTPUT}")
print(f"   Tamanho: {size_mb:.1f}MB | Formato: 1080x1920 | {DUR:.0f}s")

# Limpeza
import shutil
shutil.rmtree(TMP, ignore_errors=True)
