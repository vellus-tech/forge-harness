# Handoff — gate-assert-visibility

> Artefato de passagem de contexto entre sessões e entre code agents (Codex ↔ Claude Code ↔ …).
> Gerado por `/forge:handoff` (ou pelo hook opt-in de sessão). Seções 1-3 e 5 são determinísticas
> (montadas a partir do estado do change); a seção 4 é o único texto narrativo. **Não é fonte da
> verdade** — o estado canônico vive em `.forge/specs/active/gate-assert-visibility/`.

## 1. Header

- **Change:** `gate-assert-visibility` · type `bugfix` · scale `2` · fase `verified`
- **Branch:** `develop` · HEAD `08acf9f` (2026-08-04T19:21:42-03:00)

## 2. Estado

- **Wave atual:** n/d
- **Stories:** 0/0 · **Tasks:** 0/0
- **Deferrals abertos:** nenhum
- **Runtime:** test=`n/d` · typecheck=`n/d` · lint=`n/d`

## 3. Regras fixas da sessão

1. Subagente SEMPRE com `model` explícito: haiku (bite-sized/paralelizar), sonnet
   (onda/módulo/integração/debugging), opus effort medium (design de agregados, ADRs, code-review
   crítico). Nunca herdar o modelo do orquestrador.
2. Subagente NUNCA roda `docker build`/`docker compose up --build`. O orquestrador dispara em
   `run_in_background` e segue com outra TASK enquanto aguarda.
3. Toda operação git em worktree usa `git -C <worktree>` explícito — nunca `cd` implícito que se
   perde entre chamadas de subagente.
4. Validação real (build/teste) antes de marcar qualquer TASK concluída — o relatório do subagente
   não é a verdade até o orquestrador conferir.
5. Checkpoint + encerrar a sessão por módulo/PR — não acumule múltiplos módulos numa sessão só;
   `/forge:ship` fecha o ciclo antes de abrir o próximo.
6. **TDD estrito em todo código — Vermelho → Verde → Refactor.** Teste que falha primeiro (pelo
   motivo certo, não erro de build), implementar o mínimo para passar, só então refatorar. Vale
   para features/bugfixes do produto E para mudanças na maquinaria do harness (scripts,
   validadores) — não só onde o pipeline já exige Red-first formal.

## 4. Delta narrativo

<!-- FORGE:NARRATIVE-DELTA:START -->
**Resumo do que já estava fechado antes deste delta:** `gate-assert-visibility` (bugfix scale 2, origem `LDG-0012` — asserções bash `[ cond ] && cmd` sob `set -e` que morrem ou passam em silêncio sem `FAIL`) foi especificado, implementado em 24 tasks (52 sites em 20 arquivos) e verificado (`/forge:verify` aprovado, suíte 75/75) com ~20 commits diretos em `develop`, sem branch/PR/`code-evaluator`. Ver handoff anterior (histórico de git) para o detalhe dessa fase.

**O que aconteceu depois disso, nesta mesma sessão: a dívida de processo foi resolvida de ponta a ponta.**

**1. Extração retroativa para PR.** Os ~20-32 commits diretos em `develop` foram extraídos para a branch `fix/tests/gate-assert-visibility`; `develop` local foi resetado para `origin/develop` (nenhum trabalho perdido — os commits já estavam preservados na branch antes do reset). Branch empurrada, virou PR #42.

**2. `code-evaluator` adaptado — reviewers nomeados (`logic-reviewer`, `arch-reviewer` etc., de `template/.forge/agents/review/code-evaluator.md`) não são subagent types registrados neste ambiente, então o orquestrador rodou 3 papéis equivalentes (lógica/correção, qualidade/convenções, integridade do harness) em paralelo, Opus/Sonnet — **3 rodadas de revisão adversarial**, todas registradas no PR #42:**
  - **Rodada 1 — reprovado pelos 3.** BLOCKER convergente: `plugin/forge/**` (espelho gerado do plugin Claude Code) dessincronizado de `template/.forge/commands/**` (`npm run build:plugin` não tinha rodado após editar comandos). 2 HIGH: o fix ad hoc do `LDG-0030` (deixar `type: bugfix` scale≥2 pular `design-ready`) não tinha teste nenhum, e a implementação REMOVIA `design-ready` da cadeia de estados — quebrando retrocompatibilidade (change já parado em `design-ready` numa versão anterior ficaria travado ao atualizar) e proibindo a opção de design arquitetural que `commands/specs/design.md` sempre permitiu para bugfix.
  - **Correção da rodada 1:** `design-ready` voltou a ficar SEMPRE na cadeia para scale≥2; o pulo virou rota lateral opcional `requirements-ready → tasks-ready`, só para `type: bugfix`. TDD real desta vez — teste vermelho (`tests/w21-pipeline-gate.sh` cenário `[1b]`) confirmado falhando contra o código antigo antes da correção, só depois o fix, teste verde. `plugin/forge/**` regenerado.
  - **Rodada 2 — 1 HIGH novo.** Um reviewer focado reconfirmou os 3 achados da rodada 1 corrigidos (inclusive com prova de mutação: reverteu o código, viu o teste ficar vermelho, restaurou) e achou que a correção da rodada 1 tinha uma extensão para `quick_plan.skipped_phases` (pulo autorizado para QUALQUER `type` que declarasse isso no manifest, não só bugfix) que virava código morto — `validate-spec.mjs` não honra `quick_plan` no guard de `design.md` a partir de `tasks-ready`, então o pulo era autorizado e reprovado logo em seguida pelo validador. Generalização removida, mantido só `type: bugfix`. Mais MEDIUM/LOW: doc `design.md` desatualizada, e um fix anterior (ponteiro de "dogfood" que valida contra um change ativo real) degradava silenciosamente para "OK ... SKIP" quando não havia change ativo — mesma classe de defeito (asserção que some sem reprovar) que este change inteiro existe para eliminar. Corrigido com fixture sintética sempre gerada e validada.
  - **Rodada 3 — autoverificação, sem novo agente.** Resíduo textual: a nota de resolução do `LDG-0030` no ledger e `verification.md` ainda citavam a generalização por `quick_plan` já revertida na rodada 2. Corrigido.
  - Suíte `tests/run-all.sh` revalidada 100% verde (75/75) a cada rodada — 4 vezes ao todo. Comentário consolidado postado no PR #42.

**3. Merge.** `gh pr merge 42 --squash --delete-branch` → squash em `develop`, commit `08acf9f`. Branch local e remota limpas, `develop` local sincronizado com `origin/develop`.

**4. Estado final do change:** `gate-assert-visibility` permanece `verified`, **sem** `/forge:archive` — decisão explícita do usuário, já que não há baseline de produto a atualizar (correção pura da suíte de testes do harness). `orphan-changes.mjs` classifica como `merged_unarchived`, sinal normal e aceito neste caso.

**5. Ledger final:** `LDG-0012` resolvido (via o change). `LDG-0030` resolvido — com a história completa das 3 tentativas registrada no `detail` (fix ad hoc sem teste → correção com TDD → remoção da generalização morta). `LDG-0031`–`LDG-0035` abertos, todos P3 (achados incidentais de revisão, genuinamente fora de escopo desta correção mecânica): sanitização C4 de boundary de arquivo único, asserção vazia em `w111-liaison-sync-gate.sh:259`, yaml-lite que não parseia array em flow style, mensagens FAIL bundled sem indicar qual cláusula falhou, drift entre `archive-state-machine.yaml` e a cadeia executável de `spec-transition.sh`. Nenhum P0/P1 aberto.

**Aprendizado forte a reforçar.** Mesmo com TDD e revisão adversarial pesada na implementação original, o `code-evaluator` achou 3 rodadas de problemas reais na correção "final" — incluindo a ironia de a MESMA sessão que instituiu "TDD estrito, inclusive na maquinaria do harness" ter inicialmente corrigido o `LDG-0030` sem nenhum teste. A revisão adversarial em camada (builder→validator no artefato, depois `code-evaluator` no diff final) pegou coisas que a primeira camada sozinha não pegou. Reforça a regra fixa 6 (TDD, seção 3 acima) e é argumento para nunca pular a revisão de diff mesmo quando a implementação já passou por bastante escrutínio.

**Não há pendência deste change específico.** Ciclo fechado: PR mergeado, suíte verde, ledger reconciliado. Próximo passo lógico é o próximo item do ledger (todos P2/P3 abertos, sem P0/P1) ou outro trabalho novo.
<!-- FORGE:NARRATIVE-DELTA:END -->

## 5. Como retomar

- **Claude Code:** rode `/forge:resume gate-assert-visibility` (lê o estado + ingere esta seção 4).
- **Outro agente (Codex/Cursor/Gemini):** leia este arquivo inteiro; o estado detalhado está em
  `.forge/specs/active/gate-assert-visibility/` (`manifest.yaml`, `progress.json`, `deferrals.json`,
  `tasks.md`). Siga as regras da seção 3.
