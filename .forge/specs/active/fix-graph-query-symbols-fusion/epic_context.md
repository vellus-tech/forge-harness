# Epic context — fix-graph-query-symbols-fusion

> Gerado por epic-context agent. Leitura rápida — não substitui os artefatos originais.

## Objetivo

`graph.sh query` e `graph.sh symbols` são dois sistemas de grafo desconectados: `query` nunca lê `symbols.json`, e o walk de `graph-symbols.mjs` diverge do walk de `graph-build.mjs` (não aplica `include_paths`, não cobre `.sh`/`.go` — 60,8% dos nodes deste repositório). Esta fatia funde os dois: novo extrator puro de símbolos com lexer de pilha de frames (mascara comentário/string/heredoc/regex corretamente), integração no walk unificado de `build`/`update`, e `query` passa a buscar por nome de símbolo (`arquivo:linha`), não só por caminho de arquivo. Inclui fiação de docs/rules para o agente de fato usar a capacidade nova.

## Decisões de design

- **DD-01 — Lexer de pilha de frames (`top`/`sq`/`dq`/`subst`), não par linear de estados** → toda extração de símbolo depende de `stripCommentsPreservingLines` estar correta; um modelo linear quebra em `$(...)`/crase aninhado contendo aspas (shell) e em regex JS/TS com aspas/crase — qualquer story que toque o lexer deve preservar o modelo de pilha, nunca remendar com regra ad-hoc.
- **DD-02 — Extração integrada ao walk único de `build`/`update`, nunca walk próprio** → `walkSourceFiles({root, includeGlobs})` migra para `graph-walk.mjs` como função pura, sem efeito colateral de módulo; `graph-build.mjs` e o wrapper `graph.sh symbols` importam a mesma função — nunca duplicar constantes (`SKIP_DIRS`/`LANG`/etc.) entre os dois.
- **DD-03 — `query` migra de `node -e` inline para módulo `graph-query.mjs`** → contrato `nodes`/`edges` preservado byte a byte (golden w141); seção `symbols` é aditiva.
- **DD-04 — Identidade não-única (`file#name`) ≠ chave de dedup (`file,name,type,line`) ≠ critério de desempate (`name,file,line` com `localeCompare('en')` + comparação numérica de `line`)** → três preocupações distintas, nunca colapsar numa só; `tieBreak`/`symbols.idx.tsv` reusam o mesmo comparador exportado por `graph-symbols-extract.mjs`, nunca reimplementado em paralelo.
- **DD-05 — Defasagem por `{mtime,size}` por arquivo, nunca por fingerprint estrutural** → fingerprint ignora comentário de propósito e não detecta deslocamento de `line`. Escopo assimétrico: `graph.json` ignora `generated_at`/`root` na comparação de "mudou"; `symbols.json`/`.tsv` incluem `{mtime,size}` (correção B1 — senão a defasagem fica presa para sempre). Mecanismo: flag `--if-changed` só na chamada de `update`, nunca em `build`.
- **DD-06 — Integridade referencial com dois veredictos opostos** → arquivo referenciado ausente de `graph.json` = órfão = reprova `validate`; `{mtime,size}` divergente (arquivo ainda existe) = staleness cosmética = nunca reprova `validate` (só aparece no sufixo de `query`). Qualquer story de validação deve manter essa distinção.
- **DD-07 — Degradação graciosa concentrada num único wrapper (`readSymbolsSafely()`)** → JSON corrompido é o único caso que emite `WARN`; ENOENT e entrada legada são tratados por símbolo individual, sem afetar os demais resultados.
- **DD-08 — Red-first tratando QUALQUER caminho sob `template/.forge/scripts/` como infraestrutura (`isInfraPath`)** → vale para módulos novos E módulos já existentes editados por este change. Commit vermelho nunca toca arquivo de produção, só teste em `tests/`; falha comportamental via `import()` dinâmico + `assert.fail` (módulo ausente) ou checagem `typeof` (export ausente em módulo existente) — nunca "stub neutro de produção".
- **DD-09 — Guard de CLI via `realpathSync` dos dois lados, nunca `import.meta.url === file://...`** → esse padrão quebra em `/tmp` symlinkado no macOS (mesmo padrão de `kb-cli.mjs`/`sync-adapters.mjs`).

## Contratos externos

- `symbols.json` — schema **continua `symbols/v0`**, nunca `v1`; campos aditivos `{id,file,name,type,line,layer,mtime,size}`; `edges{from,to,kind:'inherits',resolved}` preservado (consumido por `lib/mdl-gen.mjs:119`).
- `symbols.idx.tsv` — novo, projeção exata de `symbols.json`, mesmo comparador `localeCompare('en')`+numérico; par atômico com `symbols.json` (nunca um regrava sem o outro).
- `graph.sh query <termo> [--json]` — `nodes`/`edges` byte a byte iguais a hoje; seção nova `symbols (N):`; `--json` com `{nodes,edges,symbols,hint?}`, cada símbolo `{id,name,type,file,line,layer,stale,missing?}`.
- `graph.json` — schema `additionalProperties:false`, **inalterado**, golden byte a byte (w141 [2]).
- Strings literais `'zero tokens'`/`'structural change'` grepadas por `tests/w41-graph-gate.sh` — permanecem exatamente iguais.
- `installer/gitignore.patch` / `.gitignore` — ganham `symbols.json`(já presente)/`symbols.idx.tsv`(novo); artefatos não versionados.
- Frase canônica de fiação (verbatim, grepada por teste): "busca por nome de símbolo (classe/função) com arquivo:linha, não só por caminho de arquivo" — em `query.md` (corpo+`description:`), `lsp-impact-analysis.md`, `implement.md`, `README.md`.

## ADRs

- ADR-0001 (`graph-engine`, accepted) — engine do grafo é subset local nativo zero-dep; tree-sitter WASM é evolução sancionada mas condicionada a um gatilho estreito ("linguagem cuja resolução import→arquivo dependa de AST"), que nenhuma limitação aceita nesta fatia dispara. Zero-dep é inegociável — toda a correção é regex/lexer artesanal, nunca AST.

## Rules

- `rules/testing/regression-red-first.md` — protocolo Red-first; toda a bateria w344/w345 segue este protocolo, com a leitura ampliada de `isInfraPath` (DD-08).
- `rules/testing/property-based-testing.md` — base de w345 (P1-P6).
- `rules/conventions/lsp-impact-analysis.md` — é o próprio alvo do REQ-09 (a rule que instrui o agente a usar `query`, corrigida por este change, não só consultada).
- `rules/conventions/git-worktree.md` — convenção de worktree desta sessão.
- `rules/conventions/no-ai-attribution.md` — commits desta implementação, sem coautoria de IA.

## Invariantes críticas

- `graph.json` nunca muda de schema nem de conteúdo byte a byte (golden w141 [2]) — nenhuma story pode tocar isso.
- `symbols.json` nunca vira `symbols/v1` — só campos aditivos.
- Nó shell no grafo de arquivos nunca gera `edge` a partir de símbolo (`tests/w165` [3]) — símbolos shell só entram em `symbols.json`.
- `stripComments` original de `graph-build.mjs` (índice JVM, w141/graph-jvm-gate) permanece intocada — a nova função `stripCommentsPreservingLines` é separada, nunca substitui a antiga.
- `resolveInheritance`/`rankSymbols`/`tieBreak` são funções puras, nunca fecham sobre a ordem do walk do sistema de arquivos (`readdirSync` não é estável) — herança e desempate sempre operam sobre array já materializado.
- `{mtime,size}` entra na comparação de "mudou" de `update` **só** para `symbols.json`/`.tsv`, nunca para `graph.json` (que ignora `generated_at`/`root`).
- `graph.sh symbols` standalone nunca escreve `graph.json`/`fingerprints.json`/`report.md` como efeito colateral.
- `graph.sh query` nunca escreve em disco — é operação de leitura pura, inclusive nos casos de degradação (REQ-10), sempre `exit 0`.
- Toda extração de `.go` produz `symbols: []` nesta fatia (decisão explícita — `DECL.go` é change futuro, não é regressão).
- Toda story sob `template/.forge/scripts/` segue Red-first via `isInfraPath` (DD-08) — commit vermelho só em `tests/`, nunca diff de produção.
