# Bugfix — red-replay-graft-base

## 1. Comportamento atual (incorreto)

`lib/red-replay.mjs` deriva a árvore pré-correção por duas estratégias, e as duas erram quando o teste de regressão e a correção entraram no **mesmo commit** (squash de PR) e algum commit **posterior** tocou os mesmos `fix_files` por outro motivo:

- **`ancestry`** — `findFixCommitAfter` presume que o primeiro commit posterior ao commit de introdução do caso que toca `fix_files` é a correção. Quando a correção já está no próprio commit de introdução do caso, esse "primeiro posterior" é ruído qualquer, e a base derivada (`parent(ruído)`) **já contém a correção**. O teste passa lá e o replay conclui, com confiança, "teste já passa na árvore base — não reproduz o defeito relatado (item 2)". É uma afirmação falsa sobre o Red: o motor não mediu o que diz ter medido.
- **`revert-synthesis`** — `findFixLastCommit` reverte o **último** commit que tocou cada `fix_file`, que pelo mesmo motivo pode ser o commit de ruído, não a correção. Mesmo escolhendo o commit certo, o patch reverso pode não aplicar sobre um HEAD que evoluiu, e aí o veredito é `not-possible` — sem tentar a única base que ainda existe.

Reprodução real (2026-08-03, este repositório): o change `hookspath-respect-custom` teve teste (`tests/w94-hookspath-preserve-gate.sh`) e correção (`bin/forge.mjs`, `installer/install.sh`) no mesmo commit `0510b3f`. O replay reportou "teste já passa na árvore base"; conferido à mão, o teste **falha** em `0510b3f^` (`FAIL [1] (hooksPath sobrescrito)`, comportamental). O revert sintetizado do mesmo commit **não aplica** no HEAD atual — as regiões de `bin/forge.mjs` e `installer/install.sh` mudaram desde então, inclusive em `8fe43d4`.

## 2. Comportamento esperado

- Quando o commit que introduziu o caso declarado **também toca** `fix_files` (teste e correção juntos), a estratégia `ancestry` **não se aplica** — nunca derivar base de um commit posterior arbitrário que toque os mesmos arquivos.
- Nesse caso, `revert-synthesis` reverte o diff do **commit de introdução do caso** (a correção real) nos arquivos que ele toca, e não o do último commit que tocou o arquivo.
- Quando o revert não aplica, cair na estratégia nova **`test-graft`**: base = `parent(caseCommit)` (árvore pré-correção histórica real) com o `test_path` **enxertado** a partir do `caseCommit`. É a única base que existe quando o teste nasceu junto da correção — e é exatamente o que um auditor faz à mão.
- O artefato registra `base_strategy: "test-graft"` e um campo próprio `graft_from` com o commit de onde o teste foi enxertado: sem isso, um auditor que rode o teste em `base_commit` não encontraria o arquivo de teste e leria a evidência como contraditória.

## 3. Comportamento que deve permanecer inalterado

- Fluxo TDD normal (bug, teste e correção em commits separados) segue por `ancestry`, com a mesma base de hoje (`w107[1]`).
- Squash em que o revert **aplica** segue por `revert-synthesis`, gravando `revert_patch` (`w107[4]`) — `test-graft` é fallback, não substituto.
- Todos os vereditos de recusa continuam valendo sobre a base nova: teste que passa na base reprova (item 2), falha não-comportamental reprova (item 3), `failure_pattern` divergente reprova (item 4), saída que não menciona o caso reprova. Enxertar o teste não afrouxa nenhuma dessas checagens.
- `not-possible` continua sendo veredito válido quando nem `parent(caseCommit)` existe.

## 4. Root cause

`deriveBase` (`lib/red-replay.mjs:133-173`) modela apenas dois mundos: "teste antes da correção" (ancestry) e "teste junto da correção, revert aplicável" (revert-synthesis). Falta o predicado que distingue os dois — "o commit que introduziu o caso também toca `fix_files`?" —, então `findFixCommitAfter` é chamado mesmo quando a correção já passou, e `findFixLastCommit` escolhe por recência em vez de escolher pela correção. Não foi detectado antes porque o fixture do `w107[4]` tem o squash como **último** commit do repositório de teste: sem commit posterior tocando o `fix_file`, `ancestry` não encontra candidato e a execução cai em `revert-synthesis` por acaso, mascarando o defeito.

## 5. Testes de regressão

- [ ] Teste que reproduz o bug: fixture com bug, squash (teste+correção juntos) e um commit posterior de ruído que reescreve a linha corrigida — o replay deve observar o Red por `test-graft` (antes da correção, falha com "teste já passa na árvore base").
- [ ] `graft_from` gravado no artefato e `base_commit` = `parent(caseCommit)`.
- [ ] Caminhos preservados: `w107[1]` (ancestry) e `w107[4]` (revert-synthesis com patch aplicável).

## 6. Rastreabilidade

Achado ao arquivar `hookspath-respect-custom` (2026-08-03), cujo pré-flight exige evidência de Red. Sem spec/baseline anterior relacionado.
