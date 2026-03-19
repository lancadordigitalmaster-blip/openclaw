// Wolf Mission Control — Edge Function: quality-gate
// Versão: 1.0 | 2026-03-05
// Avalia a qualidade do output de um agente em 4 dimensões usando Gemini.
// Aprovado (≥0.65) → missão done + aciona memory-writer
// Reprovado (<0.65) → cria missão de revisão (máx 2 tentativas)
// 3ª falha → escala para Netto via Telegram

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OLLAMA_CLOUD_KEY     = Deno.env.get("OLLAMA_CLOUD_KEY")!;
const TELEGRAM_BOT_TOKEN   = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const NETTO_TELEGRAM_ID    = Deno.env.get("NETTO_TELEGRAM_ID") ?? "789352357";

const QUALITY_THRESHOLD = 0.65;
const MAX_REVISIONS     = 2;
const EDGE_URL          = `${SUPABASE_URL}/functions/v1`;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// =============================================================
// AVALIAÇÃO DE QUALIDADE COM GEMINI
// =============================================================
async function evaluateQuality(
  missionTitle: string,
  missionDescription: string,
  agentRole: string,
  output: string
): Promise<{ score: number; breakdown: Record<string, number>; feedback: string }> {

  const system = `Você é um avaliador de qualidade de outputs de agentes de IA especializados.
Avalie o output nas 4 dimensões abaixo. Cada dimensão vale de 0 a 10.
Seja rigoroso: outputs genéricos que poderiam servir para qualquer missão devem tirar nota baixa.

DIMENSÕES:
1. Completude (0-10): O output responde ao objetivo declarado? Aborda todos os pontos da missão?
2. Especificidade (0-10): Contém números, datas, nomes, URLs, exemplos concretos? Ou é vago ("alguns", "vários", "melhorar")?
3. Acionabilidade (0-10): O próximo passo é claro e sem ambiguidade? Ou termina em "analisar", "considerar", "verificar"?
4. Qualidade Técnica (0-10): O nível é de especialista no domínio? Ou qualquer pessoa poderia ter escrito?

Responda SOMENTE com JSON válido:
{
  "completude": 0-10,
  "especificidade": 0-10,
  "acionabilidade": 0-10,
  "qualidade_tecnica": 0-10,
  "feedback": "1-2 frases explicando o principal ponto de melhoria (se houver)"
}`;

  const user = `MISSÃO: ${missionTitle}
OBJETIVO: ${missionDescription.slice(0, 500)}
AGENTE: ${agentRole}

OUTPUT A AVALIAR:
${output.slice(0, 3000)}`;

  const res = await fetch(
    "https://ollama.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OLLAMA_CLOUD_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gemma3:27b",
        max_tokens: 512,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    }
  );

  if (!res.ok) throw new Error(`Ollama Cloud quality-gate error: ${res.status}`);
  const json = await res.json();
  const raw  = json.choices[0].message.content;

  const jsonMatch = raw.match(/\{[\s\S]+\}/);
  if (!jsonMatch) throw new Error(`Quality gate não retornou JSON: ${raw}`);

  const breakdown = JSON.parse(jsonMatch[0]);
  const { completude, especificidade, acionabilidade, qualidade_tecnica, feedback } = breakdown;

  // Score final: média simples das 4 dimensões, normalizada para 0-1
  const score = ((completude + especificidade + acionabilidade + qualidade_tecnica) / 40);

  return {
    score,
    breakdown: { completude, especificidade, acionabilidade, qualidade_tecnica },
    feedback: feedback ?? "",
  };
}

// =============================================================
// TELEGRAM
// =============================================================
async function sendTelegram(chatId: string, text: string): Promise<void> {
  await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: "Markdown" }),
  }).catch(console.error);
}

// =============================================================
// HANDLER PRINCIPAL
// =============================================================
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization");
  if (!auth || auth !== `Bearer ${SUPABASE_SERVICE_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const { output_id } = await req.json();
    if (!output_id) {
      return new Response(JSON.stringify({ error: "output_id obrigatório" }), { status: 400 });
    }

    // 1. Buscar output com missão e agente
    const { data: outputRecord } = await supabase
      .from("mission_outputs")
      .select(`*, missions(*, agents(*), clients(*))`)
      .eq("id", output_id)
      .single();

    if (!outputRecord) {
      return new Response(JSON.stringify({ error: "Output não encontrado" }), { status: 404 });
    }

    const mission = outputRecord.missions;
    const agent   = mission.agents;

    // 2. Contar tentativas anteriores desta missão
    const { count: revisionCount } = await supabase
      .from("missions")
      .select("id", { count: "exact" })
      .eq("parent_id", mission.parent_id ?? mission.id)
      .eq("status", "done");

    const attempts = (revisionCount ?? 0) + 1;

    // 3. Avaliar qualidade
    const evaluation = await evaluateQuality(
      mission.title,
      mission.description,
      agent.role,
      outputRecord.output
    );

    // 4. Salvar score no output
    await supabase
      .from("mission_outputs")
      .update({ quality: evaluation.score, signals: evaluation.breakdown })
      .eq("id", output_id);

    // 5. Log
    await supabase.from("system_logs").insert({
      level: evaluation.score >= QUALITY_THRESHOLD ? "info" : "warning",
      source: "quality-gate",
      message: `Quality gate: score ${(evaluation.score * 100).toFixed(0)}% — ${evaluation.score >= QUALITY_THRESHOLD ? "APROVADO" : "REPROVADO"}`,
      agent_id: agent.id,
      mission_id: mission.id,
      payload: { score: evaluation.score, breakdown: evaluation.breakdown, feedback: evaluation.feedback, attempts },
    });

    // ==========================================================
    // APROVADO
    // ==========================================================
    if (evaluation.score >= QUALITY_THRESHOLD) {
      await supabase
        .from("missions")
        .update({ status: "done", completed_at: new Date().toISOString() })
        .eq("id", mission.id);

      // Acionar memory-writer (fire-and-forget)
      fetch(`${EDGE_URL}/memory-writer`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
        body: JSON.stringify({ output_id }),
      }).catch(console.error);

      return new Response(
        JSON.stringify({ approved: true, score: evaluation.score, feedback: evaluation.feedback }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ==========================================================
    // REPROVADO — 3ª tentativa → escalar para Netto
    // ==========================================================
    if (attempts >= MAX_REVISIONS + 1) {
      // Buscar todos os outputs desta missão para enviar ao Netto
      const { data: allOutputs } = await supabase
        .from("mission_outputs")
        .select("output, quality, created_at")
        .eq("mission_id", mission.id)
        .order("created_at");

      await supabase.from("missions")
        .update({ status: "blocked", blocked_reason: `Quality gate falhou ${attempts}× (score: ${(evaluation.score * 100).toFixed(0)}%)` })
        .eq("id", mission.id);

      await supabase.from("escalations").insert({
        type: "quality_failure",
        level: "L3",
        title: `Quality Gate falhou ${attempts}× — decisão humana necessária`,
        message: `Missão: ${mission.title}\nAgente: ${agent.emoji} ${agent.name}\nScore: ${(evaluation.score * 100).toFixed(0)}%\nFeedback: ${evaluation.feedback}`,
        agent_id: agent.id,
        mission_id: mission.id,
        metadata: { attempts, score: evaluation.score, breakdown: evaluation.breakdown },
      });

      const outputSummaries = allOutputs?.map((o: any, i: number) =>
        `*Tentativa ${i + 1}* (score: ${o.quality ? (o.quality * 100).toFixed(0) + "%" : "—"}):\n${o.output.slice(0, 300)}...`
      ).join("\n\n") ?? "";

      await sendTelegram(NETTO_TELEGRAM_ID,
        `🚨 *Quality Gate — Decisão Humana Necessária*\n\n` +
        `Missão: *${mission.title}*\n` +
        `Agente: ${agent.emoji} ${agent.name}\n` +
        `Falhou ${attempts}× consecutivas\n\n` +
        `*Últimos outputs:*\n${outputSummaries}\n\n` +
        `Use /decidir ${mission.id.slice(0, 8)} approve para aceitar o melhor output, ` +
        `ou /decidir ${mission.id.slice(0, 8)} reject para cancelar.`
      );

      return new Response(
        JSON.stringify({ approved: false, escalated: true, attempts, score: evaluation.score }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ==========================================================
    // REPROVADO — ainda tem tentativas → criar missão de revisão
    // ==========================================================
    await supabase.from("missions").insert({
      title:       `[Revisão ${attempts}] ${mission.title}`,
      description: `${mission.description}\n\n---\n## FEEDBACK DA REVISÃO ANTERIOR\n${evaluation.feedback}\n\n` +
                   `Score anterior: ${(evaluation.score * 100).toFixed(0)}% (mínimo: ${(QUALITY_THRESHOLD * 100).toFixed(0)}%)\n\n` +
                   `Pontuação por dimensão:\n` +
                   `- Completude: ${evaluation.breakdown.completude}/10\n` +
                   `- Especificidade: ${evaluation.breakdown.especificidade}/10\n` +
                   `- Acionabilidade: ${evaluation.breakdown.acionabilidade}/10\n` +
                   `- Qualidade Técnica: ${evaluation.breakdown.qualidade_tecnica}/10\n\n` +
                   `Output anterior para referência:\n${outputRecord.output.slice(0, 1000)}`,
      priority:    mission.priority,
      priority_score: mission.priority_score,
      agent_id:    mission.agent_id,
      client_id:   mission.client_id,
      parent_id:   mission.parent_id ?? mission.id,
      status:      "assigned",
      created_by:  "quality-gate",
    });

    await supabase.from("missions")
      .update({ status: "handoff" })
      .eq("id", mission.id);

    return new Response(
      JSON.stringify({ approved: false, revision_created: true, attempts, score: evaluation.score, feedback: evaluation.feedback }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[quality-gate]", err);
    await supabase.from("system_logs").insert({
      level: "error", source: "quality-gate",
      message: `Erro no quality-gate: ${err.message}`,
      payload: { error: String(err) },
    });
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
