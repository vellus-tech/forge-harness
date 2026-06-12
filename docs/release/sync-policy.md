# Política de sync: workspace → template global (v0.1.0)

Como propagar atualizações do harness para projetos e para o `/init-project` global.

## Fontes

- **Fonte de verdade do harness:** `forge-harness/template/.forge/` (este repo).
- **Release congelado:** tag `v0.1.0` — o que o `/init-project` global instala.
- **Snapshot de contrato:** `snapshot/project-bootstrap/` — referência imutável do adapter Claude
  (gate `tests/snapshot/verify-manifest.sh` + `claude-contract.bats` source mode).

## Quando propagar

1. Mudança no `template/.forge/**` entra por wave + gate verde (`tests/run-all.sh` 100%).
2. Merge em `develop` → `main`.
3. **Cortar/mover o tag** de release (`v0.x.y`) no `main` quando a mudança for liberada.
4. O `/init-project` global aponta para o tag — novos projetos recebem a versão liberada.

## Como atualizar um projeto já onboarded

Não há `forge update` ainda (achado **W2-A** dos pilotos). Procedimento manual até existir:

1. Branch + snapshot do estado atual (`git commit -am "wip: pre-update"`).
2. Preservar estado do projeto: `FORGE.md`, `forge.yaml`, `.forge/product/`, `.forge/specs/`,
   `.forge/custom/`, `constitution.md`, `context.md` e rules editadas.
3. Remover a maquinaria (`.forge` machinery, `.claude`, `AGENTS.md`, `CLAUDE.md`, `QWEN.md`).
4. Reinstalar do tag: `installer/install.sh --target <proj> --slug … --name … --desc …`.
5. Re-aplicar os hand-edits de estado e re-`sync-adapters --set <lista>`.
6. `doctor` limpo + `validate-spec` no baseline.

Validado no piloto W8.2 (azim-crm). Um `forge update` que automatize isto é change candidato pós-v0.1.0.

## Guarda

- `tests/snapshot/verify-manifest.sh` → snapshot íntegro.
- `tests/run-all.sh` → suíte 100% antes de mover qualquer tag.
