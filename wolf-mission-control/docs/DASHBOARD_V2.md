# Dashboard v2.0 — Arquitetura React + Supabase Realtime
# Planejado: 2026-03-05 | Status: NÃO IMPLEMENTADO (referência)

> Dashboard atual: 5 páginas HTML estáticas em `/workspace/*.html`
> Esta doc descreve a evolução para React/Next.js com Realtime.

---

## Stack

```
Next.js 14 (App Router)
Supabase JS v2 (Realtime + Auth)
Zustand (estado global)
Tailwind CSS + Wolf Design System
TypeScript
```

---

## Estrutura de Arquivos

```
wolf-dashboard/
├── app/
│   ├── layout.tsx          # Wolf Design System providers
│   ├── page.tsx            # Redirect para /kanban
│   ├── kanban/page.tsx     # Board de missões
│   ├── equipe/page.tsx     # Status dos agentes
│   ├── neural/page.tsx     # Topologia neural
│   ├── analytics/page.tsx  # Métricas e gráficos
│   └── config/page.tsx     # Configurações do sistema
├── components/
│   ├── kanban/
│   │   ├── KanbanBoard.tsx
│   │   ├── MissionCard.tsx
│   │   └── Column.tsx
│   ├── equipe/
│   │   ├── AgentCard.tsx
│   │   └── SquadSection.tsx
│   ├── neural/
│   │   └── NeuralCanvas.tsx   # Canvas com topologia animada
│   └── analytics/
│       ├── KPIStrip.tsx
│       └── Charts.tsx
├── lib/
│   ├── supabase.ts         # Client singleton
│   ├── realtime.ts         # Hook useWolfRealtime()
│   └── api.ts              # createMission(), resolveMissionBlock()
├── store/
│   ├── missionsStore.ts    # Zustand: missions com upsertMission()
│   └── agentsStore.ts      # Zustand: agents status
└── types/
    └── wolf.ts             # Mission, Agent, Client, Handoff, MissionOutput
```

---

## TypeScript Types

```typescript
// types/wolf.ts

export type MissionStatus =
  | "inbox" | "assigned" | "in_progress"
  | "blocked" | "handoff" | "done" | "cancelled";

export type MissionPriority = "low" | "medium" | "high" | "critical";

export interface Mission {
  id: string;
  title: string;
  description: string;
  status: MissionStatus;
  priority: MissionPriority;
  priority_score: number;
  agent_id: string | null;
  client_id: string | null;
  parent_id: string | null;
  blocked_reason: string | null;
  due_at: string | null;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
  agents?: Agent;
  clients?: Client;
}

export interface Agent {
  id: string;
  name: string;
  emoji: string;
  slug: string;
  squad: "core" | "marketing" | "dev" | "ops";
  type: "LEAD" | "SPEC" | "INT";
  role: string;
  status: "idle" | "working" | "busy" | "error";
  model: string;
  governance: "L1" | "L2" | "L3" | "L4";
  created_at: string;
}

export interface Client {
  id: string;
  name: string;
  slug: string;
  telegram_id: string | null;
  clickup_list_id: string | null;
  status: "active" | "inactive" | "paused";
}

export interface Handoff {
  id: string;
  from_agent_id: string;
  to_agent_id: string;
  mission_id: string;
  signal_type: string;
  payload: Record<string, unknown>;
  status: "pending" | "accepted" | "ignored";
  created_at: string;
}
```

---

## Supabase Client + Realtime

```typescript
// lib/supabase.ts
import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

// lib/realtime.ts
import { useEffect } from "react";
import { supabase } from "./supabase";
import { useMissionsStore } from "@/store/missionsStore";
import { useAgentsStore } from "@/store/agentsStore";

export function useWolfRealtime() {
  const { upsertMission } = useMissionsStore();
  const { updateAgentStatus } = useAgentsStore();

  useEffect(() => {
    const channel = supabase
      .channel("wolf-realtime")
      .on("postgres_changes", { event: "*", schema: "public", table: "missions" },
        (payload) => upsertMission(payload.new as Mission)
      )
      .on("postgres_changes", { event: "*", schema: "public", table: "agents" },
        (payload) => updateAgentStatus(payload.new as Agent)
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, []);
}
```

---

## Zustand Store (Missões)

```typescript
// store/missionsStore.ts
import { create } from "zustand";
import type { Mission } from "@/types/wolf";

interface MissionsState {
  missions: Mission[];
  setMissions: (missions: Mission[]) => void;
  upsertMission: (mission: Mission) => void;
  getMissionsByStatus: (status: Mission["status"]) => Mission[];
}

export const useMissionsStore = create<MissionsState>((set, get) => ({
  missions: [],
  setMissions: (missions) => set({ missions }),
  upsertMission: (mission) =>
    set((state) => {
      const index = state.missions.findIndex((m) => m.id === mission.id);
      if (index >= 0) {
        const updated = [...state.missions];
        updated[index] = mission;
        return { missions: updated };
      }
      return { missions: [mission, ...state.missions] };
    }),
  getMissionsByStatus: (status) =>
    get().missions.filter((m) => m.status === status),
}));
```

---

## API Helpers

```typescript
// lib/api.ts
import { supabase } from "./supabase";

export async function createMission(params: {
  title: string;
  description: string;
  agent_slug: string;
  client_slug?: string;
  priority?: string;
}) {
  // Buscar IDs por slug
  const [{ data: agent }, { data: client }] = await Promise.all([
    supabase.from("agents").select("id").eq("slug", params.agent_slug).single(),
    params.client_slug
      ? supabase.from("clients").select("id").eq("slug", params.client_slug).single()
      : Promise.resolve({ data: null }),
  ]);

  return supabase.from("missions").insert({
    title: params.title,
    description: params.description,
    agent_id: agent?.id ?? null,
    client_id: client?.id ?? null,
    priority: params.priority ?? "medium",
    status: "assigned",
    created_by: "dashboard",
  }).select().single();
}

export async function resolveMissionBlock(missionId: string) {
  return supabase.from("missions")
    .update({ status: "assigned", blocked_reason: null })
    .eq("id", missionId);
}

export async function getDashboardMetrics() {
  const [missions, agents, escalations] = await Promise.all([
    supabase.from("missions").select("status, priority_score").not("status", "in", '("done","cancelled")'),
    supabase.from("agents").select("status, squad"),
    supabase.from("escalations").select("level").is("resolved_at", null),
  ]);

  return { missions: missions.data, agents: agents.data, escalations: escalations.data };
}
```

---

## Kanban Board (componente principal)

```typescript
// components/kanban/KanbanBoard.tsx
"use client";
import { useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { useMissionsStore } from "@/store/missionsStore";
import { useWolfRealtime } from "@/lib/realtime";
import Column from "./Column";

const COLUMNS: Mission["status"][] = ["inbox", "assigned", "in_progress", "blocked", "done"];

export default function KanbanBoard() {
  const { setMissions, getMissionsByStatus } = useMissionsStore();
  useWolfRealtime(); // Inicia subscriptions Realtime

  useEffect(() => {
    supabase
      .from("missions")
      .select("*, agents(*), clients(*)")
      .not("status", "in", '("cancelled")')
      .order("priority_score", { ascending: false })
      .then(({ data }) => data && setMissions(data));
  }, []);

  return (
    <div className="kanban-board">
      {COLUMNS.map((status) => (
        <Column key={status} status={status} missions={getMissionsByStatus(status)} />
      ))}
    </div>
  );
}
```

---

## Variáveis de Ambiente (.env.local)

```bash
NEXT_PUBLIC_SUPABASE_URL=https://dqhiafxbljujahmpcdhf.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
```

---

## Roadmap de Implementação

- [ ] **Fase 1:** Setup Next.js + Supabase + tipos TypeScript
- [ ] **Fase 2:** KanbanBoard com Realtime (substituir wolf-kanban.html)
- [ ] **Fase 3:** Equipe page com status de agentes ao vivo
- [ ] **Fase 4:** Analytics page com queries do banco (substituir wolf-analytics.html)
- [ ] **Fase 5:** Neural page (canvas animado) com dados reais de missões
- [ ] **Fase 6:** Config page (editar system prompts dos agentes)

> Implementar quando Netto confirmar que quer migrar de HTML estático para React.

---

*Wolf Mission Control · Dashboard v2.0 Architecture · 2026-03-05*
