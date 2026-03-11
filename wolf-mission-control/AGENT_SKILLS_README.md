# 🎯 Agent Skills & Capabilities System

**Status:** ✅ Ready to Deploy  
**Components:** SQL + React + CSS  
**Purpose:** Visualizar pontos fortes/fracos de cada agente no Mission Control

---

## 🚀 Como Usar

### 1. Deploy no Supabase

Rode essas migrations na ordem:

```sql
-- 1. Primeiro
./wolf-mission-control/migrations/002_agent_skills.sql

-- 2. Depois (seed data)
./wolf-mission-control/seeds/agent_skills_data.sql
```

### 2. Integrar no Mission Control

```jsx
import AgentCapabilities from './components/AgentCapabilities';

// Inside your Mission Detail component
<AgentCapabilities 
  agent={mission.agent} 
  capabilities={mission.agent_capabilities}
/>
```

### 3. Query no Banco

```sql
SELECT * FROM agent_capability_summary
WHERE id = :agent_id;
```

Retorna:

```json
{
  "id": "uuid",
  "name": "Luna",
  "emoji": "✍️",
  "squad": "marketing",
  "capabilities": {
    "strengths": [
      {
        "skill": "Copywriting",
        "proficiency": 5,
        "category": "marketing",
        "tools": ["Notion", "Canva"]
      }
    ],
    "improvements": [
      {
        "skill": "Technical SEO",
        "proficiency": 2,
        "category": "marketing"
      }
    ]
  }
}
```

---

## 📊 Visualização

Cards com:
- ✅ **Pontos Fortes** (destaque em cor)
- 📈 **Áreas de Melhoria** (mais opaco)
- 📊 **Proficiency Bar** (1-5 stars visual)
- 🛠️ **Tools** (lista de ferramentas que usa)

---

## 🔄 Manutenção

### Adicionar novo agente

```sql
INSERT INTO agent_skills (agent_id, skill_name, category, proficiency, is_strength)
VALUES (
  (SELECT id FROM agents WHERE slug = 'seu-agente'),
  'Skill Name',
  'marketing|dev|design|strategy|ops',
  3,
  TRUE
);
```

### Atualizar proficiência

```sql
UPDATE agent_skills
SET proficiency = 4
WHERE skill_name = 'React Development'
  AND agent_id = (SELECT id FROM agents WHERE slug = 'pixel');
```

---

## 🎨 Customização

**Mudar cores:**
- Edit `AgentCapabilities.css` → `CATEGORY_COLORS`
- Proficiency colors em `PROFICIENCY_LEVELS`

**Ajustar layout:**
- Grid em `skills-grid` (default: `auto-fill minmax(220px)`)
- Responsivo em `@media (max-width: 768px)`

---

## 🧪 Testes

```javascript
// Mock data pra testar
const mockAgent = {
  id: '123',
  name: 'Luna',
  emoji: '✍️',
  squad: 'marketing'
};

const mockCapabilities = {
  strengths: [
    {
      skill: 'Copywriting',
      proficiency: 5,
      category: 'marketing',
      tools: ['Notion', 'Canva']
    }
  ],
  improvements: [
    {
      skill: 'Technical SEO',
      proficiency: 2,
      category: 'marketing'
    }
  ]
};

<AgentCapabilities 
  agent={mockAgent} 
  capabilities={mockCapabilities} 
/>
```

---

## 📈 Próximos Passos

1. [ ] Integrar em Mission Card (mostrar skills ao clicar agente)
2. [ ] Adicionar filtro "Procurar agentes por skill"
3. [ ] Dashboard de "Skill Gaps" (o que falta no time)
4. [ ] Auto-update de proficiência baseado em performance
5. [ ] Sugerir handoffs baseado em skills complementares

---

*Criado: 2026-03-07*  
*Sistema: Agent Skills & Capabilities v1.0*
