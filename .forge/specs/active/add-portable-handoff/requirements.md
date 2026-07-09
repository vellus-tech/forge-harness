# Requirements — add-portable-handoff

> Requisitos do change `add-portable-handoff`. Cada requisito é verificável e rastreável à proposal.

## REQ-01 — Comando `/forge:handoff` gera artefato portátil

- **Quando** o usuário roda `/forge:handoff [<change-id>]`, **o sistema deve** gravar/sobrescrever
  `.forge/HANDOFF.md` com 5 seções: (1) header, (2) estado determinístico, (3) regras fixas da sessão,
  (4) delta narrativo, (5) ponteiros de retomada.
- **Critérios de aceite:**
  - [ ] Sem `<change-id>`, usa o change ativo; com id inexistente, falha com mensagem clara.
  - [ ] Seções 1–3 e 5 são idênticas entre duas execuções sem mudança de estado (determinísticas).
  - [ ] Seção 3 embute as mesmas 5 regras fixas do `/forge:resume` (para agente sem plugin Forge).
  - [ ] Seção 4 é a única escrita por modelo; nunca é tratada como fonte da verdade.
- **Rastreia:** proposal §2.1
- **Notas:** artefato em caminho fixo `.forge/HANDOFF.md` (decisão travada); git log = cadeia de handoffs.

## REQ-02 — Gerador determinístico sem LLM

- **Quando** invocado (por comando ou hook), **o sistema deve** montar o scaffold determinístico de
  `.forge/HANDOFF.md` lendo `manifest.yaml` + `progress.json` + `deferrals.json` + bloco `runtime:` do
  `FORGE.md` + estado git, sem chamada a LLM e sem dependência npm em runtime.
- **Critérios de aceite:**
  - [ ] `template/.forge/scripts/handoff-gen.sh` roda com `set -euo pipefail`, reusa `lib/yaml-lite.mjs`.
  - [ ] Executa e produz saída válida mesmo sem provider LLM configurado (rule-based).
  - [ ] Relocável via `FORGE_ROOT` (mesmo padrão de `spec-new.sh`).
- **Rastreia:** proposal §2.1
- **Notas:** reuso obrigatório de `scripts/lib/yaml-lite.mjs` (parser YAML zero-dep já existente).

## REQ-03 — `/forge:resume` ingere o handoff

- **Quando** `/forge:resume` roda e `.forge/HANDOFF.md` existe, **o sistema deve** ler a seção 4 (delta
  narrativo) e incorporá-la ao mandato de retomada, além do estado já lido.
- **Critérios de aceite:**
  - [ ] Sem `.forge/HANDOFF.md`, comportamento atual do `resume` é preservado (nenhuma regressão).
  - [ ] Com o arquivo presente, o mandato reflete o delta narrativo.
- **Rastreia:** proposal §2.3

## REQ-04 — Descoberta agente-agnóstica via `AGENTS.md`

- **Quando** o `AGENTS.md` é gerado por `sync-adapters.mjs`, **o sistema deve** incluir uma linha de
  ponteiro instruindo a ler `.forge/HANDOFF.md` no início de uma sessão nova.
- **Critérios de aceite:**
  - [ ] A linha aparece no `AGENTS.md` regenerado e, por symlink, em `CLAUDE.md`/`QWEN.md`/`GEMINI.md`.
  - [ ] O `doctor` continua limpo (header "Generated from .forge/FORGE.md" preservado; sem drift).
- **Rastreia:** proposal §2.2

## REQ-05 — Automação de sessão opt-in

- **Quando** `forge.yaml > handoff.auto` for `true`, **o sistema deve** emitir hooks `SessionStart`
  (surface do `.forge/HANDOFF.md`) e `SessionEnd` (regenera o scaffold) no `.claude/settings.json`;
  **quando** `false` (default), **não deve** emitir nada além do baseline atual.
- **Critérios de aceite:**
  - [ ] `handoff.auto: false` → `settings.json` idêntico ao baseline (só `PreToolUse`/`Bash`).
  - [ ] `handoff.auto: true` → `settings.json` inclui `SessionStart` + `SessionEnd` apontando para
        `template/.forge/hooks/session/on-session-{start,end}.sh`.
  - [ ] Hooks de sessão rodam rule-based, sem LLM.
- **Rastreia:** proposal §2.4
- **Notas:** flag opt-in no padrão de `quality.evals_enabled`.

## REQ-06 — Gate de pre-push valida README/CHANGELOG (hard require)

- **Quando** um `git push` inclui range com mudança user-facing (commit `feat|fix|perf` OU path fora de
  docs/config), **o sistema deve** bloquear (`exit 1`) se `README.md` **e** `CHANGELOG.md` não
  estiverem no diff `<base>..<local>`; **quando** o range é docs-only/chore-only, **deve** passar.
- **Critérios de aceite:**
  - [ ] Branch nova (remote sha zeros) usa `merge-base` com a default branch como base.
  - [ ] Range user-facing sem os dois docs → `exit 1` com mensagem clara nomeando o que falta.
  - [ ] Range user-facing com ambos os docs → passa. Range docs-only/chore-only → passa.
  - [ ] Sem válvula de escape (decisão travada: hard require).
- **Rastreia:** proposal §2.5
- **Notas:** helper `hooks/git/lib/check-docs-reviewed.sh` sourced pelo `pre-push`; testável isolado.

## REQ-07 — Suíte de testes verde e plugin sincronizado

- **Quando** `npm test` roda, **o sistema deve** passar, incluindo o gate novo do classificador de docs,
  o `C5` atualizado e o `plugin-sync-gate` (plugin byte-idêntico após `build:plugin`).
- **Critérios de aceite:**
  - [ ] `tests/w61-docs-review-gate.sh`: user-facing sem docs falha; docs-only passa; com docs passa.
  - [ ] `C5` aceita baseline (1 comando wired) e o modo `handoff.auto` (+2 Session hooks).
  - [ ] `plugin/forge/**` regenerado por `npm run build:plugin` e commitado; `plugin-sync-gate` verde.
  - [ ] `docs/refer/slash-commands.md` com a contagem de comandos atualizada (+1).
- **Rastreia:** proposal §4 (riscos)

## Requisitos não funcionais do change

- **NFR-01 —** Zero dependência de runtime externo (sem daemon/servidor/SQLite/embeddings); apenas bash
  + node já presentes. Medição: `handoff-gen.sh` e o hook de pre-push rodam num clone limpo sem instalar
  nada além do que o harness já exige.
- **NFR-02 —** Determinismo do núcleo: seções 1–3 e 5 do handoff reproduzíveis byte-a-byte sem mudança
  de estado. Medição: duas execuções consecutivas do gerador → `diff` vazio nas seções determinísticas.
- **NFR-03 —** Portabilidade agente-agnóstica: o artefato é markdown puro legível por qualquer agente;
  a descoberta não depende do plugin Claude. Medição: `AGENTS.md` contém o ponteiro.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | `<change-id>` (posicional) | CLI `/forge:handoff [<change-id>]` | TASK (W2) |
| REQ-05 | `handoff.auto` (bool) | config `forge.yaml` | TASK (W5) |
| REQ-06 | sem parâmetro exposto (gate automático, sem escape) | git hook `pre-push` | TASK (W4) |
| REQ-02/03/04/07 | sem parâmetro configurável | — (comportamento interno) | TASK (W1/W3/W5/W6) |

## Fora de escopo (reafirmação)

- Daemon, servidor sempre-ativo, SQLite, embeddings, busca semântica (proposal §3).
- Reescrita do `/forge:resume` (apenas extensão).
- Válvula de escape no gate de docs (decisão travada: hard require).
