# Verification — tasks-meta-required

- **Commit sob verificação:** `1915213` (branch `develop`)
- **Verificado em:** 2026-08-03
- **Veredito global: PASS.** `npm test` → **PASS=73 FAIL=0 SKIP=0** (300s).

## Tabela item-a-item (bugfix.md)

| Item | Veredito | Evidência |
|---|---|---|
| §1 — plano sem metadados atravessa TSK-01/02/03 | PASS | `w130[16]` caso (a) falhava com "esperava 1 achado TSK-06, veio []"; Red observado pelo motor (`ancestry`, base `5510749`, o commit do teste em vermelho). |
| §2 — omissão sistemática bloqueia | PASS | `tasks-graph.mjs:checkTasksGraph` emite `TSK-06` com `enforceable: true` quando `semMeta.length === tasks.length` e há mais de uma task; a mensagem nomeia TSK-01, TSK-02 e TSK-03 como os checks que passaram por vacuidade (asserido no caso (a)). |
| §2 — omissão pontual avisa | PASS | `enforceable: false` nomeando as tasks sem bloco — caso (b). Confirmado em artefato real: `validate-spec create-forge-project-harness` passou a emitir `WARN (TSK-06 … 11 de 30 task(s) sem bloco …)`. |
| §2 — `depende: —` não é omissão | PASS | Predicado é `hasMeta` (a linha declarou algum campo?), não `dependsOn.length`. Caso (c) cobre `depende: —` e `depende: nenhuma`. |
| §2 — mensagem diz o que não foi verificado | PASS | Caso (a) assere a presença dos três códigos na mensagem. |
| §3 — TSK-01..05 inalterados | PASS | `w130[3]`–`w130[6]`, `w130[8]` (PBT do TSK-03) e o bloco de TSK-05 em `w130[12]` seguem verdes; caso (e) confirma que `TSK-01` continua acusando dependência pendurada quando há metadados. |
| §3 — robustez de reconhecimento de campo | PASS | `w130[12]` (oito variações de escrita + três formas de cabeçalho de wave) verde. |
| §3 — plano de uma task não dispara | PASS | Caso (d). |
| §3 — SRF-00/01/02 inalterados | PASS | `w130[13]`, `w130[14]`, `w130[15]` verdes; `validate-spec` do change antigo segue emitindo o mesmo `WARN SRF-02` de antes. |

## Efeito medido em artefato real

`create-forge-project-harness` (o plano que motivou o `LDG-0011`): 30 tasks, **19 com bloco de
metadados e 19 arestas declaradas**, 11 sem bloco (todas da Wave 1), 7 waves. Passou a emitir o
`TSK-06` não-bloqueante nomeando as 11. O change novo (`tasks-meta-required`), com os quatro blocos
declarados, valida sem nenhum achado de `TSK-06`.

## Correção de premissa do ledger

O `LDG-0011` afirma "30 tasks e ZERO arestas declaradas". A medição acima mostra 19 arestas — o
número do ledger descreve o estado anterior à correção que fez o parser reconhecer campo por nome
em qualquer ordem. O defeito estrutural que o item aponta continua real e é o que este change fecha;
o exemplo é que envelheceu. Registrado no `bugfix.md §1` e a ser corrigido no próprio item ao
resolvê-lo.

## Comandos executados

- `npm test` → PASS=73 FAIL=0 SKIP=0
- `bash tests/w130-tasks-graph-gate.sh` → PASS (16 casos)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/red-evidence.sh replay tasks-meta-required` → Red observado (ancestry, base 5510749)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/validate-spec.sh tasks-meta-required` → OK
- `bash tests/plugin-sync-gate.sh` → PASS (documentação do TSK-06 no comando + plugin regenerado)
