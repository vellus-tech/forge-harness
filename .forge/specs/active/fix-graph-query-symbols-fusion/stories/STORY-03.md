---
story_id: STORY-03
epic: fix-graph-query-symbols-fusion
title: Walk unificado + integração em graph-build.mjs
depends_on: [STORY-02]
status: todo
---

# STORY-03 — Walk unificado + integração em graph-build.mjs

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Extrair `walkSourceFiles({root, includeGlobs})` para `graph-walk.mjs` como função pura (sem efeito colateral de módulo), refatorar `graph-build.mjs` para importá-la e para chamar `extractSymbols`/`assembleSymbolsArtifacts` dentro do walk único, gravando `symbols.json`/`symbols.idx.tsv` de verdade — preservando o golden byte a byte de `graph.json` (w141).

## Embedded context

### Requirements

- REQ-03 — integração em `graph-build.mjs`: `extractSymbols` chamado por arquivo dentro do walk único (o mesmo que já aplica `include_paths`/`SKIP_UNDER_BIN`), usando `src` já lido em `srcCache`. Resolve herança iterando símbolos em ordem canônica `(file,line)`, nunca a ordem de `readdirSync`. Grava `symbols.json` (schema `symbols/v0`, aditivo `{id,file,name,type,line,layer,mtime,size}`, preserva `edges{kind:'inherits'}`) e `symbols.idx.tsv` (`name\tfile\tline\ttype\tlayer`, ordenado por `(name,file,line)`, projeção exata — par atômico, nunca um regrava sem o outro). Universo percorrido amplia (`.sh`/`.go`, `include_paths`).
- REQ-08 (parcial — só a parte do walk unificado que `graph-build.mjs` consome; o wrapper `graph.sh symbols` é da STORY-04) — `walkSourceFiles` é a mesma função usada pelos dois consumidores, nunca duplicada.
- bugfix.md §3 (invariante) — `graph.json` schema inalterado, conteúdo byte a byte idêntico ao golden w141 [2]; `stripComments` original de `graph-build.mjs:192` intocada.
- bugfix.md B4 — `symbols.json`/`symbols.idx.tsv` gravados em `.forge/graph/`, não versionados; `.gitignore` raiz e `installer/gitignore.patch` ganham as duas entradas.

### Design

- design.md DD-02 — `walk()` hoje não é pura (fecha sobre globais, muta `census` por closure). Refatoração mínima: `walkSourceFiles({root, includeGlobs})` em `graph-walk.mjs`, retorna `{files, census}` em vez de mutar closure. Migram junto `SKIP_DIRS`/`SKIP_UNDER_BIN`/`CENSUS_EXT`/`LANG`/`SKIP_FILE` — as cinco constantes, exportadas de `graph-walk.mjs`, nunca duplicadas. `graph-build.mjs` continua usando `LANG` fora do walk (processamento de node) — importa de `graph-walk.mjs`, não mantém cópia local.
- design.md DD-02 — ponto de injeção de ordem (P4/[26]): herança e desempate recebem o array `symbols[]` já materializado como parâmetro explícito, nunca fechando sobre a ordem do walk.
- design.md §3 (alternativas descartadas) — cache por hash de conteúdo (`rawSha256`) para defasagem foi rejeitado nesta fatia (adiado para Fase 2); esta story usa `{mtime,size}`.

### Contratos / interfaces

- `symbols.json` schema `symbols/v0` — aditivo, nunca `v1`. Consumido por `lib/mdl-gen.mjs:119` (`edges.filter(kind==='inherits')`).
- `symbols.idx.tsv` — novo artefato, projeção exata, sem consumidor existente a quebrar.
- `graph.json` — inalterado, golden byte a byte (w141 [2]).
- `installer/gitignore.patch` / `.gitignore` — ganham `symbols.json` (já presente em `gitignore.patch`)/`symbols.idx.tsv` (novo nos dois).

### Rules aplicáveis

- `rules/testing/regression-red-first.md` (DD-08) — `graph-walk.mjs` é módulo novo (commit vermelho só em `tests/`, `import()` dinâmico); `graph-build.mjs` é módulo existente editado (export novo detectado por `typeof`, nunca diff de produção no commit vermelho).
- `rules/testing/property-based-testing.md` — P6 (`symbols.idx.tsv` é projeção exata de `symbols.json`) fecha nesta story.

### ADRs

- ADR-0001 — zero-dep; nenhuma mudança aqui introduz dependência externa.

## Tasks

- [ ] TASK-04 — Extrair `walkSourceFiles({root, includeGlobs})` para `graph-walk.mjs`; `graph-build.mjs` refatorado para importar e usar, preservando golden w141 byte a byte (paths: `template/.forge/scripts/lib/graph-walk.mjs` novo, `template/.forge/scripts/lib/graph-build.mjs`, `manifest.yaml` (adiciona `graph-walk.mjs` a `affected_paths`), `README.md` contagem `scripts/ (179→180)`; depende: TASK-03). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/w141-codegraph-layer-map-gate.sh && bash tests/w200-readme-inventory-gate.sh`. Padrão de falha: `^FAIL [DD-02]` (`import()` dinâmico de `graph-walk.mjs` ainda inexistente).
- [ ] TASK-05 — `graph-build.mjs` chama `extractSymbols`/`assembleSymbolsArtifacts` dentro do walk unificado, grava `symbols.json`+`symbols.idx.tsv`, resolve herança em ordem canônica `(file,line)`; `.gitignore` raiz e `installer/gitignore.patch` ganham as duas entradas (paths: `template/.forge/scripts/lib/graph-build.mjs`, `.gitignore`, `installer/gitignore.patch`; depende: TASK-04). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/w133-gitignore-reconcile-gate.sh`. Padrão de falha: `^FAIL [5a]` (determinismo, arquivos ainda não gravados). Cenários: [5a] determinismo, [6c]/P6 projeção exata, [7] deslocamento de `line` sem invalidar fingerprint, [9a] `include_paths` via `graph.sh build`, [13b] herança sobrevive à integração, [26b] herança independente de ordem (regressão real), [27] gitignore.patch contém `symbols.idx.tsv`.

## Acceptance criteria

- [ ] `walkSourceFiles({root, includeGlobs})` retorna `{files, census}` sem mutar closure; respeita `include_paths`/`SKIP_DIRS`/`SKIP_UNDER_BIN`; inclui `.sh`/`.go`.
- [ ] `tests/w141-codegraph-layer-map-gate.sh [2]` (golden byte a byte de `graph.json`) permanece verde depois da refatoração de `graph-build.mjs`.
- [ ] `symbols.json`/`symbols.idx.tsv` são gerados por `graph.sh build`, deterministicamente (dois builds idênticos incluindo `mtime`/`size`).
- [ ] Herança resolvida (`edges.kind==='inherits'`) é idêntica sob permutação da ordem física do walk.
- [ ] `.gitignore` e `installer/gitignore.patch` contêm `symbols.idx.tsv`; `tests/w133-gitignore-reconcile-gate.sh` verde com asserção nova sobre os dois artefatos.
- [ ] Commits vermelhos de TASK-04/TASK-05 tocam só `tests/`.

## Out of scope

- Flag `--if-changed`/honestidade do `update` — é da STORY-04 (TASK-06).
- Wrapper `graph.sh symbols` — é da STORY-04 (TASK-07).
- `validate-graph.mjs` — é da STORY-04 (TASK-08).
