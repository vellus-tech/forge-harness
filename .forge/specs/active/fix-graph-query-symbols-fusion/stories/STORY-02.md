---
story_id: STORY-02
epic: fix-graph-query-symbols-fusion
title: Extrator puro de símbolos + lexer de pilha de frames
depends_on: [STORY-01]
status: todo
---

# STORY-02 — Extrator puro de símbolos + lexer de pilha de frames

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Criar `graph-symbols-extract.mjs`: o lexer `stripCommentsPreservingLines` (pilha de frames `top`/`sq`/`dq`/`subst`) que mascara comentário/string/heredoc/regex corretamente, `extractSymbols(rel, lang, src)`, `resolveInheritance(symbolsByFile)` e `assembleSymbolsArtifacts(...)` — tudo como funções puras, sem nenhuma integração com `graph-build.mjs` ainda.

## Embedded context

### Requirements

- REQ-01 — `extractSymbols(rel, lang, src) → {symbols:[{name,type,line}], inherit:[{name,base,line}]}`. Migra as regexes `DECL` de `graph-symbols.mjs` linha a linha, preservando captura de `base`. Identidade `id = ${rel}#${name}` (não-única); dedup por `(file,name,type,line)`. Ganha suporte a shell (`function X()`/`X() {`), TS/JS moderno (`export const X = (...) =>`), índice de offsets de linha pré-computado. Decisão sobre Go: `extractSymbols` não ganha `DECL.go` nesta fatia — `.go` produz `symbols: []`.
- REQ-02 — `stripCommentsPreservingLines(src, lang)`, lexer de passada única com estados `normal`/`line-comment`/`block-comment`/`regex`/`string`/`heredoc`, mascarando comentário E conteúdo de string (não só evitando mexer dentro de aspas). Regras por linguagem: Python `#` sempre abre comentário fora de string; shell `#` só abre em início de palavra e não precedido por `$`; demais linguagens `//`/`/*`, com precedência sobre `regex` (JS/TS). Shell usa pilha de frames `top`/`sq`/`dq`/`subst` para `$(...)`/crase aninhados contendo aspas — ver DD-01. Estado `regex` (JS/TS) obrigatório para não mascarar código por causa de `` /`/g ``. Heredoc (`<<EOF`/`<<-EOF`/variantes de aspas), here-string `<<<` explicitamente excluído. `${...}` suprime comentário incondicionalmente em shell.

### Design

- design.md DD-01 — Lexer de pilha de frames, não par linear de estados: frames `top`/`sq`/`dq`/`subst`; só `top`/`subst` podem abrir `heredoc`/`line-comment` — nunca `dq`. Toda extração de símbolo depende desta função estar correta; nunca remendar com regra ad-hoc.
- design.md DD-02 (parcial, só a parte que esta story produz) — `resolveInheritance(symbolsByFile)` é **fixada em `graph-symbols-extract.mjs`**, nunca em `graph-build.mjs` (confirmado: `graph-build.mjs` tem efeito colateral de módulo no topo — `resolve(process.argv[2]||'.')` e `writeFileSync` fora de guarda de CLI — importar o módulo num teste de propriedade disparia um build real no dogfood). Herança/desempate sempre operam sobre array já materializado, nunca fechando sobre a ordem do walk.
- design.md DD-02 — vocabulário de `lang` unificado: `extractSymbols` adota os valores de `LANG` de `graph-build.mjs` (`java`,`kotlin`,`go`,`shell`, não `jvm`); resolve `java`/`kotlin` para o mesmo conjunto de regexes internamente.
- design.md DD-04 — identidade (`file#name`, não-única) ≠ dedup (`file,name,type,line`) ≠ desempate (`name,file,line`, `localeCompare('en')`+numérico). `assembleSymbolsArtifacts` exporta o comparador (`compareSymbolNames`) como função própria — reusado pela TASK-09 em `tieBreak`, nunca reimplementado.

### Contratos / interfaces

- `symbols.json` (schema `symbols/v0`, aditivo) e `symbols.idx.tsv` ainda não são gravados em disco por esta story — `assembleSymbolsArtifacts` só produz o objeto `{symbolsJson, idxTsv}` em memória; a gravação é da STORY-03.
- `id` de símbolo = `${rel}#${name}` (formato exigido por `tests/graph-symbols-gate.sh:55`, `endsWith("#"+a)`).

### Rules aplicáveis

- `rules/testing/regression-red-first.md` com a leitura ampliada de `isInfraPath` (DD-08) — módulo novo sob `template/.forge/scripts/lib/`: commit vermelho só em `tests/`, usando `import()` dinâmico + `try/catch` → `assert.fail`.
- `rules/testing/property-based-testing.md` — base de P2 (sem duplicata), P4-herança (invariância sob permutação), P5 (invariância cosmética), provadas nesta story via w344 (não w345, que só é criado na TASK-14).

### ADRs

- ADR-0001 — zero-dep inegociável; toda a correção é regex/lexer artesanal, nunca AST.

## Tasks

- [ ] TASK-03 — Criar `graph-symbols-extract.mjs`: `stripCommentsPreservingLines` + `extractSymbols` + `resolveInheritance` + `assembleSymbolsArtifacts` + exportação do comparador `compareSymbolNames` (paths: `template/.forge/scripts/lib/graph-symbols-extract.mjs` novo, `tests/w344-graph-query-symbols-gate.sh` novo, `tests/fixtures/graph-query-symbols/*.ts.txt|*.cs.txt|*.py.txt|*.sh.txt`, `README.md` contagem `scripts/ (178→179)` e badge `gates-243→244`; depende: TASK-02). Teste: `bash tests/w344-graph-query-symbols-gate.sh && bash tests/w200-readme-inventory-gate.sh`. Padrão de falha: `^FAIL \[0\]` (`import()` dinâmico de módulo ausente → `assert.fail`). Cenários cobertos nesta task: [0] vacuidade por linguagem, [8]/[8b] fantasma de string/comentário, [13a] herança pura, [18] equivalência com motor antigo (golden diferencial), [19]/[19c]/[19d] regras shell, [20] heredoc, [21] docstring Python, [26a] herança independente de ordem (pura), [29]/[29b]/[29c] estado regex JS/TS, [30]/[31]/[31b] here-string/heredoc, [32]/[32b] oráculo de corpus real; PBT: P2, P4-herança, P5.

## Acceptance criteria

- [ ] `extractSymbols(rel, lang, src)` produz `{name,type,line}` idêntico ao motor antigo para cs/ts/js/py/jvm, com diferenças anotadas (remoções = fantasmas eliminados; adições = shell/`export const =>`).
- [ ] `stripCommentsPreservingLines` mascara `"class Ghost"`, `` `class Ghost` ``, docstring Python, heredoc contendo `class Ghost`, sem deslocar `line` das declarações seguintes (exceto pelas linhas de comentário realmente inseridas).
- [ ] `` /`/g `` (regex com backtick) não abre estado de string/template literal.
- [ ] `x="$(grep -E '...' "$y" ...)"` seguido de declaração real continua indexável com `line` correta (pilha de frames, não par linear).
- [ ] `resolveInheritance` e o desempate (via `compareSymbolNames`) produzem resultado idêntico sob permutação de ordem de entrada (P4-herança, P5).
- [ ] `.go` produz `symbols: []`.
- [ ] `tests/w344-graph-query-symbols-gate.sh` e `tests/w200-readme-inventory-gate.sh` verdes.
- [ ] Commit vermelho desta task toca só `tests/` — nenhum arquivo de produção.

## Out of scope

- Integração com `graph-build.mjs`/`walkSourceFiles` e gravação real de `symbols.json`/`symbols.idx.tsv` em disco — é da STORY-03.
- `rankSymbols`/`tieBreak` de `graph.sh query` — é da STORY-05.
