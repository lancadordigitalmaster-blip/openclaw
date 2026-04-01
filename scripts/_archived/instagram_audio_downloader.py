#!/usr/bin/env python3
"""
Instagram Audio Downloader
Baixa o áudio de vídeos do Instagram

Uso:
    python instagram_audio_downloader.py <URL_DO_POST>
    
Exemplo:
    python instagram_audio_downloader.py "https://www.instagram.com/reel/ABC123XYZ"
"""

import sys
import os
import re
import subprocess
from pathlib import Path
from urllib.parse import urlparse

def check_yt_dlp():
    """Verifica se yt-dlp está instalado"""
    try:
        result = subprocess.run(['yt-dlp', '--version'], 
                              capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

def install_yt_dlp():
    """Instala yt-dlp via pip"""
    print("🔧 Instalando yt-dlp...")
    try:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '--upgrade', 'yt-dlp'], 
                      check=True)
        print("✅ yt-dlp instalado!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Erro ao instalar yt-dlp: {e}")
        print("\nTente instalar manualmente com:")
        print("  pip install yt-dlp")
        return False

def validate_instagram_url(url):
    """Valida se é URL válida do Instagram"""
    patterns = [
        r'https?://(?:www\.)?instagram\.com/(?:p|reel|tv|reels)/[^/?\s]+',
        r'https?://(?:www\.)?instagr\.am/[^/?\s]+',
    ]
    
    for pattern in patterns:
        if re.match(pattern, url):
            return True
    return False

def extract_shortcode(url):
    """Extrai o shortcode da URL para nomear o arquivo"""
    parsed = urlparse(url)
    path = parsed.path.strip('/')
    parts = path.split('/')
    
    # Pega o último pedaço que não é vazio
    for part in reversed(parts):
        if part and part not in ['p', 'reel', 'tv', 'reels']:
            return part[:50]  # Limita tamanho
    
    return "instagram_audio"

def download_audio(url, output_dir=None):
    """Baixa apenas o áudio do vídeo do Instagram"""
    
    # Define diretório de saída
    if output_dir is None:
        output_dir = Path.home() / "Downloads" / "Instagram_Audio"
    else:
        output_dir = Path(output_dir)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Nome base do arquivo
    shortcode = extract_shortcode(url)
    base_name = f"{shortcode}_%(title).50s"
    
    # Caminho completo de saída
    output_template = str(output_dir / base_name)
    
    print(f"\n🎯 URL: {url}")
    print(f"📁 Salvando em: {output_dir}")
    print("⏳ Baixando áudio...\n")
    
    # Comando yt-dlp
    cmd = [
        'yt-dlp',
        '--no-warnings',
        '--no-check-certificate',
        '--extract-audio',
        '--audio-format', 'mp3',
        '--audio-quality', '0',  # Melhor qualidade
        '--add-metadata',
        '--embed-thumbnail',
        '--output', output_template + '.%(ext)s',
        '--user-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        '--cookies-from-browser', 'chrome',  # Tenta usar cookies do Chrome
        url
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=False, text=True)
        
        if result.returncode == 0:
            # Procura o arquivo MP3 criado
            mp3_files = list(output_dir.glob(f"{shortcode}*.mp3"))
            if mp3_files:
                downloaded_file = max(mp3_files, key=lambda p: p.stat().st_mtime)
                print(f"\n✅ Áudio baixado com sucesso!")
                print(f"📂 Arquivo: {downloaded_file}")
                print(f"📊 Tamanho: {downloaded_file.stat().st_size / 1024 / 1024:.2f} MB")
                return True
            else:
                print("\n⚠️ Download pareceu funcionar mas não encontrei o arquivo MP3")
                return False
        else:
            print(f"\n❌ Erro no download (código {result.returncode})")
            return False
            
    except Exception as e:
        print(f"\n❌ Erro: {e}")
        return False

def main():
    print("🎵 Instagram Audio Downloader")
    print("=" * 50)
    
    # Verifica argumentos
    if len(sys.argv) < 2:
        print("\n❌ Erro: Forneça a URL do Instagram")
        print("\nUso:")
        print("  python instagram_audio_downloader.py <URL>")
        print("\nExemplos:")
        print("  python instagram_audio_downloader.py 'https://instagram.com/reel/ABC123'")
        print("  python instagram_audio_downloader.py 'https://instagram.com/p/XYZ789'")
        sys.exit(1)
    
    url = sys.argv[1].strip()
    
    # Valida URL
    if not validate_instagram_url(url):
        print(f"\n❌ URL inválida: {url}")
        print("\nFormatos aceitos:")
        print("  - https://instagram.com/reel/CODIGO")
        print("  - https://instagram.com/p/CODIGO")
        print("  - https://instagram.com/tv/CODIGO")
        sys.exit(1)
    
    # Verifica/instala yt-dlp
    version = check_yt_dlp()
    if not version:
        print("⚠️ yt-dlp não encontrado")
        if not install_yt_dlp():
            sys.exit(1)
    else:
        print(f"✅ yt-dlp {version}")
    
    # Baixa o áudio
    success = download_audio(url)
    
    if success:
        print("\n🎉 Pronto! O áudio está na pasta Downloads/Instagram_Audio")
    else:
        print("\n💡 Dica: Se falhou, pode ser que:")
        print("   - O vídeo é privado/restrito")
        print("   - Precisa de login (abra o Instagram no Chrome primeiro)")
        print("   - A URL expirou ou o post foi removido")
        sys.exit(1)

if __name__ == "__main__":
    main()
