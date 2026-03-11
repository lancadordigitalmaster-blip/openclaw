// Wolf Mission Control — Edge Function: telegram-notifier
// Versão: 2.0 | 2026-03-05
// Envia notificações formatadas para o Telegram do Netto
// Lê da tabela escalations — não depende de LLM

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL        = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TELEGRAM_BOT_TOKEN  = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const NETTO_TELEGRAM_ID   = Deno.env.get("NETTO_TELEGRAM_ID") ?? "789352357";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// =============================================================
// FORMATADORES
// =============================================================

function formatEscalation(escalation: Record<string, unknown>): string {
  const levelEmoji: Record<string, string> = {
    L1: "ℹ️", L2: "⚠️", L3: "🔴", L4: "🚨",
  };
  const typeEmoji: Record<string, string> = {
    alert: "📢", sla_breach: "⏱️", quality_failure: "❌", agent_error: "🤖",
  };

  const emoji = typeEmoji[escalation.type as string] ?? "📌";
  const level = levelEmoji[escalation.level as string] ?? "❓";

  return [
    `${level} ${emoji} *${escalation.title}*`,
    ``,
    escalation.message as string,
    ``,
    `_${new Date().toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}_`,
  ].join("\n");
}

function formatAlert(title: string, body: string, level: "info" | "warning" | "critical"): string {
  const icons = { info: "💡", warning: "⚠️", critical: "🚨" };
  return `${icons[level]} *${title}*\n\n${body}`;
}

function formatDailyReport(payload: Record<string, unknown>): string {
  const lines = [
    `📊 *Wolf Mission Control — ${payload.date}*`,
    `━━━━━━━━━━━━━━━━━━━━━━━`,
    `🎯 Missões hoje:     ${payload.missions_today ?? 0}`,
    `✅ Concluídas:       ${payload.completed_today ?? 0}`,
    `🔄 Em andamento:     ${payload.in_progress ?? 0}`,
    `🔴 Bloqueadas:       ${payload.blocked_open ?? 0}`,
    `━━━━━━━━━━━━━━━━━━━━━━━`,
    `🪙 Tokens usados:    ${Number(payload.total_tokens ?? 0).toLocaleString("pt-BR")}`,
    `⭐ Qualidade média:  ${payload.avg_quality ? `${(Number(payload.avg_quality) * 100).toFixed(0)}%` : "—"}`,
  ];
  return lines.join("\n");
}

// =============================================================
// ENVIO TELEGRAM
// =============================================================

async function sendTelegram(chatId: string, text: string): Promise<boolean> {
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: "Markdown",
      disable_web_page_preview: true,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`[telegram-notifier] Erro ao enviar: ${err}`);
    return false;
  }
  return true;
}

async function logToSystem(level: string, message: string, payload = {}): Promise<void> {
  await supabase.from("system_logs").insert({
    level,
    source: "telegram-notifier",
    message,
    payload,
  });
}

// =============================================================
// HANDLER PRINCIPAL
// =============================================================

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || authHeader !== `Bearer ${SUPABASE_SERVICE_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const body = await req.json();
    const { type, payload, chat_id } = body;
    const targetChat = chat_id ?? NETTO_TELEGRAM_ID;

    let message = "";
    let logMessage = "";

    // --------------------------------------------------------
    // TIPO: escalation — envia escalação diretamente
    // --------------------------------------------------------
    if (type === "escalation" && payload?.escalation_id) {
      const { data: esc } = await supabase
        .from("escalations")
        .select("*")
        .eq("id", payload.escalation_id)
        .single();

      if (!esc) {
        return new Response(JSON.stringify({ error: "Escalação não encontrada" }), { status: 404 });
      }

      message = formatEscalation(esc);
      logMessage = `Escalação enviada: ${esc.title}`;

      // Marca como notificado
      await supabase.from("escalations").update({
        metadata: { ...esc.metadata, notified_at: new Date().toISOString() },
      }).eq("id", esc.id);
    }

    // --------------------------------------------------------
    // TIPO: alert — alerta avulso
    // --------------------------------------------------------
    else if (type === "alert") {
      message = formatAlert(
        payload?.title ?? "Alerta Wolf",
        payload?.body ?? "",
        payload?.level ?? "info",
      );
      logMessage = `Alerta enviado: ${payload?.title}`;
    }

    // --------------------------------------------------------
    // TIPO: daily_report — relatório diário
    // --------------------------------------------------------
    else if (type === "daily_report") {
      // Busca último log de daily-report se não vier payload
      let reportData = payload;
      if (!reportData?.date) {
        const { data: log } = await supabase
          .from("system_logs")
          .select("payload")
          .eq("source", "daily-report")
          .order("created_at", { ascending: false })
          .limit(1)
          .single();
        reportData = log?.payload ?? {};
      }
      message = formatDailyReport(reportData);
      logMessage = "Relatório diário enviado";
    }

    // --------------------------------------------------------
    // TIPO: pending_escalations — envia todas abertas
    // --------------------------------------------------------
    else if (type === "pending_escalations") {
      const { data: pending } = await supabase
        .from("escalations")
        .select("*")
        .is("resolved_at", null)
        .order("created_at", { ascending: false })
        .limit(5);

      if (!pending || pending.length === 0) {
        return new Response(JSON.stringify({ sent: 0, message: "Sem escalações abertas" }), { status: 200 });
      }

      for (const esc of pending) {
        await sendTelegram(targetChat, formatEscalation(esc));
      }

      await logToSystem("info", `${pending.length} escalações enviadas`, { count: pending.length });
      return new Response(JSON.stringify({ sent: pending.length }), { status: 200 });
    }

    else {
      return new Response(JSON.stringify({ error: "Tipo inválido. Use: escalation|alert|daily_report|pending_escalations" }), {
        status: 400,
      });
    }

    // Enviar mensagem
    const sent = await sendTelegram(targetChat, message);
    await logToSystem(sent ? "info" : "error", logMessage, { type, sent });

    return new Response(
      JSON.stringify({ success: sent, type, chat_id: targetChat }),
      { status: sent ? 200 : 500, headers: { "Content-Type": "application/json" } },
    );

  } catch (err) {
    console.error("[telegram-notifier] Erro:", err);
    await logToSystem("error", "Erro no telegram-notifier", { error: String(err) });
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
