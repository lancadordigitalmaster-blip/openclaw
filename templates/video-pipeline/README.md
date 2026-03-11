# 🎬 PIPELINE DE VÍDEO — Wolf Agency

> Estrutura anti-frustração. Cada etapa é um checkpoint. Nada se perde.

---

## 📁 Estrutura de Pastas

```
PROJETO-VIDEO/
├── 📋 00-briefing/           → Briefing aprovado (NÃO EDITAR)
├── 📝 01-pre-producao/       → Pesquisa, referências, inspiração
├── 📖 02-roteiro/            → Roteiros versionados
├── 🎨 03-storyboard/         → Storyboard e animatic
├── 🎥 04-gravacao/           → Footage brutos organizados
├── ✂️ 05-edicao/             → Projetos de edição (versionados)
├── 👁️ 06-revisao/            → Versões para aprovação
├── ✅ 07-final/              → Master final (congelado)
├── 🚀 08-entrega/            → Exports em formatos específicos
├── 📦 _assets/               → Assets compartilhados (música, fontes, LUTs)
├── 📤 _exports/              → Exports temporários
└── 🗄️ _archive/              → Arquivos descartados (não deleta)
```

---

## 🚦 REGRAS DE OURO

### 1. NUNCA edite na pasta de origem
- `00-briefing/` é SÓ LEITURA após aprovado
- Crie cópia na próxima etapa para editar

### 2. VERSIONAMENTO OBRIGATÓRIO
```
roteiro_v01.md
roteiro_v02_revisao-netto.md
roteiro_v03_aprovado.md
```

### 3. CHECKPOINTS = SALVAMENTO
Antes de qualquer mudança grande:
- Copie para `_archive/`
- Nomeie com data: `projeto_2026-03-05_v01.prproj`

### 4. NOMENCLATURA PADRONIZADA
```
[projeto]_[etapa]_[versao]_[estado].[ext]

ex: campanha-q1_05-edicao_v03_revisando.prproj
ex: campanha-q1_06-revisao_v04_para-cliente.mp4
```

---

## 🔄 FLUXO DE TRABALHO

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 00-BRIEFING │───→│01-PRE-PROD  │───→│ 02-ROTEIRO  │
│  (aprovado) │    │(referências)│    │ (versionado)│
└─────────────┘    └─────────────┘    └──────┬──────┘
                                             │
┌─────────────┐    ┌─────────────┐    ┌──────▼──────┐
│ 08-ENTREGA  │←───│ 07-FINAL    │←───│ 06-REVISAO  │
│  (formats)  │    │  (master)   │    │(aprovação)  │
└─────────────┘    └─────────────┘    └──────┬──────┘
                                             │
┌─────────────┐    ┌─────────────┐    ┌──────▼──────┐
│  _ARCHIVE   │    │ 05-EDIÇÃO   │←───│ 04-GRAVAÇÃO │
│ (descartes) │    │(projetos)   │    │  (footage)  │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## 📋 CHECKLIST POR ETAPA

### 00-Briefing
- [ ] Objetivo do vídeo definido
- [ ] Público-alvo claro
- [ ] Tom de voz aprovado
- [ ] Duração estimada
- [ ] Referências anexadas
- [ ] **APROVAÇÃO ASSINADA**

### 01-Pré-Produção
- [ ] Pesquisa de referências
- [ ] Mood board criado
- [ ] Paleta de cores definida
- [ ] Música/sons pre-selecionados
- [ ] Locação/equipamento confirmado

### 02-Roteiro
- [ ] Roteiro v01 escrito
- [ ] Revisão interna
- [ ] Aprovação cliente
- [ ] Roteiro final congelado

### 03-Storyboard
- [ ] Storyboard desenhado
- [ ] Animatic (opcional)
- [ ] Timing aprovado

### 04-Gravação
- [ ] Checklist de equipamento
- [ ] Backup imediato (3 cópias)
- [ ] Organização por cenas
- [ ] Log de takes

### 05-Edição
- [ ] Projeto criado na pasta correta
- [ ] Assets organizados (bins/pastas)
- [ ] Corte rough
- [ ] Corte fine
- [ ] Color grading
- [ ] Mix de áudio

### 06-Revisão
- [ ] Export para revisão
- [ ] Feedback documentado
- [ ] Ajustes realizados
- [ ] **APROVAÇÃO FINAL**

### 07-Final
- [ ] Master em máxima qualidade
- [ ] Arquivos de projeto compactados
- [ ] Documentação final

### 08-Entrega
- [ ] Formato Redes Sociais (vertical 9:16)
- [ ] Formato YouTube (horizontal 16:9)
- [ ] Formato Stories (9:16 curto)
- [ ] Thumbnail

---

## 🛡️ PROTEÇÃO CONTRA PROBLEMAS

| Problema | Solução na estrutura |
|----------|---------------------|
| "Perdi o arquivo original" | `_archive/` guarda tudo |
| "Editei o briefing errado" | `00-briefing/` é read-only |
| "Qual versão é a final?" | `07-final/` só tem aprovado |
| "O cliente mudou tudo" | Versionamento mostra evolução |
| "O export travou" | `_exports/` separado do projeto |
| "Falta espaço" | `_archive/` pode ir para nuvem |

---

## 💾 BACKUP E ARMAZENAMENTO

### Local (SSD/Rápido)
- Etapas ativas (00-08)
- Projetos de edição abertos

### Nuvem (Sincronizado)
- `_assets/` (compartilhado)
- `07-final/` (entregas)
- `08-entrega/` (exports)

### Arquivo Frio
- `_archive/` após 30 dias
- Projetos concluídos

---

## 🚀 QUICK START

1. **Copie** esta pasta `video-pipeline/`
2. **Renomeie** para seu projeto: `campanha-q1-2026/`
3. **Preencha** o briefing em `00-briefing/`
4. **Siga** o fluxo etapa por etapa
5. **Nunca pule** checkpoints

---

*Template v1.0 — Wolf Agency*
