# Verification — add-ledger-evidence-aging

## Resultado: APROVADO

- **Verificado em:** 2026-10-30, branch `feat/harness/ledger-evidence-aging`.
- **Suíte completa:** `bash tests/run-all.sh` (3481 s, máquina com load ~50 de outras sessões) — `PASS=181 FAIL=3`. As três falhas foram investigadas: `w145` acusou 17 pipelines `cmd | grep -q` sob `pipefail` no gate novo — defeito real do gate, corrigido no commit da TASK-11 e reverificado isolado (rc 0); `w151` passou em todas as asserções (`PASS w151-heavy-mutex (56 cenário(s))`) e reprovou só porque a árvore rastreada mudou durante a execução — a mudança foi a própria correção do `w145` aplicada pelo orquestrador enquanto a suíte rodava; reexecutado isolado com a árvore parada, rc 0; `w96` reprova por ambiente (`@babel/parser indisponível`: a dependência de desenvolvimento declarada no `package.json` não está no `node_modules` local do checkout principal) e não toca nenhum arquivo deste change. Depois do commit final: `tests/ledger-evidence-aging-gate.sh`, `w145` e `w151` reexecutados isolados, todos rc 0.
- **Gate do change:** `bash tests/ledger-evidence-aging-gate.sh` — `PASS ledger-evidence-aging (all: 39 cenário(s))`, 10 grupos, contador declarados × executados por grupo.
- **Prova de vermelho por task:** `red-evidence.sh task --red <vermelho> --green <verde>` devolveu `OK task` (classificação `behavioral`) para TASK-01 a TASK-09; TASK-10 (só teste) e TASK-11 (documentação e suíte) são declaradas sem par no `tasks.md`. Setup usado na prova: `ln -sfn <checkout principal>/node_modules node_modules` (o worktree efêmero do replay não tem `ajv`, dependência de desenvolvimento que o CI instala).

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 — schema aditivo e compatível | `template/.forge/schemas/ledger.schema.json` (`last_verified`, `evidence` inline com cinco campos e `additionalProperties: false`, `supersedes`, `links.superseded_by`, `superseded` no enum; `required` intocado) | gate `schema-1..4` (ledger real com 133 entradas conforme; 2 válidas e 6 violações reprovadas nominalmente; portas existentes não gravam os campos novos); `w202` verde | VERIFICADO |
| REQ-02 — porta `verify` | `ledger-ops.sh` ramo `verify)` | gate `verify-1`, `verify-3`, `verify-5`, `verify-6`, `verify-7` (carimbo = HEAD, detail intacto em `confirmed`, `CORREÇÃO DE REGISTRO` com prefixo preservado em `changed`, 6 registros em ordem, `last_verified` do último, recusa de `resolved`/`promoted`, aviso do `note --kind measurement`, idade passa a partir do `last_verified`) | VERIFICADO |
| REQ-03 — conteúdo mínimo da evidência | `ledger-ops.sh` `checkEvidence()` + resolução de commit no shell | gate `verify-2` (17 violações recusadas com ledger byte-a-byte intacto, inclusive `..`, caminho absoluto e link simbólico para fora da raiz), `verify-4` (SHA completo, `test::nome`, intervalo, `command` não executado); `mutation-1` | VERIFICADO |
| REQ-04 — supersessão e cadeia | `ledger-ops.sh` (`add --supersedes`, travas em `add`/`update`/`promote`/`resolve`, `show`, sufixos do `list`), `spec-new.sh`, `ledger-render.mjs` | gate `supersede-1..3`, `show-1..2`, `specnew-1`, `closed-2..3` | VERIFICADO |
| REQ-05 — `stale` | `lib/ledger-aging.mjs`, `ledger-ops.sh` ramo `stale)` e `_resolve_stale_days`/`_asof_valid` | gate `stale-1..8` (universo, ordem, fronteira 30/31, precedência do limiar, rc 2, `--strict`, determinismo, HEAD como relógio, `0 de 0`) | VERIFICADO |
| REQ-06 — fiação no ciclo de vida | `ledger-ops.sh` `status`/`list`, `doctor.sh` (dentro do guard de `ledger.json`), `ledger-render.mjs` | gate `wiring-1..5`, `closed-3`; execução real sobre o ledger deste repositório: `LEDGER: 38 ativo(s) ... · 38 sem reverificação há mais de 30d` e `list` marcando `· sem reverificação há 34d` | VERIFICADO |
| REQ-07 — `superseded` encerrado para todo leitor | `ledger-render.mjs`, `ledger-ops.sh` (`note`, `status`), `tools/plan-progress.mjs` | gate `closed-1` (asserção por sítio com guarda de padrão), `closed-2`, `mutation-3` (oráculo fixo); `w202`, `w156` verdes | VERIFICADO |
| REQ-08 — documentação e configuração | `commands/harness/ledger.md`, `commands/harness/resume.md`, rule `ledger-consultation.md` (regra 7), `forge.yaml` (`stale_days: 30` ativo), `forge.schema.json`, usage/help, `plugin/forge/commands/`, `CHANGELOG.md`, `README.md` | gate `docs-1`; `plugin-sync-gate`, `w257`, `w200` verdes | VERIFICADO |
| REQ-09 — gate hermético com mutação | `tests/ledger-evidence-aging-gate.sh` | `mutation-1..3` (controle, mutação, recontrole, `cmp`); retrato do `ledger.json` rastreado antes/depois; gates do ledger `w98`, `w157`, `w193`, `w194`, `w202`, `w203`, `w207`, `w211` verdes | VERIFICADO |
| NFR-01 — zero dependência | `lib/ledger-aging.mjs` só importa `node:fs`/`node:url`; `package.json` sem dependência nova | inspeção do diff | VERIFICADO |
| NFR-02 — sem relógio de parede | `ledger-ops.sh` e `lib/ledger-aging.mjs` | gate `docs-2` e prova de mutação `docs-3` | VERIFICADO |
| NFR-03 — escrita atômica e sem perda | toda porta nova grava por `_write_json`; acréscimos ao `detail` por prefixo preservado | gate `verify-5` (prefixo por `cmp`), `supersede-1` (bloco `SUBSTITUÍDO` exato) | VERIFICADO |

## Checks deterministas

Ver `verification.yaml` (gravado por `spec-verify.sh`) e o log da suíte completa.

## Desvios e observações

- O design §2.4 descrevia a comparação de `last_verified` com `evidence[].at` como lexical; a implementação compara por `Date.parse`, conforme o §8 incorporado no gate `design_reviewed`.
- O universo do envelhecimento é "status fora do conjunto encerrado" (design §8), igual ao `status` e ao renderizador; para ledgers conformes ao enum coincide com `open`/`planned`/`in-progress` do REQ-05.
- A medição do NFR-02 cobre os dois arquivos inteiros (superconjunto do recorte das portas novas).
- `tools/plan-progress.mjs` foi incluído como leitor de status a partir da validação das tasks; não é distribuído a consumidores.

## Follow-ups abertos

- O `red-evidence.sh task` roda o teste num worktree efêmero sem `node_modules`; gate que depende de `ajv` (dependência de desenvolvimento) só prova o vermelho com `--setup-command` ligando o `node_modules` do checkout principal. Vale um idioma oficial (setup padrão ou documentação no `implement.md`) para não depender de quem executa lembrar.
- O `w96` reprova em checkout local sem `@babel/parser` instalado (ambiente, não código); conferir no CI do PR.

- Renomear `tests/ledger-evidence-aging-gate.sh` para o ordinal `wNNN` na hora do merge (critério de nome do REQ-09; convenção do projeto de decidir o ordinal só no merge).
- Reverificar os 38 itens ativos do ledger deste repositório com `ledger-ops.sh verify` (todos aparecem envelhecidos; a reverificação é trabalho de curadoria fora do escopo do change, e o ledger do tronco não é escrito por branch de feature).
