// Wolf Mission Control — Edge Function: trigger-mission
// Versão: 1.0 | 2026-03-05
// Aciona um agente para executar uma missão com contexto completo

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OLLAMA_CLOUD_KEY = Deno.env.get("OLLAMA_CLOUD_KEY")!;
const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const NETTO_TELEGRAM_ID = "789352357";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

Deno.serve(async (req) => {
  try {
    const { mission_id } = await req.json();
    if (!mission_id) {
      return new Response(JSON.stringify({ error: "mission_id obrigatório" }), { status: 400 });
    }

    // 1. Buscar missão com agente e cliente
    const { data: mission, error: missionErr } = await supabase
      .from("missions")
      .select(`*, agents(*), clients(*)`)
      .eq("id", mission_id)
      .single();

    if (missionErr || !mission) {
      return new Response(JSON.stringify({ error: "Missão não encontrada" }), { status: 404 });
    }

    // 2. Marcar como in_progress
    await supabase
      .from("missions")
      .update({ status: "in_progress", started_at: new Date().toISOString() })
      .eq("id", mission_id);

    // 3. Buscar memória relevante do agente para este cliente
    const { data: memory } = await supabase
      .from("agent_memory")
      .select("memory_type, key, content, relevance")
      .eq("agent_id", mission.agent_id)
      .eq("client_id", mission.client_id)
      .or("expires_at.is.null,expires_at.gt.now()")
      .order("relevance", { ascending: false })
      .limit(8);

    // 4. Buscar handoffs pendentes para este agente
    const { data: pendingHandoffs } = await supabase
      .from("handoffs")
      .select("*, from_agent:from_agent_id(name, emoji)")
      .eq("to_agent_id", mission.agent_id)
      .eq("status", "pending")
      .limit(3);

    // 5. Montar system prompt enriquecido com skill_ref
    let systemPrompt = mission.agents.system_prompt;
    if (mission.agents.skill_ref) {
      systemPrompt += `\n\n## SKILL CARREGADA\nReferência: ${mission.agents.skill_ref}\n`;
    }

    // 6. Montar contexto completo para o agente
    const contextualPrompt = `
MISSÃO: ${mission.title}
STATUS: ${mission.status}
PRIORIDADE: ${mission.priority} (score: ${mission.priority_score})
${mission.due_at ? `PRAZO: ${new Date(mission.due_at).toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" })}` : ""}

CONTEXTO DA MISSÃO:
${mission.description}

CLIENTE: ${mission.clients?.name || "Wolf Agency (interno)"}
${mission.clients?.metadata ? `DADOS DO CLIENTE: ${JSON.stringify(mission.clients.metadata, null, 2)}` : ""}

${memory && memory.length > 0 ? `
MEMÓRIA RELEVANTE (${memory.length} registros):
${memory.map((m: any) => `[${m.memory_type}/${m.key || "geral"}] ${JSON.stringify(m.content)}`).join("\n")}
` : ""}

${pendingHandoffs && pendingHandoffs.length > 0 ? `
SINAIS RECEBIDOS (handoffs pendentes):
${pendingHandoffs.map((h: any) => `De ${h.from_agent?.emoji} ${h.from_agent?.name}: [${h.signal_type}] ${JSON.stringify(h.payload)}`).join("\n")}
` : ""}

${mission.context && Object.keys(mission.context).length > 0 ? `
CONTEXTO ACUMULADO DE HANDOFFS ANTERIORES:
${JSON.stringify(mission.context, null, 2)}
` : ""}

---
EXECUTE A MISSÃO ACIMA.
Se precisar sinalizar outro agente, use o formato:
[SIGNALS]
{
  "handoffs": [{ "to_agent": "nome", "signal_type": "tipo", "payload": {...} }],
  "alerts": [{ "level": "critical|high|medium", "message": "..." }]
}
[/SIGNALS]
`.trim();

    // 7. Chamar Ollama Cloud API (OpenAI-compatible)
    const model = mission.agents.model || "kimi-k2.5";

    const llmResponse = await fetch(
      `https://ollama.com/v1/chat/completions`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${OLLAMA_CLOUD_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: mission.agents.max_tokens || 8192,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: contextualPrompt },
          ],
        }),
      }
    );

    if (!llmResponse.ok) {
      const errBody = await llmResponse.text();
      throw new Error(`Ollama Cloud API error: ${llmResponse.status} — ${errBody}`);
    }

    const llmResult = await llmResponse.json();
    const output = llmResult.choices[0].message.content;
    const tokensUsed = llmResult.usage?.completion_tokens || 0;

    // 8. Salvar output
    const { data: outputRecord } = await supabase
      .from("mission_outputs")
      .insert({
        mission_id,
        agent_id: mission.agent_id,
        output,
        tokens_used: tokensUsed,
        model_used: model,
      })
      .select()
      .single();

    // 9. Processar sinais [SIGNALS]
    const signalResult = await processSignals(output, mission);

    // 10. Atualizar missão como done (se não tiver handoff)
    const finalStatus = signalResult.hasHandoff ? "handoff" : "done";
    await supabase
      .from("missions")
      .update({
        status: finalStatus,
        completed_at: new Date().toISOString(),
      })
      .eq("id", mission_id);

    // 11. Salvar lição aprendida na memória
    if (mission.client_id) {
      await supabase.from("agent_memory").upsert({
        agent_id: mission.agent_id,
        client_id: mission.client_id,
        memory_type: "context",
        key: `mission_${mission_id.slice(0, 8)}`,
        content: {
          title: mission.title,
          status: finalStatus,
          summary: output.slice(0, 500),
          completed_at: new Date().toISOString(),
        },
        relevance: 0.7,
      }, { onConflict: "agent_id,client_id,memory_type,key" });
    }

    return new Response(
      JSON.stringify({
        success: true,
        mission_id,
        status: finalStatus,
        tokens_used: tokensUsed,
        handoffs_created: signalResult.handoffsCreated,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("trigger-mission error:", err);

    // Notificar Netto em caso de erro crítico
    await sendTelegram(
      NETTO_TELEGRAM_ID,
      `🔴 *Erro crítico no WMC*\nEdge Function trigger-mission falhou:\n\`${err.message}\``
    );

    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

// =============================================================
// Processa sinais [SIGNALS] do output do agente
// =============================================================
async function processSignals(output: string, mission: any) {
  const signalMatch = output.match(/\[SIGNALS\]([\s\S]+?)\[\/SIGNALS\]/);
  if (!signalMatch) return { hasHandoff: false, handoffsCreated: 0 };

  let signals: { handoffs?: any[]; alerts?: any[] };
  try {
    signals = JSON.parse(signalMatch[1].trim());
  } catch {
    console.warn("Falha ao parsear [SIGNALS]:", signalMatch[1]);
    return { hasHandoff: false, handoffsCreated: 0 };
  }

  let handoffsCreated = 0;

  // Processar handoffs
  if (signals.handoffs && signals.handoffs.length > 0) {
    for (const handoff of signals.handoffs) {
      // Buscar agente destino pelo slug/nome
      const { data: toAgent } = await supabase
        .from("agents")
        .select("id, name")
        .or(`slug.eq.${handoff.to_agent},name.ilike.${handoff.to_agent}`)
        .single();

      if (!toAgent) {
        console.warn(`Agente não encontrado: ${handoff.to_agent}`);
        continue;
      }

      // Registrar handoff
      await supabase.from("handoffs").insert({
        from_agent_id: mission.agent_id,
        to_agent_id: toAgent.id,
        mission_id: mission.id,
        signal_type: handoff.signal_type,
        payload: handoff.payload,
        status: "pending",
      });

      // Criar nova missão derivada para o agente destino
      const newMissionTitle = `[Handoff] ${handoff.signal_type} — de ${mission.agents?.name || "agente"}`;
      const { data: newMission } = await supabase
        .from("missions")
        .insert({
          title: newMissionTitle,
          description: JSON.stringify(handoff.payload),
          status: "assigned",
          priority: mission.priority,
          priority_score: mission.priority_score,
          agent_id: toAgent.id,
          client_id: mission.client_id,
          parent_id: mission.id,
          context: {
            original_mission: mission.title,
            handoff_type: handoff.signal_type,
            from_agent: mission.agents?.name,
          },
          created_by: "handoff",
        })
        .select()
        .single();

      handoffsCreated++;
    }
  }

  // Processar alertas
  if (signals.alerts && signals.alerts.length > 0) {
    for (const alert of signals.alerts) {
      if (alert.level === "critical" || alert.level === "high") {
        const emoji = alert.level === "critical" ? "🔴" : "🟠";
        await sendTelegram(
          NETTO_TELEGRAM_ID,
          `${emoji} *Alerta WMC — ${alert.level.toUpperCase()}*\n` +
          `Missão: ${mission.title}\n` +
          `Agente: ${mission.agents?.emoji} ${mission.agents?.name}\n` +
          `Mensagem: ${alert.message}`
        );

        // Marcar missão como bloqueada se crítica
        if (alert.level === "critical") {
          await supabase
            .from("missions")
            .update({ status: "blocked", blocked_reason: alert.message })
            .eq("id", mission.id);
        }
      }
    }
  }

  return { hasHandoff: handoffsCreated > 0, handoffsCreated };
}

// =============================================================
// Envia mensagem via Telegram
// =============================================================
async function sendTelegram(chatId: string, text: string) {
  try {
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: "Markdown",
      }),
    });
  } catch (e) {
    console.error("Telegram send error:", e);
  }
}
