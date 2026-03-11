import { Composition, AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing } from 'remotion';
import React from 'react';

// Componente de partículas de fundo
const Particles: React.FC = () => {
  const frame = useCurrentFrame();
  const particles = Array.from({ length: 20 }, (_, i) => ({
    id: i,
    x: Math.random() * 100,
    y: Math.random() * 100,
    size: Math.random() * 3 + 1,
    speed: Math.random() * 0.5 + 0.2,
  }));

  return (
    <AbsoluteFill style={{ background: '#0a0a0f' }}>
      {particles.map((p) => (
        <div
          key={p.id}
          style={{
            position: 'absolute',
            left: `${p.x}%`,
            top: `${p.y + (frame * p.speed) % 100}%`,
            width: p.size,
            height: p.size,
            background: '#00d4ff',
            borderRadius: '50%',
            opacity: 0.6,
            boxShadow: '0 0 10px #00d4ff',
          }}
        />
      ))}
    </AbsoluteFill>
  );
};

// Componente de scan lines
const ScanLines: React.FC = () => (
  <AbsoluteFill
    style={{
      background: 'repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,212,255,0.03) 2px, rgba(0,212,255,0.03) 4px)',
      pointerEvents: 'none',
    }}
  />
);

// Componente principal da intro
const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames, fps } = useVideoConfig();

  // Animação de entrada do texto
  const textOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const textScale = interpolate(frame, [0, 25], [0.8, 1], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Efeito de glitch
  const glitchOffset = interpolate(frame, [10, 15, 20], [0, 5, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Glow pulsante
  const glowIntensity = interpolate(frame, [0, 30, 60, 90, 120, 150], [0, 1, 0.7, 1, 0.8, 1], {
    extrapolateRight: 'clamp',
  });

  // Linha de scan aparecendo
  const scanProgress = interpolate(frame, [20, 50], [0, 100], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{ background: '#0a0a0f', fontFamily: 'monospace' }}>
      <Particles />
      <ScanLines />
      
      {/* Grid de fundo */}
      <AbsoluteFill
        style={{
          backgroundImage: `
            linear-gradient(rgba(0,212,255,0.05) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0,212,255,0.05) 1px, transparent 1px)
          `,
          backgroundSize: '50px 50px',
        }}
      />

      {/* Container do texto */}
      <AbsoluteFill
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
        }}
      >
        {/* Linha de scan */}
        <div
          style={{
            position: 'absolute',
            width: `${scanProgress}%`,
            height: 2,
            background: 'linear-gradient(90deg, transparent, #00d4ff, transparent)',
            top: '48%',
            opacity: 0.8,
          }}
        />

        {/* Texto principal com glitch */}
        <div
          style={{
            opacity: textOpacity,
            transform: `scale(${textScale}) translateX(${glitchOffset}px)`,
            textAlign: 'center',
          }}
        >
          <h1
            style={{
              fontSize: '80px',
              fontWeight: 'bold',
              color: '#ffffff',
              textShadow: `
                0 0 ${20 * glowIntensity}px #00d4ff,
                0 0 ${40 * glowIntensity}px #00d4ff,
                0 0 ${60 * glowIntensity}px #0088cc
              `,
              letterSpacing: '8px',
              margin: 0,
            }}
          >
            NETTO GIROTTO
          </h1>
          
          {/* Subtexto */}
          <div
            style={{
              marginTop: '20px',
              fontSize: '18px',
              color: '#00d4ff',
              opacity: interpolate(frame, [40, 60], [0, 0.8]),
              letterSpacing: '12px',
            }}
          >
            MARKETING DIGITAL
          </div>
        </div>

        {/* Efeito de borda tecnológica */}
        <div
          style={{
            position: 'absolute',
            bottom: '100px',
            width: interpolate(frame, [60, 90], [0, 300]),
            height: 2,
            background: 'linear-gradient(90deg, transparent, #00d4ff, transparent)',
            opacity: 0.6,
          }}
        />
      </AbsoluteFill>

      {/* Cantos tecnológicos */}
      <Corner position="top-left" frame={frame} />
      <Corner position="top-right" frame={frame} />
      <Corner position="bottom-left" frame={frame} />
      <Corner position="bottom-right" frame={frame} />
    </AbsoluteFill>
  );
};

// Componente de canto tecnológico
const Corner: React.FC<{ position: string; frame: number }> = ({ position, frame }) => {
  const opacity = interpolate(frame, [30, 50], [0, 1]);
  const size = 40;
  
  const positions: Record<string, React.CSSProperties> = {
    'top-left': { top: 30, left: 30 },
    'top-right': { top: 30, right: 30 },
    'bottom-left': { bottom: 30, left: 30 },
    'bottom-right': { bottom: 30, right: 30 },
  };

  return (
    <div
      style={{
        position: 'absolute',
        width: size,
        height: size,
        border: '2px solid #00d4ff',
        opacity,
        ...positions[position],
        borderRight: position.includes('left') ? 'none' : undefined,
        borderLeft: position.includes('right') ? 'none' : undefined,
        borderBottom: position.includes('top') ? 'none' : undefined,
        borderTop: position.includes('bottom') ? 'none' : undefined,
      }}
    />
  );
};

// Exporta a composição
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="Intro"
        component={Intro}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};

export default RemotionRoot;
