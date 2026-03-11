#!/usr/bin/env python3
"""
Intro Generator — Video Editor Pro
Wolf Agency

Gera intros animadas usando Python + Pillow + FFmpeg
Fallback quando Remotion não disponível
"""

import os
import sys
import argparse
from PIL import Image, ImageDraw, ImageFont
import subprocess

# Configurações padrão
DEFAULT_WIDTH = 1920
DEFAULT_HEIGHT = 1080
DEFAULT_FPS = 30
DEFAULT_DURATION = 5

# Cores Wolf
COLORS = {
    'bg': (10, 10, 15),
    'text': (255, 255, 255),
    'cyan': (0, 212, 255),
    'orange': (255, 107, 53),
    'grid': (0, 100, 120),
}

# Estilos predefinidos
STYLES = {
    'tech': {
        'bg_color': (10, 10, 15),
        'accent_color': (0, 212, 255),
        'grid': True,
        'scan_line': True,
        'corners': True,
    },
    'clean': {
        'bg_color': (245, 245, 245),
        'accent_color': (0, 0, 0),
        'grid': False,
        'scan_line': False,
        'corners': False,
    },
    'bold': {
        'bg_color': (0, 0, 0),
        'accent_color': (255, 107, 53),
        'grid': False,
        'scan_line': False,
        'corners': True,
    },
}

def get_font(size):
    """Tenta carregar fonte do sistema, fallback para default"""
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except:
                pass
    
    return ImageFont.load_default()

def create_frame(frame_num, total_frames, text, subtext, style_config, width, height):
    """Cria um único frame da animação"""
    
    # Cria imagem base
    img = Image.new('RGB', (width, height), style_config['bg_color'])
    draw = ImageDraw.Draw(img)
    
    # Progresso da animação (0.0 a 1.0)
    t = frame_num / total_frames
    
    # Fontes
    font_large = get_font(80)
    font_small = get_font(24)
    
    # Efeito de fade in
    if frame_num < total_frames * 0.2:
        alpha = frame_num / (total_frames * 0.2)
    else:
        alpha = 1.0
    
    # Grid de fundo (se habilitado)
    if style_config.get('grid', False):
        for i in range(0, width, 50):
            draw.line([(i, 0), (i, height)], fill=COLORS['grid'], width=1)
        for i in range(0, height, 50):
            draw.line([(0, i), (width, i)], fill=COLORS['grid'], width=1)
    
    # Texto principal
    bbox = draw.textbbox((0, 0), text, font=font_large)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) // 2
    y = (height - text_height) // 2 - 30
    
    # Efeito de glow
    if style_config.get('accent_color'):
        glow = int(20 + 10 * abs((frame_num % 60) - 30) / 30)
        for offset in range(glow, 0, -4):
            intensity = int(100 * alpha * (offset / glow))
            r = max(0, style_config['accent_color'][0] - offset)
            g = max(0, style_config['accent_color'][1] - offset)
            b = max(0, style_config['accent_color'][2] - offset)
            draw.text((x + offset//4, y + offset//4), text, font=font_large, fill=(r, g, b))
    
    # Texto principal
    main_color = (int(255*alpha), int(255*alpha), int(255*alpha))
    draw.text((x, y), text, font=font_large, fill=main_color)
    
    # Subtexto (aparece depois de 1s)
    if subtext and frame_num > total_frames * 0.2:
        sub_alpha = min(1.0, (frame_num - total_frames * 0.2) / (total_frames * 0.1))
        bbox_sub = draw.textbbox((0, 0), subtext, font=font_small)
        text_width_sub = bbox_sub[2] - bbox_sub[0]
        x_sub = (width - text_width_sub) // 2
        y_sub = y + text_height + 30
        
        sub_color = (
            int(style_config['accent_color'][0] * sub_alpha),
            int(style_config['accent_color'][1] * sub_alpha),
            int(style_config['accent_color'][2] * sub_alpha)
        )
        draw.text((x_sub, y_sub), subtext, font=font_small, fill=sub_color)
    
    # Linha de scan (se habilitado)
    if style_config.get('scan_line', False):
        scan_y = 200 + (frame_num * 6) % (height - 400)
        draw.line([(0, scan_y), (width, scan_y)], fill=style_config['accent_color'], width=2)
    
    # Cantos tecnológicos (se habilitado)
    if style_config.get('corners', False):
        corner_size = 40
        corner_color = style_config['accent_color']
        delay = total_frames * 0.03
        
        corners = [
            (30, 30, delay * 1.5),  # top-left
            (width - 30 - corner_size, 30, delay * 1.7),  # top-right
            (30, height - 30, delay * 1.9),  # bottom-left
            (width - 30 - corner_size, height - 30, delay * 2.1),  # bottom-right
        ]
        
        for cx, cy, d in corners:
            if frame_num > d:
                # Horizontal
                draw.line([(cx, cy), (cx + corner_size, cy)], fill=corner_color, width=2)
                # Vertical
                draw.line([(cx, cy), (cx, cy + corner_size)], fill=corner_color, width=2)
    
    return img

def generate_intro(text, subtext, style, duration, fps, width, height, output_path):
    """Gera a intro completa"""
    
    total_frames = int(duration * fps)
    style_config = STYLES.get(style, STYLES['tech'])
    
    # Cria diretório temporário para frames
    frames_dir = "/tmp/intro_frames"
    os.makedirs(frames_dir, exist_ok=True)
    
    print(f"Gerando {total_frames} frames...")
    
    # Gera frames
    for i in range(total_frames):
        frame = create_frame(i, total_frames, text, subtext, style_config, width, height)
        frame_path = os.path.join(frames_dir, f"frame_{i:04d}.png")
        frame.save(frame_path)
        
        if i % 30 == 0:
            print(f"  Frame {i}/{total_frames}")
    
    print(f"✅ Frames gerados")
    
    # Compila com FFmpeg
    print("Compilando vídeo...")
    cmd = [
        "ffmpeg", "-y",
        "-framerate", str(fps),
        "-i", os.path.join(frames_dir, "frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-movflags", "+faststart",
        output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Erro no FFmpeg: {result.stderr}")
        return False
    
    # Limpa frames temporários
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))
    os.rmdir(frames_dir)
    
    print(f"✅ Vídeo salvo: {output_path}")
    return True

def main():
    parser = argparse.ArgumentParser(description="Gera intros animadas")
    parser.add_argument("--text", "-t", required=True, help="Texto principal")
    parser.add_argument("--subtext", "-s", default="", help="Subtexto")
    parser.add_argument("--style", choices=list(STYLES.keys()), default="tech", help="Estilo visual")
    parser.add_argument("--duration", "-d", type=int, default=5, help="Duração em segundos")
    parser.add_argument("--fps", type=int, default=30, help="Frames por segundo")
    parser.add_argument("--width", "-w", type=int, default=1920, help="Largura")
    parser.add_argument("--height", type=int, default=1080, help="Altura")
    parser.add_argument("--output", "-o", default="intro.mp4", help="Caminho de saída")
    
    args = parser.parse_args()
    
    success = generate_intro(
        text=args.text,
        subtext=args.subtext,
        style=args.style,
        duration=args.duration,
        fps=args.fps,
        width=args.width,
        height=args.height,
        output_path=args.output
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
