# Design — add-portable-handoff

> Design técnico do change `add-portable-handoff`. Fonte canônica: `template/.forge/**`.

## 1. Contexto e restrições

- **Zero-dep:** nada de daemon/servidor/SQLite/embeddings; só bash + node já presentes (NFR-01).
- **Fonte única:** comandos vivem em `template/.forge/commands/**`; `plugin/forge/**` é gerado por
  `npm run build:plugin` e travado por `tests/plugin-sync-gate.sh`.
- **Scripts relocáveis:** padrão `FORGE_ROOT` + `SCRIPT_DIR` (como `spec-new.sh`); templates resolvidos
  de `$SCRIPT_DIR/../templates`, dados sob `$FORGE_ROOT/.forge`.
- **Adapters gerados:** `.claude/settings.json` e `AGENTS.md` saem de `scripts/lib/sync-adapters.mjs`
  (`GENERATORS.claude` / `GENERATORS.agents`), com lockfile por adapter checado pelo `doctor`.
- **Contrato de teste:** `tests/snapshot/claude-contract.bats` C5 trava hoje `wired -eq 1`.
- **Hooks git:** portáveis via `core.hooksPath .forge/hooks/git` (installer). `pre-push` já bloqueia.

## 2. Decisão técnica

### 2.1 `handoff-gen.sh` (núcleo determinístico) — REQ-01, REQ-02
`template/.forge/scripts/handoff-gen.sh <?change-id>`. Resolve o change (arg ou o único ativo). Lê via
`node` + `lib/yaml-lite.mjs`: `manifest.yaml` (id/type/scale/status), `progress.json`
(wave/stories/tasks/last_commit), `deferrals.json` (abertos), `runtime:` do `FORGE.md` **se existir**
(degrada com "n/d" quando ausente — caso deste repo), estado git (`git -C`). Emite as seções 1-3 e 5 em
`$FORGE_ROOT/.forge/HANDOFF.md`, deixando um marcador `<!-- FORGE:NARRATIVE-DELTA -->` para a seção 4.
Idempotente: mesma entrada → mesma saída (NFR-02). As 5 regras fixas (seção 3) vivem no template, não
hardcoded no script.

### 2.2 Comando `/forge:handoff` — REQ-01
`template/.forge/commands/harness/handoff.md` (frontmatter `description` + `argument-hint`). Protocolo
híbrido (padrão `resume`/`wave`): (1) roda `handoff-gen.sh`; (2) modelo escreve o delta narrativo
substituindo o marcador; (3) confirma gravação. Nunca reescreve as seções determinísticas.

### 2.3 `/forge:resume` estendido — REQ-03
Edição pontual em `commands/harness/resume.md`: passo novo "se `.forge/HANDOFF.md` existir, leia a seção
`Delta narrativo` e inclua no mandato". Guard: ausência do arquivo = comportamento atual intacto.

### 2.4 Ponteiro no `AGENTS.md` — REQ-04
Em `sync-adapters.mjs` `GENERATORS.agents`, acrescentar uma linha fixa ao corpo projetado:
`> Sessão nova? Leia `.forge/HANDOFF.md` se existir (handoff portátil entre sessões/agentes).`
Preserva o header "Generated from .forge/FORGE.md". Symlinks herdam.

### 2.5 Hooks de sessão opt-in — REQ-05
- `template/.forge/hooks/session/on-session-end.sh` → `exec handoff-gen.sh` (rule-based; sem passo de
  modelo — o delta fica com o marcador vazio).
- `template/.forge/hooks/session/on-session-start.sh` → `[ -f .forge/HANDOFF.md ] && cat` (stdout vira
  contexto no Claude Code).
- Flag `handoff.auto` no `forge.yaml` (default `false`).
- `GENERATORS.claude`: quando a flag é `true`, além do `PreToolUse` atual, emite `SessionStart` +
  `SessionEnd` apontando para os dois scripts. A leitura da flag usa `yaml-lite` sobre `forge.yaml`.

### 2.6 Gate de pre-push — REQ-06
`template/.forge/hooks/git/lib/check-docs-reviewed.sh`, sourced no fim de `hooks/git/pre-push`.
Algoritmo:
```
ler linhas do stdin: <localref> <localsha> <remoteref> <remotesha>
para cada ref não-delete:
  base = (remotesha all-zero) ? merge-base(localsha, origin/DEFAULT) : remotesha
  files = git diff --name-only base..localsha
  types = tipos convencionais dos commits base..localsha
  user_facing = (types ∩ {feat,fix,perf}) ou (files fora de docs/**,*.md,config)
  se user_facing e não (README.md ∈ files e CHANGELOG.md ∈ files): exit 1 (msg nomeia faltantes)
passa
```
Sem escape (decisão travada). Mensagem instrui atualizar os dois e re-push.

### 2.7 Template do artefato
`template/.forge/templates/handoff/HANDOFF.md` com placeholders `<...>`, as 5 seções e o texto fixo das
regras de sessão.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| `ai-memory` em paralelo | cross-agent + busca semântica prontos | daemon Docker, captura lossy por LLM, OAuth contra política, 70% redundante | parecer: incorporar |
| Handoff na raiz (`./HANDOFF.md`) | descoberta sem ponteiro | polui a raiz, destaque em todo diff | decisão travada: `.forge/HANDOFF.md` |
| Handoff por-change no spec dir | consistente c/ estado | não descoberto por agente não-Forge | idem |
| Gate warn-only / com escape | menos atrito | zero enforcement / escape enfraquece | decisão travada: hard require |
| Hook de sessão sempre-on | automação total | moving-parts imposto, quebra ethos zero-dep | opt-in via flag |

## 4. Contratos e integrações afetados

- **`.claude/settings.json`** (gerado): novo formato condicional (baseline vs +Session hooks). Contrato
  C5 atualizado para aceitar ambos os estados.
- **`AGENTS.md`** (gerado): +1 linha de corpo; header/lock preservados.
- **`forge.yaml`**: +chave `handoff.auto` (retrocompatível; ausência = false).
- **`plugin/forge/**`**: +1 comando (`handoff`); regenerado e commitado.
- **git `pre-push`**: +checagem bloqueante (novo comportamento observável no push).

## 5. Plano de migração / rollout

Aditivo e retrocompatível. `handoff.auto` nasce `false` → nenhum projeto existente muda de
comportamento em sessão. O gate de pre-push passa a valer no próximo push de quem tem
`core.hooksPath` apontado (installer). `AGENTS.md`/plugin regenerados no mesmo change.

## 6. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação / detecção |
|---|---|---|---|
| C5 quebra ao emitir Session hooks | Alta | Médio | atualizar C5 na mesma wave (W5); `npm test` detecta |
| Hard-require × auto-changelog no merge | Média | Médio | ship atualiza CHANGELOG antes do push; nota na proposal |
| `plugin-sync-gate` vermelho por esquecer build | Média | Baixo | `npm run build:plugin` na W2; gate detecta |
| `handoff-gen.sh` quebra sem `FORGE.md` no root | Média | Baixo | degradar campos de runtime para "n/d"; testar neste repo |
| node v26 e yaml-lite | Baixa | Baixo | yaml-lite é JS puro; sem binário nativo |

## 7. Rastreabilidade

| REQ | Seção do design |
|---|---|
| REQ-01 | §2.1, §2.2, §2.7 |
| REQ-02 | §2.1 |
| REQ-03 | §2.3 |
| REQ-04 | §2.4 |
| REQ-05 | §2.5 |
| REQ-06 | §2.6 |
| REQ-07 | §4 (contrato C5/plugin), verificação via `npm test` |
