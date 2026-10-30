# Tasks — add-unified-knowledge-search

> Tasks do change `add-unified-knowledge-search`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha` (e `Setup do teste`, opcional): o Red é provado por execução (`red-evidence.sh task`) e uma task sem os dois campos é marcada `[!]`, não pulada.
> Ordinais de gate (`w284`…`w290`) derivados de `gate-ordinal.sh next` em 2026-10-30; colisão com branch paralela é resolvida por renomeação na hora do merge, nunca por reserva.

## Wave 1 — Fundação lexical (zero-dep)

- [ ] TASK-01 — Corpus: fontes, exclusões e corte em trechos (rastreia: REQ-01, design §2.3; paths: `template/.forge/scripts/lib/kb-corpus.mjs`, `tests/w284-kb-corpus-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w284-kb-corpus-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-02 — Índice lexical: normalização, BM25, entidades, links e serialização determinística (rastreia: REQ-02, REQ-03, design §2.4; paths: `template/.forge/scripts/lib/kb-lexical.mjs`, `tests/w285-kb-lexical-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/w285-kb-lexical-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-03 — Fusão: RRF ponderado e combinação do re-rank como funções puras (rastreia: REQ-03, REQ-07, design §2.5, §2.6; paths: `template/.forge/scripts/lib/kb-fuse.mjs`, `tests/w286-kb-fuse-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w286-kb-fuse-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 2 — CLI e avaliação

- [ ] TASK-04 — `kb.sh` e `kb-cli.mjs`: build, query, status, saída texto e `--json`, neutralização de trecho, reconstrução automática, `--lexical`, erros de uso (rastreia: REQ-02, REQ-04, REQ-08, REQ-10, design §2.2; paths: `template/.forge/scripts/kb.sh`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/w287-kb-cli-gate.sh`; depende: TASK-02, TASK-03)
  - Teste (comando): `bash tests/w287-kb-cli-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-05 — Avaliador `kb.sh eval` e conjunto de avaliação versionado (calibração, holdout, fixture hermética com métricas esperadas à mão) (rastreia: REQ-11, design §2.10; paths: `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/eval/`, `tests/w287-kb-cli-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/w287-kb-cli-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 3 — Camada semântica

- [ ] TASK-06 — Pins do runtime e dos modelos, e devDependencies do workspace nas mesmas versões (rastreia: REQ-05, design §2.6, §2.10; paths: `template/.forge/scripts/lib/kb-pins/`, `package.json`, `package-lock.json`, `tests/w288-kb-semantic-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w288-kb-semantic-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-07 — `kb-semantic.mjs`: carga do runtime, varredura de binário nativo, integridade, embeddings com cache, cross-encoder, degradação; integração no CLI; inferência real com modelos ONNX de fixture (rastreia: REQ-06, REQ-07, REQ-08, design §2.6; paths: `template/.forge/scripts/lib/kb-semantic.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/onnx-fixture.mjs`, `tests/w288-kb-semantic-gate.sh`; depende: TASK-04, TASK-06)
  - Teste (comando): `bash tests/w288-kb-semantic-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-08 — `kb-install.mjs` e `kb.sh semantic install|remove|status` (rastreia: REQ-05, design §2.7; paths: `template/.forge/scripts/lib/kb-install.mjs`, `template/.forge/scripts/kb.sh`, `tests/w289-kb-install-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/w289-kb-install-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 4 — Guardas de rede e zero-dep, superfície

- [ ] TASK-09 — Gates de rede (permissões do Node e interceptador) e estáticos (imports, hosts de LLM, programas do `kb.sh`, instalação só por `semantic install`, zero-dep do caminho lexical) (rastreia: REQ-04, REQ-05, REQ-08, REQ-09, NFR-03, design §2.8; paths: `tests/w290-kb-offline-gate.sh`, `tests/fixtures/kb/no-network.mjs`; depende: TASK-08)
  - Teste (comando): `bash tests/w290-kb-offline-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-10 — Superfície: `/forge:kb`, remissão em `/forge:query`, `.gitignore`/`gitignore.patch`, linha `info` do `doctor.sh`, plugin regenerado, README (rastreia: REQ-10, design §2.9; paths: `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/query.md`, `installer/gitignore.patch`, `.gitignore`, `template/.forge/scripts/doctor.sh`, `plugin/forge/`, `README.md`, `tests/w287-kb-cli-gate.sh`; depende: TASK-08)
  - Teste (comando): `bash tests/w287-kb-cli-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-11 — ADR 0004 "camada opt-in com dependência instalada sob demanda" no baseline (rastreia: design §2.9; paths: `.forge/product/current/adr/0004-opt-in-runtime-layer.md`, `.forge/product/current/adr/README.md`; depende: TASK-08)
  - Teste (comando): `test -f .forge/product/current/adr/0004-opt-in-runtime-layer.md && grep -q 0004 .forge/product/current/adr/README.md`
  - Padrão de falha: `.*`

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-02, TASK-04, TASK-09 |
| REQ-03 | TASK-02, TASK-03 |
| REQ-04 | TASK-04, TASK-09 |
| REQ-05 | TASK-06, TASK-08, TASK-09 |
| REQ-06 | TASK-07 |
| REQ-07 | TASK-03, TASK-07 |
| REQ-08 | TASK-04, TASK-07, TASK-09 |
| REQ-09 | TASK-09 |
| REQ-10 | TASK-04, TASK-10 |
| REQ-11 | TASK-05 |
| NFR-01, NFR-02 | medição no verify (evidence) |
| NFR-03 | TASK-09 |
| design §2.9 (ADR) | TASK-11 |
