#!/usr/bin/env python3
"""
Wolf Shorts Factory v5 — Pipeline Premium
Blur BG + Hook texto + Progress bar + Legendas com palavra destacada + SFX + Color grade
"""
import subprocess, sys, os, re, json, tempfile, struct, wave, math

FFMPEG  = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
FFPROBE = "/opt/homebrew/opt/ffmpeg-full/bin/ffprobe"
SOURCE  = sys.argv[1]
START   = int(sys.argv[2])
END     = int(sys.argv[3])
NAME    = sys.argv[4]
HOOK    = sys.argv[5] if len(sys.argv) > 5 else "ASSISTA ATÉ O FINAL 🔥"
SFX_T   = sys.argv[6] if len(sys.argv) > 6 else "impact"
OUT_DIR = os.path.expanduser("~/Desktop/wolf-shorts")
SFX_DIR = os.path.join(OUT_DIR, "sfx")
TMP     = tempfile.mkdtemp()
DUR     = END - START

def run(cmd, label=""):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ⚠️  {label}: {r.stderr[-200:]}")
    return r.returncode == 0

print(f"\n{'━'*45}")
print(f"🎬 Wolf Shorts v5 — {NAME}")
print(f"   Duração: {DUR}s | Hook: {HOOK}")
print(f"{'━'*45}\n")

# ── 1. CORTAR ────────────────────────────────────
print("✂️  [1/6] Cortando...")
run(f'{FFMPEG} -y -ss {START} -to {END} -i "{SOURCE}" -c:v libx264 -c:a aac -preset fast "{TMP}/raw.mp4"', "corte")

W = int(subprocess.check_output(f'{FFPROBE} -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 "{TMP}/raw.mp4"', shell=True).strip())
H = int(subprocess.check_output(f'{FFPROBE} -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 "{TMP}/raw.mp4"', shell=True).strip())
SCALE_H = int(H * 1080 / W)
OV_Y    = (1920 - SCALE_H) // 2
print(f"   Original: {W}x{H} → overlay: 1080x{SCALE_H} em Y={OV_Y}")

# ── 2. BLUR BG + COLOR GRADE ─────────────────────
print("📐 [2/6] Blur background + color grade...")
run(f'''{FFMPEG} -y -i "{TMP}/raw.mp4" -filter_complex \
"[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,\
eq=saturation=1.4:contrast=1.05,boxblur=30:6[bg];\
[0:v]scale=1080:{SCALE_H}[fg];\
[bg][fg]overlay=0:{OV_Y}[v];\
[0:a]acopy[a]" \
-map "[v]" -map "[a]" -c:v libx264 -c:a aac -preset fast "{TMP}/blurred.mp4"''', "blur")
print("   ✅ Blur + color grade OK")

# ── 3. TRANSCRIÇÃO COM WORD TIMESTAMPS ───────────
print("🎙️  [3/6] Transcrevendo com word timestamps...")
subprocess.run(
    f'whisper "{TMP}/raw.mp4" --model base --language Portuguese '
    f'--word_timestamps True --output_format json --output_dir "{TMP}/"',
    shell=True, capture_output=True
)
json_file = next((f for f in os.listdir(TMP) if f.endswith('.json')), None)

words_timed = []  # [(start, end, word)]
segments    = []  # [(start, end, text)]
if json_file:
    with open(f"{TMP}/{json_file}") as f:
        data = json.load(f)
    for seg in data.get("segments", []):
        segments.append((seg["start"], seg["end"], seg["text"].strip()))
        for w in seg.get("words", []):
            words_timed.append((w["start"], w["end"], w["word"].strip()))
    print(f"   ✅ {len(segments)} segmentos | {len(words_timed)} palavras com timestamp")

# ── 4. GERAR ASS COM PALAVRA DESTACADA ───────────
print("💬 [4/6] Gerando legendas com palavra destacada...")

def fmt_ts(s):
    h = int(s // 3600)
    m = int((s % 3600) // 60)
    sec = s % 60
    return f"{h}:{m:02d}:{sec:05.2f}"

ass_content = """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial Black,58,&H00FFFFFF,&H00000000,&H96000000,-1,0,0,0,100,100,0,0,1,4,2,2,40,40,220,1
Style: Highlight,Arial Black,58,&H0000FFFF,&H00000000,&H96000000,-1,0,0,0,100,100,0,0,1,4,2,2,40,40,220,1
Style: Hook,Arial Black,52,&H00FFFFFF,&H000000FF,&HBE000000,-1,0,0,0,100,100,0,0,1,3,2,8,60,60,80,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

events = []

# Hook texto (primeiros 3s)
events.append(f"Dialogue: 0,0:00:00.00,0:00:03.00,Hook,,0,0,0,,{HOOK}")

# Legendas com palavra destacada
# Agrupar palavras em linhas de máx 5 palavras
line_buf = []
for i, (ws, we, word) in enumerate(words_timed):
    line_buf.append((ws, we, word))
    # Fechar linha a cada 4-5 palavras ou quando pausa > 0.4s
    next_start = words_timed[i+1][0] if i+1 < len(words_timed) else we + 1
    is_last = (i == len(words_timed) - 1)
    gap = next_start - we

    if len(line_buf) >= 5 or gap > 0.4 or is_last:
        line_start = line_buf[0][0]
        line_end   = line_buf[-1][1]
        # Para cada palavra nessa linha, mostrar a linha com a palavra atual em destaque
        for j, (ws2, we2, w2) in enumerate(line_buf):
            parts = []
            for k, (_, _, wk) in enumerate(line_buf):
                clean = re.sub(r'[{}\\]', '', wk)
                if k == j:
                    parts.append(f"{{\\c&H00FFFF&}}{clean}{{\\c&HFFFFFF&}}")
                else:
                    parts.append(clean)
            line_text = " ".join(parts)
            events.append(
                f"Dialogue: 1,{fmt_ts(ws2)},{fmt_ts(we2)},Default,,0,0,0,,{line_text}"
            )
        line_buf = []

ass_content += "\n".join(events)

with open(f"{TMP}/subs.ass", "w") as f:
    f.write(ass_content)
print(f"   ✅ {len(events)} eventos ASS gerados (hook + legendas com highlight)")

# ── 5. QUEIMAR LEGENDAS + PROGRESS BAR ───────────
print("🔥 [5/6] Queimando legendas + progress bar + hook...")

FADE_OUT = DUR - 1
PROG_H   = 8   # altura da progress bar em pixels
PROG_Y   = 1920 - PROG_H - 5  # posição Y (rodapé)

run(f'''{FFMPEG} -y -i "{TMP}/blurred.mp4" -filter_complex \
"[0:v]ass={TMP}/subs.ass[subbed];\
[subbed]drawbox=x=0:y={PROG_Y}:w='iw*t/{DUR}':h={PROG_H}:color=0x00FFFF@0.9:t=fill[progd];\
[progd]fade=t=in:st=0:d=0.4,fade=t=out:st={FADE_OUT}:d=0.8[vout];\
[0:a]afade=t=in:st=0:d=0.4,afade=t=out:st={FADE_OUT}:d=0.8[aout]" \
-map "[vout]" -map "[aout]" \
-c:v libx264 -c:a aac -preset fast "{TMP}/rendered.mp4"''', "legendas+progbar")
print("   ✅ Legendas + progress bar OK")

# ── 6. SFX ───────────────────────────────────────
print(f"🔊 [6/6] Adicionando SFX ({SFX_T})...")
sfx_file = f"{SFX_DIR}/{SFX_T}.wav"
final    = f"{OUT_DIR}/{NAME}.mp4"

if os.path.exists(sfx_file):
    run(f'''{FFMPEG} -y -i "{TMP}/rendered.mp4" -i "{sfx_file}" -filter_complex \
"[1:a]adelay=400|400,volume=0.3[sfx];\
[0:a][sfx]amix=inputs=2:duration=first[aout]" \
-map "0:v" -map "[aout]" \
-c:v copy -c:a aac -preset fast "{final}"''', "sfx")
else:
    subprocess.run(f'cp "{TMP}/rendered.mp4" "{final}"', shell=True)

size = os.path.getsize(final) / 1024 / 1024
print(f"\n{'━'*45}")
print(f"✅ PRONTO: {NAME}.mp4")
print(f"   {size:.1f}MB | {DUR}s | 1080x1920 | blur+legendas+hook+progbar+sfx")
print(f"   📁 {final}")
print(f"{'━'*45}\n")

import shutil
shutil.rmtree(TMP, ignore_errors=True)
