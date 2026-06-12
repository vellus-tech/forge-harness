<div align="center">

# 🔨 Forge Project Harness

**Spec-Driven Development como fonte única — multi-agente, determinista e com code graph nativo.**

[![CI](https://github.com/MiltonSilvaJr/forge-harness/actions/workflows/ci.yml/badge.svg)](https://github.com/MiltonSilvaJr/forge-harness/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-v0.1.0--rc1-blue.svg)](./CHANGELOG.md)
[![Gates](https://img.shields.io/badge/gates-28%20passing-brightgreen.svg)](./tests)
[![Runtime](https://img.shields.io/badge/runtime-zero--dependency-success.svg)](#)
[![Node](https://img.shields.io/badge/node-%E2%89%A520-339933.svg)](#)
[![Adapters](https://img.shields.io/badge/adapters-claude%20%C2%B7%20codex%20%C2%B7%20cursor%20%C2%B7%20%2B5-8A2BE2.svg)](#adapters-multi-agente)

</div>

---

O **Forge Project Harness** transforma um repositório em um projeto **Spec-Driven Development (SDD)**:
uma única fonte de verdade em `.forge/`, da qual são geradas as configurações de cada ferramenta de IA
(Claude Code, Codex, Cursor, Gemini, Qwen, Kiro…). O fluxo do "o quê" ao "código" passa por gates com
**humano no loop**, validadores **deterministas** e um **code graph** nativo — tudo sem dependências de
runtime e sem gastar tokens onde não precisa.

> **Por que existe:** padronizar o ciclo spec→design→tasks→implementação→verificação→archive de forma
> reprodutível e agnóstica de agente, com rigor proporcional ao risco (Quick Plan para o simples, eval
> quantitativo opt-in para o avançado).

## ✨ Destaques

- **Fonte única `.forge/`** projetada para múltiplos agentes via `AGENTS.md` (padrão da indústria) +
  adapters gerados com **lockfile determinista** e **detecção de drift**.
- **Ciclo SDD com gates HITL:** `spec → clarify → requirements → design → tasks → implement → verify →
  archive`, com loops *builder→validator* (`[MISS]`/`[CONFLICT]`/`[CLARIFY]`, máx. 3 iterações).
- **Validadores deterministas** (não só revisores probabilísticos): harness, spec, archive, frontmatter, graph.
- **Code graph nativo** (zero-dep, zero tokens): dependências entre módulos, **violações de camada**
  (clean architecture), **ciclos**, símbolo-nível com herança, diagramas **C4** coloridos e **overview
  HTML interativo**.
- **Eval harness opt-in:** avaliação A/B quantitativa de skills/commands/templates + **meta-avaliação do
  próprio harness** (evolução por evidência, não opinião).
- **Sessões longas:** story sharding, waves, ledger de deferrals e disciplina de contexto.
- **Baseline & archive:** capabilities versionadas, `spec-delta` com *apply* determinista, ingestão de
  `docs/product/` legado **sem perda**.
- **PoC notação MDL 2.0** ([mdlmodel.com](https://mdlmodel.com)) gerada a partir do code graph.

## 🚀 Quickstart

```bash
# instalar o harness em um projeto (greenfield ou existente)
git clone https://github.com/MiltonSilvaJr/forge-harness.git
forge-harness/installer/install.sh \
  --target /caminho/do/seu-projeto \
  --slug seu-projeto --name "Seu Projeto" --desc "Descrição em 1 linha"

cd /caminho/do/seu-projeto
bash .forge/scripts/doctor.sh        # detecta stack + diagnostica o ambiente
```

O installer cria `.forge/` (fonte única) + `AGENTS.md` + `CLAUDE.md` (symlink) + os adapters do(s)
agente(s) ativo(s). Por padrão instala apenas o adapter **claude**; adicione outros com
`bash .forge/scripts/sync-adapters.sh --set claude,codex,cursor`.

## 🧭 Ciclo de vida SDD

```text
spec new ─▶ clarify ─▶ requirements ─▶ design ─▶ tasks ─▶ implement ─▶ verify ─▶ archive
              (HITL)        (loop)       (loop)             (story a story)        (baseline)
```

Cada transição é registrada por scripts deterministas; os gates humanos (`approve`/`review`/`reject`/
`block`) ficam em `approvals.yaml`. Em `scale` baixo, fases são puláveis (Quick Plan) com justificativa.

## 🕸️ Code graph & arquitetura

```bash
bash .forge/scripts/graph.sh build                 # constrói o grafo (determinista, zero tokens)
bash .forge/scripts/graph.sh deps --by-project     # dependências módulo→módulo + violações de camada + ciclos
bash .forge/scripts/graph.sh symbols               # símbolo-nível (classes/interfaces/funções + herança)
bash .forge/scripts/graph.sh path <a> <b>          # cadeia de dependência (BFS)
bash .forge/scripts/c4.sh                           # diagramas C4 (.md Mermaid) + overview.html navegável
bash .forge/scripts/graph.sh mdl                    # PoC: diagramas na notação MDL 2.0
```

Engine nativo (sem tree-sitter, sem deps): nós = arquivos (com camada inferida), arestas = imports/
referências resolvidas. Para módulos grandes, os diagramas **agregam por submódulo** (renderável e
completo, sem virar *hairball*).

## 🔌 Adapters multi-agente

`claude` · `codex` · `gemini` · `qwen` · `cursor` · `kiro` · `forge-cli` · `agents-skills`

`AGENTS.md` (raiz) é a interface canônica; `CLAUDE.md`/`QWEN.md`/`GEMINI.md` são projeções (symlink).
Trocar/adicionar um agente reconcilia o workspace (gera os ausentes, poda os removidos) sem perda.

## 📁 Estrutura

```text
template/.forge/        # o harness instalável (fonte única)
├── FORGE.md            # governança + frontmatter de runtime
├── agents/  (43)       # subagentes por categoria (specifications, architecture, review, …)
├── commands/ (43)      # comandos /forge:* (specs, waves, graph, quality, …)
├── skills/   (9)       # skills especialistas (gate-runner, story-context, …)
├── rules/   (33)       # convenções (arquitetura, domínio, testing, …)
├── schemas/ (17)       # JSON Schemas (manifest, spec-delta, grading, graph, …)
└── scripts/ (46)       # engine determinista (graph, archive, sync-adapters, hooks, …)
installer/              # install.sh + gitignore.patch + delegação global do /init-project
tests/                  # 28 gates deterministas + run-all.sh
docs/                   # planos (MVP1–5, Fase 8) + referência do harness
snapshot/               # snapshot congelado do adapter Claude (contrato de compatibilidade)
```

## ✅ Testes

```bash
bash tests/run-all.sh          # roda os 28 gates + suítes bats; saída agregada
```

Cada wave de desenvolvimento entrega seu gate junto (shift-left). O contrato do adapter Claude
(`tests/snapshot/claude-contract.bats`) garante compatibilidade do início (snapshot) ao fim.

## 🗺️ Status & roadmap

`v0.1.0-rc1` — MVP1–MVP5 completos + consolidação (Fase 8) + code graph. Ver [CHANGELOG](./CHANGELOG.md).

- [x] Núcleo canônico, multi-adapter, ciclo SDD, validadores
- [x] Baseline/archive, code graph + insights de arquitetura, eval harness opt-in
- [x] `/init-project` global delegando ao Forge
- [ ] Teste manual em Claude Code real (contrato C10) + remoção dos wrappers deprecados → **v0.1.0**
- [ ] Renderer MDL nativo (PoC atual aproxima via Mermaid)

## 🤝 Contribuindo

1. Branch a partir de `develop` (`feature/<wave>`); todo trabalho entra com **gate verde**.
2. `bash tests/run-all.sh` deve passar 100% antes do merge.
3. Convenções em `template/.forge/rules/`; documentos em **pt-BR**, identificadores em inglês.
4. Sem co-autoria de IA em mensagens de commit/PR.

## 📄 Licença

[MIT](./LICENSE) © 2026 Milton Antonio da Silva Jr
