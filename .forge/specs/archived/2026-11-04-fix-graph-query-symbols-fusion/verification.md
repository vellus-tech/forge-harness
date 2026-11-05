# Verification — fix-graph-query-symbols-fusion

> Change `fix-graph-query-symbols-fusion` (bugfix, scale 2). Verificação determinística e revisão adversarial independente antes do archive.

## 1. Estado do código

- HEAD verificado: `da581189` (branch `fix/graph/query-symbols-fusion`, 0 commits atrás de `develop`).
- Red SDD-level: `evidence/red/red-evidence.json` com `status: observed`, replay por ancestralidade na base `8a8d612`, `replay_head` no HEAD da entrega.
- Nenhum `TODO`/`FIXME` residual nos arquivos do change.

## 2. Checks determinísticos executados

| Check | Comando | Resultado |
|---|---|---|
| Gate do change (w344) | `FORGE_ROOT="$(pwd)" bash tests/w344-graph-query-symbols-gate.sh` | PASS — inclui [1], [2], [3], [4], [4c], [5b], [6a], [6b], [7], [7b], [10a], [10b], [11], [12], [12b], [12c], [14], [15], [15b], [16], [16b], [17a], [17b], [18], [22a], [22b], [23], [24a], [24b], [24c], [28], [32], [32b], [33] e PBTs |
| Gate de PBT (w345) | `FORGE_ROOT="$(pwd)" bash tests/w345-graph-symbols-property-gate.sh` | PASS — P1 a P6 com seed fixa, mais `tt-p2`/`tt-p4` (teste do teste com contraexemplo minimizado) |
| Red-first estático | `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/check-red-first.sh check fix-graph-query-symbols-fusion` | OK — apenas WARN não bloqueante do item 7 (nome do teste não contém palavra-chave do defeito) |
| Red replay | `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/red-evidence.sh replay fix-graph-query-symbols-fusion` | OK — `FAIL [red-task01-processarPedido]` observado na base; verde no HEAD |
| Regressão w151 | `bash tests/w151-heavy-mutex-gate.sh` | PASS após corrigir a herança de `LC_ALL` no controle negativo do T4 |
| Suíte completa | `bash tests/run-all.sh` | registrada no fechamento (ver seção 5) |

## 3. Prova de mutação dos gates novos

Cada gate novo foi provado por mutação real na cópia do worktree, com restauração em seguida:

- `[12c]` falha quando `--if-changed` é removido de `graph.sh update` (a fiação real deixa de honrar a garantia; o `[12]` que chama o módulo direto não pegava).
- `[15b]` falha quando o catch de `graph.json` corrompido volta a sair 0 (regressão de sinalização de erro).
- `[24c]` falha quando o desempate numérico de `line` vira `localeCompare` de string (`9` vs `12`).
- `[4]` e `[17a]` falham quando a instrução `graph.sh build` é removida da mensagem de órfão.

## 4. Cobertura dos REQs

| REQ | Evidência |
|---|---|
| REQ-01/REQ-02 (extrator + lexer) | [0], [8], [8b], [13a], [18], [19], [19c], [19d], [20], [21], [26a], [29], [29b], [29c], [30], [31], [31b], [32], [32b]; corpus completo de 92 `.mjs` e 97 `.sh` |
| REQ-03 (integração no build) | [5a], [5b], [12], [26b]; `symbols.json`/`symbols.idx.tsv` com gitignore |
| REQ-04 (defasagem por `{mtime,size}`) | [7b], [10b], [22a], [22b], [6b] |
| REQ-05 (query por símbolo, ranking e `--json`) | [1], [2], [3], [10a], [24a], [24b], [24c], [23], [cli-symlink] |
| REQ-06 (update honesto) | [5b], [12], [12c], [22b]; cabeçalho do `graph.sh` sem a frase falsa |
| REQ-07 (integridade referencial) | [4], [4c], [17a], [28] |
| REQ-08 (wrapper `symbols` sem side-effect) | [5a], [7], [11] |
| REQ-09 (fiação de doc/rule) | [33]; `build:plugin` verificado por asserção real |
| REQ-10 (degradação graciosa) | [14], [15], [15b], [16], [16b], [17b] |

## 5. Suíte completa

Executada na árvore final (pós-archive) em três shards isolados, como o CI: shard 1 `PASS=85` (82 gates + 3 suítes bats), shard 2 `PASS=82`, shard 3 `PASS=81`; total **248/248**, 0 FAIL, 0 SKIP, 0 UNVERIFIED. `OK — suíte 100% verde`.

## 6. Revisão adversarial independente

O validador independente (contexto novo, sem edição) emitiu FAIL inicial com um BLOCKER de entrega (evidência de Red fora do HEAD) e seis MAJOR de contrato/teste. Todos foram tratados: evidência commitada; `[12c]` cobre a fiação de `--if-changed`; `[7]` restaurado; corpus expandido de 13/8 para 92/97 arquivos com diff regenerado; mensagem de órfão instrui `graph.sh build`; `graph.json` corrompido volta a sair não-zero; `[24c]` cobre o desempate numérico. Os MINOR foram tratados ou registrados: `kb.md` entrou em `affected_paths`, o cabeçalho do `graph.sh` foi corrigido, o aviso de índice ausente alinhou `graph.sh build`, e o `graph.json` do dogfood é regenerado no fechamento.

## 7. Limites conhecidos

- `graph.json` de um repositório consumidor continua sendo entrada essencial: corrupção é FAIL, não degradação. A degradação graciosa vale só para a camada aditiva de símbolos.
- O corpus é um snapshot versionado; regenerá-lo é ato explícito, não parte do gate.
