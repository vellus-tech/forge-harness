---
story_id: STORY-04
epic: fix-graph-query-symbols-fusion
title: update honesto + wrapper symbols + validate-graph.mjs
depends_on: [STORY-03]
status: done
---

# STORY-04 — update honesto + wrapper symbols + validate-graph.mjs

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Tornar `graph.sh update` honesto de fato (flag `--if-changed`, escopo assimétrico `graph.json` vs `symbols.json`/`.tsv`), transformar `graph-symbols.mjs` num wrapper fino sobre o walk/extrator unificado, e adicionar integridade referencial a `validate-graph.mjs` distinguindo órfão (reprova) de staleness cosmética (não reprova).

## Embedded context

### Requirements

- REQ-04 (correção B1) — defasagem por `{mtime,size}`, não por fingerprint estrutural. `{mtime,size}` **entra** na comparação de "mudou de verdade" do `update` **só** para `symbols.json`/`symbols.idx.tsv` — senão a defasagem fica presa para sempre depois de editar só o corpo de uma função.
- REQ-06 — `update` honesto (Fase 1): `graph.json`/`fingerprints.json`/`summaries.json` só regravam se o conteúdo mudar (sem `generated_at`/`root`); `symbols.json`/`.tsv` regravam sempre que `{mtime,size}` divergir. Texto de `graph.sh:5`, `update.md:2`/`:16` e descrição da skill `forge:update` corrigidos (não afirmar mais que "nada é reprocessado"). Strings `'zero tokens'`/`'structural change'` permanecem exatamente iguais.
- REQ-07 — `validate-graph.mjs`: todo `symbol.file` precisa existir como `node.id` em `graph.json`; ausência de `symbols.json` pula a checagem; `symbols.json` corrompido produz `FAIL` dedicado.
- REQ-08 — `graph.sh symbols`/`graph-symbols.mjs` vira wrapper fino sobre `walkSourceFiles`+`extractSymbols`+`assembleSymbolsArtifacts`, herdando universo ampliado; nunca escreve `graph.json`/`fingerprints.json`/`report.md`; `layer` via `graph.json` existente ou `'unknown'`.

### Design

- design.md DD-05 — defasagem por `{mtime,size}`, escopo assimétrico: (i) comparação sempre contra conteúdo do arquivo de saída em disco, nunca cache em memória; (ii) arquivo de saída corrompido no momento da comparação → `update` trata como "mudou", escreve incondicionalmente, nunca propaga exceção de parse; (iii) mecanismo concreto: flag `--if-changed` só na chamada de `update` (`graph.sh`), nunca em `build` — `graph-build.mjs` compara antes de cada `writeFileSync` e pula a escrita quando não mudou.
- design.md DD-02 — `includeGlobs` do wrapper `graph.sh symbols` não é `[]` por omissão: calcula exatamente como `graph-build.mjs` (`readForgeFrontmatter`+`compileLayerMap`). Wrapper standalone pode gerar órfão esperado (diagnóstico, não bug) se rodar antes de `build`/`update`.
- design.md DD-06 — integridade referencial com dois veredictos opostos: arquivo referenciado ausente de `graph.json` = órfão = reprova `validate`; `{mtime,size}` divergente (arquivo ainda existe) = staleness cosmética = nunca reprova `validate` (só aparece no sufixo de `query`, que é da STORY-05). `symbols.json` corrompido no parse por `validate-graph.mjs` segue o mesmo padrão já existente para `graph.json` parse falho (`try/catch` → `FAIL` dedicado).

### Contratos / interfaces

- `graph.json` — comparação de "mudou" ignora `generated_at`/`root`.
- `symbols.json`/`symbols.idx.tsv` — comparação inclui `{mtime,size}` por símbolo.
- `graph.sh symbols` standalone — nunca escreve `graph.json`/`fingerprints.json`/`report.md` como efeito colateral (invariante crítica do epic_context).

### Rules aplicáveis

- `rules/testing/regression-red-first.md` (DD-08) — todas as três tasks editam módulo já existente (`graph-build.mjs`, `graph.sh`, `graph-symbols.mjs`, `validate-graph.mjs`) — commit vermelho via checagem `typeof`/`import()` dinâmico em `tests/`, nunca diff de produção.

### ADRs

- ADR-0001 — sem impacto direto; nenhuma dependência nova.

## Tasks

- [X] TASK-06 — Flag `--if-changed` em `graph-build.mjs`; `graph.sh` passa a flag só em `update`; texto de `graph.sh:5` corrigido (paths: `template/.forge/scripts/lib/graph-build.mjs`, `template/.forge/scripts/graph.sh`; depende: TASK-05). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/w41-graph-gate.sh`. Padrão de falha: `^FAIL [12]` (update sempre reescreve incondicionalmente hoje). Cenários: [5b] não-regravação sob `--if-changed`, [12] honestidade (dois updates sem toque = sem regravação, via `mtime` do arquivo de saída), [12b] arquivo de saída corrompido força escrita incondicional, [22a] `{mtime,size}` atualiza em `symbols.json` após editar só o corpo (dado, sem passar por `query`).
- [X] TASK-07 — `graph-symbols.mjs` vira wrapper fino sobre `walkSourceFiles`+`extractSymbols`+`assembleSymbolsArtifacts` (paths: `template/.forge/scripts/lib/graph-symbols.mjs`, `tests/graph-symbols-gate.sh`; depende: TASK-06). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/graph-symbols-gate.sh`. Padrão de falha: `^FAIL [9b]` (universo ampliado ainda não herdado). Cenários: [9b] universo ampliado via wrapper standalone, [25] sem side-effect (regressão).
- [X] TASK-08 — `validate-graph.mjs` ganha checagem de integridade referencial guardada por `existsSync(symbolsPath)` (paths: `template/.forge/scripts/lib/validate-graph.mjs`; depende: TASK-07). Teste: `bash tests/w344-graph-query-symbols-gate.sh`. Padrão de falha: `^FAIL [4]`. Cenários: [4] reprova órfão com mensagem explícita, [4c] `symbols.json` corrompido → `FAIL` dedicado, [6a] mutação (arquivo inexistente reprova), [17a] órfão pós-`git pull` (parte `validate`), [28] ausência de `symbols.json` não reprova.

## Acceptance criteria

- [X] Dois `update` consecutivos sem toque real não regravam nenhum dos 5 artefatos (verificado só por `mtime` do arquivo de saída, nunca inode).
- [X] Editar só o corpo de uma função (mesma `line`/`name`/`type`) e rodar `update` real atualiza `{mtime,size}` em `symbols.json`.
- [X] `graph.sh symbols` isolado sobre diretório oculto declarado em `include_paths` indexa a função shell esperada.
- [X] `graph.sh symbols` standalone não altera `mtime` de `graph.json`/`fingerprints.json`/`report.md`.
- [X] `validate-graph.mjs` reprova com mensagem explícita quando `symbol.file` não existe em `graph.json`; não reprova por staleness cosmética; pula a checagem quando `symbols.json` ausente; `FAIL` dedicado quando `symbols.json` corrompido.
- [X] `tests/w41-graph-gate.sh`, `tests/graph-symbols-gate.sh` verdes; strings `'zero tokens'`/`'structural change'` inalteradas.
- [X] Commits vermelhos das três tasks tocam só `tests/`.

## Out of scope

- Migração de `graph.sh query` para `graph-query.mjs` e ranking/desempate — é da STORY-05.
- Degradação graciosa de `query` (ENOENT/corrompido/legado) — é da STORY-05 (TASK-11).
