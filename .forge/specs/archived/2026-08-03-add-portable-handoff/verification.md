# Verification — add-portable-handoff

> Checkpoint de verificação REQ-a-REQ contra o código real. Commit verificado:
> `785885026280bbc985a8ec44eb8e57d25cccf16c` (HEAD). Verificado em 2026-07-09.

**Veredito global: VERDE.** Todos os REQ-01..07 e NFR-01..03 em PASS. `npm test`: **PASS=35 FAIL=0 SKIP=0**.
`validate-spec add-portable-handoff`: OK.

## Tabela REQ-a-REQ

| REQ | Status | Evidência |
|---|---|---|
| REQ-01 — `/forge:handoff` gera artefato portátil (5 seções) | PASS | Template com as 5 seções + marcador de delta: `template/.forge/templates/handoff/HANDOFF.md:8-46`. Comando: `template/.forge/commands/harness/handoff.md:1-45` (frontmatter `description`+`argument-hint`, protocolo híbrido). Sem id usa o único ativo / id inexistente falha: `handoff-gen.sh:19-32` — verificado por execução: `handoff-gen.sh does-not-exist` → `FAIL (change inexistente...)` exit 1. Seção 3 embute as 5 regras fixas, idênticas às de `resume.md:46-56` (comparação textual). Seção 4 é o único bloco por-modelo, entre marcadores `FORGE:NARRATIVE-DELTA`. |
| REQ-02 — gerador determinístico sem LLM | PASS | `handoff-gen.sh:10` (`set -euo pipefail`), lê `manifest/progress/deferrals` + `runtime:` do FORGE.md (opcional) + git via `git -C` (`:34-48`), delega ao `lib/handoff-render.mjs` que reusa `yaml-lite.mjs` (`:11`). Sem chamada a LLM, sem dep npm. Relocável por `FORGE_ROOT` (`:13`, `:50`). Determinismo (diff vazio em 2 execuções): `w40[2]` PASS. Datas vêm do commit HEAD, não do relógio (`:37`). |
| REQ-03 — `/forge:resume` ingere o handoff | PASS | `resume.md:27-29` (passo 5: lê só a seção 4 entre os marcadores; ausência do arquivo = comportamento inalterado). Saída inclui linha `Handoff:` (`:43`). Sem regressão: guard explícito "(se existir)". |
| REQ-04 — descoberta agnóstica via `AGENTS.md` | PASS | Ponteiro fixo no corpo projetado: `template/.forge/templates/AGENTS.md:24-26` ("Sessão nova / troca de agente? … leia `.forge/HANDOFF.md`"). Header "Generated from .forge/FORGE.md" preservado (`:1-2`). Symlinks (CLAUDE/QWEN/GEMINI) herdam via `linkToAgentsMd`. `npm test` (claude-contract.bats + doctor gates) verde → sem drift. |
| REQ-05 — automação de sessão opt-in | PASS | Flag `handoff.auto` default `false`: `forge.yaml:26-29`; schema: `forge.schema.json:131-137`. `sync-adapters.mjs:119-125` (`readHandoffAuto`) + `:212-215` emite `SessionStart`/`SessionEnd` só quando true, apontando para `hooks/session/on-session-{start,end}.sh`. Hooks rule-based sem LLM: `on-session-start.sh` (cat), `on-session-end.sh` (exec gen). `w42[1]` (false→1 command, sem Session hooks) e `w42[2]` (true→+2, 3 commands) PASS. |
| REQ-06 — gate pre-push README/CHANGELOG hard-require | PASS | `check-docs-reviewed.sh` sourced por `pre-push:12-20`. Classificador user-facing por tipo convencional (feat/fix/perf) OU path fora de docs/config (`:38-64`); base via merge-base p/ branch nova (`:13-36`). **Sem env var de bypass** (leitura integral confirma — nenhum `FORGE_SKIP`/`--no-verify`-friendly escape no helper). `w41` PASS: user-facing sem docs → exit 1; com ambos → 0; docs-only/chore-only → 0. |
| REQ-07 — suíte verde e plugin sincronizado | PASS | `npm test` = PASS=35/FAIL=0. `tests/w61-docs-review-gate.sh` presente e verde. `plugin-sync-gate.sh` verde (plugin byte-idêntico); `plugin/forge/commands/handoff.md` presente. `docs/refer/slash-commands.md:3` = "50 commands" == `find template/.forge/commands` (50); `/forge:handoff` listado (`:134`). Nuance C5: o contrato C5 (`claude-contract.bats:162-168`) segue validando só o baseline (`wired -eq 1`) — correto, pois a árvore gerada nasce com `auto:false`; o modo +2 Session hooks é coberto pelo `w42`, não pelo C5. Intenção da AC atendida (ambos os estados validados na suíte), com a divisão baseline=C5 / opt-in=w42. |
| NFR-01 — zero dep de runtime externo | PASS | Só bash + node. `handoff-gen.sh` usa `git`/`awk`/`node` + `yaml-lite.mjs` (JS puro, sem binário nativo). Pre-push idem. Sem daemon/SQLite/embeddings. `w40`/`w41` rodam em fixture limpa (`mktemp -d`) sem instalar nada. |
| NFR-02 — determinismo do núcleo | PASS | `w40[2]`: 2 execuções consecutivas → `diff` vazio. `handoff-render.mjs:53-68` preserva delta já escrito e não injeta timestamp de relógio; ordem de campos estável. |
| NFR-03 — portabilidade agnóstica | PASS | Artefato é markdown puro (`HANDOFF.md`); descoberta via ponteiro em `AGENTS.md` (não depende do plugin Claude) — REQ-04. Seção 5 dá instrução explícita para agente não-Forge ler o arquivo inteiro. |

## Observações (não bloqueantes)

- O contrato C5 não foi estendido para asserir o estado `+2 Session hooks`; essa cobertura vive no
  `w62-handoff-hook-gate.sh`. Funcionalmente equivalente à AC ("C5 aceita ambos os estados"), mas a
  literalidade fica dividida entre dois testes — registrar caso se queira consolidar no C5 depois.
- A execução da verificação regenerou `.forge/HANDOFF.md` (atualização determinística do header para
  a fase `implemented` / HEAD atual) — mudança benigna, reflete o estado real. `manifest.yaml`
  (`implementing`→`implemented`) já estava modificado no working tree antes desta verificação (marca
  da fase de implementação, ainda não commitada).
