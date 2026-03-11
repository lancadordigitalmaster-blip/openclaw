// Wolf Mission Control — Edge Function: memory-writer
// Versão: 1.0 | 2026-03-05
// Extrai lições estruturadas de um output aprovado e salva em agent_memory.
// Chamado automaticamente pelo quality-gate após aprovação.
// Acumula contexto por agente × cliente para missões futuras.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OLLAMA_CLOUD_KEY     = Deno.env.get("OLLAMA_CLOUD_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// =============================================================
// EXTRAÇÃO DE MEMÓRIA COM GEMINI
// =============================================================
async function extractMemory(
  missionTitle: string,
  missionDescription: string,
  agentName: string,
  agentRole: string,
  clientName: string,
  output: string,
  qualityScore: number
): Promise<Array<{
  memory_type: string;
  key: string;
  content: Record<string, unknown>;
  relevance: number;
  expires_at: string | null;
}>> {

  const system = `Você é o sistema de memória do Wolf Mission Control.
Dado um output de qualidade aprovada, extraia lições e contexto para sessões futuras.

Extraia APENAS informações concretas e reutilizáveis. Ignore boilerplate.
Foco em:
- Padrões que funcionaram (ex: "campanha CBO com público frio funcionou para clínicas")
- Dados de performance (CPA, ROAS, CTR específicos de um cliente)
- Preferências identificadas (tom de comunicação, estilo visual)
- Erros evitados (ex: "cliente X não aceita CTAs diretas")
- Insights de mercado (concorrentes, tendências, benchmarks)

Responda SOMENTE com JSON array válido. Máximo 4 itens:
[
  {
    "memory_type": "performance|context|lesson|signal",
    "key": "chave_unica_snake_case",
    "content": { "resumo": "...", "dados": {...}, "quando_usar": "..." },
    "relevance": 0.0-1.0,
    "expires_days": null ou número de dias até expirar (null = permanente)
  }
]

memory_type:
- performance: métricas numéricas (CPA, ROAS, taxa de abertura, score)
- context: informações sobre o cliente ou projeto
- lesson: aprendizado reutilizável para próximas missões
- signal: alerta ou padrão de atenção`;

  const user = `AGENTE: ${agentName} (${agentRole})
CLIENTE: ${clientName}
MISSÃO: ${missionTitle}
OBJETIVO: ${missionDescription.slice(0, 400)}
QUALITY SCORE: ${(qualityScore * 100).toFixed(0)}%

OUTPUT APROVADO:
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
        max_tokens: 1024,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    }
  );

  if (!res.ok) throw new Error(`Ollama Cloud memory-writer error: ${res.status}`);
  const json = await res.json();
  const raw  = json.choices[0].message.content;

  const jsonMatch = raw.match(/\[[\s\S]+\]/);
  if (!jsonMatch) {
    console.warn("[memory-writer] Gemini não retornou array JSON:", raw);
    return [];
  }

  const memories = JSON.parse(jsonMatch[0]);
  const now = Date.now();

  return memories.map((m: any) => ({
    memory_type: m.memory_type ?? "context",
    key:         m.key ?? `auto_${now}`,
    content:     m.content ?? {},
    relevance:   Math.min(1, Math.max(0, m.relevance ?? 0.7)),
    expires_at:  m.expires_days
      ? new Date(now + m.expires_days * 86400000).toISOString()
      : null,
  }));
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

    // 1. Buscar output com missão, agente e cliente
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
    const client  = mission.clients;

    // 2. Só processar se há cliente associado (memória é por agente × cliente)
    if (!mission.client_id) {
      await supabase.from("system_logs").insert({
        level: "info", source: "memory-writer",
        message: "Missão sem cliente — memória não gravada",
        agent_id: agent.id, mission_id: mission.id,
      });
      return new Response(JSON.stringify({ saved: 0, reason: "no_client" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Extrair memórias com Gemini
    const memories = await extractMemory(
      mission.title,
      mission.description,
      agent.name,
      agent.role,
      client?.name ?? "cliente desconhecido",
      outputRecord.output,
      outputRecord.quality ?? 0.75
    );

    if (memories.length === 0) {
      await supabase.from("system_logs").insert({
        level: "info", source: "memory-writer",
        message: "Nenhuma memória extraída do output",
        agent_id: agent.id, mission_id: mission.id,
      });
      return new Response(JSON.stringify({ saved: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Salvar memórias (upsert por agent_id+client_id+memory_type+key)
    let saved = 0;
    for (const mem of memories) {
      const { error } = await supabase.from("agent_memory").upsert({
        agent_id:    agent.id,
        client_id:   mission.client_id,
        memory_type: mem.memory_type,
        key:         mem.key,
        content:     {
          ...mem.content,
          source_mission: mission.title,
          source_output:  output_id,
          updated_at:     new Date().toISOString(),
        },
        relevance:   mem.relevance,
        expires_at:  mem.expires_at,
      }, { onConflict: "agent_id,client_id,memory_type,key" });

      if (error) {
        console.error("[memory-writer] upsert error:", error.message);
      } else {
        saved++;
      }
    }

    // 5. Log
    await supabase.from("system_logs").insert({
      level: "info", source: "memory-writer",
      message: `${saved} memórias gravadas para ${agent.name} × ${client?.name}`,
      agent_id: agent.id, mission_id: mission.id,
      payload: { saved, memories_count: memories.length, client: client?.name },
    });

    return new Response(
      JSON.stringify({ saved, total_extracted: memories.length }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[memory-writer]", err);
    await supabase.from("system_logs").insert({
      level: "error", source: "memory-writer",
      message: `Erro no memory-writer: ${err.message}`,
      payload: { error: String(err) },
    }).catch(() => {});
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
