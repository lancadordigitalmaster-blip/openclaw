// Wolf Mission Control — Edge Function: alfred-router
// Versão: 1.0 | 2026-03-05
// Recebe mensagens do Telegram, usa Alfred (Gemini) para decidir ação,
// cria missão no WMC e aciona trigger-mission automaticamente.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OLLAMA_CLOUD_KEY     = Deno.env.get("OLLAMA_CLOUD_KEY")!;
const TELEGRAM_BOT_TOKEN   = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const NETTO_TELEGRAM_ID    = Deno.env.get("NETTO_TELEGRAM_ID") ?? "789352357";
const WOLF_KEY             = Deno.env.get("WOLF_ROUTER_KEY") ?? "wolf-secret";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const EDGE_URL = `${SUPABASE_URL}/functions/v1`;

// =============================================================
// MAPA DE AGENTES (slug → nome para Alfred decidir)
// =============================================================
const AGENT_MAP: Record<string, string> = {
  alfred: "Orquestrador geral",
  gabi:   "Tráfego pago (Meta Ads, Google Ads, TikTok Ads, CPA, ROAS, campanhas)",
  luna:   "Copy, conteúdo, legendas, roteiros, calendário editorial",
  sage:   "SEO técnico, keywords, análise orgânica, briefings de conteúdo",
  nova:   "Inteligência de mercado, tendências, análise de concorrentes",
  titan:  "Tech lead, arquitetura, code review, decisões técnicas",
  pixel:  "Frontend, React, UI/UX, componentes, performance web",
  forge:  "Backend, APIs, Edge Functions, banco de dados, integrações",
  shield: "QA e segurança, testes, OWASP, validação de código",
  atlas:  "Gestão de projetos, ClickUp, cronogramas, tarefas",
  echo:   "Comunicação com clientes, Telegram, WhatsApp, relatórios",
  flux:   "Automação, N8N, webhooks, crons, rotinas operacionais",
};

// =============================================================
// CHAMADA LLM (Ollama Cloud)
// =============================================================
async function callLLM(system: string, user: string, maxTokens = 1024): Promise<string> {
  const res = await fetch(
    "https://ollama.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OLLAMA_CLOUD_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "kimi-k2.5",
        max_tokens: maxTokens,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    }
  );
  if (!res.ok) throw new Error(`Ollama Cloud error: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.choices[0].message.content;
}

// =============================================================
// DECISÃO DO ALFRED: qual agente executa a missão
// =============================================================
async function alfredDecide(message: string): Promise<{
  agent_slug: string;
  title: string;
  description: string;
  priority: string;
}> {
  const agentList = Object.entries(AGENT_MAP)
    .map(([slug, role]) => `  ${slug}: ${role}`)
    .join("\n");

  const system = `Você é Alfred, orquestrador do Wolf Mission Control.
Dado um pedido em linguagem natural, você decide:
1. Qual agente deve executar
2. Um título curto para a missão (máx 60 chars)
3. Uma descrição estruturada com contexto completo
4. Prioridade: low | medium | high | critical

AGENTES DISPONÍVEIS:
${agentList}

Responda SOMENTE com JSON válido, sem markdown, sem explicação:
{
  "agent_slug": "slug do agente",
  "title": "título curto da missão",
  "description": "descrição completa com contexto e objetivo claro",
  "priority": "medium"
}`;

  const raw = await callLLM(system, message, 512);

  // Extrair JSON mesmo se vier com markdown
  const jsonMatch = raw.match(/\{[\s\S]+\}/);
  if (!jsonMatch) throw new Error(`Alfred não retornou JSON válido: ${raw}`);

  return JSON.parse(jsonMatch[0]);
}

// =============================================================
// TELEGRAM: enviar mensagem
// =============================================================
async function sendTelegram(chatId: string, text: string): Promise<void> {
  await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: "Markdown" }),
  }).catch(console.error);
}

// =============================================================
// STATUS DO SISTEMA
// =============================================================
async function getSystemStatus(): Promise<string> {
  const [{ data: agents }, { data: missions }, { data: escalations }] = await Promise.all([
    supabase.from("agents").select("name, emoji, status, squad"),
    supabase.from("missions").select("status").not("status", "in", '("done","cancelled")'),
    supabase.from("escalations").select("level").is("resolved_at", null),
  ]);

  const working = agents?.filter((a: any) => a.status === "working").length ?? 0;
  const total   = agents?.length ?? 0;
  const inbox   = missions?.filter((m: any) => m.status === "inbox").length ?? 0;
  const active  = missions?.filter((m: any) => m.status === "in_progress").length ?? 0;
  const blocked = missions?.filter((m: any) => m.status === "blocked").length ?? 0;
  const alerts  = escalations?.length ?? 0;

  return [
    `🐺 *Wolf Mission Control — Status*`,
    `━━━━━━━━━━━━━━━━━━━━━━━`,
    `🤖 Agentes: ${working} trabalhando / ${total} total`,
    `📋 Missões: ${active} ativas | ${inbox} na fila | ${blocked} bloqueadas`,
    `🚨 Alertas abertos: ${alerts}`,
    `━━━━━━━━━━━━━━━━━━━━━━━`,
    `_Supabase WMC · ${new Date().toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}_`,
  ].join("\n");
}

// =============================================================
// HANDLER TELEGRAM UPDATE
// =============================================================
async function handleTelegramUpdate(update: any): Promise<void> {
  const message = update.message;
  if (!message?.text) return;

  const chatId    = String(message.chat.id);
  const text      = message.text.trim();
  const isNetto   = chatId === NETTO_TELEGRAM_ID;

  // Só Netto pode usar
  if (!isNetto) {
    await sendTelegram(chatId, "⛔ Acesso restrito ao operador Wolf.");
    return;
  }

  // ── /status ──
  if (text.startsWith("/status")) {
    await sendTelegram(chatId, await getSystemStatus());
    return;
  }

  // ── /agentes ──
  if (text.startsWith("/agentes")) {
    const { data: agents } = await supabase
      .from("agents")
      .select("emoji, name, role, status, squad")
      .order("squad");

    const lines = agents?.map((a: any) =>
      `${a.emoji} *${a.name}* (${a.squad}) — ${a.status}\n  _${a.role}_`
    ) ?? [];

    await sendTelegram(chatId, `🤖 *Agentes Wolf*\n\n${lines.join("\n\n")}`);
    return;
  }

  // ── /decidir {mission_id} approve|reject ──
  if (text.startsWith("/decidir")) {
    const parts = text.split(" ");
    const missionId = parts[1];
    const decision  = parts[2]; // approve | reject

    if (!missionId || !decision) {
      await sendTelegram(chatId, "Uso: `/decidir {mission_id} approve|reject`");
      return;
    }

    const newStatus = decision === "approve" ? "assigned" : "cancelled";
    await supabase.from("missions").update({ status: newStatus }).eq("id", missionId);
    await sendTelegram(chatId, `✅ Missão \`${missionId.slice(0, 8)}\` → *${newStatus}*`);
    return;
  }

  // ── /missao {descrição} ou qualquer mensagem livre ──
  const missionText = text.startsWith("/missao")
    ? text.replace("/missao", "").trim()
    : text;

  if (!missionText) {
    await sendTelegram(chatId,
      "Envie uma instrução para criar uma missão, ou use:\n/status · /agentes · /decidir"
    );
    return;
  }

  // Alfred decide
  await sendTelegram(chatId, "🎩 Alfred analisando...");

  let decision;
  try {
    decision = await alfredDecide(missionText);
  } catch (err) {
    await sendTelegram(chatId, `❌ Alfred falhou ao analisar: ${err.message}`);
    return;
  }

  // Buscar agent_id pelo slug
  const { data: agent } = await supabase
    .from("agents")
    .select("id, name, emoji")
    .eq("slug", decision.agent_slug)
    .single();

  if (!agent) {
    await sendTelegram(chatId, `❌ Agente '${decision.agent_slug}' não encontrado.`);
    return;
  }

  // Criar missão
  const { data: mission, error: missionErr } = await supabase
    .from("missions")
    .insert({
      title:       decision.title,
      description: decision.description,
      priority:    decision.priority,
      agent_id:    agent.id,
      status:      "assigned",
      created_by:  "telegram",
    })
    .select()
    .single();

  if (missionErr || !mission) {
    await sendTelegram(chatId, `❌ Erro ao criar missão: ${missionErr?.message}`);
    return;
  }

  // Confirmar para Netto
  await sendTelegram(chatId,
    `${agent.emoji} *${agent.name}* recebeu a missão:\n` +
    `📋 *${decision.title}*\n` +
    `🎯 Prioridade: ${decision.priority}\n` +
    `🆔 \`${mission.id.slice(0, 8)}\`\n\n` +
    `_Executando..._`
  );

  // Acionar trigger-mission
  fetch(`${EDGE_URL}/trigger-mission`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({ mission_id: mission.id }),
  }).catch(console.error); // fire-and-forget
}

// =============================================================
// HANDLER PRINCIPAL
// =============================================================
Deno.serve(async (req) => {
  // Verificar autenticação (Telegram webhook ou chamada direta com wolf-key)
  const authHeader = req.headers.get("x-wolf-key");
  const isTelegram = req.headers.get("content-type")?.includes("application/json") &&
    !authHeader; // webhooks do Telegram não enviam x-wolf-key

  if (authHeader && authHeader !== WOLF_KEY) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const body = await req.json();

    // Chamada direta (criar missão direto, ex: via N8N ou dashboard)
    if (authHeader === WOLF_KEY && body.mission_title) {
      const decision = await alfredDecide(body.mission_title);
      const { data: agent } = await supabase.from("agents").select("id").eq("slug", decision.agent_slug).single();

      const { data: mission } = await supabase.from("missions").insert({
        title:       decision.title,
        description: decision.description,
        priority:    decision.priority,
        agent_id:    agent?.id ?? null,
        status:      "assigned",
        created_by:  body.created_by ?? "api",
      }).select().single();

      if (mission) {
        fetch(`${EDGE_URL}/trigger-mission`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}` },
          body: JSON.stringify({ mission_id: mission.id }),
        }).catch(console.error);
      }

      return new Response(JSON.stringify({ mission_id: mission?.id, agent: decision.agent_slug }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Webhook do Telegram
    if (body.update_id) {
      await handleTelegramUpdate(body);
      return new Response("ok", { status: 200 });
    }

    return new Response(JSON.stringify({ error: "Formato inválido" }), { status: 400 });
  } catch (err) {
    console.error("[alfred-router]", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
