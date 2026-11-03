# Verification — extend-kb-corpus-sources

> Checkpoint review REQ a REQ do change `extend-kb-corpus-sources`, contra o código real implementado (TASK-01..TASK-05, todas `[X]`). Suíte isolada (`tests/w309-kb-corpus-gate.sh` + `tests/extend-kb-corpus-sources-gate.sh`) com 48 casos, todos `PASS`/`OK`, confirmados de forma independente a cada task (não apenas pelo relatório do subagente implementador).

## REQ-01 — Indexar specs ativas como fonte própria (`active-spec`), revertendo REQ-FHT-072

Implementado em `template/.forge/scripts/lib/kb-corpus.mjs` (`collect()`/`sourceFiles()`), commits `2bc4d768`(red)/`ab82f16e`(green). `tests/w309-kb-corpus-gate.sh` caso `[1]` exige `active-spec .forge/specs/active/wip/proposal.md` no corpus; a exclusão de peer/blob/código/node_modules permanece intocada no mesmo arquivo. `spec-delta.yaml` grava `modify_requirement` full-replacement de `REQ-FHT-072`/`SCN-FHT-072-A` com o texto novo — conferido linha a linha contra o comportamento implementado (specs ativas entram com `kind: active-spec`; peer/blob/código/node_modules continuam fora). **Rótulo de `kind` em `kb.sh query` (último critério do REQ-01) — achado real do gate `implementation_verified` na 1ª rodada: a implementação original da TASK-04 só expunha o rótulo de status MADR, não o rótulo de origem de `kind`.** Corrigido nesta fase de verify, TDD completo: caso `[32]` endurecido para exigir `[ACTIVE-SPEC] ` antes do `doc` na saída texto (commits `daf1f3dc` red / `e7025ca9` green, prova via `red-evidence.sh task` rc 0); `KIND_LABEL` novo em `kb-cli.mjs::printText()`, combinável com o rótulo de status (`active-spec`/`extra-path` → `[ACTIVE-SPEC] `/`[EXTRA-PATH] `; `baseline`/`archived-spec`/`plan`/`changelog`/`ledger`/`liaison` preservam a saída atual, sem prefixo). **Status: atende** (corrigido durante verify).

## REQ-02 — Fonte configurável `kb.extra_paths` com allowlist obrigatória

Implementado em `kb-corpus.mjs` (`readExtraPaths`, `resolveExtraPathDirs` compartilhada entre `collect()`/`sourceFiles()`), commits `4ce01f32`(red)/`8083ba1f`(green). As 4 etapas do design §2.2 estão no código: sintaxe textual (`[5]`-`[8]`, inclusive `**` isolado e `/etc/**` absoluto), resolução física via `realpathSync.native` parando só em `ENOENT` (`[23]` prova `ELOOP` tratado como falha real, nunca "inexistente"), regras de segurança sobre o caminho JÁ resolvido (`[9]`-`[14]`, `[24]` — fecha os furos de symlink para `.forge/liaison`, symlink para raiz via `..`, symlink de arquivo interno, overlap ancestral/descendente com `docs/plans`, e o caso macOS case-insensitive em `[16]`), allowlist com `# motivo:` obrigatório (`[15]`), retrocompat quando ausente (`[2]`). Um desvio técnico real encontrado durante a implementação (não um gap de segurança): `addFile()` usava `docRoot` bruto para calcular o `id` relativo, divergindo do caminho físico resolvido em ambientes com symlink no próprio `docRoot` (ex.: `/tmp` no macOS) — corrigido fazendo `resolveExtraPathDirs` devolver também `realDocRoot`, usado como raiz na chamada de `addFile` para `extra-path`. **Status: atende.**

## REQ-03 — Schema declara `kb.extra_paths`

Bloco `kb` novo em `template/.forge/schemas/forge.schema.json`, `additionalProperties: false`, mesmo commit `8083ba1f`. Casos `[19]`-`[21]` provam: array válido aceito, chave extra rejeitada, `extra_paths` não-array rejeitado — via `ajv`/`tools/validate-forge.mjs` (mesma convenção de `tests/w20-spec-gate.sh` caso `[5]`). **Status: atende.**

## REQ-04 — `kb.sh status`/`build` reportam contagem por fonte

`countKinds()` nova e compartilhada em `kb-cli.mjs`, commits `a76a7c4d`(red)/`e25ce738`(green). Caso `[25]` (`status --json` inclui `kinds.active-spec`), `[26]` (`extra-path: 0` explícito quando configurado e vazio — nunca ausente), `[27]` (`build`, saída texto, lista contagem por fonte). Medido na própria execução de `kb.sh build` deste repositório (ver NFR-02 abaixo): `517 documentos (active-spec=34 archived-spec=238 baseline=11 changelog=1 ledger=175 liaison=12 plan=46)`. **Status: atende.**

## REQ-05 — Documentação não afirma cobertura total

`template/.forge/commands/graph/kb.md` reescrito, commits `13856d3c`(red)/`54c8a6f7`(green): seção "O que entra e o que nunca entra" lista as 8 fontes (incluindo `active-spec`/`extra-path`), seção "Multi-repositório" qualifica a limitação, seção "Registrar um fato pontual" orienta `ledger-ops.sh add --type follow-up` com a ressalva do enum fechado. Casos `[36]`-`[39]` provam presença dos três conteúdos e ausência de frase de cobertura total não qualificada (`[39]` usa `! grep -qi`, não `grep -v` — achado de revisão anterior, corrigido). **Status: atende.**

## REQ-06 — Fontes novas participam do mecanismo de staleness já existente

Caso `[1]` (TASK-01) e `[17]`/`[18]` (TASK-02) provam ponta a ponta, via `kb.sh status`/`query` reais (nunca a função interna `sourceFiles()`, que não é exportada): editar o conteúdo de um doc `active-spec`/`extra-path` entre dois `build` reporta `defasado`; sem `build` explícito, o próximo `query` já reconstrói e reflete o texto novo (reconstrução automática de `loadIndex()`); remover/renomear um arquivo `extra-path` já indexado faz o doc desaparecer no próximo `build`. Nenhum mecanismo novo foi criado — `sourceFiles()`/`collect()` dos dois kinds novos passaram a alimentar `quickFingerprint()`/`fingerprint()` já existentes. **Status: atende.**

## REQ-07 — Status MADR extraído e rotulado na resposta de busca

`madrStatus()` em `kb-corpus.mjs`, `INDEX_FORMAT` 3→4 em `kb-lexical.mjs`, exposição em `search()`/`printText()`/`cmdQuery` em `kb-cli.mjs`, commits `b7443477`(red)/`682be25d`(green). Casos `[28]`-`[35]`: `accepted` sem rótulo (`[28]`), sufixo real do ADR 0004 deste repositório não quebra a classificação (`[29]`), `superseded` com rótulo em texto e campo `status` em `--json` (`[30]`), documento não-ADR sem campo `status` e sem erro (`[31]`), `kind` sempre presente em `--json` (`[32]`), índice antigo `format: 3` reconstruído automaticamente (`[33]`), pontuação colada removida (`[34]`), variantes PT-BR mapeadas (`[35]`). Nenhuma mudança em `kb-fuse.mjs` — ranking/RRF/re-rank intocados, conforme decisão de design §3. **Status: atende.**

## NFR-01 — Zero chamada de rede nova

Reexecutados `tests/w313-kb-offline-lexical-gate.sh` (7 casos, `PASS`) e `tests/w318-kb-offline-semantic-gate.sh` (2 casos, `PASS`) depois de TASK-01..05 completas — confirmado por leitura que os dois iteram `lib/kb-*.mjs` por glob (não lista fixa), cobrindo o código novo sem precisar de edição. Zero import fora de `node:*`/harness no código novo (`readExtraPaths`/parser de allowlist usam só `readFileSync`/`realpathSync.native`; `madrStatus` é regex pura). **Status: atende.**

## NFR-02 — Custo de build proporcional

Medido no próprio repositório, pós-implementação: `FORGE_ROOT="$PWD" bash template/.forge/scripts/kb.sh build` →
`OK índice lexical: 517 documentos (active-spec=34 archived-spec=238 baseline=11 changelog=1 ledger=175 liaison=12 plan=46), 6800 trechos (0.7s)`, `time`: 0,66s user / 0,09s system / 0,799s total. `active-spec` contribui 34 de 517 documentos (~6,6%) sobre um build de menos de 1 segundo — sem meta numérica rígida (conforme design/requirements), o custo é claramente proporcional ao número de arquivos novos, sem comportamento quadrático perceptível. Não há `extra_paths` configurado neste repositório (dogfood, sem `forge.yaml` próprio) — o custo dessa fonte é, por construção (mesmo `walk()`), da mesma ordem por arquivo que as demais fontes. **Status: atende.**

## Suíte isolada do change

`bash tests/w309-kb-corpus-gate.sh && bash tests/extend-kb-corpus-sources-gate.sh` → 9 + 39 = 48 casos, todos `PASS`/`OK`, confirmados por execução direta (não só relatada pelo subagente) depois de cada task.

## Suíte completa do repositório

**1ª execução** (`FORGE_ROOT="$PWD" bash tests/run-all.sh`, 3973s): `PASS=201 FAIL=42`. Nenhum dos 42 gates reprovados toca arquivo deste change (`kb-corpus.mjs`, `kb-cli.mjs`, `kb-lexical.mjs`, `forge.schema.json`, `kb.md`, `w309`, `extend-kb-corpus-sources-gate.sh` ausentes da lista). Investigação (gate `implementation_verified`, 1ª rodada): a causa real **não foi contenção de lock do git entre worktrees** (hipótese inicial do orquestrador, descartada) — foi o `FORGE_ROOT="$PWD"` exportado na invocação, que propagou para dentro de `spec-new.sh` (chamado por `w20`/outros gates) e colidiu com nomes de fixture (`feat-x`, `fix-y`, `ref-z`, `green-w`, `brown-v`, entre ~20 outros) que a trava de sobrescrita do próprio `spec-new.sh` rejeitou — e esses mesmos diretórios de fixture ficaram vazados, não rastreados, em `.forge/specs/active/` desta worktree (22 diretórios, criados entre 22:43 e 23:48 durante a 1ª execução). Removidos antes da 2ª execução (seriam indexados como `active-spec` pelo próprio REQ-01 deste change, poluindo o corpus).

**2ª execução**, sem `FORGE_ROOT` exportado (correção da causa raiz): `PASS=238 FAIL=5` (4288s) — confirma que a causa real dos 42 era o `FORGE_ROOT` exportado, não concorrência entre worktrees. Os 5 restantes, investigados um a um:

- `w139-secrets-gate.sh` — **causado por este change.** O fixture do caso `[22]` (TASK-02, extensão `.pem` rejeitada) continha, no texto-fonte de `tests/extend-kb-corpus-sources-gate.sh`, o cabeçalho PEM de chave privada por extenso (as cinco linhas de hífen + "BEGIN"/"END" + o tipo de chave — omitido aqui de propósito, nesta mesma frase, para este arquivo de verificação não recriar o mesmo falso positivo), disparando falso positivo no scanner de segredos sobre o PRÓPRIO arquivo de teste (o caso só precisa da extensão, nunca de conteúdo PEM real). Corrigido: conteúdo trocado para texto genérico sem padrão de segredo. Commit `eddb8812`.
- `plugin-sync-gate.sh` — **causado por este change.** TASK-05 editou `template/.forge/commands/graph/kb.md` mas não regenerou o espelho `plugin/forge/commands/kb.md` (`npm run build:plugin`). Corrigido: build do plugin executado e commitado. Commit `eddb8812`.
- `w200-readme-inventory-gate.sh` — **causado por este change.** `tests/extend-kb-corpus-sources-gate.sh` é um gate novo (+1 na árvore de `tests/*-gate.sh`), e o badge de contagem no `README.md` ficou desatualizado (240 → 241 real). Corrigido: badge atualizado. Commit `34c24b63`.
- `graph-jvm-gate.sh` e `npx-pack-gate.sh` — **não relacionados a este change.** Nenhum dos dois toca arquivo deste change; reexecutados isoladamente depois das três correções acima e passaram limpos (`OK`), sem nenhuma alteração de código — consistentes com falha transitória do ambiente (outras sessões paralelas no mesmo `.git` compartilhado) no momento exato da 2ª execução, não com regressão.

**3ª execução** (confirmação final, depois das 3 correções): `PASS=241 FAIL=2` (4125s) — `gate-assert-visibility-gate.sh` e, de novo, `w139-secrets-gate.sh`.

- `w139-secrets-gate.sh` — **recaída causada por esta MESMA sessão de verify**: o texto que eu tinha escrito acima, nesta seção de `verification.md`, para EXPLICAR a correção anterior, citava o cabeçalho PEM por extenso em prosa — recriando o mesmo falso positivo, agora sobre o próprio `verification.md`. Corrigido: a explicação acima foi reescrita sem o cabeçalho literal. Reexecutado isolado depois da correção: `OK [15]`, `PASS w139-secrets-gate`.
- `gate-assert-visibility-gate.sh` — **não relacionado a este change** (não toca nenhum arquivo deste change; testa `w80-suite-gate.sh`). Reexecutado isolado duas vezes depois da 3ª execução completa: `rc=0`, `OK [1]`, `PASS` — passa limpo. Flake transitório do ambiente (mesma classe dos dois da 2ª execução), não regressão.

**Conclusão:** depois de 3 execuções completas de `tests/run-all.sh` e investigação individual de toda falha, as únicas causadas por este change (3 no total: fixture PEM do `w139` duas vezes — a 1ª no código de teste, a 2ª na própria prosa deste arquivo —, `plugin-sync-gate.sh`, `w200-readme-inventory-gate.sh`) estão corrigidas e confirmadas por reexecução isolada. As demais (42 na 1ª execução, 2 na 2ª, 2 na 3ª — nenhuma repetida entre execuções exceto o `w139` recaído por mim) são ambientais: `FORGE_ROOT` exportado colidindo com fixtures de `spec-new.sh` (causa raiz real dos 42, não concorrência de git como hipotetizado inicialmente) e flakiness pontual de dois gates não relacionados, cada um confirmado limpo isoladamente.

## Desvios e notas registradas

- `spec-delta.yaml` recebeu, além do `modify_requirement` de `REQ-FHT-072` (autorado na TASK-01), seis operações `add_requirement` novas (`REQ-FHT-102`..`REQ-FHT-107`, uma por REQ-02..REQ-07 de `requirements.md`) — autoradas nesta fase de verify, a partir do texto já revisado dos requisitos, antes do archive.
- Rótulo de origem (`kind`) na saída texto de `kb.sh query` — gap real encontrado pelo gate `implementation_verified` (1ª rodada), corrigido via TDD nesta mesma fase (ver REQ-01 acima).
- 22 diretórios de fixture de teste vazados em `.forge/specs/active/` (não rastreados pelo git, gerados por execuções anteriores de gates como `w20`/`w13`/outros) foram removidos antes de reexecutar a suíte completa — não eram specs reais do projeto.
- Nenhum `NEEDS CLARIFICATION` pendente; nenhuma task ficou `[!]`.
