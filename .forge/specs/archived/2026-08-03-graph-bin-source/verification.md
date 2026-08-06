# Verification — graph-bin-source

- **Commit sob verificação:** `afed3db` (branch `develop`)
- **Verificado em:** 2026-08-03
- **Veredito global: PASS.** `npm test` → **PASS=73 FAIL=0 SKIP=0** (254s).

## Tabela item-a-item (bugfix.md)

| Item | Veredito | Evidência |
|---|---|---|
| §1 — entrypoint Node fora do grafo | PASS | `w41[10]` falhava com "bin/cli.mjs (entrypoint declarado no package.json) ficou fora do grafo — nodes: [\"src/run.mjs\"]"; Red observado pelo motor (`ancestry`, base `76161b6`). |
| §2 — `bin/` percorrido, `LANG` decide | PASS | `bin` removido de `SKIP_DIRS`; o nó e a aresta `bin/cli.mjs → src/run.mjs` (resolvida) aparecem no grafo do fixture. |
| §2 — saída de build dentro de `bin/` podada | PASS | `SKIP_UNDER_BIN` casa `Debug|Release|x64|x86|AnyCPU|net*|netstandard|netcoreapp` e só é aplicada quando `basename(dir) === 'bin'`; `bin/Debug/net8.0/Generated.cs` (`.cs`, casa `LANG`) não entra. |
| §2 — resto de `SKIP_DIRS` intocado | PASS | Controles de `dist/` e `obj/` no mesmo caso. |
| §3 — determinismo e fingerprint | PASS | `w41[3]`, `w41[4]`, `w41[5]` verdes — nó novo muda o grafo sem mudar fingerprint de nó existente. |
| §3 — governance, schema, integridade | PASS | `w41[1]`, `w41[2]`, `w41[6]`, `w41[8]`, `w41[9]` verdes. |

## Efeito medido em artefato real

Grafo deste repositório: **19 → 20 nós**, com `bin/forge.mjs` (o CLI publicado no npm) presente pela
primeira vez. Os 107 arquivos de `template/.forge/scripts/**` seguem fora — é o `LDG-0027`, escopo
distinto e ainda aberto.

## Observação (não bloqueante)

O replay exigiu `setup_command: npm ci --no-audit --no-fund`: o `w41` chama
`tools/validate-yaml.mjs`, que importa o pacote `yaml` (devDependency), e o worktree efêmero nasce
sem `node_modules`. Sem o setup, o motor classifica corretamente como "ambiente do worktree
incompleto" e devolve `not-possible` em vez de um Red falso. Custo: duas instalações por replay
(HEAD e base) — exatamente o argumento do `LDG-0004` para mover o replay ao CI.

## Comandos executados

- `npm test` → PASS=73 FAIL=0 SKIP=0
- `bash tests/w41-graph-gate.sh` → OK (10 casos)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/red-evidence.sh replay graph-bin-source` → Red observado (ancestry, base 76161b6)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/graph.sh build` → 20 nodes (era 19)
