# Tasks — add-unify-changelog-skill

> Tasks do change `add-unify-changelog-skill`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Numeração de gate (`wNNN`) é atribuída na implementação (`gate-ordinal.sh`), não fixada aqui.
> Cada TASK é atômica: primeiro o teste declarado roda e falha (vermelho, com o `Padrão de falha` batendo), depois a implementação da própria TASK faz passar (verde) — nenhuma TASK adia seu teste para uma TASK posterior.

## Wave 1 — Motor de rascunho (Node) na skill

- [X] TASK-01 — `scripts/changelog-engine.mjs`: modo explícito (`--type`/`--description`), formato Keep a Changelog pt-BR, cria CHANGELOG ausente com cabeçalho padrão (rastreia: REQ-01, REQ-06, REQ-14; paths: `template/.forge/skills/readme-generator/scripts/changelog-engine.mjs`; depende: —)
  - Teste (comando): `bash tests/w<N>-changelog-engine-explicito-gate.sh` (novo — cenários: cria CHANGELOG ausente com cabeçalho Keep a Changelog; grava `- <description>` em `### <Seção-pt-BR>` dentro de `[Unreleased]`; não altera seções de versões já numeradas)
  - Padrão de falha: `node: .../changelog-engine.mjs: no such file or directory` (arquivo ainda não existe no vermelho)
- [X] TASK-02 — Modo derivado (`--subject`, `--path` com recusa rc 2 em componente inexistente) deriva de Conventional Commits usando o mapeamento de `conventional-commits.md` (feat→Adicionado, fix/perf→Corrigido; demais tipos sem entrada) (rastreia: REQ-08, DIV-01, DIV-02; paths: mesmo arquivo; depende: TASK-01)
  - Teste (comando): `bash tests/w<N>-changelog-engine-derivado-gate.sh` (cenários: `--subject "feat(x): ..."` gera Adicionado; `--subject "perf(x): ..."` gera Corrigido, não Changed/Alterado; `--subject "refactor(x): ..."` não gera entrada; `--path <componente-existente>` varre o intervalo de commits do componente e gera entrada (caso positivo); `--path <inexistente>` sai com `rc=2` (caso negativo))
  - Padrão de falha: `rc esperado 2, obtido 0 — --path inexistente aceito indevidamente`
- [X] TASK-03 — Modo `--merge-range`: deriva do intervalo do merge, idempotente por sufixo `(<hash>)`, marcador `**[BREAKING]**` para `!`, NUNCA cria CHANGELOG ausente, no-op quando `HEAD` não é merge (rastreia: REQ-02, REQ-03, REQ-03b, REQ-03e; paths: mesmo arquivo; depende: TASK-02)
  - Teste (comando): `bash tests/w<N>-changelog-engine-merge-range-gate.sh` (cenários: merge feat+fix gera 2 entradas com sufixo de hash; rerodar não duplica; `feat(x)!: ...` grava `**[BREAKING]**`; sem CHANGELOG raiz não cria nada e sai rc 0; `HEAD` não-merge não altera o arquivo; CHANGELOG sem `## [Unreleased]` ganha a seção criada antes da primeira versão numerada)
  - Padrão de falha: `FAIL idempotencia: contagem mudou entre execucoes` ou `FAIL: CHANGELOG.md criado indevidamente em --merge-range`
- [X] TASK-04 — Detecção de `release-please-config.json`: modo explícito/derivado recusa editar e aponta para o título do PR (REQ-10); `--merge-range` é no-op informativo (REQ-10b) (rastreia: REQ-10, REQ-10b; paths: mesmo arquivo; depende: TASK-03)
  - Teste (comando): `bash tests/w<N>-changelog-engine-release-please-gate.sh` (cenários: componente com `release-please-config.json` + modo explícito → CHANGELOG intocado, saída aponta "título do PR"; raiz com `release-please-config.json` + `--merge-range` → CHANGELOG intocado, sem erro)
  - Padrão de falha: `FAIL: CHANGELOG.md alterado com release-please-config.json presente`

## Wave 2 — Gates do comando (released/preserve/lint)

- [X] TASK-05 — `scripts/gates/released.mjs`: cada seção `## [X.Y.Z]` do arquivo anterior idêntica byte a byte no novo (rastreia: REQ-11; paths: `template/.forge/skills/readme-generator/scripts/gates/released.mjs`; depende: TASK-01)
  - Teste (comando): `bash tests/w<N>-changelog-gate-released-gate.sh` (cenários: versão publicada idêntica → passa; 1 byte alterado numa versão publicada → `FAIL`; versão publicada removida → `FAIL`)
  - Padrão de falha: `FAIL released: secao [X.Y.Z] divergente do arquivo anterior`
- [X] TASK-06 — `scripts/gates/preserve.mjs`: nenhum bloco antigo removido em relação ao arquivo anterior (rastreia: REQ-11; paths: mesmo diretório; depende: TASK-05)
  - Teste (comando): `bash tests/w<N>-changelog-gate-preserve-gate.sh` (cenários: bloco `### Added` com conteúdo removido sem substituto → `FAIL`; conjunto vazio comparado a arquivo vazio anterior → passa; arquivo novo ganhando conteúdo → passa)
  - Padrão de falha: `FAIL preserve: bloco removido sem substituto`
- [X] TASK-07 — `scripts/gates/lint.mjs`: travessão, quebra de linha dentro de parágrafo, acentuação ASCII, placeholder, link quebrado (rastreia: REQ-11; paths: mesmo diretório; depende: TASK-06)
  - Teste (comando): `bash tests/w<N>-changelog-gate-lint-gate.sh` (cenários: entrada com travessão → `FAIL`; entrada com "nao" em vez de "não" → `FAIL`; entrada limpa → passa)
  - Padrão de falha: `FAIL lint: travessao encontrado` / `FAIL lint: acentuacao ausente`

## Wave 3 — `resolve-skill.sh` e comando delegante

- [X] TASK-08 — `template/.forge/scripts/resolve-skill.sh <nome> [<arquivo>...]`: ordem `FORGE_SKILL_DIR_<NOME>` → `.forge/skills/<nome>/` do projeto → skill de usuário do adapter; `FAIL skill <nome> ausente` rc 1 nas três ausentes (rastreia: REQ-12; paths: `template/.forge/scripts/resolve-skill.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/w<N>-resolve-skill-gate.sh` (cenários: só `.forge/skills/<nome>` presente → resolve esse; `FORGE_SKILL_DIR_<NOME>` definido → tem precedência; nenhuma das três → `FAIL skill <nome> ausente`, rc 1)
  - Padrão de falha: `FAIL skill readme-generator ausente` (ausência das três fontes no vermelho, script ainda não existe)
- [X] TASK-09 — Reescrever `template/.forge/commands/docs/update-changelog.md`: args opcionais, trava em `develop`/`master`/`main` (REQ-09), chama `resolve-skill.sh` + `changelog-engine.mjs` no modo apropriado, roda os 4 gates (`released`, `preserve`, `lint`, `check-ai-attribution.sh text`), nunca commita (rastreia: REQ-01, REQ-07, REQ-09, REQ-11, REQ-12; paths: `template/.forge/commands/docs/update-changelog.md`; depende: TASK-08)
  - Teste (comando): `bash tests/w<N>-update-changelog-comando-gate.sh` (verificação estática do markdown: trava de branch protegida documentada nos "Passos a Executar"; detecção de `release-please-config.json` documentada (REQ-10); os 4 gates nomeados explicitamente, incluindo `check-ai-attribution.sh text`; nenhuma instrução de `git commit` no corpo)
  - Padrão de falha: `FAIL: comando nao documenta check-ai-attribution.sh` / `FAIL: comando instrui commit`

## Wave 4 — Hook `post-merge` religado

- [X] TASK-10 — Trocar a chamada de `changelog-from-merge.mjs` por `resolve_delegated changelog-engine "skills/readme-generator/scripts/changelog-engine.mjs"` em modo `--merge-range`, sem gates, com checagem de `release-please-config.json` antes (REQ-10b) e mantendo `delegation_failed=1` no padrão já existente; hook nunca usa `resolve-skill.sh` (REQ-07) (rastreia: REQ-02, REQ-03c, REQ-03d, REQ-05, REQ-05b, REQ-05c, REQ-07, REQ-13; paths: `template/.forge/hooks/git/post-merge`; depende: TASK-03, TASK-04)
  - Teste (comando): `bash tests/w<N>-post-merge-changelog-engine-gate.sh` (novo, cenários próprios do hook: alvo ausente com `skills/readme-generator/` presente → erro `delegation_failed=1`, texto citando `scripts/changelog-engine.mjs`; `.forge/` ausente → no-op silencioso rc 2; sem `node` no PATH → no-op sem erro; hook nunca commita — `git log` sem novo commit após rodar; override de skill de usuário/`FORGE_SKILL_DIR_*` no ambiente NÃO é consultado pelo hook)
  - Padrão de falha: `post-merge FALHOU: .forge/skills/readme-generator/ existe mas scripts/changelog-engine.mjs nao`

## Wave 5 — Reescrita dos gates existentes (paridade antes da remoção)

- [X] TASK-11 — Reescrever `tests/w147-hook-delegation-gate.sh` cenário [1] (e a variante `process.exit(3)`, linha 65) para o alvo novo `skills/readme-generator/scripts/changelog-engine.mjs`, casando o texto literal de erro atualizado da TASK-10 (rastreia: REQ-05, REQ-13; paths: `tests/w147-hook-delegation-gate.sh`; depende: TASK-10)
  - Teste (comando): `bash tests/w147-hook-delegation-gate.sh`
  - Padrão de falha: `FAIL [1]` (cenário [1] ainda referenciando `scripts/lib/changelog-from-merge.mjs`)
- [X] TASK-12 — Reescrever `tests/w223-delegacao-arvore-do-hook-gate.sh` cenários [3], [8] e toda a família [10*] (inclui [10b]/[10c]/[10d]) para montar `skills/readme-generator/scripts/` como diretório-lar, em vez de `scripts/lib` (rastreia: REQ-05b; paths: `tests/w223-delegacao-arvore-do-hook-gate.sh`; depende: TASK-10)
  - Teste (comando): `bash tests/w223-delegacao-arvore-do-hook-gate.sh`
  - Padrão de falha: `FAIL [3]` ou `FAIL [8]` ou `FAIL [10` (casa toda a família 10*)
- [X] TASK-13 — Teste de regressão `released`/`preserve` com os 4 controles da issue (versão publicada alterada, versão removida, bloco removido, conjunto vazio); nasce com o mesmo preâmbulo de isolamento de `GIT_DIR`/`GIT_WORK_TREE`/etc. que `tests/changelog-merge-gate.sh` tem hoje, porque este arquivo passa a ser a vítima real do w248 (TASK-15) (rastreia: REQ-11, issue #238 item 4; paths: `tests/w<N>-changelog-gates-regressao.sh`; depende: TASK-05, TASK-06)
  - Teste (comando): `bash tests/w<N>-changelog-gates-regressao.sh`
  - Padrão de falha: `FAIL [1]` (versão publicada alterada não reprovada) / `FAIL [2]` (versão removida não reprovada) / `FAIL [3]` (bloco removido não reprovado) / `FAIL [4]` (conjunto vazio tratado como erro, deveria passar)
- [X] TASK-14 — Teste novo cobrindo os cenários do `changelog-merge-gate.sh` antigo contra o motor novo: feat/fix→entrada pt-BR, chore ignorado, refactor/revert ignorados (DIV-02), `perf`→Corrigido (DIV-01), idempotência, no-op sem merge, no-op sem CHANGELOG raiz, no-op com release-please (rastreia: REQ-02, REQ-03, DIV-01, DIV-02, REQ-10b; paths: `tests/w<N>-changelog-merge-engine-gate.sh`; depende: TASK-03, TASK-04)
  - Teste (comando): `bash tests/w<N>-changelog-merge-engine-gate.sh`
  - Padrão de falha: `FAIL [1]`..`FAIL [8]` (um por cenário listado)
- [X] TASK-15 — Reescrever `tests/w248-git-dir-isolation-gate.sh` cenários [1], [2], [12], [14] e [16] usando o arquivo da TASK-13 como vítima real, em vez de `tests/changelog-merge-gate.sh` (rastreia: design §2 checklist de paridade; paths: `tests/w248-git-dir-isolation-gate.sh`; depende: TASK-13)
  - Teste (comando): `bash tests/w248-git-dir-isolation-gate.sh`
  - Padrão de falha: `FAIL [1]` / `FAIL [2]` / `FAIL [12]` / `FAIL [14]` / `FAIL [16]`

## Wave 6 — Remoção com tombstone (só depois da paridade acima estar verde)

- [X] TASK-16 — Remover `template/.forge/scripts/lib/changelog-from-merge.mjs` e `tests/changelog-merge-gate.sh`; adicionar entrada em `installer/removed-files.txt` (path relativo a `.forge/`, um por linha, formato real conferido na implementação). NÃO tocar `template/machinery-history.json` (gerado no pós-tag) nem `snapshot/project-bootstrap/` (imutável) (rastreia: design §2/§5; paths: `template/.forge/scripts/lib/changelog-from-merge.mjs`, `tests/changelog-merge-gate.sh`, `installer/removed-files.txt`; depende: TASK-11, TASK-12, TASK-13, TASK-14, TASK-15)
  - Teste (comando): `! test -f template/.forge/scripts/lib/changelog-from-merge.mjs && ! test -f tests/changelog-merge-gate.sh && grep -qx 'scripts/lib/changelog-from-merge.mjs' installer/removed-files.txt` (composto com `&&`: qualquer condição falsa faz o comando sair ≠0)
  - Padrão de falha: rc≠0 — um dos dois arquivos ainda presente, ou tombstone ausente de `installer/removed-files.txt`

## Wave 7 — SKILL.md, espelho vivo e suíte completa

- [X] TASK-17 — `template/.forge/skills/readme-generator/SKILL.md`: descreve só o que é portado (CHANGELOG, modos explícito/derivado/merge-range, gates `released`/`preserve`/`lint`); declara explicitamente que README e comparação de branches irmãs NÃO fazem parte desta versão; `references/` vazio ou com exemplo genérico, sem conteúdo específico de consumidor (rastreia: proposal §2/§3; paths: `template/.forge/skills/readme-generator/SKILL.md`; depende: TASK-01..TASK-07)
  - Teste (comando): `tests/w<N>-skill-readme-generator-escopo-gate.sh` (script novo, não grep solto: reprova se o SKILL.md contém instrução executável de gerar/comparar README ou branches irmãs; passa se essas palavras só aparecem dentro de uma frase de "fora de escopo nesta versão" — distinção por proximidade de frase, não por presença da palavra)
  - Padrão de falha: `FAIL: SKILL.md promete README ou comparação de branches irmãs sem a ressalva de escopo` (script ainda não existe no vermelho)
- [X] TASK-18 — Rodar `template/.forge/scripts/build-plugin.sh` e confirmar `plugin/forge/commands/update-changelog.md` sincronizado no MESMO commit da TASK; confirmar que `snapshot/project-bootstrap/` permanece intocado (rastreia: design §2 "Espelhos"; paths: `plugin/forge/commands/update-changelog.md`; depende: TASK-09)
  - Teste (comando): `bash template/.forge/scripts/build-plugin.sh && git diff --exit-code plugin/forge/commands/update-changelog.md && git diff --exit-code "$(git merge-base HEAD origin/develop)"...HEAD -- snapshot/` (a base usa `merge-base` com `develop`, não "não commitado", porque uma mudança já commitada em `snapshot/` também precisa reprovar)
  - Padrão de falha: rc≠0 — diff residual em `plugin/` após o build, ou qualquer mudança em `snapshot/` desde que a branch divergiu
- [X] TASK-19 — `npm test` completo verde (rastreia: todos os REQ; paths: —; depende: TASK-01..TASK-18)
  - Teste (comando): `npm test`
  - Padrão de falha: qualquer `FAIL` na saída

## Rastreabilidade

| REQ / DIV | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-09 |
| REQ-02 | TASK-03, TASK-10, TASK-14 |
| REQ-03, REQ-03b, REQ-03e | TASK-03 |
| REQ-03c, REQ-03d | TASK-10 |
| REQ-04 | fora de escopo (intocado) |
| REQ-05, REQ-05b, REQ-05c | TASK-10, TASK-11, TASK-12 |
| REQ-06 | TASK-01 |
| REQ-07 | TASK-09, TASK-10 |
| REQ-08 | TASK-02 |
| REQ-09 | TASK-09 |
| REQ-10 | TASK-04, TASK-09 |
| REQ-10b | TASK-04, TASK-10, TASK-14 |
| REQ-11 | TASK-05, TASK-06, TASK-07, TASK-09, TASK-13 |
| REQ-12 | TASK-08 |
| REQ-13 | TASK-10, TASK-11 |
| REQ-14 | TASK-01 |
| DIV-01, DIV-02 | TASK-02, TASK-14 |
