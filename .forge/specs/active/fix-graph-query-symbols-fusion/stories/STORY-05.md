---
story_id: STORY-05
epic: fix-graph-query-symbols-fusion
title: graph.sh query migra para graph-query.mjs
depends_on: [STORY-04]
status: todo
---

# STORY-05 — graph.sh query migra para graph-query.mjs

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Criar `graph-query.mjs` com ranking/desempate puros, migrar `graph.sh query` do `node -e` inline para o módulo, adicionar a seção `symbols (N):`, defasagem por `{mtime,size}`, contrato `--json` completo, e degradação graciosa (ENOENT/JSON corrompido/formato legado) — sem jamais quebrar `nodes`/`edges` byte a byte.

## Embedded context

### Requirements

- REQ-05 — `graph.sh query` migra do `node -e` inline para `graph-query.mjs`: `nodes`/`edges` byte a byte iguais; seção nova `symbols (N):` (`Nome [type] arquivo:linha (layer)` + sufixo de defasagem); ranking exato→prefixo→substring; desempate determinístico `(name,file,line)` — `name`/`file` por `localeCompare`, `line` numérico. Dica de 0-resultados (texto canônico exato, exit 0). Flag `--json` com `{nodes,edges,symbols,hint?}`, cada símbolo `{id,name,type,file,line,layer,stale}`.
- REQ-04 — sufixo `(linha possivelmente defasada)`/`stale:true` quando `{mtime,size}` do arquivo divergem do indexado; só os ≤20 resultados recebem `stat()`.
- REQ-10 — degradação graciosa: ENOENT no `stat()` → sufixo `(arquivo não encontrado — rode graph.sh build)` + `missing:true` no JSON, sem afetar os demais; `symbols.json` corrompido → `WARN` em stderr, degrada para nodes/edges-only; entrada legada sem `mtime`/`size` → "não verificável", sem crash. Todos saem com `exit 0`.

### Design

- design.md DD-03 — `query` migra de `node -e` inline para módulo próprio; contrato `nodes`/`edges` preservado byte a byte (golden w141, capturado na STORY-01/TASK-02).
- design.md DD-04 — locale fixo: `localeCompare(b, 'en')`, nunca sem argumento — determinístico entre máquinas. `rankSymbols`/`tieBreak` reusam o `compareSymbolNames` já exportado por `graph-symbols-extract.mjs` (STORY-02) — nunca reimplementam `localeCompare` em paralelo.
- design.md DD-07 — degradação concentrada em `readSymbolsSafely()` — único ponto que emite `WARN`; ENOENT e legado tratados por símbolo individual. Aviso de formato legado/ausência em stderr só quando `symbols.length > 0 E nenhuma entrada tem mtime` (evita vacuidade com projeto só `.go`).
- design.md DD-09 — `--json` em qualquer posição relativa ao termo; termo iniciando com `--` fora de escopo. Guard de CLI via `realpathSync` dos dois lados (padrão `kb-cli.mjs`), nunca `import.meta.url === file://...` (quebra em `/tmp` symlinkado no macOS). Funções de ranking exportadas sem corte de 20 — corte é decisão do CLI.

### Contratos / interfaces

- `graph.sh query <termo> [--json]` — `nodes`/`edges` byte a byte iguais a hoje (golden w141 + `query-golden-pre-change.txt` da STORY-01); seção `symbols` aditiva; `--json` com `{nodes,edges,symbols,hint?}`.
- `graph.sh query` nunca escreve em disco — operação de leitura pura, sempre `exit 0` (invariante crítica do epic_context).

### Rules aplicáveis

- `rules/testing/regression-red-first.md` (DD-08) — `graph-query.mjs` é módulo novo (TASK-09, commit vermelho só `tests/`, `import()` dinâmico); TASK-10/TASK-11 editam o mesmo módulo já criado na mesma wave — ainda sob `template/.forge/scripts/`, mesma disciplina.
- `rules/testing/property-based-testing.md` — P1 (completude), P3 (metamórfica), P4-desempate (invariância sob permutação) fecham aqui.

### ADRs

- ADR-0001 — sem impacto; heurística regex/ranking, nunca AST.

## Tasks

- [ ] TASK-09 — Criar `graph-query.mjs`: `rankSymbols`/`tieBreak` puros, guard de CLI via `realpathSync`; `graph.sh query` chama o módulo, `nodes`/`edges` preservadas byte a byte (paths: `template/.forge/scripts/lib/graph-query.mjs` novo, `template/.forge/scripts/graph.sh`, `README.md` contagem `scripts/ (180→181)`; depende: TASK-08). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/w41-graph-gate.sh && bash tests/w200-readme-inventory-gate.sh`. Padrão de falha: `^FAIL [1]` (módulo ausente). Cenários: [1] controle (golden pré-mudança sem `symbols.json`), [2] acerto de símbolo, [3] ranking+desempate, [10a] `--json` básico, [24a] desempate entre arquivos (saída humana); regressão `w41-graph-gate.sh [7]` sob `/tmp` symlinkado; PBT P1, P3, P4-desempate.
- [ ] TASK-10 — Seção `symbols (N):` com defasagem por `{mtime,size}`, `--json` completo (`stale`), dica de 0-resultados (paths: `template/.forge/scripts/lib/graph-query.mjs`; depende: TASK-09). Teste: `bash tests/w344-graph-query-symbols-gate.sh`. Padrão de falha: `^FAIL [7b]`. Cenários: [7b] sufixo de defasagem, [10b] `--json` completo (`stale`), [11] `query` não escreve em disco, [22b] defasagem some após `update` real (visível via query), [6b] staleness de fingerprint-only não marca stale, [23] dica de 0-resultados (texto exato), [24b] desempate completo com `--json`.
- [ ] TASK-11 — Degradação graciosa: `readSymbolsSafely()`, ENOENT por símbolo, entrada legada, aviso de formato legado/vacuidade (paths: `template/.forge/scripts/lib/graph-query.mjs`; depende: TASK-10). Teste: `bash tests/w344-graph-query-symbols-gate.sh`. Padrão de falha: `^FAIL [14]`. Cenários: [14] ENOENT, [15] JSON corrompido (degrada sem crash), [16] legado sem mtime/size, [16b] vacuidade (`symbols:[]` não dispara aviso falso), [17b] `query` não crasha com `symbols.json` órfão pós-pull.

## Acceptance criteria

- [ ] `nodes`/`edges` de `graph.sh query` idênticos byte a byte ao golden `query-golden-pre-change.txt` quando `symbols.json` ausente (cenário de controle).
- [ ] Busca por nome de símbolo real (ex. `processarPedido`) produz `symbols (N):` com `arquivo:linha`.
- [ ] Desempate determinístico `(name,file,line)` com `localeCompare('en')`+numérico, idêntico sob permutação de ordem de criação de arquivos.
- [ ] `--json` produz `{nodes,edges,symbols,hint?}`; cada símbolo com `{id,name,type,file,line,layer,stale}`.
- [ ] Sufixo de defasagem aparece só com divergência real de `{mtime,size}` e some após `update` real.
- [ ] `query` nunca lança exceção não tratada e sempre sai `exit 0`, inclusive com `symbols.json` ausente/corrompido/legado/ENOENT.
- [ ] `tests/w41-graph-gate.sh` (inclusive `[7]` sob `/tmp` symlinkado) e `tests/w344-graph-query-symbols-gate.sh` verdes.
- [ ] Commits vermelhos das três tasks tocam só `tests/`.

## Out of scope

- Documentação/rule/fiação do agente — é da STORY-06.
- Consolidação do PBT num arquivo `w345` dedicado e fechamento do Red SDD-level — é da STORY-07.
