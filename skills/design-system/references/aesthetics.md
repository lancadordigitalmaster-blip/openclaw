# Guia de Estéticas — Design Extractor

> Estes são shells de referência. Adapte conforme os tokens extraídos do input do usuário.

---

## Industrial / Dark Tech

```css
:root {
  --color-bg: #0d0d0d;
  --color-surface: #141414;
  --color-surface-raised: #1c1c1c;
  --color-border: #2a2a2a;
  --color-text: #e8e8e8;
  --color-text-muted: #666;
  --color-accent: #ff6b00;       /* laranja LED */
  --color-accent-alt: #00ff88;   /* verde terminal */

  /* Sombras metálicas */
  --shadow-card:
    inset 0 1px 0 rgba(255,255,255,0.05),
    0 4px 20px rgba(0,0,0,0.6),
    0 1px 3px rgba(0,0,0,0.8);

  /* Borda metálica */
  --border-metal: 1px solid #2a2a2a;
  --gradient-metal: linear-gradient(135deg, #1c1c1c 0%, #141414 100%);
}

/* Botão industrial */
.btn-primary {
  background: var(--color-accent);
  box-shadow:
    0 0 20px rgba(255,107,0,0.3),
    inset 0 1px 0 rgba(255,255,255,0.1);
  border: 1px solid rgba(255,107,0,0.5);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
}
```

---

## Glassmorphism

```css
:root {
  --color-bg: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
  --glass-bg: rgba(255, 255, 255, 0.05);
  --glass-border: rgba(255, 255, 255, 0.1);
  --glass-blur: blur(20px);
  --color-text: #ffffff;
  --color-text-muted: rgba(255,255,255,0.6);
  --color-accent: #7c3aed;
}

.card {
  background: var(--glass-bg);
  backdrop-filter: var(--glass-blur);
  -webkit-backdrop-filter: var(--glass-blur);
  border: 1px solid var(--glass-border);
  border-radius: 20px;
}

/* Inner glow */
.card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, transparent 60%);
  pointer-events: none;
}
```

---

## Cyberpunk / Neon

```css
:root {
  --color-bg: #050508;
  --color-surface: #0a0a12;
  --color-border: #1a1a2e;
  --color-text: #e2e8f0;
  --color-text-muted: #64748b;
  --neon-primary: #00f5ff;    /* cyan */
  --neon-secondary: #ff00ff;  /* magenta */
  --neon-accent: #ffe600;     /* amarelo */
}

/* Efeito glitch em texto */
@keyframes glitch {
  0%, 100% { clip-path: inset(0 0 95% 0); transform: translateX(-2px); }
  25% { clip-path: inset(40% 0 40% 0); transform: translateX(2px); }
  50% { clip-path: inset(80% 0 5% 0); transform: translateX(-1px); }
}

/* Botão neon */
.btn-neon {
  border: 1px solid var(--neon-primary);
  color: var(--neon-primary);
  background: transparent;
  text-shadow: 0 0 8px var(--neon-primary);
  box-shadow:
    0 0 10px rgba(0,245,255,0.2),
    inset 0 0 10px rgba(0,245,255,0.05);
  clip-path: polygon(8px 0%, 100% 0%, calc(100% - 8px) 100%, 0% 100%);
}

/* Scan line overlay */
body::after {
  content: '';
  position: fixed;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0,0,0,0.05) 2px,
    rgba(0,0,0,0.05) 4px
  );
  pointer-events: none;
  z-index: 9999;
}
```

---

## Brutalist

```css
:root {
  --color-bg: #ffffff;
  --color-surface: #f5f5f5;
  --color-border: #000000;
  --color-text: #000000;
  --color-accent: #ff0000;  /* ou amarelo #ffff00 */
  --border-size: 3px;
  --radius: 0px;  /* ZERO radius */
}

.card {
  border: var(--border-size) solid var(--color-border);
  border-radius: 0;
  box-shadow: 6px 6px 0 #000;
  background: #fff;
}

.btn-primary {
  border: var(--border-size) solid #000;
  border-radius: 0;
  box-shadow: 4px 4px 0 #000;
  background: var(--color-accent);
  color: #000;
  text-transform: uppercase;
  font-weight: 700;
  transition: box-shadow 0.1s;
}

.btn-primary:hover {
  box-shadow: 2px 2px 0 #000;
  transform: translate(2px, 2px);
}
```

---

## Corporate / SaaS

```css
:root {
  --color-bg: #fafafa;
  --color-surface: #ffffff;
  --color-border: #e5e7eb;
  --color-text: #111827;
  --color-text-muted: #6b7280;
  --color-accent: #6366f1;      /* indigo */
  --color-accent-hover: #4f46e5;

  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.07), 0 1px 3px rgba(0,0,0,0.06);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05);
}
```

---

## Luxury / Premium

```css
:root {
  --color-bg: #0a0804;
  --color-surface: #12100a;
  --color-border: #2a2518;
  --color-text: #f5f0e8;
  --color-text-muted: #8a7d6a;
  --color-gold: #c9a84c;
  --color-gold-light: #e8c97a;

  --font-serif: 'Playfair Display', serif;  /* adicionar ao Google Fonts */
  --font-display: 'Plus Jakarta Sans', sans-serif;
}

h1, h2 {
  font-family: var(--font-serif);
  font-weight: 400;
  letter-spacing: 0.02em;
}

.accent-line {
  width: 40px;
  height: 1px;
  background: linear-gradient(90deg, var(--color-gold), transparent);
  margin: 16px auto;
}
```

---

## Playful / Consumer

```css
:root {
  --color-bg: #fffbf7;
  --color-surface: #ffffff;
  --color-border: #f0e8e0;
  --color-text: #1a1a1a;
  --color-text-muted: #888;
  --color-accent: #ff6b6b;
  --color-accent-2: #4ecdc4;
  --color-accent-3: #ffe66d;

  --radius-full: 9999px;
  --radius-lg: 24px;
  --radius-md: 16px;

  --gradient-fun: linear-gradient(135deg, #ff6b6b, #ffa500);
}

.btn-primary {
  border-radius: var(--radius-full);
  background: var(--gradient-fun);
  box-shadow: 0 8px 24px rgba(255,107,107,0.35);
  transform: translateY(0);
  transition: transform 0.2s, box-shadow 0.2s;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 32px rgba(255,107,107,0.45);
}
```
