/**
 * MissionCard com Agent Skills Integrado
 * 
 * Exemplo de como usar o AgentCapabilities dentro de uma Mission Card
 */

import React, { useState } from 'react';
import AgentCapabilities from './AgentCapabilities';
import './MissionCard.css';

export function MissionCard({ mission, onUpdate }) {
  const [expandCapabilities, setExpandCapabilities] = useState(false);

  const getPriorityColor = (priority) => {
    const colors = {
      critical: '#EF4444',
      high: '#F97316',
      medium: '#EAB308',
      low: '#84CC16',
    };
    return colors[priority] || '#6B7280';
  };

  const getStatusIcon = (status) => {
    const icons = {
      inbox: '📥',
      assigned: '🎯',
      in_progress: '🔄',
      blocked: '🚫',
      done: '✅',
      cancelled: '❌',
    };
    return icons[status] || '❓';
  };

  return (
    <div className="mission-card">
      {/* HEADER */}
      <div className="mission-header">
        <div className="mission-status">
          <span className="status-icon">{getStatusIcon(mission.status)}</span>
          <span className="status-text">{mission.status}</span>
        </div>
        <div
          className="priority-dot"
          style={{ backgroundColor: getPriorityColor(mission.priority) }}
          title={`Prioridade: ${mission.priority}`}
        />
      </div>

      {/* TITLE & DESCRIPTION */}
      <div className="mission-content">
        <h3 className="mission-title">{mission.title}</h3>
        <p className="mission-description">{mission.description}</p>

        {/* AGENT ASSIGNMENT */}
        {mission.agent && (
          <div className="agent-assignment">
            <span className="agent-emoji">{mission.agent.emoji}</span>
            <span className="agent-name">{mission.agent.name}</span>
          </div>
        )}
      </div>

      {/* METADATA */}
      <div className="mission-meta">
        {mission.due_at && (
          <span className="meta-item">
            📅 {new Date(mission.due_at).toLocaleDateString('pt-BR')}
          </span>
        )}
        {mission.tags && mission.tags.length > 0 && (
          <div className="tags">
            {mission.tags.map((tag) => (
              <span key={tag} className="tag">
                {tag}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* AGENT CAPABILITIES (EXPANDÍVEL) */}
      {mission.agent && mission.agent_capabilities && (
        <div className="capabilities-section">
          <button
            className="capabilities-toggle"
            onClick={() => setExpandCapabilities(!expandCapabilities)}
          >
            <span className="toggle-icon">{expandCapabilities ? '▼' : '▶'}</span>
            Ver Skills do Agente
          </button>

          {expandCapabilities && (
            <div className="capabilities-expanded">
              <AgentCapabilities
                agent={mission.agent}
                capabilities={mission.agent_capabilities}
              />
            </div>
          )}
        </div>
      )}

      {/* ACTIONS */}
      <div className="mission-actions">
        <button
          className="action-btn primary"
          onClick={() => onUpdate?.(mission.id, { status: 'in_progress' })}
          disabled={mission.status === 'in_progress'}
        >
          Começar
        </button>
        <button
          className="action-btn secondary"
          onClick={() => onUpdate?.(mission.id, { status: 'blocked' })}
        >
          Pausar
        </button>
      </div>
    </div>
  );
}

export default MissionCard;
