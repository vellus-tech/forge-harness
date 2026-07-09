# Proposal — add-portable-handoff

> Change `add-portable-handoff` (type: `feature`, scale 3) — criado em 2026-07-08 por milton.
> Fluxo dogfood: os scripts do engine rodam via `FORGE_ROOT=<repo> bash template/.forge/scripts/*.sh`
> (o harness não está materializado na raiz; a fonte canônica é `template/.forge/**`).

## 1. Por quê (problema / motivação)

Hoje é preciso **pedir manualmente** ao agente que prepare um arquivo de hand-off para transportar
contexto entre sessões, ou entre code agents distintos (ex.: Codex → Claude Code). O `/forge:resume`
já sintetiza um mandato de retomada, mas (a) é um slash command do **plugin Claude** — Codex/Cursor não
o executam — e (b) é efêmero: não deixa um artefato persistido e portátil.

Avaliação prévia (parecer) do `ai-memory` (Akita) concluiu **incorporar** suas boas ideias em vez de
rodá-lo em paralelo: o Forge já detém o estado de forma mais auditável (`progress.json`,
`deferrals.json`, `manifest.yaml`, baseline `product/current/`); adotar o daemon Docker + captura
*lossy* por LLM + o caminho de OAuth "contra política" da Anthropic não se paga. O delta que falta é
estreito e cabe no ethos zero-dep.

## 2. O que muda

1. **Comando `/forge:handoff [<change-id>]`** — gera um artefato portátil e agente-agnóstico em
   `.forge/HANDOFF.md` (caminho fixo, sobrescrito, versionado em git). Núcleo determinístico (script)
   monta estado + regras fixas + ponteiros; o modelo preenche apenas um "delta narrativo" curto.
2. **Ponteiro no `AGENTS.md`** — uma linha "Sessão nova? Leia `.forge/HANDOFF.md` se existir", tornando
   o artefato descoberto por qualquer agente (todos leem `AGENTS.md`; `CLAUDE/QWEN/GEMINI.md` são symlink).
3. **`/forge:resume` estendido** — ao retomar, ingere o `.forge/HANDOFF.md` (delta narrativo) se existir.
4. **Automação opt-in** — hooks `SessionStart`/`SessionEnd` (rule-based, sem LLM), emitidos no
   `.claude/settings.json` só quando a flag `handoff.auto: true` do `forge.yaml` estiver ligada.
5. **Gate de pre-push (hard require)** — bloqueia push com mudança user-facing (`feat|fix|perf` ou
   fonte tocada) se `README.md` **e** `CHANGELOG.md` não estiverem no diff do range. Sem escape.

## 3. O que NÃO muda (fora de escopo)

- Sem daemon, servidor, SQLite, embeddings ou qualquer runtime externo — permanece zero-dep.
- Comportamento atual do `/forge:resume` preservado (só **estendido**, não reescrito).
- Modelo de baseline (`product/current/`), lifecycle de changes e demais comandos intactos.
- Hooks git existentes (`pre-commit`, `post-merge`) e o `PreToolUse`/worktree-guard preservados.
- Sem busca semântica / índice histórico (o `ai-memory` faz; não é a dor atual — baseline já é a
  memória de longo prazo).

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`
- **Paths afetados:** `template/.forge/`, `tests/`, `docs/`, `plugin/forge/`, `README.md`, `CHANGELOG.md`, `forge.yaml`
- **Dependências:** nenhuma (specs/código)
- **Riscos:**
  - Adicionar `SessionStart`/`SessionEnd` ao `settings.json` quebra o teste `C5`
    (`tests/snapshot/claude-contract.bats`, hoje trava `wired -eq 1`) — quebra **esperada**, tratada na W5.
  - Hard-require × auto-changelog: o `post-merge` acumula o `CHANGELOG.md` no *merge*, não no push da
    feature branch → o gate exige o CHANGELOG já atualizado no push. Mitigação: `/forge:ship`/`prepare-pr`
    atualiza `[Unreleased]` antes do push.
  - `plugin/forge/**` é artefato commitado: esquecer `npm run build:plugin` derruba o `plugin-sync-gate`.

## 5. Próximos passos

`/forge:requirements` → `/forge:design` → `/forge:analyze` + `/forge:impact` (scale 3) → `/forge:tasks`
→ `/forge:implement` (por waves) → `/forge:verify` → `/code-review` → `/forge:ship` → `sync-adapters` +
`doctor`. Cada gate HITL aguarda aprovação humana.
