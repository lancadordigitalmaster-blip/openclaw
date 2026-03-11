/**
 * AgentCapabilities Component
 * Exibe skills de cada agente com UI/UX visual
 * 
 * Design: Cards com badges de proficiência
 * Usa cores pra diferenciar pontos fortes vs melhorias
 */

import React from 'react';
import './AgentCapabilities.css';

const PROFICIENCY_LEVELS = {
  1: { label: 'Iniciante', color: '#9CA3AF' },
  2: { label: 'Intermediário', color: '#FBBF24' },
  3: { label: 'Avançado', color: '#60A5FA' },
  4: { label: 'Expert', color: '#34D399' },
  5: { label: 'Master', color: '#8B5CF6' },
};

const CATEGORY_COLORS = {
  marketing: '#FF6B6B',
  dev: '#4ECDC4',
  design: '#FFE66D',
  strategy: '#95E1D3',
  ops: '#F38181',
};

export function AgentCapabilities({ agent, capabilities }) {
  if (!agent || !capabilities) {
    return <div className="agent-capabilities empty">Sem dados</div>;
  }

  const { strengths = [], improvements = [] } = capabilities;

  return (
    <div className="agent-capabilities">
      <div className="agent-header">
        <span className="agent-emoji">{agent.emoji}</span>
        <div className="agent-info">
          <h3>{agent.name}</h3>
          <span className="squad-badge">{agent.squad}</span>
        </div>
      </div>

      {/* PONTOS FORTES */}
      {strengths.length > 0 && (
        <div className="skills-section strengths">
          <h4 className="section-title">💪 Pontos Fortes</h4>
          <div className="skills-grid">
            {strengths.map((skill, idx) => (
              <SkillBadge key={idx} skill={skill} isStrength={true} />
            ))}
          </div>
        </div>
      )}

      {/* MELHORIAS */}
      {improvements.length > 0 && (
        <div className="skills-section improvements">
          <h4 className="section-title">📈 Áreas de Melhoria</h4>
          <div className="skills-grid">
            {improvements.map((skill, idx) => (
              <SkillBadge key={idx} skill={skill} isStrength={false} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SkillBadge({ skill, isStrength }) {
  const profLevel = PROFICIENCY_LEVELS[skill.proficiency] || PROFICIENCY_LEVELS[3];
  const categoryColor = CATEGORY_COLORS[skill.category] || '#6B7280';

  return (
    <div
      className={`skill-badge ${isStrength ? 'strength' : 'improvement'}`}
      style={{
        borderColor: categoryColor,
        '--proficiency-color': profLevel.color,
      }}
    >
      <div className="skill-name">{skill.skill}</div>
      <div className="skill-meta">
        <span className="category-tag" style={{ backgroundColor: categoryColor }}>
          {skill.category}
        </span>
        <div className="proficiency-bar">
          <div
            className="proficiency-fill"
            style={{
              width: `${(skill.proficiency / 5) * 100}%`,
              backgroundColor: profLevel.color,
            }}
          />
        </div>
        <span className="proficiency-label">{profLevel.label}</span>
      </div>

      {/* TOOLS */}
      {skill.tools && skill.tools.length > 0 && (
        <div className="tools-list">
          {skill.tools.slice(0, 3).map((tool, idx) => (
            <span key={idx} className="tool-tag">
              {tool}
            </span>
          ))}
          {skill.tools.length > 3 && (
            <span className="tool-tag more">+{skill.tools.length - 3}</span>
          )}
        </div>
      )}
    </div>
  );
}

export default AgentCapabilities;
