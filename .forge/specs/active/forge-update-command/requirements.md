# Requirements — forge-update-command

## REQ-01 — Subcomando `update` no CLI

- **Quando** o usuário roda `npx forge-harness update` (ou `node bin/forge.mjs update`) num projeto com
  `.forge/`, **o sistema deve** atualizar a maquinaria do harness preservando os dados do projeto.
- **Critérios de aceite:**
  - [ ] `.forge/` ausente → falha clara sugerindo `init` (exit 3), nada alterado.
  - [ ] `--target <dir>` e `--source <template>` respeitados (paridade com `init`).
  - [ ] Relatório final lista o que foi atualizado, o que foi preservado, e o backup.
- **Rastreia:** proposal §2.1

## REQ-02 — Overlay aditivo da maquinaria

- **Quando** o `update` roda, **o sistema deve** sobrescrever com o template novo apenas
  `agents/ commands/ hooks/ schemas/ scripts/ skills/ templates/ rules/`, `adapters/*.yaml`
  (nunca `*.lock.yaml`) e o `README.md` do `.forge/`, adicionando arquivos novos e **sem deletar** nada.
- **Critérios de aceite:**
  - [ ] Arquivo de maquinaria alterado no template → atualizado no projeto.
  - [ ] Arquivo extra do projeto em dir de maquinaria (órfão) → **preservado** (não deletado).
  - [ ] `adapters/*.lock.yaml` não sobrescrito pelo overlay (regenerado por sync-adapters).
- **Rastreia:** proposal §2.1

## REQ-03 — Preservação dos dados do projeto

- **Quando** o `update` roda, **o sistema deve** deixar intactos `specs/active`, `specs/archived`,
  `product/current`, `product/published`, `custom/`, `evals/` (conteúdo), `runners.yaml`, `FORGE.md`,
  `constitution.md`, `context.md`.
- **Critérios de aceite:**
  - [ ] Uma spec e um ADR presentes antes do update permanecem **byte-idênticos** depois.
  - [ ] `runners.yaml` com `enabled: true` permanece inalterado.
  - [ ] `constitution.md`/`context.md`/`FORGE.md` inalterados.
- **Rastreia:** proposal §2.1, §3

## REQ-04 — Merge campo-a-campo do `forge.yaml`

- **Quando** o `update` roda, **o sistema deve** atualizar **apenas** `harness.template_version` para a
  versão do pacote, preservando `adapters:` ativos e todas as demais chaves/flags.
- **Critérios de aceite:**
  - [ ] `template_version` = `pkgVersion()` após o update.
  - [ ] `adapters:` (lista ativa) e demais campos idênticos ao anterior.
- **Rastreia:** proposal §2.1

## REQ-05 — Reconciliação de adapters e ambiente

- **Quando** o overlay termina, **o sistema deve** rodar `sync-adapters --adapter all` (preserva a lista
  ativa), garantir o `core.hooksPath .forge/hooks/git`, o bloco managed do `.gitignore`, e (se claude
  ativo e não `--no-plugin`) re-materializar o plugin global.
- **Critérios de aceite:**
  - [ ] `.claude`/`AGENTS.md`/lockfiles regenerados sem drift (doctor limpo).
  - [ ] hooksPath corrigido quando estava errado.
  - [ ] `--no-plugin` pula a instalação do plugin (CI/testes).
- **Rastreia:** proposal §2.1

## REQ-06 — `--dry-run` e backup

- **Quando** o usuário passa `--dry-run`, **o sistema deve** listar os paths que mudariam **sem escrever
  nada** (exit 0). **Quando** aplica de verdade, **o sistema deve** criar `.forge.bak-N` por padrão,
  exceto com `--no-backup`.
- **Critérios de aceite:**
  - [ ] `--dry-run` não altera o disco.
  - [ ] Sem `--no-backup`, `.forge.bak-N` é criado; com `--no-backup`, não.
- **Rastreia:** proposal §2.1

## REQ-07 — Slash `/forge:upgrade`

- **Quando** o usuário roda `/forge:upgrade` no agente, **o sistema deve** disparar o `update` do CLI,
  mostrando o `--dry-run` antes de aplicar. Nome distinto de `/forge:update` (grafo).
- **Critérios de aceite:**
  - [ ] Comando `template/.forge/commands/harness/upgrade.md` com frontmatter válido.
  - [ ] Plugin rebuildado (contagem 50→51) e `plugin-sync-gate` verde.
- **Rastreia:** proposal §2.2

## REQ-08 — Correção do falso-positivo do doctor

- **Quando** o `doctor` varre a fonte canônica, **o sistema deve** excluir `specs/ worktrees/ product/
  evals/ custom/` das checagens de "refs `.claude/`" e de placeholders `<PROJECT_*>`.
- **Critérios de aceite:**
  - [ ] Projeto com spec citando `.claude/` no texto → doctor **não** reporta vazamento.
  - [ ] Projeto com `<PROJECT_ID>` em `worktrees/**` → doctor **não** reporta placeholder órfão.
- **Rastreia:** proposal §2.3

## REQ-09 — Suíte verde e cobertura por tarball

- **Quando** `npm test` roda, **o sistema deve** passar, incluindo um gate unitário do `update` e uma
  seção no `npx-pack-gate` que exercita o **tarball empacotado**.
- **Critérios de aceite:**
  - [ ] `tests/w63-forge-update-gate.sh`: preservação (a–d), órfão preservado (e), dry-run (f), doctor (g).
  - [ ] `tests/npx-pack-gate.sh [6]`: init+update do tarball preserva produto e atualiza maquinaria.
  - [ ] Idempotência: rodar `update` 2× sem mudança de versão é no-op.
- **Rastreia:** proposal §4

## Requisitos não funcionais do change

- **NFR-01 —** Zero-dep: só node builtins no `bin/forge.mjs` (sem novas dependências npm).
- **NFR-02 —** Idempotência: `update` repetido sem mudança de versão não altera o working tree.
- **NFR-03 —** Reversibilidade: toda escrita coberta por `.forge.bak-N` (salvo `--no-backup`) e
  precedível por `--dry-run`.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | subcomando `update`, `--target`, `--source` | CLI | TASK-01 |
| REQ-06 | `--dry-run`, `--no-backup` | CLI | TASK-01 |
| REQ-05 | `--no-plugin` | CLI | TASK-01 |
| REQ-07 | `/forge:upgrade` | slash command | TASK-05 |
| REQ-02/03/04/08/09 | sem parâmetro configurável | — (comportamento interno) | TASK-02/03/07/08 |

## Fora de escopo (reafirmação)

- Manifesto de hash / prune de órfãos (proposal §3).
- Sobrescrita de `runners.yaml`/`FORGE.md`/`constitution.md`/`context.md`.
- Slash com nome `/forge:update` (colide com o comando de grafo).
