#!/usr/bin/env python3
"""
wolf-copilot.py — Interactive Voice + Computer Use Assistant
Wolf Agency — Alfred Copilot Mode

Modos de input:
  --mode text  : você digita, Alfred fala + navega (default)
  --mode voice : você fala no microfone, Alfred fala + navega (requer mic)
  --mode whatsapp : input via WhatsApp, Alfred fala + navega (via bridge)

Uso:
  python3 wolf-copilot.py --task "abrir clawhub e encontrar melhores skills"
  python3 wolf-copilot.py --mode voice --voice Luciana
  python3 wolf-copilot.py  (modo texto interativo)
"""

import argparse
import json
import os
import re
import select
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

# ── Config ──
ENV_FILE = Path.home() / ".openclaw" / ".env"
LOG_FILE = Path("/tmp/wolf-copilot.log")
RECORD_FILE = Path("/tmp/wolf-copilot-input.wav")
MCP_BIN = "/opt/homebrew/opt/mcp-server-macos-use/bin/mcp-server-macos-use"

# Carregar .env
def load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())

load_env()

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

# ── Logging ──
def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}"
    print(f"  \033[90m{entry}\033[0m")
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")


# ══════════════════════════════════════════════════════════
# TTS — Text-to-Speech via macOS `say`
# ══════════════════════════════════════════════════════════

class Speaker:
    def __init__(self, voice="antonio"):
        self.process = None
        self.audio_file = Path("/tmp/wolf-copilot-tts.mp3")
        # Mapear vozes amigáveis para Edge TTS IDs
        self.voice_map = {
            "antonio": "pt-BR-AntonioNeural",
            "francisca": "pt-BR-FranciscaNeural",
            "thalita": "pt-BR-ThalitaMultilingualNeural",
        }
        voice_lower = voice.lower()
        if voice_lower in self.voice_map:
            self.voice = self.voice_map[voice_lower]
        elif voice.startswith("pt-BR-"):
            self.voice = voice
        else:
            self.voice = "pt-BR-AntonioNeural"
        # Verificar se edge-tts está disponível (tentar global e venv)
        self.python = "python3"
        self.use_edge = False
        for py in ["/opt/homebrew/bin/python3", "python3", sys.executable]:
            r = subprocess.run([py, "-m", "edge_tts", "--version"],
                               capture_output=True, timeout=5)
            if r.returncode == 0:
                self.python = py
                self.use_edge = True
                break
        if not self.use_edge:
            log("edge-tts nao disponivel, usando macOS say como fallback")
            self.voice = "Eddy"
        else:
            log(f"TTS: Edge Neural ({self.voice})")

    def _clean_text(self, text):
        """Limpa texto para TTS."""
        clean = re.sub(r'[*_`#\[\]()]', '', text)
        clean = re.sub(r'\bhttps?://\S+', 'link', clean)
        clean = re.sub(r'<[^>]+>', '', clean)
        clean = clean.replace('\n', '. ').replace('  ', ' ')
        return clean[:2000].strip()

    def speak(self, text, wait=True):
        """Fala o texto via alto-falante (Edge TTS neural ou macOS fallback)."""
        if not text or not text.strip():
            return
        clean = self._clean_text(text)
        if not clean:
            return

        log(f"TTS: {clean[:80]}...")

        if self.use_edge:
            # Salvar texto em arquivo temp para evitar problemas com aspas
            txt_file = Path("/tmp/wolf-copilot-tts.txt")
            txt_file.write_text(clean, encoding="utf-8")
            self.process = subprocess.Popen(
                ["bash", "-c",
                 f'{self.python} -m edge_tts --voice "{self.voice}" '
                 f'-f {txt_file} '
                 f'--write-media {self.audio_file} 2>/dev/null && '
                 f'afplay {self.audio_file}'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        else:
            # Fallback macOS say
            self.process = subprocess.Popen(
                ["say", "-v", self.voice, "-r", "210", clean],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )

        if wait:
            self.process.wait()

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait()
        # Parar qualquer afplay em andamento
        subprocess.run(["pkill", "-f", "afplay.*wolf-copilot-tts"],
                       capture_output=True)

    def is_speaking(self):
        return self.process and self.process.poll() is None

    def wait_done(self):
        while self.is_speaking():
            time.sleep(0.1)


# ══════════════════════════════════════════════════════════
# Input — Text mode (teclado) ou Voice mode (microfone)
# ══════════════════════════════════════════════════════════

class TextInput:
    """Input via teclado no terminal."""
    def listen(self):
        try:
            print()
            user = input("  \033[32m> Voce: \033[0m").strip()
            if user:
                log(f"Input: {user}")
            return user if user else None
        except (EOFError, KeyboardInterrupt):
            return None


class VoiceInput:
    """Input via microfone + Groq Whisper."""
    def __init__(self):
        self.groq_key = GROQ_API_KEY

    def _has_mic(self):
        try:
            import sounddevice as sd
            devs = sd.query_devices()
            return any(d.get('max_input_channels', 0) > 0 for d in devs)
        except Exception:
            return False

    def listen(self):
        print("\n  \033[32m🎙  Ouvindo... (fale agora)\033[0m")
        log("Ouvindo microfone...")

        try:
            proc = subprocess.run([
                "rec", "-q", str(RECORD_FILE),
                "rate", "16000", "channels", "1",
                "silence", "1", "0.3", "3%",
                "1", "2.0", "3%",
                "trim", "0", "15"
            ], timeout=20, capture_output=True, text=True)

            if not RECORD_FILE.exists() or RECORD_FILE.stat().st_size < 1000:
                return None

            log(f"Audio gravado: {RECORD_FILE.stat().st_size} bytes")
            return self._transcribe(str(RECORD_FILE))

        except Exception as e:
            log(f"Erro mic: {e}")
            return None

    def _transcribe(self, path):
        print("  \033[33m📝 Transcrevendo...\033[0m")
        try:
            result = subprocess.run([
                "curl", "-s", "--max-time", "10",
                "https://api.groq.com/openai/v1/audio/transcriptions",
                "-H", f"Authorization: Bearer {self.groq_key}",
                "-F", f"file=@{path}",
                "-F", "model=whisper-large-v3",
                "-F", "language=pt",
                "-F", "response_format=json"
            ], capture_output=True, text=True, timeout=15)
            data = json.loads(result.stdout)
            text = data.get("text", "").strip()
            if text:
                print(f"  \033[36m💬 Voce: {text}\033[0m")
                log(f"Transcrito: {text}")
            return text if text else None
        except Exception as e:
            log(f"Erro STT: {e}")
            return None


# ══════════════════════════════════════════════════════════
# Computer Use — MCP macOS
# ══════════════════════════════════════════════════════════

class ComputerUse:
    def __init__(self):
        self.proc = None
        self.msg_id = 0
        self._start_server()

    def _start_server(self):
        log("Iniciando MCP server...")
        self.proc = subprocess.Popen(
            [MCP_BIN],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        self._send({"jsonrpc": "2.0", "id": self._next_id(), "method": "initialize",
                     "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "wolf-copilot", "version": "1.0"}}})
        resp = self._recv()
        if resp:
            info = resp.get("result", {}).get("serverInfo", {})
            log(f"MCP: {info.get('name', '?')} v{info.get('version', '?')}")
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})

    def _next_id(self):
        self.msg_id += 1
        return self.msg_id

    def _send(self, msg):
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        self.proc.stdin.flush()

    def _recv(self, timeout=15):
        start = time.time()
        while time.time() - start < timeout:
            if select.select([self.proc.stdout], [], [], 0.5)[0]:
                line = self.proc.stdout.readline().decode().strip()
                if line:
                    try:
                        data = json.loads(line)
                        if "id" in data:
                            return data
                    except json.JSONDecodeError:
                        continue
        return {}

    def call(self, tool_name, arguments):
        full_name = f"macos-use_{tool_name}" if not tool_name.startswith("macos-use_") else tool_name
        self._send({
            "jsonrpc": "2.0", "id": self._next_id(),
            "method": "tools/call",
            "params": {"name": full_name, "arguments": arguments}
        })
        resp = self._recv(timeout=15)
        text = ""
        for c in resp.get("result", {}).get("content", []):
            if c.get("type") == "text":
                text += c["text"]
        return text

    def open_app(self, identifier):
        return self.call("open_application_and_traverse", {"identifier": identifier})

    def click(self, pid, x, y, width=None, height=None):
        args = {"pid": pid, "x": x, "y": y}
        if width: args["width"] = width
        if height: args["height"] = height
        return self.call("click_and_traverse", args)

    def type_text(self, pid, text):
        return self.call("type_and_traverse", {"pid": pid, "text": text})

    def press_key(self, pid, key, modifiers=None):
        args = {"pid": pid, "keyName": key}
        if modifiers:
            args["modifierFlags"] = json.dumps(modifiers)
        return self.call("press_key_and_traverse", args)

    def scroll(self, pid, x, y, delta_y=3):
        return self.call("scroll_and_traverse",
                         {"pid": pid, "x": x, "y": y, "deltaY": delta_y})

    def refresh(self, pid):
        return self.call("refresh_traversal", {"pid": pid})

    def close(self):
        if self.proc:
            try:
                self.proc.stdin.close()
                self.proc.terminate()
                self.proc.wait(timeout=3)
            except Exception:
                pass


# ══════════════════════════════════════════════════════════
# LLM Brain — Anthropic Claude
# ══════════════════════════════════════════════════════════

SYSTEM_PROMPT = """IDIOMA OBRIGATORIO: PORTUGUES BRASILEIRO. NUNCA responda em ingles.

Voce e Alfred, o copiloto inteligente da Wolf Agency.

CONTEXTO: Voce esta controlando o Mac do Netto em tempo real via Computer Use.
Voce FALA pelo alto-falante (TTS) e o Netto digita ou fala de volta.

REGRAS DE COMUNICACAO:
1. SEMPRE responda em PORTUGUES BRASILEIRO — sem excecao
2. Fale de forma natural, concisa e direta — suas respostas viram audio
3. NAO use markdown, emojis, asteriscos, ou formatacao — sera falado em voz alta
4. Maximo 3-4 frases por resposta
5. Narre brevemente o que esta fazendo antes de agir
6. Quando analisar a tela, resuma as informacoes mais relevantes

ACOES DISPONIVEIS:
Retorne acoes entre tags <actions>...</actions> como JSON array.
Cada acao e um objeto com "action" e parametros.

Acoes possiveis:
- {"action": "open_app", "identifier": "com.apple.Safari"} — abre app (bundle ID ou nome)
- {"action": "click", "x": 100, "y": 200} — clica na coordenada (usa PID do contexto)
- {"action": "click", "x": 100, "y": 200, "width": 50, "height": 30} — clica no centro do elemento
- {"action": "type", "text": "texto"} — digita texto no campo focado
- {"action": "press_key", "key": "Return"} — pressiona tecla
- {"action": "press_key", "key": "l", "modifiers": ["Command"]} — atalho Cmd+L
- {"action": "press_key", "key": "a", "modifiers": ["Command"]} — selecionar tudo
- {"action": "scroll", "x": 500, "y": 400, "delta_y": -3} — scroll (negativo=baixo)
- {"action": "refresh"} — le estado atual da tela sem agir
- {"action": "wait", "seconds": 2} — esperar

REGRAS DE NAVEGACAO:
- Sempre inclua narracao FORA das tags <actions>
- Extraia coordenadas dos elementos visiveis no [ESTADO DA TELA]
- Apos clicar/navegar, faca refresh para ver resultado
- Leia os elementos visiveis ANTES de clicar — nao chute coordenadas
- URLs: use Cmd+L para focar barra de endereco, depois type + Enter
- Se um elemento nao esta visivel, faca scroll para encontrar

FORMATO DA RESPOSTA:
Narracao aqui em texto simples para TTS.

<actions>
[{"action": "...", ...}]
</actions>

Mais narracao se necessario."""


class Brain:
    def __init__(self):
        self.history = []
        # Usar gateway local OpenClaw (OpenAI-compatible)
        self.gateway_url = "http://127.0.0.1:18789/v1/chat/completions"
        self.gateway_token = "b52639408a26e05b9170423402be3068db69ae001d4b0610"
        self.model = "anthropic/claude-haiku-4-5-20251001"

    def think(self, user_input, screen_context=""):
        """Envia ao LLM via gateway e retorna (narracao, acoes)."""
        content = user_input
        if screen_context:
            if len(screen_context) > 6000:
                screen_context = screen_context[:6000] + "\n[...truncado]"
            content += f"\n\n[ESTADO DA TELA]\n{screen_context}"

        self.history.append({"role": "user", "content": content})
        # System prompt como primeira mensagem + ultimas 12
        messages = [{"role": "system", "content": SYSTEM_PROMPT}] + self.history[-12:]

        try:
            payload = json.dumps({
                "model": self.model,
                "max_tokens": 2048,
                "messages": messages
            })

            result = subprocess.run([
                "curl", "-s", "--max-time", "45",
                self.gateway_url,
                "-H", f"Authorization: Bearer {self.gateway_token}",
                "-H", "content-type: application/json",
                "-d", payload
            ], capture_output=True, text=True, timeout=50)

            data = json.loads(result.stdout)
            if "error" in data:
                log(f"LLM Error: {data['error']}")
                return "Desculpe, tive um problema. Pode repetir?", []

            full_text = ""
            for choice in data.get("choices", []):
                msg = choice.get("message", {})
                full_text += msg.get("content", "")

            if not full_text:
                log(f"LLM empty response: {result.stdout[:200]}")
                return "Nao recebi resposta do modelo. Tentando de novo.", []

            self.history.append({"role": "assistant", "content": full_text})

            # Separar narracao e acoes
            narration = full_text
            actions = []

            actions_match = re.search(r'<actions>(.*?)</actions>', full_text, re.DOTALL)
            if actions_match:
                try:
                    actions = json.loads(actions_match.group(1))
                except json.JSONDecodeError:
                    log("Erro parsing actions JSON")
                narration = re.sub(r'<actions>.*?</actions>', '', full_text, flags=re.DOTALL).strip()

            return narration, actions

        except Exception as e:
            log(f"Brain error: {e}")
            return "Tive um problema de conexao. Vou tentar de novo.", []


# ══════════════════════════════════════════════════════════
# Copilot — Loop principal
# ══════════════════════════════════════════════════════════

class Copilot:
    def __init__(self, voice="Luciana", input_mode="text", initial_task=None):
        self.speaker = Speaker(voice)
        self.input_handler = VoiceInput() if input_mode == "voice" else TextInput()
        self.computer = ComputerUse()
        self.brain = Brain()
        self.running = True
        self.current_pid = None
        self.initial_task = initial_task
        self.input_mode = input_mode

        signal.signal(signal.SIGINT, self._handle_exit)

    def _handle_exit(self, signum, frame):
        print("\n\n  \033[31m🛑 Encerrando copiloto...\033[0m")
        self.running = False
        self.speaker.stop()
        self.computer.close()
        sys.exit(0)

    def execute_actions(self, actions):
        """Executa lista de acoes no computador."""
        screen_result = ""
        for action in actions:
            act = action.get("action", "")
            log(f"Acao: {act}")
            print(f"  \033[35m⚡ {act}\033[0m", end="")

            try:
                if act == "open_app":
                    result = self.computer.open_app(action["identifier"])
                    pid_match = re.search(r'pid:\s*(\d+)', result)
                    if pid_match:
                        self.current_pid = int(pid_match.group(1))
                    screen_result = result
                    print(f" → PID {self.current_pid}")

                elif act == "click":
                    pid = action.get("pid", self.current_pid)
                    result = self.computer.click(
                        pid, action["x"], action["y"],
                        action.get("width"), action.get("height"))
                    screen_result = result
                    print(f" → ({action['x']},{action['y']})")

                elif act == "type":
                    pid = action.get("pid", self.current_pid)
                    result = self.computer.type_text(pid, action["text"])
                    screen_result = result
                    print(f" → '{action['text'][:30]}'")

                elif act == "press_key":
                    pid = action.get("pid", self.current_pid)
                    mods = action.get("modifiers")
                    result = self.computer.press_key(pid, action["key"], mods)
                    screen_result = result
                    mod_str = f"{'+'.join(mods)}+" if mods else ""
                    print(f" → {mod_str}{action['key']}")

                elif act == "scroll":
                    pid = action.get("pid", self.current_pid)
                    result = self.computer.scroll(
                        pid, action["x"], action["y"],
                        action.get("delta_y", -3))
                    screen_result = result
                    print(f" → dy={action.get('delta_y', -3)}")

                elif act == "refresh":
                    pid = action.get("pid", self.current_pid)
                    result = self.computer.refresh(pid)
                    screen_result = result
                    print(" → atualizado")

                elif act == "wait":
                    secs = action.get("seconds", 2)
                    time.sleep(secs)
                    print(f" → {secs}s")

                else:
                    print(f" → acao desconhecida")

            except Exception as e:
                log(f"Erro executando {act}: {e}")
                print(f" → ERRO: {e}")

        return screen_result

    def process_turn(self, user_input):
        """Processa um turno completo: LLM → fala → acoes → feedback."""
        # Obter contexto da tela
        screen_context = ""
        if self.current_pid:
            screen_context = self.computer.get_screen_state(self.current_pid) if hasattr(self.computer, 'get_screen_state') else self.computer.refresh(self.current_pid)

        # Pensar
        print("  \033[33m🧠 Pensando...\033[0m")
        narration, actions = self.brain.think(user_input, screen_context)

        # Falar narracao
        print(f"\n  \033[1m🤖 Alfred:\033[0m {narration}\n")
        self.speaker.speak(narration, wait=False)

        # Executar acoes
        if actions:
            screen = self.execute_actions(actions)
            self.speaker.wait_done()

            # Feedback apos acoes (loop de ate 3 follow-ups autonomos)
            for i in range(3):
                narration2, actions2 = self.brain.think(
                    "Executei as acoes. Analise o estado da tela e continue a tarefa. "
                    "Se a tarefa esta completa ou precisa de input do usuario, diga isso sem novas acoes.",
                    screen_context=screen
                )
                print(f"\n  \033[1m🤖 Alfred:\033[0m {narration2}\n")
                self.speaker.speak(narration2, wait=False)

                if not actions2:
                    break  # Sem mais acoes = esperando input

                screen = self.execute_actions(actions2)
                self.speaker.wait_done()

    def run(self):
        """Loop principal do copiloto."""
        mode_label = {"text": "Teclado", "voice": "Microfone", "whatsapp": "WhatsApp"}

        print("\n" + "=" * 60)
        print("  \033[1m🐺 Wolf Copilot — Alfred Interactive Mode\033[0m")
        print(f"  Input: {mode_label.get(self.input_mode, self.input_mode)}")
        print(f"  Voz: {self.speaker.voice}")
        print("=" * 60)
        if self.input_mode == "text":
            print("  Digite seus comandos. 'sair' para encerrar.")
        else:
            print("  Fale naturalmente. 'para' ou 'sair' para encerrar.")
        print("  Ctrl+C tambem encerra.\n")

        # Saudacao
        greeting = "Ola Netto! Copiloto ativo. Estou pronto para navegar e explorar."
        if self.initial_task:
            greeting += f" Voce pediu: {self.initial_task}. Vou comecar agora."
        self.speaker.speak(greeting)

        # Tarefa inicial
        if self.initial_task:
            self.process_turn(
                f"O usuario pediu: {self.initial_task}. "
                "Comece executando as acoes necessarias. "
                "Narre o que esta fazendo para ele ouvir."
            )

        # Loop interativo
        while self.running:
            self.speaker.wait_done()

            user_input = self.input_handler.listen()
            if not user_input:
                continue

            # Saida
            exit_words = ["para", "parar", "sair", "exit", "quit", "encerrar", "tchau"]
            if any(w == user_input.lower().strip() for w in exit_words):
                self.speaker.speak("Beleza! Encerrando o copiloto. Ate mais, Netto!")
                self.speaker.wait_done()
                break

            self.process_turn(user_input)

        self.computer.close()
        print("\n  \033[90m👋 Copiloto encerrado.\033[0m\n")


# ══════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Wolf Copilot — Voice + Computer Use",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python3 wolf-copilot.py
  python3 wolf-copilot.py --task "abrir clawhub e analisar melhores skills"
  python3 wolf-copilot.py --voice Eddy --task "abrir safari e pesquisar tendencias marketing"
  python3 wolf-copilot.py --mode voice  (requer microfone)
        """)
    parser.add_argument("--voice", default="antonio",
                        help="Voz TTS: antonio, francisca, thalita (default: antonio)")
    parser.add_argument("--mode", default="text", choices=["text", "voice"],
                        help="Modo de input: text ou voice (default: text)")
    parser.add_argument("--task", default=None,
                        help="Tarefa inicial para executar automaticamente")
    args = parser.parse_args()

    # Validar deps
    ok = True
    # Verificar gateway ativo
    gw_check = subprocess.run(
        ["curl", "-s", "--max-time", "3", "http://127.0.0.1:18789/health"],
        capture_output=True, text=True)
    if '"ok":true' not in gw_check.stdout:
        print("  ERRO: OpenClaw gateway nao esta rodando (porta 18789)")
        ok = False
    if not Path(MCP_BIN).exists():
        print(f"  ERRO: MCP server nao encontrado em {MCP_BIN}")
        ok = False
    if subprocess.run(["which", "say"], capture_output=True).returncode != 0:
        print("  ERRO: 'say' nao encontrado (macOS apenas)")
        ok = False
    if args.mode == "voice":
        if not GROQ_API_KEY:
            print("  ERRO: GROQ_API_KEY necessaria para modo voice")
            ok = False
        if subprocess.run(["which", "rec"], capture_output=True).returncode != 0:
            print("  ERRO: 'rec' (sox) necessario para modo voice")
            ok = False
    if not ok:
        sys.exit(1)

    copilot = Copilot(voice=args.voice, input_mode=args.mode, initial_task=args.task)
    copilot.run()


if __name__ == "__main__":
    main()
