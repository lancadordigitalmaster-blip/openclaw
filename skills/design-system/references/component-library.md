# Biblioteca de Componentes Base — Design Extractor

> Estes são shells de componentes. Adapte as CSS Variables conforme os tokens extraídos.
> Todos os componentes assumem que as variáveis do :root já estão definidas.

---

## Button System

```html
<!-- Primary -->
<button class="btn btn-primary">Ação Principal</button>

<!-- Secondary -->
<button class="btn btn-secondary">Ação Secundária</button>

<!-- Ghost -->
<button class="btn btn-ghost">Ação Terciária</button>

<!-- Danger -->
<button class="btn btn-danger">Excluir</button>

<!-- Loading -->
<button class="btn btn-primary btn-loading" disabled>
  <span class="spinner"></span>
  Carregando...
</button>

<!-- Icon + Text -->
<button class="btn btn-primary btn-icon">
  <svg width="16" height="16"><!-- icon --></svg>
  Com Ícone
</button>

<style>
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 20px;
  border-radius: var(--radius-md);
  font-family: var(--font-display);
  font-size: 14px;
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
  transition: all 0.18s var(--ease);
  border: 1px solid transparent;
  white-space: nowrap;
  text-decoration: none;
}

.btn:disabled { opacity: 0.4; cursor: not-allowed; }

.btn-primary {
  background: var(--color-accent);
  color: var(--color-bg);
  border-color: var(--color-accent);
}
.btn-primary:hover:not(:disabled) { filter: brightness(1.1); }
.btn-primary:active:not(:disabled) { filter: brightness(0.9); transform: translateY(1px); }

.btn-secondary {
  background: var(--color-surface);
  color: var(--color-text);
  border-color: var(--color-border);
}
.btn-secondary:hover:not(:disabled) { background: var(--color-border); }

.btn-ghost {
  background: transparent;
  color: var(--color-text);
  border-color: transparent;
}
.btn-ghost:hover:not(:disabled) { background: var(--color-surface); }

.btn-danger {
  background: transparent;
  color: #ef4444;
  border-color: #ef4444;
}
.btn-danger:hover:not(:disabled) { background: #ef4444; color: white; }

.spinner {
  width: 14px;
  height: 14px;
  border: 2px solid currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }
</style>
```

---

## Card

```html
<div class="card">
  <div class="card-header">
    <span class="card-tag">Label</span>
    <button class="card-action">···</button>
  </div>
  <h3 class="card-title">Título do Card</h3>
  <p class="card-body">Descrição ou conteúdo do card. Limite de 2-3 linhas para legibilidade.</p>
  <div class="card-footer">
    <span class="card-meta">Metadado</span>
    <button class="btn btn-primary" style="padding:8px 16px; font-size:13px;">Ação</button>
  </div>
</div>

<style>
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 20px;
  transition: transform 0.2s var(--ease), box-shadow 0.2s var(--ease);
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md, 0 8px 24px rgba(0,0,0,0.15));
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.card-tag {
  font-family: var(--font-mono, monospace);
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-accent);
  background: rgba(var(--color-accent-rgb, 255,68,68), 0.1);
  padding: 3px 8px;
  border-radius: var(--radius-sm);
}

.card-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 8px;
  line-height: 1.3;
}

.card-body {
  font-size: 14px;
  line-height: 1.6;
  color: var(--color-text-muted);
  margin-bottom: 16px;
}

.card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.card-meta {
  font-size: 12px;
  color: var(--color-text-muted);
  font-family: var(--font-mono, monospace);
}
</style>
```

---

## Form Elements

```html
<!-- Input -->
<div class="field">
  <label class="field-label">Label</label>
  <input type="text" class="input" placeholder="Placeholder text">
  <span class="field-hint">Texto de ajuda opcional</span>
</div>

<!-- Input Error -->
<div class="field field-error">
  <label class="field-label">Label</label>
  <input type="text" class="input" value="Valor inválido">
  <span class="field-hint">Mensagem de erro</span>
</div>

<!-- Toggle -->
<label class="toggle">
  <input type="checkbox" class="toggle-input">
  <span class="toggle-track">
    <span class="toggle-thumb"></span>
  </span>
  <span class="toggle-label">Ativar recurso</span>
</label>

<style>
.field { display: flex; flex-direction: column; gap: 6px; }

.field-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--color-text);
  letter-spacing: 0.01em;
}

.input {
  width: 100%;
  padding: 10px 14px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-family: var(--font-display);
  font-size: 14px;
  transition: border-color 0.15s var(--ease), box-shadow 0.15s var(--ease);
  outline: none;
}

.input::placeholder { color: var(--color-text-muted); }

.input:focus {
  border-color: var(--color-accent);
  box-shadow: 0 0 0 3px rgba(var(--color-accent-rgb, 255,68,68), 0.15);
}

.field-error .input { border-color: #ef4444; }
.field-error .field-hint { color: #ef4444; }

.field-hint { font-size: 12px; color: var(--color-text-muted); }

/* Toggle */
.toggle { display: flex; align-items: center; gap: 10px; cursor: pointer; }
.toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }

.toggle-track {
  position: relative;
  width: 44px;
  height: 24px;
  background: var(--color-border);
  border-radius: 12px;
  transition: background 0.2s var(--ease);
  flex-shrink: 0;
}

.toggle-input:checked + .toggle-track { background: var(--color-accent); }

.toggle-thumb {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 18px;
  height: 18px;
  background: white;
  border-radius: 50%;
  transition: transform 0.2s var(--ease);
  box-shadow: 0 1px 3px rgba(0,0,0,0.3);
}

.toggle-input:checked + .toggle-track .toggle-thumb { transform: translateX(20px); }
.toggle-label { font-size: 14px; color: var(--color-text); }
</style>
```

---

## Badge System

```html
<span class="badge badge-default">Default</span>
<span class="badge badge-success">Ativo</span>
<span class="badge badge-warning">Pendente</span>
<span class="badge badge-error">Erro</span>
<span class="badge badge-accent">Premium</span>
<span class="badge badge-dot badge-success">
  <span class="dot"></span>Online
</span>

<style>
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: var(--radius-sm);
  font-size: 11px;
  font-weight: 600;
  font-family: var(--font-mono, monospace);
  letter-spacing: 0.04em;
  text-transform: uppercase;
  white-space: nowrap;
}

.badge-default  { background: var(--color-surface); color: var(--color-text-muted); border: 1px solid var(--color-border); }
.badge-success  { background: rgba(34,197,94,0.15); color: #22c55e; }
.badge-warning  { background: rgba(234,179,8,0.15); color: #eab308; }
.badge-error    { background: rgba(239,68,68,0.15); color: #ef4444; }
.badge-accent   { background: rgba(var(--color-accent-rgb,255,68,68),0.15); color: var(--color-accent); }

.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}
</style>
```

---

## Alert System

```html
<div class="alert alert-success">
  <svg class="alert-icon" viewBox="0 0 20 20" fill="currentColor">
    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"/>
  </svg>
  <div>
    <p class="alert-title">Sucesso</p>
    <p class="alert-body">Operação realizada com sucesso.</p>
  </div>
</div>

<style>
.alert {
  display: flex;
  gap: 12px;
  padding: 14px 16px;
  border-radius: var(--radius-md);
  border: 1px solid transparent;
}

.alert-icon { width: 20px; height: 20px; flex-shrink: 0; margin-top: 1px; }
.alert-title { font-size: 14px; font-weight: 600; margin-bottom: 2px; }
.alert-body { font-size: 13px; opacity: 0.8; line-height: 1.5; }

.alert-success { background: rgba(34,197,94,0.1); border-color: rgba(34,197,94,0.2); color: #22c55e; }
.alert-warning { background: rgba(234,179,8,0.1); border-color: rgba(234,179,8,0.2); color: #eab308; }
.alert-error   { background: rgba(239,68,68,0.1); border-color: rgba(239,68,68,0.2); color: #ef4444; }
.alert-info    { background: rgba(59,130,246,0.1); border-color: rgba(59,130,246,0.2); color: #3b82f6; }
</style>
```
