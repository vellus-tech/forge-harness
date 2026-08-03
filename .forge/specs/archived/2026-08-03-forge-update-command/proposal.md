# Proposal — forge-update-command

> Change `forge-update-command` (type: `feature`, scale 3) — criado em 2026-07-09 por milton.
> Fluxo dogfood: engine via `FORGE_ROOT=<repo> bash template/.forge/scripts/*.sh`.

## 1. Por quê (problema / motivação)

O harness Forge só sabe **instalar** (`npx forge-harness init`), não **atualizar**. Num projeto que já
tem `.forge/`, a única via para pegar uma versão nova é `init --force`, que **move o `.forge/` inteiro
para backup e reinstala do zero** — destruindo do lugar `specs/`, o baseline `product/current/` e a
config real do `forge.yaml`. O próprio `bin/forge.mjs` (linhas 199-200) já manda "preferir o update
cirúrgico". Nesta linha de trabalho, propaguei o `/forge:handoff` a projetos reais com um script ad-hoc
(`scratchpad/forge-update.sh`) que valida a abordagem; falta transformá-lo num comando distribuído.

## 2. O que muda

1. **Subcomando `npx forge-harness update`** — atualização cirúrgica: overlay aditivo da **maquinaria**
   do harness em `.forge/`, **preservando** os dados do projeto. JS puro no `bin/forge.mjs`.
2. **Slash `/forge:upgrade`** — wrapper que roda o CLI de dentro do agente (nome novo; `/forge:update`
   já existe e atualiza o grafo).
3. **Correção acoplada** do falso-positivo do `doctor` (guard que varre `specs/worktrees/product`).

## 3. O que NÃO muda (fora de escopo)

- `init`/`install-plugin` intactos; `update` é subcomando novo, aditivo.
- Sem manifesto de hash / prune de órfãos (overlay aditivo nunca deleta — evolução futura).
- `FORGE.md`/`constitution.md`/`context.md`/`forge.yaml`(exceto `template_version`)/`runners.yaml` e
  todo `specs/product/custom/evals` **nunca** sobrescritos.
- Sem novo mecanismo de distribuição — usa o tarball npm já existente.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`
- **Paths afetados:** `bin/forge.mjs`, `template/.forge/commands/`, `template/.forge/scripts/doctor.sh`,
  `tests/`, `docs/`, `plugin/forge/`, `README.md`, `CHANGELOG.md`
- **Dependências:** nenhuma
- **Riscos:**
  - `rules/` overlay pode sobrescrever rule-base editada in-place (anti-padrão; `custom/rules/**` é o
    override oficial) — mitigado por backup `.forge.bak-N` + `--dry-run`.
  - Órfãos não removidos (overlay aditivo) — documentado.
  - Regex de `template_version` no `forge.yaml` precisa ser cirúrgica (não tocar `adapters:`/flags).

## 5. Próximos passos

`/forge:requirements` → `/forge:design` → analyze/impact (scale 3) → `/forge:tasks` → implement →
verify → code-review → ship → merge → publish (rc9).
