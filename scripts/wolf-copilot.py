#!/usr/bin/env python3
"""
wolf-copilot.py — Interactive Voice + Computer Use Assistant
Wolf Agency — Alfred Copilot Mode

Fluxo:
  1. Alfred fala (TTS macOS)
  2. Você responde por voz (microfone → Groq Whisper)
  3. Alfred analisa a tela (Computer Use)
  4. LLM processa tudo e decide ações + narração
  5. Executa ações na tela + fala o resultado
  6. Loop contínuo até "para", "sair", "exit"

Uso: python3 wolf-copilot.py [--voice Luciana] [--task "abrir clawhub e analisar skills"]
"""

import argparse
import json
import os
import re
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
    def __init__(self, voice="Luciana"):
        self.voice = voice
        self.process = None
        # Verificar se a voz existe
        result = subprocess.run(["say", "-v", "?"], capture_output=True, text=True)
        voices = [l.split()[0] for l in result.stdout.splitlines()]
        if voice not in voices:
            # Fallback para Eddy (PT-BR)
            self.voice = "Eddy"
            log(f"Voz '{voice}' não encontrada, usando Eddy")

    def speak(self, text, wait=True):
        """Fala o texto. Se wait=False, fala em background."""
        if not text.strip():
            return
        # Limpar markdown e caracteres especiais
        clean = re.sub(r'[*_`#\[\]()]', '', text)
        clean = re.sub(r'\bhttps?://\S+', 'link', clean)
        clean = clean.replace('\n', '. ')
        clean = clean[:1500]  # Limitar tamanho

        log(f"TTS: {clean[:80]}...")
        self.process = subprocess.Popen(
            ["say", "-v", self.voice, "-r", "200", clean],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if wait:
            self.process.wait()

    def stop(self):
        """Interrompe fala em andamento."""
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait()

    def is_speaking(self):
        return self.process and self.process.poll() is None


# ══════════════════════════════════════════════════════════
# STT — Speech-to-Text via Groq Whisper
# ══════════════════════════════════════════════════════════

class Listener:
    def __init__(self):
        self.groq_key = GROQ_API_KEY
        if not self.groq_key:
            raise RuntimeError("GROQ_API_KEY não configurada no .env")

    def record(self, max_duration=15, silence_threshold="3%", silence_duration="2.0"):
        """Grava áudio do microfone até detectar silêncio."""
        log("Ouvindo... (fale agora)")
        print("\n  \033[32m🎙️  Ouvindo... (fale agora)\033[0m")

        # sox rec: grava até silêncio
        # silence 1 0.3 threshold = começa quando detecta som
        # silence 1 duration threshold = para quando silêncio por N segundos
        cmd = [
            "rec", "-q",
            str(RECORD_FILE),
            "rate", "16000",
            "channels", "1",
            "silence", "1", "0.3", silence_threshold,
            "1", silence_duration, silence_threshold,
            "trim", "0", str(max_duration)
        ]
        try:
            proc = subprocess.run(cmd, timeout=max_duration + 5,
                                  capture_output=True, text=True)
            if not RECORD_FILE.exists() or RECORD_FILE.stat().st_size < 1000:
                log("Nenhum áudio captado")
                return None
            log(f"Áudio gravado: {RECORD_FILE.stat().st_size} bytes")
            return str(RECORD_FILE)
        except subprocess.TimeoutExpired:
            log("Timeout na gravação")
            return None
        except Exception as e:
            log(f"Erro gravação: {e}")
            return None

    def transcribe(self, audio_path):
        """Transcreve áudio via Groq Whisper."""
        log("Transcrevendo...")
        print("  \033[33m📝 Transcrevendo...\033[0m")

        try:
            result = subprocess.run([
                "curl", "-s", "--max-time", "10",
                "https://api.groq.com/openai/v1/audio/transcriptions",
                "-H", f"Authorization: Bearer {self.groq_key}",
                "-F", f"file=@{audio_path}",
                "-F", "model=whisper-large-v3",
                "-F", "language=pt",
                "-F", "response_format=json"
            ], capture_output=True, text=True, timeout=15)

            data = json.loads(result.stdout)
            text = data.get("text", "").strip()
            if text:
                log(f"Transcrito: {text}")
                print(f"  \033[36m💬 Você: {text}\033[0m")
            return text
        except Exception as e:
            log(f"Erro transcrição: {e}")
            return None

    def listen(self):
        """Grava e transcreve em um passo."""
        path = self.record()
        if not path:
            return None
        return self.transcribe(path)


# ══════════════════════════════════════════════════════════
# Computer Use — MCP macOS via subprocess
# ══════════════════════════════════════════════════════════

class ComputerUse:
    def __init__(self):
        self.proc = None
        self.msg_id = 0
        self._start_server()

    def _start_server(self):
        """Inicia o MCP server como processo persistente."""
        log("Iniciando MCP server...")
        self.proc = subprocess.Popen(
            [MCP_BIN],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        # Initialize
        self._send({"jsonrpc": "2.0", "id": self._next_id(), "method": "initialize",
                     "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "wolf-copilot", "version": "1.0"}}})
        resp = self._recv()
        log(f"MCP Server: {resp.get('result', {}).get('serverInfo', {}).get('name', '?')}")

        # Send initialized notification
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})

    def _next_id(self):
        self.msg_id += 1
        return self.msg_id

    def _send(self, msg):
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        self.proc.stdin.flush()

    def _recv(self, timeout=10):
        """Lê resposta com timeout."""
        import select
        start = time.time()
        while time.time() - start < timeout:
            if select.select([self.proc.stdout], [], [], 0.5)[0]:
                line = self.proc.stdout.readline().decode().strip()
                if line:
                    try:
                        data = json.loads(line)
                        # Ignorar notificações, pegar só respostas com id
                        if "id" in data or "result" in data:
                            return data
                    except json.JSONDecodeError:
                        continue
        return {}

    def call(self, tool_name, arguments):
        """Chama uma tool do MCP server."""
        full_name = f"macos-use_{tool_name}" if not tool_name.startswith("macos-use_") else tool_name
        self._send({
            "jsonrpc": "2.0",
            "id": self._next_id(),
            "method": "tools/call",
            "params": {"name": full_name, "arguments": arguments}
        })
        resp = self._recv(timeout=15)
        content = resp.get("result", {}).get("content", [])
        text = ""
        for c in content:
            if c.get("type") == "text":
                text += c["text"]
        return text

    def open_app(self, identifier):
        return self.call("open_application_and_traverse", {"identifier": identifier})

    def click(self, pid, x, y, width=None, height=None):
        args = {"pid": pid, "x": x, "y": y}
        if width:
            args["width"] = width
        if height:
            args["height"] = height
        return self.call("click_and_traverse", args)

    def type_text(self, pid, text):
        return self.call("type_and_traverse", {"pid": pid, "text": text})

    def press_key(self, pid, key, modifiers=None):
        args = {"pid": pid, "keyName": key}
        if modifiers:
            args["modifierFlags"] = json.dumps(modifiers)
        return self.call("press_key_and_traverse", args)

    def scroll(self, pid, x, y, delta_y=3):
        return self.call("scroll_and_traverse", {"pid": pid, "x": x, "y": y, "deltaY": delta_y})

    def refresh(self, pid):
        return self.call("refresh_traversal", {"pid": pid})

    def get_screen_state(self, pid=None):
        """Retorna estado da tela como texto para o LLM."""
        if pid:
            return self.refresh(pid)
        return ""

    def close(self):
        if self.proc:
            self.proc.stdin.close()
            self.proc.terminate()
            self.proc.wait()


# ══════════════════════════════════════════════════════════
# LLM Brain — Anthropic Claude via API
# ══════════════════════════════════════════════════════════

class Brain:
    def __init__(self):
        self.api_key = ANTHROPIC_API_KEY
        if not self.api_key:
            raise RuntimeError("ANTHROPIC_API_KEY não configurada")
        self.history = []
        self.system_prompt = """Você é Alfred, o copiloto inteligente da Wolf Agency.

CONTEXTO: Você está controlando o Mac do Netto em tempo real. Você tem acesso ao Computer Use (navegar, clicar, digitar) e está conversando por voz com o Netto.

REGRAS:
1. Fale de forma natural e concisa — suas respostas serão convertidas em áudio
2. Não use markdown pesado, emojis excessivos ou formatação complexa — será falado
3. Máximo 3-4 frases por resposta ao narrar ações
4. Quando executar ações no computador, narre brevemente o que está fazendo
5. Quando analisar algo na tela, explique o que encontrou de forma clara
6. Se o usuário pedir para parar, encerre educadamente

AÇÕES DISPONÍVEIS:
Você pode retornar ações no formato JSON entre tags <actions>...</actions>:

<actions>
[
  {"action": "open_app", "identifier": "com.apple.Safari"},
  {"action": "click", "pid": 123, "x": 100, "y": 200},
  {"action": "type", "pid": 123, "text": "texto aqui"},
  {"action": "press_key", "pid": 123, "key": "Return"},
  {"action": "scroll", "pid": 123, "x": 500, "y": 400, "delta_y": -3},
  {"action": "refresh", "pid": 123},
  {"action": "wait", "seconds": 2}
]
</actions>

IMPORTANTE:
- Sempre inclua narração FORA das tags <actions> — é o que será falado
- Extraia PIDs e coordenadas do contexto da tela fornecido
- Após ações, peça refresh para ver resultado
- Navegue de forma inteligente — leia os elementos visíveis antes de clicar

Idioma: Português (PT-BR)"""

    def think(self, user_input, screen_context=""):
        """Envia ao LLM e retorna (narração, ações)."""
        message_content = user_input
        if screen_context:
            message_content += f"\n\n[ESTADO DA TELA]\n{screen_context}"

        self.history.append({"role": "user", "content": message_content})

        # Manter apenas últimas 10 mensagens para contexto
        context = self.history[-10:]

        try:
            payload = json.dumps({
                "model": "claude-sonnet-4-6-20250514",
                "max_tokens": 2048,
                "system": self.system_prompt,
                "messages": context
            })

            result = subprocess.run([
                "curl", "-s", "--max-time", "30",
                "https://api.anthropic.com/v1/messages",
                "-H", f"x-api-key: {self.api_key}",
                "-H", "anthropic-version: 2023-06-01",
                "-H", "content-type: application/json",
                "-d", payload
            ], capture_output=True, text=True, timeout=35)

            data = json.loads(result.stdout)
            if "error" in data:
                log(f"LLM Error: {data['error']}")
                return "Desculpe, tive um problema ao processar. Pode repetir?", []

            full_text = ""
            for block in data.get("content", []):
                if block.get("type") == "text":
                    full_text += block["text"]

            self.history.append({"role": "assistant", "content": full_text})

            # Separar narração e ações
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
            return "Tive um problema de conexão. Vou tentar de novo.", []


# ══════════════════════════════════════════════════════════
# Copilot — Loop principal
# ══════════════════════════════════════════════════════════

class Copilot:
    def __init__(self, voice="Luciana", initial_task=None):
        self.speaker = Speaker(voice)
        self.listener = Listener()
        self.computer = ComputerUse()
        self.brain = Brain()
        self.running = True
        self.current_pid = None
        self.initial_task = initial_task

        # Handle Ctrl+C
        signal.signal(signal.SIGINT, self._handle_exit)

    def _handle_exit(self, signum, frame):
        print("\n\n  \033[31m🛑 Encerrando copiloto...\033[0m")
        self.running = False
        self.speaker.stop()
        self.computer.close()
        sys.exit(0)

    def execute_actions(self, actions):
        """Executa lista de ações no computador."""
        screen_result = ""
        for action in actions:
            act = action.get("action", "")
            log(f"Executando: {act}")

            if act == "open_app":
                result = self.computer.open_app(action["identifier"])
                # Extrair PID
                pid_match = re.search(r'pid:\s*(\d+)', result)
                if pid_match:
                    self.current_pid = int(pid_match.group(1))
                    log(f"PID atualizado: {self.current_pid}")
                screen_result = result

            elif act == "click":
                pid = action.get("pid", self.current_pid)
                result = self.computer.click(
                    pid, action["x"], action["y"],
                    action.get("width"), action.get("height")
                )
                screen_result = result

            elif act == "type":
                pid = action.get("pid", self.current_pid)
                result = self.computer.type_text(pid, action["text"])
                screen_result = result

            elif act == "press_key":
                pid = action.get("pid", self.current_pid)
                result = self.computer.press_key(
                    pid, action["key"], action.get("modifiers")
                )
                screen_result = result

            elif act == "scroll":
                pid = action.get("pid", self.current_pid)
                result = self.computer.scroll(
                    pid, action["x"], action["y"], action.get("delta_y", -3)
                )
                screen_result = result

            elif act == "refresh":
                pid = action.get("pid", self.current_pid)
                result = self.computer.refresh(pid)
                screen_result = result

            elif act == "wait":
                time.sleep(action.get("seconds", 2))

        return screen_result

    def run(self):
        """Loop principal do copiloto."""
        print("\n" + "=" * 60)
        print("  \033[1m🐺 Wolf Copilot — Alfred Interactive Mode\033[0m")
        print("=" * 60)
        print("  Fale naturalmente. Diga 'para' ou 'sair' para encerrar.")
        print("  Ctrl+C também encerra.\n")

        # Saudação inicial
        greeting = "Olá Netto! Copiloto ativo. Estou pronto para navegar e explorar."
        if self.initial_task:
            greeting += f" Vi que você quer: {self.initial_task}. Vou começar agora."

        self.speaker.speak(greeting)

        # Se tem tarefa inicial, processar primeiro
        if self.initial_task:
            narration, actions = self.brain.think(
                f"O usuário pediu: {self.initial_task}. Comece executando as ações necessárias."
            )
            print(f"\n  \033[1m🤖 Alfred:\033[0m {narration}\n")
            self.speaker.speak(narration, wait=False)

            if actions:
                screen = self.execute_actions(actions)
                # Falar resultado das ações
                while self.speaker.is_speaking():
                    time.sleep(0.2)
                narration2, actions2 = self.brain.think(
                    "Acabei de executar as ações. O que vejo na tela agora?",
                    screen_context=screen
                )
                print(f"\n  \033[1m🤖 Alfred:\033[0m {narration2}\n")
                self.speaker.speak(narration2, wait=False)
                if actions2:
                    screen = self.execute_actions(actions2)

        # Loop interativo
        while self.running:
            # Esperar TTS terminar antes de ouvir
            while self.speaker.is_speaking():
                time.sleep(0.2)

            # Ouvir usuário
            user_input = self.listener.listen()

            if not user_input:
                continue

            # Comandos de saída
            exit_words = ["para", "parar", "sair", "exit", "quit", "encerrar", "tchau"]
            if any(w in user_input.lower().split() for w in exit_words):
                self.speaker.speak("Beleza! Encerrando o copiloto. Até mais, Netto!")
                self.running = False
                break

            # Obter contexto da tela se temos PID ativo
            screen_context = ""
            if self.current_pid:
                screen_context = self.computer.get_screen_state(self.current_pid)

            # Processar com LLM
            print("  \033[33m🧠 Pensando...\033[0m")
            narration, actions = self.brain.think(user_input, screen_context)

            # Falar narração
            print(f"\n  \033[1m🤖 Alfred:\033[0m {narration}\n")
            self.speaker.speak(narration, wait=False)

            # Executar ações
            if actions:
                screen = self.execute_actions(actions)

                # Se teve ações, dar feedback do resultado
                while self.speaker.is_speaking():
                    time.sleep(0.2)

                narration2, actions2 = self.brain.think(
                    "Executei as ações. O que mudou na tela?",
                    screen_context=screen
                )
                print(f"\n  \033[1m🤖 Alfred:\033[0m {narration2}\n")
                self.speaker.speak(narration2, wait=False)

                # Executar ações de follow-up (máx 1 nível)
                if actions2:
                    screen2 = self.execute_actions(actions2)

        # Cleanup
        self.computer.close()
        print("\n  \033[90m👋 Copiloto encerrado.\033[0m\n")


# ══════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="Wolf Copilot — Alfred Interactive Voice + Computer Use")
    parser.add_argument("--voice", default="Luciana", help="Voz TTS (default: Luciana)")
    parser.add_argument("--task", default=None, help="Tarefa inicial (ex: 'abrir clawhub e analisar skills')")
    args = parser.parse_args()

    # Validar deps
    deps_ok = True
    for cmd in ["rec", "say", "curl"]:
        if subprocess.run(["which", cmd], capture_output=True).returncode != 0:
            print(f"  ERRO: '{cmd}' não encontrado. Instale antes de usar.")
            deps_ok = False
    if not GROQ_API_KEY:
        print("  ERRO: GROQ_API_KEY não configurada no ~/.openclaw/.env")
        deps_ok = False
    if not ANTHROPIC_API_KEY:
        print("  ERRO: ANTHROPIC_API_KEY não configurada no ~/.openclaw/.env")
        deps_ok = False
    if not Path(MCP_BIN).exists():
        print(f"  ERRO: MCP server não encontrado em {MCP_BIN}")
        deps_ok = False
    if not deps_ok:
        sys.exit(1)

    copilot = Copilot(voice=args.voice, initial_task=args.task)
    copilot.run()


if __name__ == "__main__":
    main()
