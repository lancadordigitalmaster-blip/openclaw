---

## Agent

**Luna** — social media e conteudo

---
name: wolf-video-pipeline
description: Pipeline profissional de produção de vídeo da Wolf Agency. Cria estrutura organizada com versionamento, checkpoints e proteção contra perda de arquivos. Use para qualquer projeto de vídeo — desde reels até campanhas completas.
---

# Wolf Video Pipeline 🎬

Pipeline profissional de produção de vídeo com estrutura anti-frustração.

## Uso

### Criar Novo Projeto
```bash
./templates/video-pipeline/new-video-project.sh [nome-do-projeto]
```

Exemplo:
```bash
./templates/video-pipeline/new-video-project.sh campanha-lancamento-q2
```

Isso cria em `projects/campanha-lancamento-q2/`:
```
├── 📋 00-briefing/           → Briefing aprovado (read-only)
├── 📝 01-pre-producao/       → Pesquisa e referências
├── 📖 02-roteiro/            → Roteiros versionados
├── 🎨 03-storyboard/         → Storyboard e animatic
├── 🎥 04-gravacao/           → Footage brutos
├── ✂️ 05-edicao/             → Projetos de edição
├── 👁️ 06-revisao/            → Versões para aprovação
├── ✅ 07-final/              → Master final
├── 🚀 08-entrega/            → Exports em formatos
├── 📦 _assets/               → Assets compartilhados
├── 📤 _exports/              → Exports temporários
└── 🗄️ _archive/              → Arquivos versionados
```

## Regras de Ouro

1. **NUNCA edite na pasta de origem** — `00-briefing/` é read-only
2. **VERSIONAMENTO OBRIGATÓRIO** — `arquivo_v01.md`, `arquivo_v02.md`
3. **CHECKPOINTS = SALVAMENTO** — copie para `_archive/` antes de mudanças grandes
4. **NOMENCLATURA PADRONIZADA** — `projeto_etapa_v##_estado.ext`

## Comandos Úteis

| Comando | Descrição |
|---------|-----------|
| `new-video-project.sh nome` | Cria estrutura de projeto |
| `ls projects/` | Lista projetos ativos |

## Templates Incluídos

- `00-briefing/BRIEFING-TEMPLATE.md` — Briefing completo
- `04-gravacao/CHECKLIST-GRAVACAO.md` — Checklist de equipamento
- `NOMENCLATURA.md` — Padrões de nomeação

## Integração Alfred

No Telegram, mencione:
- "criar projeto de vídeo [nome]" → Alfred executa o script
- "estrutura de vídeo" → Mostra este guia

## Arquivos de Referência

- `templates/video-pipeline/README.md` — Documentação completa
- `templates/video-pipeline/NOMENCLATURA.md` — Padrões de arquivo
