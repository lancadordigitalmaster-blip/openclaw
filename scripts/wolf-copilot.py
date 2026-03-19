#!/usr/bin/env python3
"""
wolf-copilot.py — Alfred Interactive Assistant
Wolf Agency — Computer Use + Voice

Modos de input:
  --mode text  : você digita, Alfred fala + navega (default)
  --mode voice : você fala no microfone, Alfred fala + navega (requer mic)
  --mode whatsapp : input via WhatsApp, Alfred fala + navega (via bridge)

Uso:
  python3 wolf-copilot.py --task "buscar tendencias de marketing digital"
  python3 wolf-copilot.py --mode voice --voice antonio
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
LOG_FILE = Path("/tmp/wolf-alfred.log")
RECORD_FILE = Path("/tmp/wolf-alfred-input.wav")
MCP_BIN = "/opt/homebrew/opt/mcp-server-macos-use/bin/mcp-server-macos-use"

# Carregar .env
def load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                key, _, val = line.partition("=")
                k, v = key.strip(), val.strip()
                # Forcar carregamento — sobrescreve se vazio ou ausente
                if v and (not os.environ.get(k) or len(os.environ.get(k, "")) < 5):
                    os.environ[k] = v

load_env()

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

# Gateway auth — lê token do openclaw.json
def load_gateway_token():
    try:
        oc_file = Path.home() / ".openclaw" / "openclaw.json"
        data = json.loads(oc_file.read_text())
        return data.get("gateway", {}).get("auth", {}).get("token", "")
    except Exception:
        return ""

GATEWAY_URL = "http://localhost:18789/v1/chat/completions"
GATEWAY_TOKEN = load_gateway_token()

# ── Logging ──
def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}"
    print(f"  \033[90m{entry}\033[0m")
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")


# ══════════════════════════════════════════════════════════
# TTS — Text-to-Speech via Edge TTS Neural
# ══════════════════════════════════════════════════════════

class Speaker:
    def __init__(self, voice="antonio"):
        self.process = None
        self.audio_file = Path("/tmp/wolf-alfred-tts.mp3")
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
            log("edge-tts indisponivel, fallback macOS say")
            self.voice = "Eddy"
        else:
            log(f"TTS: Edge Neural ({self.voice})")

    def _clean_text(self, text):
        clean = re.sub(r'[*_`#\[\]()]', '', text)
        clean = re.sub(r'\bhttps?://\S+', 'link', clean)
        clean = re.sub(r'<[^>]+>', '', clean)
        clean = clean.replace('\n', '. ').replace('  ', ' ')
        return clean[:2000].strip()

    def speak(self, text, wait=True):
        if not text or not text.strip():
            return
        clean = self._clean_text(text)
        if not clean:
            return

        log(f"TTS: {clean[:80]}...")

        if self.use_edge:
            txt_file = Path("/tmp/wolf-alfred-tts.txt")
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
        subprocess.run(["pkill", "-f", "afplay.*wolf-alfred-tts"],
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
    def __init__(self):
        self.groq_key = GROQ_API_KEY

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
                                "clientInfo": {"name": "alfred", "version": "2.0"}}})
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

Voce e Alfred — um sistema de inteligencia artificial inspirado no JARVIS do Tony Stark.
Seu usuario e o Netto, dono da Wolf Agency, agencia de marketing digital.
Voce o trata como "senhor" — sempre. Nunca pelo nome. Nunca casual.

CONTEXTO: Voce controla o Mac do senhor em tempo real. Suas respostas saem pelo alto-falante como voz.

PERSONALIDADE — ESTILO JARVIS:
- Formalidade elegante de mordomo britanico adaptada ao portugues brasileiro.
- SEMPRE use "senhor" — no inicio ou fim das frases, naturalmente.
- Humor SECO e SARCASTICO sutil. Nunca piadas obvias. Ironia fina e educada.
  Exemplos: "Sim, isso certamente vai ajudar o senhor a passar despercebido." / "Como sempre, senhor, um enorme prazer observar o senhor trabalhar." / "Preparei um briefing de seguranca para o senhor ignorar completamente."
- Calmo SEMPRE. Mesmo sob pressao. Mesmo com erro. Nunca perca a compostura.
- Problemas: use "Receio que..." ou "Infelizmente..." — nunca panico, nunca "eita" ou "bugou".
  Exemplo: "Receio que estamos com um pequeno contratempo, senhor. Permitame tentar uma abordagem alternativa."
- Proativo: ofereca informacoes ANTES de ser pedido quando relevante.
- NUNCA repita o que o senhor pediu. Ele diz algo, voce simplesmente age e narra com elegancia.
- Ao completar tarefas: "Algo mais, senhor?" ou "Sera tudo, senhor?"
- Saudacoes: "Bem-vindo, senhor." / "Bom dia, senhor." / "As suas ordens, senhor." / "Sempre, senhor."
- Disponibilidade: "Para o senhor, sempre." / "Prontamente, senhor."
- Conheca o senhor: antecipe necessidades, lembre preferencias, comente com familiaridade respeitosa.

FRASES UTEIS DO JARVIS ADAPTADAS:
- "Prontamente, senhor."
- "Como desejar, senhor."
- "Receio que isso nao sera possivel no momento, senhor."
- "Permita-me sugerir uma alternativa, senhor."
- "Interessante, senhor. Encontrei algo que pode ser relevante."
- "Tudo finalizado, senhor. Algo mais?"
- "Executando, senhor."
- "Se me permite a observacao, senhor..."

REGRAS DE RESPOSTA:
1. SEMPRE em portugues brasileiro
2. NAO use markdown, emojis, asteriscos ou formatacao — suas respostas viram audio
3. Maximo 2-3 frases por resposta — conciso e elegante
4. NUNCA repita o pedido. Apenas aja e narre.
5. Narre acoes de forma concisa: "Abrindo o navegador, senhor." / "Processando..." / "Finalizado."

ACOES DISPONIVEIS:
Retorne acoes entre tags <actions>...</actions> como JSON array.

Acoes possiveis:
- {"action": "open_app", "identifier": "com.apple.Safari"} — abre app
- {"action": "click", "x": 100, "y": 200} — clica na coordenada
- {"action": "click", "x": 100, "y": 200, "width": 50, "height": 30} — clica no centro do elemento
- {"action": "type", "text": "texto"} — digita texto
- {"action": "press_key", "key": "Return"} — pressiona tecla
- {"action": "press_key", "key": "l", "modifiers": ["Command"]} — atalho Cmd+L
- {"action": "scroll", "x": 500, "y": 400, "delta_y": -3} — scroll (negativo=baixo)
- {"action": "refresh"} — le tela atual
- {"action": "wait", "seconds": 2} — esperar

REGRA CRITICA — SEMPRE AGIR:
- Quando o senhor pede algo, GERE acoes <actions> imediatamente. Nao fique apenas descrevendo o que pretende fazer.
- Se precisa buscar informacoes, abra o Safari e navegue.
- Se nenhum app esta aberto, comece com open_app.

NAVEGACAO:
- Extraia coordenadas dos elementos visiveis no [ESTADO DA TELA]
- URLs: Cmd+L para focar barra, type URL, press_key Return
- Apos agir, faca refresh para ver resultado
- Leia elementos ANTES de clicar — nao estime coordenadas

FORMATO:
Narracao elegante aqui, senhor.

<actions>
[{"action": "...", ...}]
</actions>"""


class Brain:
    def __init__(self):
        self.history = []
        self.model = "anthropic/claude-haiku-4-5-20251001"

    def think(self, user_input, screen_context=""):
        content = user_input
        if screen_context:
            if len(screen_context) > 6000:
                screen_context = screen_context[:6000] + "\n[...truncado]"
            content += f"\n\n[ESTADO DA TELA]\n{screen_context}"

        # Montar mensagens com system prompt como primeira mensagem de sistema
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        self.history.append({"role": "user", "content": content})
        messages.extend(self.history[-12:])

        try:
            import urllib.request
            import urllib.error

            payload = json.dumps({
                "model": self.model,
                "max_tokens": 2048,
                "messages": messages
            }).encode("utf-8")

            log(f"Brain: chamando gateway ({self.model})")
            req = urllib.request.Request(
                GATEWAY_URL,
                data=payload,
                headers={
                    "Authorization": f"Bearer {GATEWAY_TOKEN}",
                    "content-type": "application/json",
                },
                method="POST"
            )

            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    raw = resp.read().decode("utf-8")
            except urllib.error.HTTPError as e:
                raw = e.read().decode("utf-8")
                log(f"Brain: HTTP {e.code}: {raw[:200]}")

            log(f"Brain: resposta={raw[:300]}")
            if not raw or not raw.strip():
                return "Receio que nao obtive resposta, senhor. Permitame tentar novamente.", []

            data = json.loads(raw)
            if "error" in data:
                log(f"LLM Error: {data['error']}")
                return "Receio que tive um contratempo, senhor. Pode repetir?", []

            # Formato OpenAI-compatible do gateway
            full_text = ""
            choices = data.get("choices", [])
            if choices:
                full_text = choices[0].get("message", {}).get("content", "")

            if not full_text:
                log("LLM: resposta vazia")
                return "Infelizmente nao recebi retorno, senhor. Tentando novamente.", []

            self.history.append({"role": "assistant", "content": full_text})

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
            return "Receio que tive um problema de conexao, senhor. Um momento.", []


# ══════════════════════════════════════════════════════════
# Alfred — Loop principal
# ══════════════════════════════════════════════════════════

class Alfred:
    def __init__(self, voice="antonio", input_mode="text", initial_task=None):
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
        print("\n\n  \033[31mAlfred encerrando...\033[0m")
        self.running = False
        self.speaker.stop()
        self.computer.close()
        sys.exit(0)

    def execute_actions(self, actions):
        screen_result = ""
        for action in actions:
            act = action.get("action", "")
            log(f"Acao: {act}")
            print(f"  \033[35m> {act}\033[0m", end="")

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
                    print(" → ok")

                elif act == "wait":
                    secs = action.get("seconds", 2)
                    time.sleep(secs)
                    print(f" → {secs}s")

                else:
                    print(f" → ?")

            except Exception as e:
                log(f"Erro executando {act}: {e}")
                print(f" → ERRO: {e}")

        return screen_result

    def process_turn(self, user_input):
        screen_context = ""
        if self.current_pid:
            screen_context = self.computer.refresh(self.current_pid)

        print("  \033[33m...\033[0m")
        narration, actions = self.brain.think(user_input, screen_context)

        # Mostrar e falar
        print(f"\n  \033[1mAlfred:\033[0m {narration}\n")
        self.speaker.speak(narration, wait=False)

        # Executar acoes
        if actions:
            screen = self.execute_actions(actions)
            self.speaker.wait_done()

            # Follow-ups autonomos (ate 6 passos)
            for i in range(6):
                narration2, actions2 = self.brain.think(
                    "[SISTEMA] Acoes executadas. Analise o estado da tela. "
                    "Continue a tarefa se nao esta completa — gere mais acoes. "
                    "Se esta completa, apresente os resultados de forma concisa e elegante, "
                    "e encerre com algo como 'Algo mais, senhor?' ou 'Sera tudo, senhor?'",
                    screen_context=screen
                )
                print(f"\n  \033[1mAlfred:\033[0m {narration2}\n")
                self.speaker.speak(narration2, wait=False)

                if not actions2:
                    break

                screen = self.execute_actions(actions2)
                self.speaker.wait_done()

    def run(self):
        mode_label = {"text": "Teclado", "voice": "Microfone", "whatsapp": "WhatsApp"}

        print("\n" + "=" * 50)
        print("  \033[1mAlfred — Wolf Agency\033[0m")
        print(f"  Input: {mode_label.get(self.input_mode, self.input_mode)}")
        print(f"  Voz: {self.speaker.voice}")
        print("=" * 50)
        if self.input_mode == "text":
            print("  Digite seus comandos. 'sair' para encerrar.\n")
        else:
            print("  Fale naturalmente. 'sair' para encerrar.\n")

        # Saudacao
        if self.initial_task:
            greeting = "Prontamente, senhor."
            self.speaker.speak(greeting)
            self.process_turn(self.initial_task)
        else:
            greeting = "As suas ordens, senhor. No que posso ser util?"
            self.speaker.speak(greeting)

        # Loop interativo
        while self.running:
            self.speaker.wait_done()

            user_input = self.input_handler.listen()
            if not user_input:
                continue

            exit_words = ["para", "parar", "sair", "exit", "quit", "encerrar", "tchau"]
            if any(w == user_input.lower().strip() for w in exit_words):
                self.speaker.speak("Estarei aqui caso precise, senhor. Tenha um bom dia.")
                self.speaker.wait_done()
                break

            self.process_turn(user_input)

        self.computer.close()
        print("\n  \033[90mAlfred encerrado.\033[0m\n")


# ══════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Alfred — Wolf Agency Interactive Assistant",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python3 wolf-copilot.py
  python3 wolf-copilot.py --task "buscar tendencias marketing digital"
  python3 wolf-copilot.py --voice antonio --task "abrir safari e pesquisar noticias"
  python3 wolf-copilot.py --mode voice
        """)
    parser.add_argument("--voice", default="antonio",
                        help="Voz TTS: antonio, francisca, thalita (default: antonio)")
    parser.add_argument("--mode", default="text", choices=["text", "voice"],
                        help="Modo de input: text ou voice (default: text)")
    parser.add_argument("--task", default=None,
                        help="Tarefa inicial para executar")
    args = parser.parse_args()

    ok = True
    if not GATEWAY_TOKEN:
        print("  ERRO: Gateway token nao encontrado em ~/.openclaw/openclaw.json")
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

    alfred = Alfred(voice=args.voice, input_mode=args.mode, initial_task=args.task)
    alfred.run()


if __name__ == "__main__":
    main()
