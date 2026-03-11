const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  downloadMediaMessage,
  proto,
} = require("@whiskeysockets/baileys");
const Anthropic = require("@anthropic-ai/sdk");
const pino = require("pino");
const qrcode = require("qrcode-terminal");
const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");
const { execSync, execFile } = require("child_process");

// ============================================================
// CONFIG
// ============================================================
const AUTH_DIR = path.join(__dirname, "auth_state");
const SESSIONS_DIR = path.join(__dirname, "sessions");
const GROUPS_DIR = path.join(__dirname, "groups");
const LOG_DIR = path.join(__dirname, "logs");
const SOUL_PATH = path.resolve(
  process.env.SOUL_PATH || "/Users/thomasgirotto/.openclaw/workspace/SOUL.md"
);
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || "";
const GROQ_API_KEY = process.env.GROQ_API_KEY || "";
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || "";
const MODEL = process.env.MODEL || "claude-sonnet-4-6";
const MAX_HISTORY = 30;
const MAX_MSG_LENGTH = 4000;
const MAX_RETRIES = 2;
const REMINDERS_FILE = path.join(__dirname, "reminders.json");
const ALLOWED_NUMBERS = (process.env.ALLOWED_NUMBERS || "")
  .split(",")
  .filter(Boolean);

// ============================================================
// REMINDERS SYSTEM
// ============================================================
function loadReminders() {
  try {
    if (fs.existsSync(REMINDERS_FILE)) {
      return JSON.parse(fs.readFileSync(REMINDERS_FILE, "utf-8"));
    }
  } catch {}
  return [];
}

function saveReminders(reminders) {
  fs.writeFileSync(REMINDERS_FILE, JSON.stringify(reminders, null, 2));
}

function startReminderChecker() {
  setInterval(async () => {
    try {
      const reminders = loadReminders();
      if (reminders.length === 0) return;

      const now = new Date();
      const nowSP = new Date(now.toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }));
      let changed = false;

      for (const r of reminders) {
        if (r.fired) continue;
        const triggerTime = new Date(r.triggerAt);
        if (nowSP >= triggerTime) {
          // Fire reminder
          try {
            if (activeSock) {
              const jid = r.recipientJid || `${r.recipientPhone}@s.whatsapp.net`;
              const msg = `⏰ *LEMBRETE*\n\n${r.message}\n\n_Agendado em ${r.createdAt}_`;
              await activeSock.sendMessage(jid, { text: msg });
              log("reminder", `Lembrete disparado para ${r.recipientPhone}: ${r.message.slice(0, 50)}`);
            }
          } catch (err) {
            logError("reminder", "Erro ao enviar lembrete", err);
          }
          r.fired = true;
          changed = true;
        }
      }

      if (changed) {
        // Remove fired reminders older than 24h
        const cleaned = reminders.filter(r => {
          if (!r.fired) return true;
          const firedAgo = now - new Date(r.triggerAt);
          return firedAgo < 24 * 60 * 60 * 1000;
        });
        saveReminders(cleaned);
      }
    } catch (err) {
      logError("reminder", "Erro no checker", err);
    }
  }, 30 * 1000); // Check every 30 seconds
}

// ============================================================
// INIT
// ============================================================
for (const dir of [SESSIONS_DIR, GROUPS_DIR, LOG_DIR]) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

// API key is resolved dynamically — reloads from .env or OpenClaw auth-profiles on each call
function resolveAnthropicKey() {
  // 1. Try env var (set by start.sh from .env)
  if (process.env.ANTHROPIC_API_KEY) return process.env.ANTHROPIC_API_KEY;
  // 2. Try reading fresh from .env file
  try {
    const envFile = "/Users/thomasgirotto/.openclaw/.env";
    const content = fs.readFileSync(envFile, "utf-8");
    const match = content.match(/^ANTHROPIC_API_KEY=(.+)$/m);
    if (match && match[1].trim()) return match[1].trim();
  } catch {}
  // 3. Try OpenClaw auth-profiles
  try {
    const authFile = "/Users/thomasgirotto/.openclaw/agents/main/agent/auth-profiles.json";
    const data = JSON.parse(fs.readFileSync(authFile, "utf-8"));
    const profile = data.profiles?.["anthropic:default"];
    if (profile?.key) return profile.key;
  } catch {}
  return ANTHROPIC_API_KEY; // original fallback
}

let anthropic = new Anthropic({ apiKey: resolveAnthropicKey() });
const logger = pino({ level: "warn" });
const sessions = new Map();
const groupsMeta = new Map(); // groupJid -> { name, subject, participants }
const messageQueues = new Map(); // phone -> Promise chain (serialize per user)
let soulPromptCache = { text: "", mtime: 0 };
let myLidCache = ""; // LID (Linked Identity) cached from auth creds

// ============================================================
// LOGGING
// ============================================================
function log(tag, msg) {
  const ts = new Date().toISOString();
  const line = `${ts} [${tag}] ${msg}`;
  console.log(line);
}

function logError(tag, msg, err) {
  const ts = new Date().toISOString();
  const line = `${ts} [${tag}] ${msg}: ${err?.message || err}`;
  console.error(line);
}

// ============================================================
// SOUL PROMPT (cached, reloads on file change)
// ============================================================
function loadSoulPrompt() {
  try {
    const stat = fs.statSync(SOUL_PATH);
    if (stat.mtimeMs !== soulPromptCache.mtime) {
      soulPromptCache.text = fs.readFileSync(SOUL_PATH, "utf-8");
      soulPromptCache.mtime = stat.mtimeMs;
      log("soul", "SOUL.md recarregado");
    }
    return soulPromptCache.text;
  } catch (err) {
    logError("soul", "Erro ao ler SOUL.md", err);
    return "Voce e Alfred, assistente da Wolf Agency. Responda em portugues do Brasil.";
  }
}

// ============================================================
// SESSION PERSISTENCE
// ============================================================
function sessionPath(phone) {
  return path.join(SESSIONS_DIR, `${phone}.json`);
}

function loadSessionFromDisk(phone) {
  try {
    const file = sessionPath(phone);
    if (fs.existsSync(file)) {
      const data = JSON.parse(fs.readFileSync(file, "utf-8"));
      // Sessoes com imagens base64 no historico ficam pesadas — limitar
      const history = (data.history || []).map((msg) => {
        if (Array.isArray(msg.content)) {
          // Remover imagens antigas do historico persistido para nao inflar disco
          return {
            ...msg,
            content: msg.content.filter((b) => b.type !== "image"),
          };
        }
        return msg;
      }).filter((msg) => {
        // Remover mensagens vazias apos filtrar imagens
        if (Array.isArray(msg.content) && msg.content.length === 0) return false;
        return true;
      });
      return { history, lastActivity: data.lastActivity || Date.now() };
    }
  } catch (err) {
    logError("session", `Erro ao carregar ${phone}`, err);
  }
  return null;
}

function saveSessionToDisk(phone, session) {
  try {
    // Salvar sem imagens base64 (pesado demais)
    const history = session.history.map((msg) => {
      if (Array.isArray(msg.content)) {
        return {
          ...msg,
          content: msg.content.filter((b) => b.type !== "image"),
        };
      }
      return msg;
    }).filter((msg) => {
      if (Array.isArray(msg.content) && msg.content.length === 0) return false;
      return true;
    });
    fs.writeFileSync(
      sessionPath(phone),
      JSON.stringify({ history, lastActivity: session.lastActivity }),
      "utf-8"
    );
  } catch (err) {
    logError("session", `Erro ao salvar ${phone}`, err);
  }
}

function getSession(phone) {
  if (!sessions.has(phone)) {
    const saved = loadSessionFromDisk(phone);
    if (saved) {
      sessions.set(phone, saved);
      log("session", `Restaurada: ${phone} (${saved.history.length} msgs)`);
    } else {
      sessions.set(phone, { history: [], lastActivity: Date.now() });
      log("session", `Nova: ${phone}`);
    }
  }
  const session = sessions.get(phone);
  session.lastActivity = Date.now();
  return session;
}

// Limpeza periódica (salvar + expirar inativas)
setInterval(() => {
  const now = Date.now();
  for (const [phone, session] of sessions) {
    if (now - session.lastActivity > 2 * 60 * 60 * 1000) {
      log("session", `Expirada: ${phone}`);
      sessions.delete(phone);
      try { fs.unlinkSync(sessionPath(phone)); } catch {}
    } else {
      saveSessionToDisk(phone, session);
    }
  }
}, 5 * 60 * 1000);

// ============================================================
// MESSAGE QUEUE (serialize per user — prevent race conditions)
// ============================================================
function enqueue(phone, fn) {
  const prev = messageQueues.get(phone) || Promise.resolve();
  const next = prev.then(fn).catch((err) => {
    logError("queue", `Erro na fila de ${phone}`, err);
  });
  messageQueues.set(phone, next);
  return next;
}

// ============================================================
// AUDIO TRANSCRIPTION (ffmpeg + Groq Whisper)
// ============================================================
async function transcribeAudio(buffer) {
  if (!GROQ_API_KEY) {
    return "[Audio recebido mas transcrição não disponível no momento]";
  }

  const id = Date.now();
  const tmpInput = `/tmp/wa-audio-${id}.ogg`;
  const tmpOutput = `/tmp/wa-audio-${id}.m4a`;

  try {
    fs.writeFileSync(tmpInput, buffer);

    execSync(
      `/opt/homebrew/bin/ffmpeg -y -i "${tmpInput}" -c:a aac -b:a 128k "${tmpOutput}" 2>/dev/null`,
      { timeout: 30000 }
    );

    const result = execSync(
      `curl -s --max-time 60 https://api.groq.com/openai/v1/audio/transcriptions ` +
        `-H "Authorization: Bearer ${GROQ_API_KEY}" ` +
        `-F "file=@${tmpOutput}" ` +
        `-F "model=whisper-large-v3" ` +
        `-F "language=pt" ` +
        `-F "response_format=text"`,
      { timeout: 75000 }
    )
      .toString()
      .trim();

    log("audio", `Transcrito (${result.length} chars): "${result.slice(0, 80)}"`);
    return result || "[Audio vazio ou inaudivel]";
  } catch (err) {
    logError("audio", "Erro na transcricao", err);
    return "[Erro ao transcrever audio — tente enviar como texto]";
  } finally {
    try { fs.unlinkSync(tmpInput); } catch {}
    try { fs.unlinkSync(tmpOutput); } catch {}
  }
}

// ============================================================
// VIDEO → AUDIO TRANSCRIPTION
// ============================================================
async function transcribeVideo(buffer) {
  if (!GROQ_API_KEY) {
    return "[Video recebido mas transcrição não disponível no momento]";
  }

  const id = Date.now();
  const tmpInput = `/tmp/wa-video-${id}.mp4`;
  const tmpOutput = `/tmp/wa-video-${id}.m4a`;

  try {
    fs.writeFileSync(tmpInput, buffer);

    // Extrair apenas audio do video
    execSync(
      `/opt/homebrew/bin/ffmpeg -y -i "${tmpInput}" -vn -c:a aac -b:a 128k "${tmpOutput}" 2>/dev/null`,
      { timeout: 60000 }
    );

    const result = execSync(
      `curl -s --max-time 60 https://api.groq.com/openai/v1/audio/transcriptions ` +
        `-H "Authorization: Bearer ${GROQ_API_KEY}" ` +
        `-F "file=@${tmpOutput}" ` +
        `-F "model=whisper-large-v3" ` +
        `-F "language=pt" ` +
        `-F "response_format=text"`,
      { timeout: 75000 }
    )
      .toString()
      .trim();

    log("video", `Audio transcrito (${result.length} chars)`);
    return result || "[Audio do video vazio ou inaudivel]";
  } catch (err) {
    logError("video", "Erro na transcricao", err);
    return "[Erro ao transcrever audio do video]";
  } finally {
    try { fs.unlinkSync(tmpInput); } catch {}
    try { fs.unlinkSync(tmpOutput); } catch {}
  }
}

// ============================================================
// TELEGRAM BRIDGE (forward messages to Telegram)
// ============================================================
function sendTelegram(chatId, text) {
  return new Promise((resolve, reject) => {
    if (!TELEGRAM_BOT_TOKEN) {
      return reject(new Error("TELEGRAM_BOT_TOKEN não configurado"));
    }
    const payload = JSON.stringify({
      chat_id: chatId || TELEGRAM_CHAT_ID,
      text: text.slice(0, 4096),
      parse_mode: "Markdown",
    });
    const req = https.request(
      {
        hostname: "api.telegram.org",
        path: `/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        let body = "";
        res.on("data", (d) => (body += d));
        res.on("end", () => resolve(body));
      }
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

// ============================================================
// CUSTOM TOOLS FOR ANTHROPIC
// ============================================================
const customTools = [
  {
    name: "get_current_datetime",
    description:
      "Retorna a data e hora atual no fuso de Brasilia (America/Sao_Paulo). Use para responder perguntas sobre data, hora, dia da semana.",
    input_schema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "send_telegram_notification",
    description:
      "Envia uma notificação para o Telegram do Netto. Use quando o usuario pedir para avisar no Telegram, enviar lembrete, ou quando algo urgente precisar ser comunicado fora do WhatsApp.",
    input_schema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "Texto da mensagem a enviar no Telegram",
        },
      },
      required: ["message"],
    },
  },
  {
    name: "read_file",
    description:
      "Le o conteudo de um arquivo do workspace Wolf Agency. Pode ler documentos, configs, dados de clientes, etc. Caminho base: /Users/thomasgirotto/.openclaw/workspace/",
    input_schema: {
      type: "object",
      properties: {
        filepath: {
          type: "string",
          description:
            "Caminho relativo ao workspace (ex: shared/memory/clients.yaml) ou absoluto",
        },
      },
      required: ["filepath"],
    },
  },
  {
    name: "write_file",
    description:
      "Salva conteudo em um arquivo no workspace. Use para gerar propostas HTML, relatorios, exports, etc. O arquivo fica acessivel via http://localhost:3002/files/[caminho]. Para propostas, salve em skills/page-architect/output/proposta-[slug].html",
    input_schema: {
      type: "object",
      properties: {
        filepath: {
          type: "string",
          description:
            "Caminho relativo ao workspace (ex: skills/page-architect/output/proposta-wesley.html)",
        },
        content: {
          type: "string",
          description: "Conteudo completo do arquivo a ser salvo",
        },
      },
      required: ["filepath", "content"],
    },
  },
  {
    name: "list_files",
    description:
      "Lista arquivos de um diretorio do workspace. Util para ver o que existe em uma pasta.",
    input_schema: {
      type: "object",
      properties: {
        directory: {
          type: "string",
          description:
            "Caminho relativo ao workspace (ex: skills/) ou absoluto",
        },
      },
      required: ["directory"],
    },
  },
  {
    name: "search_group_messages",
    description:
      "Busca mensagens nos grupos de WhatsApp monitorados. Use para analisar conversas, levantar dados, verificar pendencias, faturamento, formularios enviados, etc. Pode filtrar por grupo, data, remetente e palavra-chave.",
    input_schema: {
      type: "object",
      properties: {
        group_name: {
          type: "string",
          description:
            "Nome parcial do grupo para filtrar (ex: 'vendas', 'financeiro'). Deixe vazio para todos os grupos.",
        },
        date_from: {
          type: "string",
          description: "Data inicial no formato YYYY-MM-DD (ex: 2026-03-01)",
        },
        date_to: {
          type: "string",
          description:
            "Data final no formato YYYY-MM-DD (ex: 2026-03-08). Se omitido, usa a mesma que date_from.",
        },
        keyword: {
          type: "string",
          description:
            "Palavra-chave para filtrar mensagens (ex: 'formulario', 'pagamento', 'valor'). Deixe vazio para todas.",
        },
        sender_name: {
          type: "string",
          description:
            "Nome parcial do remetente para filtrar (ex: 'gabriela', 'netto'). Deixe vazio para todos.",
        },
      },
      required: ["date_from"],
    },
  },
  {
    name: "list_groups",
    description:
      "Lista todos os grupos de WhatsApp monitorados com nome, numero de participantes e quantidade de mensagens capturadas.",
    input_schema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "send_group_message",
    description:
      "Envia uma mensagem para um grupo de WhatsApp. Use para cobrar pendencias, enviar lembretes, ou comunicar algo no grupo. Cuidado: use apenas quando o usuario pedir explicitamente para enviar algo no grupo.",
    input_schema: {
      type: "object",
      properties: {
        group_name: {
          type: "string",
          description: "Nome parcial do grupo (ex: 'vendas', 'financeiro')",
        },
        message: {
          type: "string",
          description: "Texto da mensagem a enviar no grupo",
        },
      },
      required: ["group_name", "message"],
    },
  },
  {
    name: "fetch_group_history",
    description:
      "Busca mensagens HISTORICAS de um grupo de WhatsApp direto do servidor. Use quando precisar de mensagens anteriores a data de ativacao da bridge. Retorna mensagens mais antigas que as ja capturadas. IMPORTANTE: requer restart da bridge para funcionar na primeira vez.",
    input_schema: {
      type: "object",
      properties: {
        group_name: {
          type: "string",
          description: "Nome parcial do grupo (ex: 'vendas', 'financeiro')",
        },
        count: {
          type: "number",
          description: "Quantidade de mensagens para buscar (default: 50, max: 500)",
        },
      },
      required: ["group_name"],
    },
  },
  {
    name: "set_reminder",
    description:
      "Agenda um lembrete para ser enviado no WhatsApp privado do usuario no horario especificado. Use quando o usuario pedir para ser lembrado de algo. Interprete a linguagem natural e converta para datetime. Fuso: America/Sao_Paulo.",
    input_schema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "Texto do lembrete (ex: 'Ligar pro cliente Joao sobre o orcamento')",
        },
        datetime: {
          type: "string",
          description: "Data e hora no formato YYYY-MM-DDTHH:MM (fuso Sao Paulo). Ex: '2026-03-10T15:00'. Se o usuario disse 'amanha as 9h', calcule a data correta.",
        },
      },
      required: ["message", "datetime"],
    },
  },
  {
    name: "list_reminders",
    description:
      "Lista todos os lembretes agendados (pendentes e recentes). Use quando o usuario perguntar quais lembretes tem agendados.",
    input_schema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "cancel_reminder",
    description:
      "Cancela um lembrete agendado pelo indice (numero). Use list_reminders primeiro para ver os indices.",
    input_schema: {
      type: "object",
      properties: {
        index: {
          type: "number",
          description: "Indice do lembrete a cancelar (comecando em 1)",
        },
      },
      required: ["index"],
    },
  },
  {
    name: "clickup_tasks",
    description:
      "Busca tarefas do ClickUp com filtros. Use para consultar contas a receber, contas a pagar, ou qualquer lista do ClickUp. Retorna dados limpos (sem custom_fields inflados).",
    input_schema: {
      type: "object",
      properties: {
        list: {
          type: "string",
          description: "Qual lista buscar: 'receber' (contas a receber), 'pagar' (contas a pagar), ou ID numérico da lista",
        },
        status: {
          type: "string",
          description: "Filtrar por status (ex: 'para receber', 'para pagar', 'vencido', 'pago'). Deixe vazio para todos.",
        },
        include_closed: {
          type: "boolean",
          description: "Incluir tarefas fechadas? Default: false",
        },
      },
      required: ["list"],
    },
  },
  {
    name: "web_request",
    description:
      "Faz uma requisicao HTTP GET para buscar dados de APIs ou paginas web. Use para consultar APIs, verificar status de servicos, buscar informacoes.",
    input_schema: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "URL completa para requisitar (ex: https://api.example.com/data)",
        },
        headers: {
          type: "object",
          description: "Headers HTTP opcionais (ex: { Authorization: 'Bearer xxx' })",
        },
      },
      required: ["url"],
    },
  },
  {
    name: "figma_board",
    description:
      "Le o conteudo de um board ou arquivo do Figma via API. Extrai toda a estrutura, textos, cores, tipografia e componentes. Use quando o usuario pedir para extrair design system de um link do Figma, ou quando precisar ler o board 'Design System Creator' (file_key padrao: aSM8Ga9rLeliEmAIHtbS3w).",
    input_schema: {
      type: "object",
      properties: {
        file_key: {
          type: "string",
          description: "File key do Figma (parte da URL entre /file/ e /). Default: aSM8Ga9rLeliEmAIHtbS3w",
        },
        node_ids: {
          type: "string",
          description: "IDs de nodes especificos separados por virgula (opcional). Se omitido, le o arquivo inteiro.",
        },
        export_images: {
          type: "boolean",
          description: "Se true, exporta os nodes principais como URLs de imagem PNG (para analise visual).",
        },
      },
      required: [],
    },
  },
  {
    name: "deploy_proposal",
    description:
      "Faz deploy de uma proposta HTML para a internet via Vercel. Retorna a URL publica para enviar ao cliente. Use APOS salvar o arquivo com write_file.",
    input_schema: {
      type: "object",
      properties: {
        filepath: {
          type: "string",
          description:
            "Caminho do arquivo HTML relativo ao workspace (ex: skills/page-architect/output/proposta-wesley-ramos.html)",
        },
        site_name: {
          type: "string",
          description:
            "Nome curto para a URL (ex: proposta-wesley). Sera usado como path: vercel-wolfpack-proposals.vercel.app/proposta-wesley",
        },
      },
      required: ["filepath"],
    },
  },
  {
    name: "build_proposal",
    description:
      "Monta uma proposta comercial HTML cinematografica a partir de dados JSON. Use esta ferramenta SEMPRE que precisar gerar uma proposta. Voce so precisa fornecer os dados estruturados — o script monta o HTML completo automaticamente usando o template Wolf. Apos montar, faz deploy automatico no Vercel e retorna a URL publica.",
    input_schema: {
      type: "object",
      properties: {
        client_name: { type: "string", description: "Nome do cliente" },
        tagline: { type: "string", description: "Frase de impacto da capa (ex: 'Autoridade construida. Audiencia conquistada.')" },
        service_type: { type: "string", description: "Tipo de servico (ex: 'Marca Pessoal', 'Social Media')" },
        year: { type: "string", description: "Ano da proposta (default: ano atual)" },
        whatsapp: { type: "string", description: "Numero WhatsApp para CTA (default: 5573991484716)" },
        ticker_items: { type: "array", items: { type: "string" }, description: "Palavras-chave dos servicos para o ticker animado" },
        context: {
          type: "object",
          properties: {
            heading: { type: "string", description: "Titulo da secao contexto (ex: 'Quem e Wesley Ramos')" },
            bio_paragraphs: { type: "array", items: { type: "string" }, description: "Paragrafos da bio do cliente. Use **negrito** para destaques." },
            badges: { type: "array", items: { type: "string" }, description: "Badges de expertise (ex: '16+ anos na corporacao')" },
            objectives: { type: "array", items: { type: "string" }, description: "Lista de objetivos do projeto" }
          }
        },
        services: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              tag: { type: "string" },
              bullets: { type: "array", items: { type: "string" } }
            }
          },
          description: "Servicos oferecidos (viram accordion interativo)"
        },
        deliverables: {
          type: "array",
          items: {
            type: "object",
            properties: {
              badge: { type: "string" },
              title: { type: "string" },
              highlight: { type: "boolean" },
              rows: { type: "array", items: { type: "object", properties: { label: { type: "string" }, value: { type: "string" } } } }
            }
          },
          description: "Entregaveis por fase"
        },
        investment: {
          type: "object",
          properties: {
            currency: { type: "string", description: "Moeda (default: R$)" },
            amount: { type: "string", description: "Valor (ex: '4.500')" },
            suffix: { type: "string", description: "Sufixo (ex: '/mes')" },
            payment_options: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  title: { type: "string" },
                  desc: { type: "string" },
                  highlight: { type: "boolean" }
                }
              }
            }
          }
        },
        support: { type: "array", items: { type: "string" }, description: "Itens de suporte inclusos" },
        close: {
          type: "object",
          properties: {
            heading: { type: "string", description: "Headline de fechamento" },
            body: { type: "string", description: "Texto de apoio do fechamento" },
            cta_text: { type: "string", description: "Texto do botao CTA (default: 'Falar com a Wolf')" }
          }
        },
        template: { type: "string", enum: ["classic"], description: "Estilo do template. Apenas 'classic' disponivel no momento." }
      },
      required: ["client_name", "services"],
    },
  },
];

async function executeCustomTool(name, input) {
  const WORKSPACE = "/Users/thomasgirotto/.openclaw/workspace";

  switch (name) {
    case "get_current_datetime": {
      const now = new Date().toLocaleString("pt-BR", {
        timeZone: "America/Sao_Paulo",
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });
      return `Data/hora atual (Brasilia): ${now}`;
    }

    case "send_telegram_notification": {
      try {
        await sendTelegram(TELEGRAM_CHAT_ID, input.message);
        return "Notificacao enviada com sucesso no Telegram.";
      } catch (err) {
        return `Erro ao enviar Telegram: ${err.message}`;
      }
    }

    case "set_reminder": {
      try {
        const reminders = loadReminders();
        const triggerAt = input.datetime; // YYYY-MM-DDTHH:MM
        const now = new Date().toLocaleString("pt-BR", {
          timeZone: "America/Sao_Paulo",
          day: "2-digit", month: "2-digit", year: "numeric",
          hour: "2-digit", minute: "2-digit"
        });
        // recipientPhone will be set by the caller context
        const reminder = {
          message: input.message,
          triggerAt: triggerAt,
          recipientPhone: "557382256278", // Netto (default)
          recipientJid: "557382256278@s.whatsapp.net",
          createdAt: now,
          fired: false,
        };
        reminders.push(reminder);
        saveReminders(reminders);
        const triggerDate = new Date(triggerAt);
        const formatted = triggerDate.toLocaleString("pt-BR", {
          timeZone: "America/Sao_Paulo",
          day: "2-digit", month: "2-digit",
          hour: "2-digit", minute: "2-digit"
        });
        log("reminder", `Agendado: "${input.message}" para ${formatted}`);
        return `Lembrete agendado com sucesso!\n📅 ${formatted}\n💬 ${input.message}`;
      } catch (err) {
        return `Erro ao agendar lembrete: ${err.message}`;
      }
    }

    case "list_reminders": {
      const reminders = loadReminders();
      const pending = reminders.filter(r => !r.fired);
      if (pending.length === 0) {
        return "Nenhum lembrete agendado.";
      }
      return "Lembretes agendados:\n\n" + pending.map((r, i) => {
        const dt = new Date(r.triggerAt).toLocaleString("pt-BR", {
          timeZone: "America/Sao_Paulo",
          day: "2-digit", month: "2-digit",
          hour: "2-digit", minute: "2-digit"
        });
        return `${i + 1}. 📅 ${dt} — ${r.message}`;
      }).join("\n");
    }

    case "cancel_reminder": {
      const reminders = loadReminders();
      const pending = reminders.filter(r => !r.fired);
      const idx = (input.index || 1) - 1;
      if (idx < 0 || idx >= pending.length) {
        return `Indice invalido. Use list_reminders para ver os indices (1-${pending.length}).`;
      }
      const target = pending[idx];
      target.fired = true; // Mark as fired to remove
      saveReminders(reminders);
      return `Lembrete cancelado: "${target.message}"`;
    }

    case "read_file": {
      try {
        let filepath = input.filepath;
        if (!path.isAbsolute(filepath)) {
          filepath = path.join(WORKSPACE, filepath);
        }
        // Security: block reading sensitive files
        if (filepath.includes(".env") || filepath.includes("credentials")) {
          return "Acesso negado: arquivo sensivel.";
        }
        const content = fs.readFileSync(filepath, "utf-8");
        // Limitar tamanho
        return content.length > 30000
          ? content.slice(0, 30000) + "\n\n[... truncado ...]"
          : content;
      } catch (err) {
        return `Erro ao ler arquivo: ${err.message}`;
      }
    }

    case "write_file": {
      try {
        let filepath = input.filepath;
        if (!path.isAbsolute(filepath)) {
          filepath = path.join(WORKSPACE, filepath);
        }
        // Security: block writing sensitive locations
        if (filepath.includes(".env") || filepath.includes("credentials") || filepath.includes("..")) {
          return "Acesso negado: caminho sensivel ou inseguro.";
        }
        // Ensure directory exists
        const dir = path.dirname(filepath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(filepath, input.content, "utf-8");
        // Return accessible URL
        const relPath = path.relative(WORKSPACE, filepath);
        return `Arquivo salvo com sucesso!\nLocal: ${filepath}\nAcesse: http://localhost:3002/files/${relPath}\nTamanho: ${input.content.length} caracteres`;
      } catch (err) {
        return `Erro ao salvar arquivo: ${err.message}`;
      }
    }

    case "list_files": {
      try {
        let dir = input.directory;
        if (!path.isAbsolute(dir)) {
          dir = path.join(WORKSPACE, dir);
        }
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        return entries
          .map((e) => `${e.isDirectory() ? "📁" : "📄"} ${e.name}`)
          .join("\n");
      } catch (err) {
        return `Erro ao listar diretorio: ${err.message}`;
      }
    }

    case "clickup_tasks": {
      return new Promise((resolve) => {
        try {
          // Load ClickUp API key from .env
          let clickupKey = process.env.CLICKUP_API_TOKEN || "";
          if (!clickupKey) {
            try {
              const envContent = fs.readFileSync("/Users/thomasgirotto/.openclaw/.env", "utf-8");
              const match = envContent.match(/^CLICKUP_API_TOKEN=(.+)$/m);
              if (match) clickupKey = match[1].trim();
            } catch {}
          }
          if (!clickupKey) {
            resolve("Erro: CLICKUP_API_TOKEN nao encontrada no .env");
            return;
          }

          // Resolve list ID
          const listMap = {
            "receber": "901305981568",
            "pagar": "901305981569",
          };
          const listId = listMap[input.list?.toLowerCase()] || input.list;

          // Build URL with query params
          const params = new URLSearchParams();
          if (input.status) params.append("statuses[]", input.status);
          params.append("include_closed", input.include_closed ? "true" : "false");
          params.append("order_by", "due_date");
          params.append("reverse", "false");

          const url = `https://api.clickup.com/api/v2/list/${listId}/task?${params.toString()}`;

          const req = https.get(url, {
            headers: { "Authorization": clickupKey },
            timeout: 15000,
          }, (res) => {
            let body = "";
            res.on("data", (d) => (body += d));
            res.on("end", () => {
              try {
                const data = JSON.parse(body);
                if (!data.tasks || !Array.isArray(data.tasks)) {
                  resolve(`Status: ${res.statusCode}\n${body.slice(0, 2000)}`);
                  return;
                }

                // Extract clean task data (no custom_fields bloat)
                const tasks = data.tasks.map(t => {
                  const dueMs = t.due_date ? parseInt(t.due_date) : null;
                  const dueDate = dueMs ? new Date(dueMs).toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" }) : "sem prazo";
                  return {
                    nome: t.name,
                    status: t.status?.status || "?",
                    valor: (t.custom_fields || []).find(f => f.name?.toLowerCase().includes("valor"))?.value || null,
                    vencimento: dueDate,
                    vencimento_ms: dueMs,
                    responsavel: t.assignees?.map(a => a.username || a.email)?.join(", ") || "ninguem",
                    prioridade: t.priority?.priority || "normal",
                    url: t.url,
                  };
                });

                // Mark overdue
                const now = Date.now();
                for (const t of tasks) {
                  if (t.vencimento_ms && t.vencimento_ms < now && t.status !== "pago" && t.status !== "recebido") {
                    t.atrasado = true;
                  }
                }

                const summary = `${tasks.length} tarefa(s) encontrada(s) na lista "${input.list}":\n\n` +
                  tasks.map((t, i) => {
                    let line = `${i + 1}. *${t.nome}*\n   Status: ${t.status} | Vencimento: ${t.vencimento}`;
                    if (t.valor) line += ` | Valor: R$ ${t.valor}`;
                    if (t.responsavel !== "ninguem") line += ` | Resp: ${t.responsavel}`;
                    if (t.atrasado) line += ` | ⚠️ ATRASADO`;
                    return line;
                  }).join("\n\n");

                resolve(summary);
              } catch (parseErr) {
                resolve(`Erro ao processar resposta: ${parseErr.message}\n${body.slice(0, 1000)}`);
              }
            });
          });
          req.on("error", (err) => resolve(`Erro: ${err.message}`));
          req.on("timeout", () => { req.destroy(); resolve("Erro: timeout na requisicao ClickUp"); });
        } catch (err) {
          resolve(`Erro: ${err.message}`);
        }
      });
    }

    case "web_request": {
      return new Promise((resolve) => {
        try {
          const url = new URL(input.url);
          const client = url.protocol === "https:" ? https : http;
          const headers = input.headers || {};

          const req = client.get(
            input.url,
            { headers, timeout: 15000 },
            (res) => {
              let body = "";
              res.on("data", (d) => (body += d));
              res.on("end", () => {
                const result =
                  body.length > 8000
                    ? body.slice(0, 8000) + "\n[... truncado ...]"
                    : body;
                resolve(`Status: ${res.statusCode}\n\n${result}`);
              });
            }
          );
          req.on("error", (err) => resolve(`Erro: ${err.message}`));
          req.on("timeout", () => {
            req.destroy();
            resolve("Erro: timeout na requisicao");
          });
        } catch (err) {
          resolve(`Erro: ${err.message}`);
        }
      });
    }

    case "build_proposal": {
      try {
        // execSync already imported at top level
        const clientSlug = (input.client_name || "cliente")
          .toLowerCase()
          .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
          .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

        // Save JSON data to temp file
        const jsonPath = path.join(WORKSPACE, `skills/page-architect/output/.tmp-${clientSlug}.json`);
        const outputPath = path.join(WORKSPACE, `skills/page-architect/output/proposta-${clientSlug}.html`);
        const buildScript = path.join(WORKSPACE, "skills/page-architect/build-proposal.js");

        // Set defaults
        const data = { ...input };
        if (!data.year) data.year = new Date().getFullYear().toString();
        if (!data.whatsapp) data.whatsapp = "5573991484716";
        if (!data.tagline) data.tagline = "Presença digital que gera resultado.";
        if (!data.close) data.close = { heading: `Vamos transformar\nsua presença digital.`, body: "Estamos prontos para começar.", cta_text: "Falar com a Wolf" };
        if (!data.close.cta_text) data.close.cta_text = "Falar com a Wolf";

        fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2), "utf-8");

        // Run build script with template selection
        const tpl = data.template || "classic";
        execSync(`node "${buildScript}" "${jsonPath}" "${outputPath}" --template ${tpl}`, {
          cwd: WORKSPACE,
          timeout: 15000,
        });

        // Clean temp JSON
        try { fs.unlinkSync(jsonPath); } catch {}

        if (!fs.existsSync(outputPath)) {
          return "Erro: build-proposal.js nao gerou o arquivo HTML.";
        }

        const htmlSize = fs.statSync(outputPath).size;
        log("build", `Proposta gerada: ${outputPath} (${htmlSize} bytes)`);

        // Auto-deploy to Vercel
        const envContent = fs.readFileSync("/Users/thomasgirotto/.openclaw/.env", "utf-8");
        const vercelTokenMatch = envContent.match(/VERCEL_TOKEN=(.+)/);
        if (!vercelTokenMatch) {
          return `Proposta HTML gerada (${htmlSize} bytes) mas VERCEL_TOKEN nao configurado.\nArquivo local: ${outputPath}`;
        }
        const vercelToken = vercelTokenMatch[1].trim();
        const vercelScopeMatch = envContent.match(/VERCEL_SCOPE=(.+)/);
        const vercelScope = vercelScopeMatch ? vercelScopeMatch[1].trim() : "";

        // Prepare deploy directory with unique name (prevent race conditions)
        const outputDir = path.join(WORKSPACE, "skills/page-architect/output");
        if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });
        const deployDir = `/tmp/vercel-wolfpack-deploy-${Date.now()}`;
        fs.mkdirSync(deployDir, { recursive: true });
        // vercel.json config
        fs.writeFileSync(path.join(deployDir, "vercel.json"), JSON.stringify({ version: 2, outputDirectory: "." }));
        // .vercel project link (prevents creating new project each deploy)
        fs.mkdirSync(path.join(deployDir, ".vercel"), { recursive: true });
        fs.writeFileSync(path.join(deployDir, ".vercel/project.json"), JSON.stringify({
          projectId: "prj_wpyTcYuXOBeNSVZLE5wgmfcmPjD2",
          orgId: "team_kP5iE2BJV3SPb4jtyhr1PP7r",
          projectName: "vercel-wolfpack-deploy"
        }));
        // Copy all proposals
        for (const f of fs.readdirSync(outputDir)) {
          if (f.endsWith(".html")) {
            const slug = f.replace("proposta-", "").replace(".html", "");
            if (!slug) continue; // skip empty slugs
            const slugDir = path.join(deployDir, slug);
            fs.mkdirSync(slugDir, { recursive: true });
            fs.copyFileSync(path.join(outputDir, f), path.join(slugDir, "index.html"));
          }
        }
        // index page
        fs.writeFileSync(path.join(deployDir, "index.html"), "<html><head><title>Wolf Pack Proposals</title></head><body><h1>Wolf Pack Proposals</h1></body></html>");

        // Deploy via Vercel CLI
        // execSync already imported at top level
        const scopeArg = vercelScope ? `--scope "${vercelScope}"` : "";
        const vercelCmd = `vercel deploy --prod --yes --token "${vercelToken}" ${scopeArg} --cwd "${deployDir}"`;
        let vercelOutput;
        try {
          vercelOutput = execSync(vercelCmd, { encoding: "utf-8", timeout: 90000 }).trim();
          log("deploy", `Vercel output: ${vercelOutput}`);
        } catch (deployErr) {
          // Cleanup temp dir
          try { fs.rmSync(deployDir, { recursive: true }); } catch {}
          return `Proposta HTML gerada (${htmlSize} bytes) mas deploy Vercel falhou: ${deployErr.message}\nArquivo local: ${outputPath}`;
        }
        // Cleanup temp dir
        try { fs.rmSync(deployDir, { recursive: true }); } catch {}

        const publicUrl = `https://vercel-wolfpack-deploy.vercel.app/${clientSlug}`;
        log("deploy", `Proposta deployed: ${publicUrl} (${htmlSize} bytes)`);

        // Auto-register in Supabase proposals table
        let supabaseId = null;
        try {
          const sbUrl = process.env.SUPABASE_URL || "https://dqhiafxbljujahmpcdhf.supabase.co";
          const sbKey = process.env.SUPABASE_SERVICE_ROLE_KEY || (() => {
            const envC = fs.readFileSync("/Users/thomasgirotto/.openclaw/.env", "utf-8");
            const m = envC.match(/SUPABASE_SERVICE_ROLE_KEY=(.+)/);
            return m ? m[1].trim() : null;
          })();
          if (sbKey) {
            const inv = data.investment || {};
            const amountNum = parseFloat((inv.amount || "0").toString().replace(/\./g, "").replace(",", "."));
            const proposalRecord = {
              client_name: data.client_name || clientSlug,
              service_type: data.service_type || null,
              amount: amountNum || null,
              currency: inv.currency || "R$",
              suffix: inv.suffix || "/mês",
              status: "open",
              template: tpl,
              netlify_url: publicUrl,
              proposal_data: data,
            };
            if (data._seller) proposalRecord.seller = data._seller;
            if (data._origin) proposalRecord.origin = data._origin;
            if (data._proposal_code) proposalRecord.proposal_code = data._proposal_code;
            const postBody = JSON.stringify(proposalRecord);
            const sbResponse = await new Promise((resolve) => {
              const url = new URL(`${sbUrl}/rest/v1/proposals`);
              const opts = {
                hostname: url.hostname,
                path: url.pathname,
                method: "POST",
                headers: {
                  "apikey": sbKey,
                  "Authorization": `Bearer ${sbKey}`,
                  "Content-Type": "application/json",
                  "Prefer": "return=representation",
                  "Content-Length": Buffer.byteLength(postBody),
                },
              };
              const req = https.request(opts, (res) => {
                let d = ""; res.on("data", (c) => (d += c)); res.on("end", () => {
                  log("supabase", `Proposta registrada: ${data.client_name} (status: ${res.statusCode})`);
                  try { resolve(JSON.parse(d)); } catch { resolve(null); }
                });
              });
              req.on("error", (e) => { log("supabase", `Erro ao registrar proposta: ${e.message}`); resolve(null); });
              req.write(postBody);
              req.end();
            });
            if (sbResponse && Array.isArray(sbResponse) && sbResponse[0]) {
              supabaseId = sbResponse[0].id;
            }
          }
        } catch (sbErr) {
          log("supabase", `Erro ao registrar proposta no comercial: ${sbErr.message}`);
        }

        return `Proposta gerada e publicada com sucesso!\n\nURL publica: ${publicUrl}${supabaseId ? `\nID: ${supabaseId}` : ""}\n\nEnvie este link ao cliente. A pagina esta online com design cinematografico, animacoes e responsiva para mobile.`;
      } catch (err) {
        return `Erro ao gerar proposta: ${err.message}`;
      }
    }

    case "deploy_proposal": {
      try {
        let filepath = input.filepath;
        if (!path.isAbsolute(filepath)) {
          filepath = path.join(WORKSPACE, filepath);
        }
        if (!fs.existsSync(filepath)) {
          return `Erro: arquivo nao encontrado: ${filepath}`;
        }

        // Load Vercel token from .env
        const envContent = fs.readFileSync("/Users/thomasgirotto/.openclaw/.env", "utf-8");
        const vercelTokenMatch = envContent.match(/VERCEL_TOKEN=(.+)/);
        if (!vercelTokenMatch) {
          return "Erro: VERCEL_TOKEN nao configurado no .env.";
        }
        const vercelToken = vercelTokenMatch[1].trim();
        const vercelScopeMatch = envContent.match(/VERCEL_SCOPE=(.+)/);
        const vercelScope = vercelScopeMatch ? vercelScopeMatch[1].trim() : "";

        const clientSlug = (input.site_name || path.basename(filepath, ".html")).replace(/^proposta-/, "");
        if (!clientSlug) return "Erro: slug do cliente vazio. Verifique o nome do arquivo.";

        // Prepare deploy directory with unique name
        const outputDir = path.join(WORKSPACE, "skills/page-architect/output");
        const deployDir = `/tmp/vercel-wolfpack-deploy-${Date.now()}`;
        fs.mkdirSync(deployDir, { recursive: true });
        fs.writeFileSync(path.join(deployDir, "vercel.json"), JSON.stringify({ version: 2, outputDirectory: "." }));
        // .vercel project link
        fs.mkdirSync(path.join(deployDir, ".vercel"), { recursive: true });
        fs.writeFileSync(path.join(deployDir, ".vercel/project.json"), JSON.stringify({
          projectId: "prj_wpyTcYuXOBeNSVZLE5wgmfcmPjD2",
          orgId: "team_kP5iE2BJV3SPb4jtyhr1PP7r",
          projectName: "vercel-wolfpack-deploy"
        }));
        if (fs.existsSync(outputDir)) {
          for (const f of fs.readdirSync(outputDir)) {
            if (f.endsWith(".html")) {
              const slug = f.replace("proposta-", "").replace(".html", "");
              if (!slug) continue;
              const slugDir = path.join(deployDir, slug);
              fs.mkdirSync(slugDir, { recursive: true });
              fs.copyFileSync(path.join(outputDir, f), path.join(slugDir, "index.html"));
            }
          }
        }
        fs.writeFileSync(path.join(deployDir, "index.html"), "<html><head><title>Wolf Pack Proposals</title></head><body><h1>Wolf Pack Proposals</h1></body></html>");

        // Deploy via Vercel CLI
        // execSync already imported at top level
        const scopeArg = vercelScope ? `--scope "${vercelScope}"` : "";
        const vercelCmd = `vercel deploy --prod --yes --token "${vercelToken}" ${scopeArg} --cwd "${deployDir}"`;
        try {
          execSync(vercelCmd, { encoding: "utf-8", timeout: 90000 });
        } catch (deployErr) {
          try { fs.rmSync(deployDir, { recursive: true }); } catch {}
          return `Erro no deploy Vercel: ${deployErr.message}`;
        }
        try { fs.rmSync(deployDir, { recursive: true }); } catch {}

        const publicUrl = `https://vercel-wolfpack-deploy.vercel.app/${clientSlug}`;
        log("deploy", `Proposta deployed: ${publicUrl}`);
        return `Deploy concluido com sucesso!\n\nURL publica: ${publicUrl}\n\nEnvie este link ao cliente. A pagina esta online e acessivel de qualquer dispositivo.`;
      } catch (err) {
        return `Erro no deploy: ${err.message}`;
      }
    }

    case "figma_board": {
      return new Promise((resolve) => {
        try {
          // Load Figma token from .env
          let figmaToken = process.env.FIGMA_TOKEN || "";
          if (!figmaToken) {
            try {
              const envContent = fs.readFileSync("/Users/thomasgirotto/.openclaw/.env", "utf-8");
              const match = envContent.match(/^FIGMA_TOKEN=(.+)$/m);
              if (match) figmaToken = match[1].trim();
            } catch {}
          }
          if (!figmaToken) {
            resolve("Erro: FIGMA_TOKEN nao encontrada no .env");
            return;
          }

          const fileKey = input.file_key || "aSM8Ga9rLeliEmAIHtbS3w";
          let apiUrl = `https://api.figma.com/v1/files/${fileKey}`;
          if (input.node_ids) {
            apiUrl = `https://api.figma.com/v1/files/${fileKey}/nodes?ids=${encodeURIComponent(input.node_ids)}`;
          }

          const req = https.get(apiUrl, {
            headers: { "X-Figma-Token": figmaToken },
            timeout: 20000,
          }, (res) => {
            let body = "";
            res.on("data", (d) => (body += d));
            res.on("end", () => {
              try {
                if (res.statusCode !== 200) {
                  resolve(`Erro Figma API: HTTP ${res.statusCode} — ${body.slice(0, 500)}`);
                  return;
                }
                const data = JSON.parse(body);

                // Extract structured content from the node tree
                function extractNode(node, depth) {
                  if (depth > 10) return "";
                  const type = node.type || "?";
                  const name = node.name || "";
                  const text = node.characters || "";
                  let result = "";

                  // Extract fills (colors)
                  let colorInfo = "";
                  if (node.fills && node.fills.length > 0) {
                    for (const fill of node.fills) {
                      if (fill.type === "SOLID" && fill.color) {
                        const r = Math.round(fill.color.r * 255);
                        const g = Math.round(fill.color.g * 255);
                        const b = Math.round(fill.color.b * 255);
                        const hex = `#${r.toString(16).padStart(2,"0")}${g.toString(16).padStart(2,"0")}${b.toString(16).padStart(2,"0")}`.toUpperCase();
                        colorInfo += ` [fill:${hex}]`;
                      }
                    }
                  }

                  // Extract text styles
                  let styleInfo = "";
                  if (node.style) {
                    const s = node.style;
                    if (s.fontFamily) styleInfo += ` font:${s.fontFamily}`;
                    if (s.fontSize) styleInfo += ` size:${s.fontSize}px`;
                    if (s.fontWeight) styleInfo += ` weight:${s.fontWeight}`;
                  }

                  if (type === "TEXT" || type === "STICKY" || type === "SHAPE_WITH_TEXT") {
                    result += `[${type}] ${name}${colorInfo}${styleInfo}\n`;
                    if (text) result += `  > ${text.replace(/\n/g, " ").slice(0, 200)}\n`;
                  } else if (type === "SECTION") {
                    result += `\n=== SECTION: ${name} ===\n`;
                  } else if (type === "FRAME" && name && !name.startsWith("Frame")) {
                    result += `[FRAME] ${name}${colorInfo}\n`;
                  }

                  for (const child of node.children || []) {
                    result += extractNode(child, depth + 1);
                  }
                  return result;
                }

                let output = `FIGMA: ${data.name || fileKey}\n`;
                output += `Tipo: ${data.editorType || "design"}\n`;
                output += `Ultima modificacao: ${data.lastModified || "?"}\n\n`;

                const doc = input.node_ids ? Object.values(data.nodes || {})[0]?.document : data.document;
                if (doc) {
                  output += extractNode(doc, 0);
                }

                // Truncate if too long
                if (output.length > 7500) {
                  output = output.slice(0, 7500) + "\n\n[... truncado — use node_ids para focar em secoes especificas ...]";
                }

                resolve(output);
              } catch (err) {
                resolve(`Erro ao processar resposta Figma: ${err.message}`);
              }
            });
          });
          req.on("error", (err) => resolve(`Erro Figma: ${err.message}`));
          req.on("timeout", () => { req.destroy(); resolve("Erro: timeout Figma API"); });
        } catch (err) {
          resolve(`Erro: ${err.message}`);
        }
      });
    }

    case "search_group_messages": {
      try {
        const dateFrom = input.date_from;
        const dateTo = input.date_to || dateFrom;
        const keyword = (input.keyword || "").toLowerCase();
        const senderFilter = (input.sender_name || "").toLowerCase();
        const groupFilter = (input.group_name || "").toLowerCase();

        // Generate date range
        const dates = [];
        let current = new Date(dateFrom + "T00:00:00");
        const end = new Date(dateTo + "T00:00:00");
        while (current <= end) {
          dates.push(current.toISOString().split("T")[0]);
          current.setDate(current.getDate() + 1);
        }

        // Find matching groups
        const groupDirs = fs.existsSync(GROUPS_DIR)
          ? fs.readdirSync(GROUPS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory())
          : [];

        let results = [];
        let totalMessages = 0;

        for (const dir of groupDirs) {
          const metaFile = path.join(GROUPS_DIR, dir.name, "meta.json");
          let meta = { name: dir.name };
          try {
            if (fs.existsSync(metaFile)) {
              meta = JSON.parse(fs.readFileSync(metaFile, "utf-8"));
            }
          } catch {}

          // Filter by group name
          if (groupFilter && !meta.name.toLowerCase().includes(groupFilter)) continue;

          let groupMessages = [];

          for (const date of dates) {
            const file = path.join(GROUPS_DIR, dir.name, `${date}.jsonl`);
            if (!fs.existsSync(file)) continue;

            const lines = fs.readFileSync(file, "utf-8").split("\n").filter(Boolean);
            for (const line of lines) {
              try {
                const msg = JSON.parse(line);
                totalMessages++;

                // Filter by keyword
                if (keyword && !msg.text.toLowerCase().includes(keyword)) continue;

                // Filter by sender
                if (senderFilter) {
                  const name = (msg.pushName || msg.sender || "").toLowerCase();
                  if (!name.includes(senderFilter)) continue;
                }

                groupMessages.push(msg);
              } catch {}
            }
          }

          if (groupMessages.length > 0) {
            results.push({
              group: meta.name,
              groupId: dir.name,
              count: groupMessages.length,
              messages: groupMessages,
            });
          }
        }

        if (results.length === 0) {
          return `Nenhuma mensagem encontrada para os filtros:\n- Periodo: ${dateFrom} a ${dateTo}\n- Grupo: ${groupFilter || "todos"}\n- Keyword: ${keyword || "nenhuma"}\n- Remetente: ${senderFilter || "todos"}\n\nTotal de mensagens no periodo: ${totalMessages}`;
        }

        // Format output
        let output = `Resultados (${dateFrom} a ${dateTo}):\n\n`;
        for (const r of results) {
          output += `=== ${r.group} (${r.count} msgs) ===\n`;
          // Limit to avoid token overflow
          const msgs = r.messages.length > 200 ? r.messages.slice(-200) : r.messages;
          if (r.messages.length > 200) {
            output += `(mostrando ultimas 200 de ${r.messages.length})\n`;
          }
          for (const m of msgs) {
            const time = m.ts
              ? new Date(m.ts).toLocaleString("pt-BR", {
                  timeZone: "America/Sao_Paulo",
                  day: "2-digit",
                  month: "2-digit",
                  hour: "2-digit",
                  minute: "2-digit",
                })
              : "??";
            output += `[${time}] ${m.pushName || m.sender}: ${m.text}\n`;
          }
          output += "\n";
        }

        // Truncate if too large
        return output.length > 15000
          ? output.slice(0, 15000) + "\n\n[... truncado por tamanho ...]"
          : output;
      } catch (err) {
        return `Erro ao buscar mensagens: ${err.message}`;
      }
    }

    case "list_groups": {
      try {
        if (!fs.existsSync(GROUPS_DIR)) return "Nenhum grupo monitorado ainda.";

        const dirs = fs.readdirSync(GROUPS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory());
        if (dirs.length === 0) return "Nenhum grupo monitorado ainda.";

        let output = "Grupos monitorados:\n\n";
        for (const dir of dirs) {
          const metaFile = path.join(GROUPS_DIR, dir.name, "meta.json");
          let meta = { name: dir.name };
          try {
            if (fs.existsSync(metaFile)) {
              meta = JSON.parse(fs.readFileSync(metaFile, "utf-8"));
            }
          } catch {}

          // Count total messages
          const files = fs.readdirSync(path.join(GROUPS_DIR, dir.name)).filter((f) => f.endsWith(".jsonl"));
          let totalMsgs = 0;
          for (const f of files) {
            const lines = fs.readFileSync(path.join(GROUPS_DIR, dir.name, f), "utf-8").split("\n").filter(Boolean);
            totalMsgs += lines.length;
          }

          output += `- ${meta.name || dir.name}\n`;
          output += `  ID: ${dir.name}\n`;
          output += `  Participantes: ${meta.participants || "?"}\n`;
          output += `  Mensagens capturadas: ${totalMsgs}\n`;
          output += `  Dias com dados: ${files.length}\n\n`;
        }
        return output;
      } catch (err) {
        return `Erro ao listar grupos: ${err.message}`;
      }
    }

    case "fetch_group_history": {
      try {
        if (!activeSock) return "WhatsApp nao conectado.";

        const groupFilter = (input.group_name || "").toLowerCase();
        if (!groupFilter) return "Nome do grupo obrigatorio.";
        const count = Math.min(input.count || 50, 500);

        // Find matching group
        const dirs = fs.readdirSync(GROUPS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory());
        let targetJid = null;
        let targetName = null;
        let groupId = null;

        for (const dir of dirs) {
          const metaFile = path.join(GROUPS_DIR, dir.name, "meta.json");
          try {
            if (fs.existsSync(metaFile)) {
              const meta = JSON.parse(fs.readFileSync(metaFile, "utf-8"));
              if (meta.name && meta.name.toLowerCase().includes(groupFilter)) {
                targetJid = dir.name + "@g.us";
                targetName = meta.name;
                groupId = dir.name;
                break;
              }
            }
          } catch {}
        }

        if (!targetJid) return `Grupo "${input.group_name}" nao encontrado nos grupos monitorados.`;

        // Find oldest message with a valid msgKey to use as cursor
        const groupDir = path.join(GROUPS_DIR, groupId);
        const jsonlFiles = fs.readdirSync(groupDir).filter(f => f.endsWith(".jsonl")).sort();
        let oldestKey = null;
        let oldestTimestamp = Math.floor(Date.now() / 1000);

        for (const jf of jsonlFiles) {
          const lines = fs.readFileSync(path.join(groupDir, jf), "utf-8").split("\n").filter(Boolean);
          for (const line of lines) {
            try {
              const msg = JSON.parse(line);
              if (msg.msgKey && msg.msgKey.id) {
                oldestKey = msg.msgKey;
                oldestTimestamp = msg.ts ? Math.floor(new Date(msg.ts).getTime() / 1000) : oldestTimestamp;
                break; // first (oldest) message with key
              }
            } catch {}
          }
          if (oldestKey) break;
        }

        // Fallback: use group JID with empty key
        if (!oldestKey) {
          oldestKey = { remoteJid: targetJid, fromMe: false, id: "" };
        }

        log("history", `Requesting ${count} msgs on-demand for ${targetName} (${targetJid}), cursor=${oldestKey.id || "none"}`);

        try {
          await activeSock.fetchMessageHistory(count, oldestKey, oldestTimestamp);
          return `Requisição de histórico enviada para "${targetName}" (${count} msgs). As mensagens serão recebidas via sync e salvas automaticamente. Aguarde alguns segundos e use search_group_messages para verificar.`;
        } catch (fetchErr) {
          return `Erro ao buscar histórico do grupo "${targetName}": ${fetchErr.message}. O sync automático na reconexão pode já ter trazido mensagens históricas — tente search_group_messages primeiro.`;
        }
      } catch (err) {
        return `Erro: ${err.message}`;
      }
    }

    case "send_group_message": {
      try {
        if (!activeSock) return "WhatsApp nao conectado.";

        const groupFilter = (input.group_name || "").toLowerCase();
        if (!groupFilter) return "Nome do grupo obrigatorio.";

        // Find matching group
        const dirs = fs.readdirSync(GROUPS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory());
        let targetJid = null;
        let targetName = null;

        for (const dir of dirs) {
          const metaFile = path.join(GROUPS_DIR, dir.name, "meta.json");
          try {
            if (fs.existsSync(metaFile)) {
              const meta = JSON.parse(fs.readFileSync(metaFile, "utf-8"));
              if (meta.name && meta.name.toLowerCase().includes(groupFilter)) {
                targetJid = dir.name + "@g.us";
                targetName = meta.name;
                break;
              }
            }
          } catch {}
        }

        if (!targetJid) return `Grupo "${input.group_name}" nao encontrado nos grupos monitorados.`;

        await activeSock.sendMessage(targetJid, { text: input.message });
        return `Mensagem enviada no grupo "${targetName}".`;
      } catch (err) {
        return `Erro ao enviar no grupo: ${err.message}`;
      }
    }

    default:
      return `Ferramenta desconhecida: ${name}`;
  }
}

// ============================================================
// ANTHROPIC API (with tools + retry + tool loop)
// ============================================================
// Sanitize history: ensure tool_result blocks have matching tool_use in previous message
function sanitizeHistory(history) {
  const sanitized = [];
  for (let i = 0; i < history.length; i++) {
    const msg = history[i];
    if (msg.role === "user" && Array.isArray(msg.content)) {
      // Check if any tool_result blocks reference tool_use IDs from previous assistant message
      const prevMsg = sanitized.length > 0 ? sanitized[sanitized.length - 1] : null;
      const prevToolUseIds = new Set();
      if (prevMsg && prevMsg.role === "assistant" && Array.isArray(prevMsg.content)) {
        for (const block of prevMsg.content) {
          if (block.type === "tool_use") prevToolUseIds.add(block.id);
        }
      }
      const validContent = msg.content.filter(block => {
        if (block.type === "tool_result") {
          return prevToolUseIds.has(block.tool_use_id);
        }
        return true;
      });
      if (validContent.length > 0) {
        sanitized.push({ ...msg, content: validContent });
      }
    } else {
      sanitized.push(msg);
    }
  }
  return sanitized;
}

async function callAnthropic(systemPrompt, history, retryCount = 0) {
  const allTools = [
    { type: "web_search_20250305", name: "web_search", max_uses: 3 },
    ...customTools,
  ];

  try {
    // Refresh API key on each call (picks up .env changes without restart)
    const freshKey = resolveAnthropicKey();
    if (freshKey !== anthropic.apiKey) {
      anthropic = new Anthropic({ apiKey: freshKey });
      log("api", "API key atualizada do .env");
    }

    let messages = sanitizeHistory([...history]);
    let response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 16384,
      system: systemPrompt,
      messages,
      tools: allTools,
    });

    // Tool use loop — execute tools and feed results back
    let loopCount = 0;
    while (response.stop_reason === "tool_use" && loopCount < 15) {
      loopCount++;
      const assistantContent = response.content;

      // Add assistant response with tool calls to messages
      messages.push({ role: "assistant", content: assistantContent });

      // Execute each tool call
      const toolResults = [];
      for (const block of assistantContent) {
        if (block.type === "tool_use") {
          log("tool", `Executando: ${block.name}(${JSON.stringify(block.input).slice(0, 100)})`);
          const result = await executeCustomTool(block.name, block.input);
          toolResults.push({
            type: "tool_result",
            tool_use_id: block.id,
            content: result,
          });
        }
      }

      // Feed tool results back
      messages.push({ role: "user", content: toolResults });

      // Call API again
      response = await anthropic.messages.create({
        model: MODEL,
        max_tokens: 16384,
        system: systemPrompt,
        messages,
        tools: allTools,
      });
    }

    // Extract final text
    const text = response.content
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("\n");

    return {
      text: text || "Desculpe, nao consegui gerar uma resposta.",
      // Return the tool interaction messages for history
      extraMessages: messages.slice(history.length),
    };
  } catch (err) {
    if (retryCount < MAX_RETRIES) {
      const delay = (retryCount + 1) * 2000;
      logError("api", `Tentativa ${retryCount + 1} falhou, retry em ${delay}ms`, err);
      await sleep(delay);
      return callAnthropic(systemPrompt, history, retryCount + 1);
    }
    throw err;
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ============================================================
// MESSAGE SPLITTING
// ============================================================
function splitMessage(text) {
  if (text.length <= MAX_MSG_LENGTH) return [text];
  const parts = [];
  let remaining = text;
  while (remaining.length > 0 && parts.length < 5) {
    if (remaining.length <= MAX_MSG_LENGTH) {
      parts.push(remaining);
      break;
    }
    let cut = remaining.lastIndexOf("\n", MAX_MSG_LENGTH);
    if (cut < MAX_MSG_LENGTH * 0.5) cut = MAX_MSG_LENGTH;
    parts.push(remaining.slice(0, cut));
    remaining = remaining.slice(cut).trimStart();
  }
  return parts;
}

// ============================================================
// CORE: PROCESS & REPLY
// ============================================================
async function processAndReply(sock, from, phone, session) {
  try {
    // Read receipt
    try { await sock.readMessages([{ remoteJid: from, id: undefined }]); } catch {}

    // Typing indicator
    await sock.presenceSubscribe(from);
    await sock.sendPresenceUpdate("composing", from);

    const systemPrompt = loadSoulPrompt();
    const { text, extraMessages } = await callAnthropic(
      systemPrompt,
      session.history
    );

    // Add tool interaction messages to history (if any tool was used)
    if (extraMessages && extraMessages.length > 0) {
      for (const msg of extraMessages) {
        session.history.push(msg);
      }
    }

    // Add final assistant response
    session.history.push({ role: "assistant", content: text });

    // Trim history
    if (session.history.length > MAX_HISTORY) {
      session.history = session.history.slice(-MAX_HISTORY);
    }

    // Persist
    saveSessionToDisk(phone, session);

    // Stop typing
    await sock.sendPresenceUpdate("paused", from);

    // Send response (split if needed)
    const parts = splitMessage(text);
    for (const part of parts) {
      await sock.sendMessage(from, { text: part });
    }

    log("out", `${phone} | ${text.length} chars | ${parts.length} parte(s)`);
  } catch (err) {
    logError("process", `Erro para ${phone}`, err);
    try { await sock.sendPresenceUpdate("paused", from); } catch {}
    await sock.sendMessage(from, {
      text: "Desculpe, houve um erro ao processar sua mensagem. Tente novamente.",
    });
  }
}

// ============================================================
// MESSAGE HANDLERS (by type)
// ============================================================
function isAllowed(phone) {
  if (ALLOWED_NUMBERS.length === 0) return true;
  return ALLOWED_NUMBERS.includes(phone);
}

async function handleText(sock, from, body) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  log("in", `${phone} | texto: ${body.length > 80 ? body.slice(0, 80) + "..." : body}`);

  return enqueue(phone, async () => {
    const session = getSession(phone);
    session.history.push({ role: "user", content: body });
    await processAndReply(sock, from, phone, session);
  });
}

async function handleAudio(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  log("in", `${phone} | audio`);

  return enqueue(phone, async () => {
    try {
      await sock.presenceSubscribe(from);
      await sock.sendPresenceUpdate("composing", from);

      const buffer = await downloadMediaMessage(msg, "buffer", {});
      const transcription = await transcribeAudio(buffer);

      const session = getSession(phone);
      session.history.push({
        role: "user",
        content: `[Mensagem de voz transcrita]: ${transcription}`,
      });
      await processAndReply(sock, from, phone, session);
    } catch (err) {
      logError("audio", `Erro ${phone}`, err);
      await sock.sendMessage(from, {
        text: "Nao consegui processar o audio. Tente enviar como texto.",
      });
    }
  });
}

async function handleImage(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  log("in", `${phone} | imagem`);

  return enqueue(phone, async () => {
    try {
      await sock.presenceSubscribe(from);
      await sock.sendPresenceUpdate("composing", from);

      const buffer = await downloadMediaMessage(msg, "buffer", {});
      const mimetype = msg.message.imageMessage.mimetype || "image/jpeg";
      const caption = msg.message.imageMessage.caption || "";

      const session = getSession(phone);
      const content = [
        {
          type: "image",
          source: {
            type: "base64",
            media_type: mimetype,
            data: buffer.toString("base64"),
          },
        },
        { type: "text", text: caption || "Descreva ou analise esta imagem." },
      ];

      session.history.push({ role: "user", content });
      await processAndReply(sock, from, phone, session);
    } catch (err) {
      logError("image", `Erro ${phone}`, err);
      await sock.sendMessage(from, {
        text: "Nao consegui processar a imagem. Tente novamente.",
      });
    }
  });
}

async function handleVideo(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  log("in", `${phone} | video`);

  return enqueue(phone, async () => {
    try {
      await sock.presenceSubscribe(from);
      await sock.sendPresenceUpdate("composing", from);

      const buffer = await downloadMediaMessage(msg, "buffer", {});
      const caption = msg.message.videoMessage?.caption || "";
      const transcription = await transcribeVideo(buffer);

      const session = getSession(phone);
      let text = `[Video recebido]`;
      if (caption) text += `\nLegenda: ${caption}`;
      if (transcription && !transcription.includes("[Erro")) {
        text += `\n[Audio do video transcrito]: ${transcription}`;
      }

      session.history.push({ role: "user", content: text });
      await processAndReply(sock, from, phone, session);
    } catch (err) {
      logError("video", `Erro ${phone}`, err);
      await sock.sendMessage(from, {
        text: "Nao consegui processar o video. Tente enviar o audio separado ou como texto.",
      });
    }
  });
}

async function handleDocument(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  const docMsg = msg.message.documentMessage || msg.message.documentWithCaptionMessage?.message?.documentMessage;
  if (!docMsg) return;

  const filename = docMsg.fileName || "documento";
  const mimetype = docMsg.mimetype || "";
  log("in", `${phone} | documento: ${filename} (${mimetype})`);

  return enqueue(phone, async () => {
    try {
      await sock.presenceSubscribe(from);
      await sock.sendPresenceUpdate("composing", from);

      const buffer = await downloadMediaMessage(msg, "buffer", {});
      const caption = docMsg.caption || "";

      let docContent = "";

      // Tentar extrair texto de PDFs e arquivos texto
      if (mimetype === "application/pdf") {
        // Salvar e tentar extrair texto basico
        const tmpPdf = `/tmp/wa-doc-${Date.now()}.pdf`;
        try {
          fs.writeFileSync(tmpPdf, buffer);
          // Usar python para extrair texto se possivel
          docContent = execSync(
            `python3 -c "
import sys
try:
    import PyPDF2
    reader = PyPDF2.PdfReader('${tmpPdf}')
    text = ''
    for page in reader.pages[:10]:
        text += page.extract_text() + '\\n'
    print(text[:6000])
except ImportError:
    print('[PDF recebido - instale PyPDF2 para extrair texto]')
except Exception as e:
    print(f'[Erro ao ler PDF: {e}]')
"`,
            { timeout: 15000 }
          ).toString().trim();
        } catch {
          docContent = "[PDF recebido mas nao foi possivel extrair texto]";
        } finally {
          try { fs.unlinkSync(tmpPdf); } catch {}
        }
      } else if (
        mimetype.startsWith("text/") ||
        filename.endsWith(".txt") ||
        filename.endsWith(".csv") ||
        filename.endsWith(".json") ||
        filename.endsWith(".md") ||
        filename.endsWith(".yaml") ||
        filename.endsWith(".yml")
      ) {
        docContent = buffer.toString("utf-8").slice(0, 6000);
      } else {
        docContent = `[Documento recebido: ${filename} (${mimetype}) - formato nao suportado para leitura]`;
      }

      const session = getSession(phone);
      let text = `[Documento: ${filename}]`;
      if (caption) text += `\nLegenda: ${caption}`;
      if (docContent) text += `\nConteudo:\n${docContent}`;

      session.history.push({ role: "user", content: text });
      await processAndReply(sock, from, phone, session);
    } catch (err) {
      logError("doc", `Erro ${phone}`, err);
      await sock.sendMessage(from, {
        text: "Nao consegui processar o documento. Tente enviar como texto.",
      });
    }
  });
}

async function handleSticker(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  log("in", `${phone} | sticker`);

  return enqueue(phone, async () => {
    try {
      await sock.presenceSubscribe(from);
      await sock.sendPresenceUpdate("composing", from);

      const buffer = await downloadMediaMessage(msg, "buffer", {});
      const mimetype = msg.message.stickerMessage?.mimetype || "image/webp";

      const session = getSession(phone);
      const content = [
        {
          type: "image",
          source: {
            type: "base64",
            media_type: mimetype,
            data: buffer.toString("base64"),
          },
        },
        { type: "text", text: "[Sticker/Figurinha recebida] — reaja ou comente sobre ela." },
      ];

      session.history.push({ role: "user", content });
      await processAndReply(sock, from, phone, session);
    } catch (err) {
      logError("sticker", `Erro ${phone}`, err);
      // Stickers nao precisam de erro — silencioso
    }
  });
}

async function handleLocation(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  const loc = msg.message.locationMessage;
  if (!loc) return;

  log("in", `${phone} | localizacao: ${loc.degreesLatitude}, ${loc.degreesLongitude}`);

  return enqueue(phone, async () => {
    const session = getSession(phone);
    let text = `[Localizacao compartilhada]\nLatitude: ${loc.degreesLatitude}\nLongitude: ${loc.degreesLongitude}`;
    if (loc.name) text += `\nNome: ${loc.name}`;
    if (loc.address) text += `\nEndereco: ${loc.address}`;

    session.history.push({ role: "user", content: text });
    await processAndReply(sock, from, phone, session);
  });
}

async function handleContact(sock, from, msg) {
  const phone = from.replace("@s.whatsapp.net", "");
  if (!isAllowed(phone)) return;

  const contact = msg.message.contactMessage;
  if (!contact) return;

  log("in", `${phone} | contato: ${contact.displayName}`);

  return enqueue(phone, async () => {
    const session = getSession(phone);
    let text = `[Contato compartilhado]\nNome: ${contact.displayName}`;
    if (contact.vcard) {
      // Extrair telefone do vCard
      const telMatch = contact.vcard.match(/TEL.*?:([\d+\-\s]+)/i);
      if (telMatch) text += `\nTelefone: ${telMatch[1].trim()}`;
    }

    session.history.push({ role: "user", content: text });
    await processAndReply(sock, from, phone, session);
  });
}

// ============================================================
// GROUP MONITORING — passive capture, no responses
// ============================================================
function todayDateStr() {
  return new Date()
    .toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" }); // YYYY-MM-DD
}

function ensureGroupDir(groupId) {
  const dir = path.join(GROUPS_DIR, groupId);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function saveGroupMeta(groupId, meta) {
  const dir = ensureGroupDir(groupId);
  const file = path.join(dir, "meta.json");
  try {
    const existing = fs.existsSync(file)
      ? JSON.parse(fs.readFileSync(file, "utf-8"))
      : {};
    const merged = { ...existing, ...meta, updatedAt: new Date().toISOString() };
    fs.writeFileSync(file, JSON.stringify(merged, null, 2), "utf-8");
  } catch (err) {
    logError("group", `Erro ao salvar meta ${groupId}`, err);
  }
}

function appendGroupMessage(groupId, entry) {
  const dir = ensureGroupDir(groupId);
  const file = path.join(dir, `${todayDateStr()}.jsonl`);
  try {
    fs.appendFileSync(file, JSON.stringify(entry) + "\n", "utf-8");
  } catch (err) {
    logError("group", `Erro ao gravar msg ${groupId}`, err);
  }
}

function extractGroupText(msg) {
  const m = msg.message;
  if (!m) return null;

  if (m.conversation) return { type: "text", text: m.conversation };
  if (m.extendedTextMessage?.text)
    return { type: "text", text: m.extendedTextMessage.text };
  if (m.imageMessage)
    return {
      type: "image",
      text: m.imageMessage.caption || "[imagem]",
    };
  if (m.videoMessage)
    return {
      type: "video",
      text: m.videoMessage.caption || "[video]",
    };
  if (m.audioMessage) return { type: "audio", text: "[audio]" };
  if (m.documentMessage)
    return {
      type: "document",
      text: `[documento: ${m.documentMessage.fileName || "arquivo"}]`,
    };
  if (m.stickerMessage) return { type: "sticker", text: "[sticker]" };
  if (m.locationMessage)
    return {
      type: "location",
      text: `[localizacao: ${m.locationMessage.name || ""}]`,
    };
  if (m.contactMessage)
    return {
      type: "contact",
      text: `[contato: ${m.contactMessage.displayName || ""}]`,
    };
  if (m.reactionMessage)
    return {
      type: "reaction",
      text: m.reactionMessage.text || "[reacao]",
    };
  if (m.pollCreationMessage || m.pollCreationMessageV3)
    return {
      type: "poll",
      text: `[enquete: ${(m.pollCreationMessage || m.pollCreationMessageV3)?.name || ""}]`,
    };

  return { type: "other", text: `[${Object.keys(m).join(", ")}]` };
}

async function handleGroupMessage(sock, msg) {
  const groupJid = msg.key.remoteJid;
  const groupId = groupJid.replace("@g.us", "");
  const senderJid = msg.key.participant || msg.key.remoteJid;
  const sender = senderJid.replace("@s.whatsapp.net", "").replace("@lid", "");
  const fromMe = msg.key.fromMe || false;
  const m = msg.message;
  if (!m) return;

  const extracted = extractGroupText(msg);
  if (!extracted) return;

  const pushName = msg.pushName || sender;

  // Timestamp from message
  const rawTs = msg.messageTimestamp;
  const epoch = typeof rawTs === "number" ? rawTs
    : typeof rawTs === "object" && rawTs?.low ? rawTs.low
    : Math.floor(Date.now() / 1000);
  const msgDate = new Date(epoch * 1000);

  const entry = {
    ts: msgDate.toISOString(),
    sender,
    pushName,
    fromMe,
    type: extracted.type,
    text: extracted.text,
    msgKey: { id: msg.key.id, remoteJid: groupJid, fromMe, participant: msg.key.participant },
  };

  appendGroupMessage(groupId, entry);

  // Log
  const preview =
    extracted.text.length > 60
      ? extracted.text.slice(0, 60) + "..."
      : extracted.text;
  log("group", `${groupId} | ${pushName} (${sender}) | ${extracted.type}: ${preview}`);

  // Update group metadata if we don't have it yet
  if (!groupsMeta.has(groupJid)) {
    try {
      const metadata = await sock.groupMetadata(groupJid);
      const meta = {
        name: metadata.subject || groupId,
        description: metadata.desc || "",
        participants: (metadata.participants || []).length,
        owner: metadata.owner || "",
      };
      groupsMeta.set(groupJid, meta);
      saveGroupMeta(groupId, meta);
      log("group", `Meta salva: ${meta.name} (${meta.participants} membros)`);
    } catch (err) {
      groupsMeta.set(groupJid, { name: groupId });
    }
  }

  // === Check if Alfred was mentioned ===
  const textLower = extracted.text.toLowerCase();
  const myNumber = (sock.user?.id || "").split(":")[0].split("@")[0];
  const myLid = myLidCache; // LID cached on connection from creds.json

  // Check all possible mention sources
  const contextInfo = m.extendedTextMessage?.contextInfo
    || m.imageMessage?.contextInfo
    || m.videoMessage?.contextInfo
    || m.audioMessage?.contextInfo
    || m.documentMessage?.contextInfo
    || m.documentWithCaptionMessage?.message?.documentMessage?.contextInfo
    || m.stickerMessage?.contextInfo
    || {};
  const mentionedJids = contextInfo.mentionedJid || [];
  const wasMentionedByJid = mentionedJids.some((jid) => {
    const num = jid.split(":")[0].split("@")[0];
    return num === myNumber || (myLid && num === myLid);
  });

  // Also check if the text contains our LID or number as @mention
  const textMentionsUs = textLower.includes("alfred") ||
    textLower.includes("@alfred") ||
    (myNumber && textLower.includes(`@${myNumber}`)) ||
    (myLid && textLower.includes(`@${myLid}`));

  const alfredMentioned = textMentionsUs || wasMentionedByJid;

  if (!alfredMentioned || fromMe) return;

  // === ALFRED FOI MENCIONADO — processar com robustez total ===
  const groupName = groupsMeta.get(groupJid)?.name || groupId;
  log("group", `Alfred mencionado por ${pushName} em ${groupName} (tipo: ${extracted.type})`);

  const phone = `group-${groupId}`;
  return enqueue(phone, async () => {
    const session = getSession(phone);

    try {
      await sock.presenceSubscribe(groupJid);
      await sock.sendPresenceUpdate("composing", groupJid);

      // === Build message content based on media type ===
      let userContent;

      // AUDIO — transcrever com Groq Whisper
      if (m.audioMessage) {
        try {
          const buffer = await downloadMediaMessage(msg, "buffer", {});
          const transcription = await transcribeAudio(buffer);
          userContent = `[Audio de ${pushName}]: ${transcription}`;
          log("group", `Audio transcrito de ${pushName}: ${transcription.slice(0, 80)}...`);
        } catch (err) {
          logError("group-audio", `Erro transcricao`, err);
          userContent = `[Audio de ${pushName} — não foi possível transcrever]`;
        }
      }
      // IMAGEM — Vision API
      else if (m.imageMessage) {
        try {
          const buffer = await downloadMediaMessage(msg, "buffer", {});
          const mimetype = m.imageMessage.mimetype || "image/jpeg";
          const caption = m.imageMessage.caption || "";
          userContent = [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mimetype,
                data: buffer.toString("base64"),
              },
            },
            { type: "text", text: `[Imagem de ${pushName}${caption ? `: ${caption}` : ""}] Analise esta imagem.` },
          ];
          log("group", `Imagem recebida de ${pushName} (${mimetype})`);
        } catch (err) {
          logError("group-image", `Erro ao baixar imagem`, err);
          userContent = `[Imagem de ${pushName} — não foi possível baixar]`;
        }
      }
      // VIDEO — transcrever audio do video
      else if (m.videoMessage) {
        try {
          const buffer = await downloadMediaMessage(msg, "buffer", {});
          const caption = m.videoMessage?.caption || "";
          const transcription = await transcribeVideo(buffer);
          let text = `[Video de ${pushName}]`;
          if (caption) text += `\nLegenda: ${caption}`;
          if (transcription && !transcription.includes("[Erro")) {
            text += `\n[Audio do video transcrito]: ${transcription}`;
          }
          userContent = text;
        } catch (err) {
          logError("group-video", `Erro ao processar video`, err);
          userContent = `[Video de ${pushName} — não foi possível processar]`;
        }
      }
      // DOCUMENTO — extrair conteúdo
      else if (m.documentMessage || m.documentWithCaptionMessage) {
        const docMsg = m.documentMessage || m.documentWithCaptionMessage?.message?.documentMessage;
        if (docMsg) {
          try {
            const filename = docMsg.fileName || "documento";
            const mimetype = docMsg.mimetype || "";
            const buffer = await downloadMediaMessage(msg, "buffer", {});
            const caption = docMsg.caption || "";
            let docContent = "";

            if (mimetype === "application/pdf") {
              const tmpPdf = `/tmp/wa-group-doc-${Date.now()}.pdf`;
              try {
                fs.writeFileSync(tmpPdf, buffer);
                docContent = execSync(
                  `python3 -c "
import sys
try:
    import PyPDF2
    reader = PyPDF2.PdfReader('${tmpPdf}')
    text = ''
    for page in reader.pages[:10]:
        text += page.extract_text() + '\\n'
    print(text[:6000])
except ImportError:
    print('[PDF - instale PyPDF2 para extrair texto]')
except Exception as e:
    print(f'[Erro ao ler PDF: {e}]')
"`, { timeout: 15000 }
                ).toString().trim();
              } catch {
                docContent = "[PDF recebido mas nao foi possivel extrair texto]";
              } finally {
                try { fs.unlinkSync(tmpPdf); } catch {}
              }
            } else if (
              mimetype.startsWith("text/") || filename.endsWith(".txt") ||
              filename.endsWith(".csv") || filename.endsWith(".json") ||
              filename.endsWith(".md") || filename.endsWith(".yaml") || filename.endsWith(".yml")
            ) {
              docContent = buffer.toString("utf-8").slice(0, 6000);
            } else {
              docContent = `[Formato ${mimetype} nao suportado para leitura direta]`;
            }

            let text = `[Documento de ${pushName}: ${filename}]`;
            if (caption) text += `\nLegenda: ${caption}`;
            if (docContent) text += `\nConteudo:\n${docContent}`;
            userContent = text;
          } catch (err) {
            logError("group-doc", `Erro ao processar documento`, err);
            userContent = `[Documento de ${pushName} — não foi possível processar]`;
          }
        }
      }
      // STICKER — analisar como imagem
      else if (m.stickerMessage) {
        try {
          const buffer = await downloadMediaMessage(msg, "buffer", {});
          const mimetype = m.stickerMessage?.mimetype || "image/webp";
          userContent = [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mimetype,
                data: buffer.toString("base64"),
              },
            },
            { type: "text", text: `[Sticker de ${pushName}] O que este sticker representa?` },
          ];
        } catch {
          userContent = `[Sticker de ${pushName}]`;
        }
      }
      // TEXTO e outros
      else {
        userContent = `[Mensagem de ${pushName}]: ${extracted.text}`;
      }

      // Fallback
      if (!userContent) userContent = `[Mensagem de ${pushName}]: ${extracted.text}`;

      // Load recent group context (last 30 msgs from today + yesterday)
      let recentContext = "";
      try {
        const today = todayDateStr();
        const yesterday = new Date(Date.now() - 86400000)
          .toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });
        const filesToLoad = [
          path.join(GROUPS_DIR, groupId, `${yesterday}.jsonl`),
          path.join(GROUPS_DIR, groupId, `${today}.jsonl`),
        ].filter(f => fs.existsSync(f));

        let allLines = [];
        for (const f of filesToLoad) {
          allLines.push(...fs.readFileSync(f, "utf-8").split("\n").filter(Boolean));
        }
        const recent = allLines.slice(-30).map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

        if (recent.length > 0) {
          // Detect gaps > 2h between consecutive messages
          let gapWarnings = [];
          for (let i = 1; i < recent.length; i++) {
            const prev = recent[i - 1].ts ? new Date(recent[i - 1].ts).getTime() : 0;
            const curr = recent[i].ts ? new Date(recent[i].ts).getTime() : 0;
            if (prev && curr && (curr - prev) > 2 * 60 * 60 * 1000) {
              const gapHours = Math.round((curr - prev) / (60 * 60 * 1000));
              const gapTime = new Date(prev).toLocaleTimeString("pt-BR", { timeZone: "America/Sao_Paulo", hour: "2-digit", minute: "2-digit" });
              gapWarnings.push(`[⚠️ Gap de ~${gapHours}h detectado após ${gapTime} — possível período offline, dados podem estar incompletos]`);
            }
          }

          recentContext = "\n\n[Últimas mensagens do grupo para contexto]:\n" +
            recent.map((rm, idx) => {
              const t = rm.ts ? new Date(rm.ts).toLocaleTimeString("pt-BR", { timeZone: "America/Sao_Paulo", hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit" }) : "?";
              let line = `[${t}] ${rm.pushName || rm.sender}: ${(rm.text || "").slice(0, 200)}`;
              // Insert gap warning before this message if applicable
              const warning = gapWarnings.find(w => {
                const prevTs = idx > 0 && recent[idx - 1].ts ? new Date(recent[idx - 1].ts).getTime() : 0;
                const currTs = rm.ts ? new Date(rm.ts).getTime() : 0;
                return prevTs && currTs && (currTs - prevTs) > 2 * 60 * 60 * 1000;
              });
              return warning ? warning + "\n" + line : line;
            }).join("\n");
        }
      } catch {}

      // Append context to content
      if (typeof userContent === "string") {
        userContent += recentContext;
      } else if (Array.isArray(userContent)) {
        // Add context to the text block
        const textBlock = userContent.find(b => b.type === "text");
        if (textBlock) textBlock.text += recentContext;
      }

      session.history.push({ role: "user", content: userContent });
      if (session.history.length > MAX_HISTORY) {
        session.history = session.history.slice(-MAX_HISTORY);
      }

      const soulBase = loadSoulPrompt();
      const isVendasGroup = groupName.toLowerCase().includes("vnd") || groupName.toLowerCase().includes("venda");
      let groupContext = `\n\nCONTEXTO: Você está respondendo no GRUPO DE WHATSAPP "${groupName}". Responda de forma útil e objetiva. Você tem acesso a todas as suas ferramentas (buscar mensagens, web search, etc). Quando alguém te pedir algo no grupo, execute a tarefa e responda ali mesmo.`;
      if (isVendasGroup) {
        groupContext += `\n\nINSTRUÇÃO ESPECIAL — GRUPO DE VENDAS: Este é o grupo de vendas e recebimentos. Quando alguém perguntar sobre vendas, faturamento, recebimentos ou pagamentos, SEMPRE use a ferramenta search_group_messages para buscar dados dos últimos 7 dias (date_from = 7 dias atrás, keyword relevante). NÃO confie apenas no contexto imediato das últimas mensagens — pode haver dados importantes em dias anteriores. Se detectar gaps no histórico (avisos de ⚠️), informe e busque dados complementares.`;
      }
      const systemPrompt = soulBase + groupContext;
      const { text: reply, extraMessages } = await callAnthropic(
        systemPrompt,
        session.history
      );

      if (extraMessages && extraMessages.length > 0) {
        for (const em of extraMessages) session.history.push(em);
      }
      session.history.push({ role: "assistant", content: reply });
      saveSessionToDisk(phone, session);

      await sock.sendPresenceUpdate("paused", groupJid);

      const parts = splitMessage(reply);
      for (const part of parts) {
        await sock.sendMessage(groupJid, { text: part });
      }
      log("group-out", `Respondeu em ${groupName} (${extracted.type})`);
    } catch (err) {
      logError("group", `Erro ao responder em ${groupName}`, err);
      try { await sock.sendPresenceUpdate("paused", groupJid); } catch {}
    }
  });
}

// ============================================================
// HTTP API SERVER (health + send endpoint)
// ============================================================
let activeSock = null; // referência ao socket Baileys ativo

function startApiServer() {
  const server = http.createServer((req, res) => {
    // Health check
    if (req.url === "/health" && req.method === "GET") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(
        JSON.stringify({
          status: "ok",
          version: "2.1",
          uptime: Math.floor(process.uptime()),
          sessions: sessions.size,
          groups_monitored: groupsMeta.size,
          model: MODEL,
          features: {
            audio: !!GROQ_API_KEY,
            images: true,
            web_search: true,
            tools: customTools.length,
            telegram_bridge: !!TELEGRAM_BOT_TOKEN,
            group_monitoring: true,
            reminders: loadReminders().filter(r => !r.fired).length,
          },
        })
      );
      return;
    }

    // Send message endpoint — usado pelo gerador de relatórios
    if (req.url === "/send" && req.method === "POST") {
      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", async () => {
        try {
          const { to, text } = JSON.parse(body);
          if (!to || !text) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "campos 'to' e 'text' obrigatorios" }));
            return;
          }
          if (!activeSock) {
            res.writeHead(503, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "WhatsApp nao conectado" }));
            return;
          }

          // Formatar JID se necessário
          const jid = to.includes("@") ? to : `${to}@s.whatsapp.net`;

          // Quebrar mensagem longa
          const parts = splitMessage(text);
          for (const part of parts) {
            await activeSock.sendMessage(jid, { text: part });
          }

          log("api-send", `Enviado para ${to}: ${text.length} chars, ${parts.length} parte(s)`);
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ ok: true, parts: parts.length }));
        } catch (err) {
          logError("api-send", "Erro", err);
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: err.message }));
        }
      });
      return;
    }

    // Static file server — serve arquivos do workspace (propostas, exports)
    if (req.url.startsWith("/files/") && req.method === "GET") {
      const wsRoot = "/Users/thomasgirotto/.openclaw/workspace";
      const relPath = decodeURIComponent(req.url.slice(7)); // remove "/files/"
      const filePath = path.join(wsRoot, relPath);
      // Security: block traversal and sensitive files
      if (relPath.includes("..") || relPath.includes(".env") || !filePath.startsWith(wsRoot)) {
        res.writeHead(403);
        res.end("Forbidden");
        return;
      }
      try {
        if (!fs.existsSync(filePath)) {
          res.writeHead(404);
          res.end("File not found");
          return;
        }
        const content = fs.readFileSync(filePath);
        const ext = path.extname(filePath).toLowerCase();
        const mimeTypes = {
          ".html": "text/html; charset=utf-8",
          ".json": "application/json; charset=utf-8",
          ".css": "text/css; charset=utf-8",
          ".js": "application/javascript; charset=utf-8",
          ".png": "image/png",
          ".jpg": "image/jpeg",
          ".svg": "image/svg+xml",
          ".pdf": "application/pdf",
        };
        res.writeHead(200, { "Content-Type": mimeTypes[ext] || "text/plain; charset=utf-8" });
        res.end(content);
        return;
      } catch (err) {
        res.writeHead(500);
        res.end("Error reading file");
        return;
      }
    }

    // Parse proposal text via Claude — usado pelo painel comercial web
    if (req.url === "/parse-proposal" && req.method === "POST") {
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type");

      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", async () => {
        try {
          const { text, seller, origin, proposal_code, whatsapp: inputWhatsapp } = JSON.parse(body);
          if (!text || text.length < 50) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Texto da proposta muito curto" }));
            return;
          }

          log("api", `[parse-proposal] Parsing texto (${text.length} chars) via Claude...`);

          // Use Claude to parse the slide text into structured JSON
          const parsePrompt = `Voce e um parser de propostas comerciais da Wolf Agency. Converta o texto abaixo (formato de slides do WhatsApp) para JSON estruturado.

EXEMPLO DE REFERENCIA (proposta real aprovada — siga este padrao):
{
  "client_name": "Wesley Ramos",
  "service_type": "Estruturacao Digital + Producao de Conteudo",
  "tagline": "Do planejamento ao resultado",
  "year": "2026",
  "whatsapp": "5573991484716",
  "ticker_items": ["Estrategia e Planejamento", "Gestao Instagram", "Producao de Conteudo", "Design Estrategico", "Stories", "Estruturacao Digital"],
  "context": {
    "heading": "Quem e\\nWesley Ramos",
    "bio_paragraphs": [
      "Wesley Ramos e professor universitario com mais de 16 anos de experiencia na corporacao policial.",
      "Com a transicao para o empreendedorismo educacional, busca construir uma presenca digital forte para seu metodo de preparacao para concursos."
    ],
    "badges": ["16+ anos na corporacao", "Professor universitario", "Concursos policiais", "Metodo integrado"],
    "objectives": [
      "Construir autoridade no nicho de concursos policiais",
      "Desenvolver audiencia qualificada e engajada",
      "Validar o metodo de ensino integrado",
      "Preparar o lancamento da mentoria",
      "Construir a base para o curso completo no futuro"
    ]
  },
  "services": [
    { "name": "Estrategia e Planejamento", "tag": "", "bullets": ["diagnostico inicial", "definicao de posicionamento", "pilares de conteudo", "planejamento editorial mensal"] },
    { "name": "Design Estrategico", "tag": "12 criativos/mes", "bullets": ["12 criativos para o feed", "carrosseis estrategicos", "prova social"] }
  ],
  "deliverables": [
    {
      "badge": "Onboarding",
      "title": "Primeiro Mes",
      "rows": [
        {"label": "Logotipo exclusivo", "value": "Incluso"},
        {"label": "Identidade visual do perfil", "value": "Incluso"},
        {"label": "Padronizacao completa do Instagram", "value": "Incluso"}
      ]
    },
    {
      "badge": "Mensal",
      "title": "Conteudo",
      "highlight": true,
      "rows": [
        {"label": "Criativos estaticos", "value": "8 por mes", "accent": true},
        {"label": "Carrosseis estrategicos", "value": "8 por mes", "accent": true},
        {"label": "Total de posts", "value": "16 por mes", "accent": true}
      ]
    },
    {
      "badge": "Mensal",
      "title": "Video",
      "rows": [
        {"label": "Reels editados", "value": "4 por mes", "accent": true},
        {"label": "Roteiros de video", "value": "4 por mes", "accent": true}
      ]
    },
    {
      "badge": "Mensal",
      "title": "Gestao",
      "rows": [
        {"label": "Planejamento de conteudo", "value": "Mensal"},
        {"label": "Gestao do perfil", "value": "Continua"},
        {"label": "Relatorio de desempenho", "value": "Mensal"},
        {"label": "Reuniao estrategica", "value": "Mensal"}
      ]
    }
  ],
  "investment": {
    "currency": "R$", "amount": "3.500", "suffix": "/mes",
    "payment_options": [
      {"title": "PIX", "desc": "Pagamento a vista sem acrescimo.", "highlight": true},
      {"title": "Transferencia Bancaria", "desc": "TED ou DOC."}
    ]
  },
  "support": [
    "Suporte estrategico continuo",
    "Reuniao estrategica mensal de alinhamento",
    "Relatorio mensal de desempenho",
    "Ajustes no planejamento apos aprovacao mensal",
    "Direcionamento de melhorias com base em dados",
    "Grupo exclusivo para comunicacao e alinhamento"
  ],
  "close": {
    "heading": "Construir autoridade e presenca digital e o primeiro passo para transformar conhecimento em impacto real.",
    "body": "Esta proposta foi desenvolvida para estruturar sua presenca digital e preparar o terreno para o crescimento do seu projeto educacional.",
    "cta_text": "Falar com a Wolf"
  }
}

REGRAS IMPORTANTES:
1. ticker_items: nomes dos servicos + palavras-chave do nicho do cliente (6-10 itens)
2. context.badges: caracteristicas CURTAS e ESPECIFICAS do cliente/nicho (4-6 badges). NAO use titulos de secao como "Resumo & Objetivo"
3. context.bio_paragraphs: 2-3 paragrafos RICOS sobre quem e o cliente e seu negocio/momento
4. context.objectives: 4-6 objetivos estrategicos do projeto
5. services: cada servico com nome, tag (quantidade se houver), e 4-6 bullets detalhados
6. deliverables: SEPARAR EM MULTIPLOS GRUPOS por categoria:
   - Onboarding/Primeiro Mes: itens de setup inicial (identidade visual, padronizacao, estruturacao — minimo 3 itens)
   - Mensal Conteudo: posts, criativos, carrosseis COM QUANTIDADES (usar "accent": true)
   - Mensal Video: reels, roteiros, edicao COM QUANTIDADES (se aplicavel)
   - Mensal Gestao: planejamento, gestao, relatorio, reuniao
   CADA GRUPO DEVE TER 3-5 ROWS. Nao junte tudo num grupo so.
7. support: 5-6 FRASES COMPLETAS de suporte (NAO palavras soltas como "design, conteudo"). Exemplos: "Reuniao estrategica mensal", "Relatorio de desempenho", "Suporte via WhatsApp"
8. close.heading: frase inspiracional longa e personalizada ao cliente
9. investment: extrair valor e formas de pagamento do texto
10. Se um dado nao estiver explicito no texto, INFIRA baseado no contexto (agencia de marketing digital)
11. ACENTUACAO OBRIGATORIA: TODOS os textos devem ter acentos corretos em portugues. Exemplos: Produção, Conteúdo, Gestão, Estratégico, Reunião, Relatório, Transferência, Diagnóstico, Presença, Comunicação, Organização, Definição, Referências, Sugestões, Estruturação, Crédito, Bancária, Dinâmico, Audiência. NUNCA escreva sem acento (ex: "Gestao" errado, "Gestão" correto). Nomes proprios de clientes e produtos devem ser escritos EXATAMENTE como informados no texto.

Responda APENAS com o JSON valido, sem markdown, sem explicacao, sem comentarios.

TEXTO DA PROPOSTA:
${text}`;

          const apiKey = resolveAnthropicKey();
          const anthropic = new Anthropic({ apiKey });
          const response = await anthropic.messages.create({
            model: MODEL,
            max_tokens: 4000,
            messages: [{ role: "user", content: parsePrompt }],
          });

          const jsonText = response.content[0].text.trim();
          let data;
          try {
            // Remove markdown code block if present
            const cleaned = jsonText.replace(/^```json?\n?/i, '').replace(/\n?```$/i, '').trim();
            data = JSON.parse(cleaned);
          } catch (parseErr) {
            log("api", `[parse-proposal] Erro ao parsear JSON do Claude: ${parseErr.message}`);
            res.writeHead(500, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Claude retornou JSON invalido", raw: jsonText.substring(0, 200) }));
            return;
          }

          // Add metadata
          if (seller) data._seller = seller;
          if (origin) data._origin = origin;
          if (proposal_code) data._proposal_code = proposal_code;
          if (inputWhatsapp) data.whatsapp = inputWhatsapp;

          log("api", `[parse-proposal] Parsed: ${data.client_name} — ${data.service_type}`);

          // Now build the proposal
          const result = await executeCustomTool("build_proposal", data);
          const isError = result.includes("Erro");
          const urlMatch = result.match(/https:\/\/vercel-wolfpack-deploy\.vercel\.app\/[^\s]+/) || result.match(/https:\/\/wolfpack-br\.netlify\.app\/[^\s]+/);
          res.writeHead(isError ? 500 : 200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({
            ok: !isError,
            message: result,
            url: urlMatch ? urlMatch[0] : null,
            parsed_data: data,
          }));
        } catch (err) {
          logError("api-parse-proposal", "Erro", err);
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: err.message }));
        }
      });
      return;
    }

    // CORS preflight for parse-proposal
    if (req.url === "/parse-proposal" && req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      });
      res.end();
      return;
    }

    // Build proposal endpoint — usado pelo painel comercial web (JSON direto)
    if (req.url === "/build-proposal" && req.method === "POST") {
      // CORS headers
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type");

      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", async () => {
        try {
          const data = JSON.parse(body);
          if (!data.client_name) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "campo 'client_name' obrigatorio" }));
            return;
          }

          // Run the same logic as the build_proposal tool
          const result = await executeCustomTool("build_proposal", data);
          const isError = result.includes("Erro");
          const urlMatch = result.match(/https:\/\/vercel-wolfpack-deploy\.vercel\.app\/[^\s]+/) || result.match(/https:\/\/wolfpack-br\.netlify\.app\/[^\s]+/);
          res.writeHead(isError ? 500 : 200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({
            ok: !isError,
            message: result,
            url: urlMatch ? urlMatch[0] : null,
          }));
        } catch (err) {
          logError("api-proposal", "Erro", err);
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: err.message }));
        }
      });
      return;
    }

    // CORS preflight for build-proposal
    if (req.url === "/build-proposal" && req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      });
      res.end();
      return;
    }

    res.writeHead(404);
    res.end("Not found");
  });
  server.listen(3002, "127.0.0.1", () => {
    log("api", "API server em http://127.0.0.1:3002 (health + send + files + build-proposal)");
  });
}

// ============================================================
// BAILEYS CONNECTION
// ============================================================
async function startBridge() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version } = await fetchLatestBaileysVersion();

  log("bridge", `=== Wolf WhatsApp Bridge v2.1 ===`);
  log("bridge", `Baileys v${version.join(".")}`);
  log("bridge", `Modelo: ${MODEL}`);
  log("bridge", `SOUL: ${SOUL_PATH}`);
  log("bridge", `Audio: ${GROQ_API_KEY ? "ON (Groq Whisper)" : "OFF"}`);
  log("bridge", `Imagens: ON (Claude Vision)`);
  log("bridge", `Web Search: ON (Anthropic)`);
  log("bridge", `Tools: ${customTools.length} ferramentas`);
  log("bridge", `Telegram bridge: ${TELEGRAM_BOT_TOKEN ? "ON" : "OFF"}`);
  log("bridge", `Grupos: ON (monitoramento passivo + responde quando mencionado)`);
  log("bridge", `Sessoes: ${SESSIONS_DIR}`);
  log("bridge", `Grupos storage: ${GROUPS_DIR}`);
  log(
    "bridge",
    ALLOWED_NUMBERS.length > 0
      ? `Numeros permitidos: ${ALLOWED_NUMBERS.join(", ")}`
      : `Aceitando de qualquer numero`
  );

  const sock = makeWASocket({
    version,
    auth: state,
    logger,
    printQRInTerminal: false,
    browser: ["Wolf Agency", "Desktop", "1.0.0"],
    connectTimeoutMs: 60000,
    syncFullHistory: true,
    shouldSyncHistoryMessage: () => true,
  });

  sock.ev.on("connection.update", async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      log("bridge", "Escaneie o QR Code abaixo no WhatsApp:");
      qrcode.generate(qr, { small: true });
    }

    if (connection === "open") {
      log("bridge", "Conectado ao WhatsApp!");
      activeSock = sock; // expor para API server
      const user = sock.user;
      if (user) {
        log("bridge", `Numero: ${user.id.split(":")[0]}`);
        log("bridge", `Nome: ${user.name || "N/A"}`);
      }
      // Load LID from creds for mention detection
      try {
        const credsFile = path.join(AUTH_DIR, "creds.json");
        if (fs.existsSync(credsFile)) {
          const creds = JSON.parse(fs.readFileSync(credsFile, "utf-8"));
          myLidCache = (creds.me?.lid || "").split(":")[0].split("@")[0];
          if (myLidCache) log("bridge", `LID: ${myLidCache}`);
        }
      } catch {}

      // Start reminder checker
      startReminderChecker();
      const pendingReminders = loadReminders().filter(r => !r.fired).length;
      log("bridge", `Lembretes: ${pendingReminders} pendentes`);
    }

    if (connection === "close") {
      const reason =
        lastDisconnect?.error?.output?.statusCode ||
        lastDisconnect?.error?.message ||
        "unknown";
      log("bridge", `Desconectado: ${reason}`);

      const shouldReconnect =
        lastDisconnect?.error?.output?.statusCode !==
        DisconnectReason.loggedOut;

      if (shouldReconnect) {
        log("bridge", "Reconectando em 5s...");
        setTimeout(startBridge, 5000);
      } else {
        log("bridge", "Logout detectado. Apague auth_state/ e reinicie.");
      }
    }
  });

  sock.ev.on("creds.update", saveCreds);

  // === HISTORY SYNC — captura mensagens históricas ===
  sock.ev.on("messaging-history.set", async ({ chats, contacts, messages, syncType, progress }) => {
    const syncName = syncType !== undefined
      ? proto.Message.HistorySyncNotification.HistorySyncType[syncType] || syncType
      : "UNKNOWN";
    log("history", `Sync recebido: tipo=${syncName}, ${messages?.length || 0} msgs, ${chats?.length || 0} chats, progress=${progress || "?"}%`);

    if (!messages || messages.length === 0) return;

    let saved = 0;
    let skipped = 0;
    // Buffer writes per file to avoid excessive I/O
    const fileBuffers = new Map(); // filepath -> [entries]

    for (const msg of messages) {
      try {
        const remoteJid = msg.key?.remoteJid || "";
        if (!remoteJid.endsWith("@g.us")) { skipped++; continue; }

        const groupId = remoteJid.replace("@g.us", "");
        const senderJid = msg.key?.participant || msg.key?.remoteJid || "";
        const sender = senderJid.replace("@s.whatsapp.net", "").replace("@lid", "");
        const pushName = msg.pushName || sender;
        const fromMe = msg.key?.fromMe || false;

        const extracted = extractGroupText(msg);
        if (!extracted) { skipped++; continue; }

        // Timestamp original (epoch seconds)
        const rawTs = msg.messageTimestamp;
        const epoch = typeof rawTs === "number" ? rawTs
          : typeof rawTs === "object" && rawTs?.low ? rawTs.low
          : null;
        if (!epoch) { skipped++; continue; }

        const msgTs = new Date(epoch * 1000);
        const dateStr = msgTs.toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });

        const entry = {
          ts: msgTs.toISOString(),
          sender,
          pushName,
          fromMe,
          type: extracted.type,
          text: extracted.text,
          historical: true,
        };

        const dir = ensureGroupDir(groupId);
        const file = path.join(dir, `${dateStr}.jsonl`);
        if (!fileBuffers.has(file)) fileBuffers.set(file, []);
        fileBuffers.get(file).push(entry);
        saved++;
      } catch (err) {
        skipped++;
      }
    }

    // Deduplicate: load existing entries, merge, sort by timestamp
    for (const [file, newEntries] of fileBuffers) {
      try {
        let existing = [];
        if (fs.existsSync(file)) {
          existing = fs.readFileSync(file, "utf-8")
            .split("\n").filter(Boolean)
            .map(l => { try { return JSON.parse(l); } catch { return null; } })
            .filter(Boolean);
        }

        // Build dedup key: ts + sender + text (first 50 chars)
        const seen = new Set(existing.map(e => `${e.ts}|${e.sender}|${(e.text || "").slice(0, 50)}`));

        let added = 0;
        for (const entry of newEntries) {
          const key = `${entry.ts}|${entry.sender}|${(entry.text || "").slice(0, 50)}`;
          if (!seen.has(key)) {
            existing.push(entry);
            seen.add(key);
            added++;
          }
        }

        if (added > 0) {
          // Sort by timestamp
          existing.sort((a, b) => new Date(a.ts) - new Date(b.ts));
          fs.writeFileSync(file, existing.map(e => JSON.stringify(e)).join("\n") + "\n", "utf-8");
        }
        saved = saved - newEntries.length + added; // Adjust count for deduped
      } catch (err) {
        logError("history", `Erro ao salvar ${file}`, err);
      }
    }

    // Update group metadata for new groups
    const groupJids = new Set(
      messages.filter(m => m.key?.remoteJid?.endsWith("@g.us")).map(m => m.key.remoteJid)
    );
    for (const jid of groupJids) {
      if (!groupsMeta.has(jid)) {
        try {
          const metadata = await sock.groupMetadata(jid);
          const gid = jid.replace("@g.us", "");
          const meta = {
            name: metadata.subject || gid,
            description: metadata.desc || "",
            participants: (metadata.participants || []).length,
            owner: metadata.owner || "",
          };
          groupsMeta.set(jid, meta);
          saveGroupMeta(gid, meta);
        } catch {}
      }
    }

    log("history", `Sync ${syncName} concluído: ${saved} msgs novas salvas, ${skipped} ignoradas`);
  });

  // === MESSAGE ROUTER ===
  sock.ev.on("messages.upsert", async ({ messages, type }) => {
    if (type !== "notify") return;

    for (const msg of messages) {
      const remoteJid = msg.key.remoteJid || "";

      if (msg.key.fromMe && !remoteJid.endsWith("@g.us")) continue;
      if (remoteJid === "status@broadcast") continue;

      const from = remoteJid;
      const m = msg.message;
      if (!m) continue;

      try {
        // === GRUPOS — monitoramento passivo ===
        if (from.endsWith("@g.us")) {
          await handleGroupMessage(sock, msg);
          continue;
        }

        // === DM — interação normal ===
        if (msg.key.fromMe) continue;

        // Texto
        if (m.conversation || m.extendedTextMessage?.text) {
          await handleText(sock, from, m.conversation || m.extendedTextMessage.text);
        }
        // Audio / Voz
        else if (m.audioMessage) {
          await handleAudio(sock, from, msg);
        }
        // Imagem
        else if (m.imageMessage) {
          await handleImage(sock, from, msg);
        }
        // Video
        else if (m.videoMessage) {
          await handleVideo(sock, from, msg);
        }
        // Documento
        else if (m.documentMessage || m.documentWithCaptionMessage) {
          await handleDocument(sock, from, msg);
        }
        // Sticker
        else if (m.stickerMessage) {
          await handleSticker(sock, from, msg);
        }
        // Localizacao
        else if (m.locationMessage || m.liveLocationMessage) {
          await handleLocation(sock, from, msg);
        }
        // Contato
        else if (m.contactMessage) {
          await handleContact(sock, from, msg);
        }
        // Tipo desconhecido
        else {
          const types = Object.keys(m).join(", ");
          log("bridge", `Tipo nao tratado de ${from.replace("@s.whatsapp.net", "")}: ${types}`);
        }
      } catch (err) {
        logError("router", `Erro ao processar mensagem de ${from}`, err);
      }
    }
  });
}

// ============================================================
// GRACEFUL SHUTDOWN
// ============================================================
function shutdown(signal) {
  log("bridge", `${signal} recebido — salvando sessoes...`);
  for (const [phone, session] of sessions) {
    saveSessionToDisk(phone, session);
  }
  log("bridge", "Sessoes salvas. Encerrando.");
  process.exit(0);
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

// ============================================================
// START
// ============================================================
if (!ANTHROPIC_API_KEY) {
  console.error("[bridge] ANTHROPIC_API_KEY nao configurada!");
  process.exit(1);
}

log("bridge", "Wolf WhatsApp Bridge v2.1 iniciando...");
startApiServer();
startBridge().catch((err) => {
  logError("bridge", "Erro fatal", err);
  process.exit(1);
});
