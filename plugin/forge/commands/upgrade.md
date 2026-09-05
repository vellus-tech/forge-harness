---
description: Atualiza o harness Forge deste projeto para a versão mais recente do template (npx forge-harness update) — overlay cirúrgico da maquinaria (commands/agents/hooks/scripts/schemas/rules), preservando specs, baseline e config. Distinto de /forge:update (que atualiza o grafo de código).
argument-hint: "[--no-backup]"
---

# /forge:upgrade — atualiza o harness para a versão nova do template

> Não confundir com `/forge:update` (grafo de código incremental). Este comando atualiza a
> **maquinaria do harness** (`.forge/commands`, `agents`, `hooks`, `scripts`, `schemas`, `rules`,
> `templates`, `adapters/*.yaml`) a partir do pacote `forge-harness`, **preservando** os dados do
> projeto: `specs/`, `product/current/` (baseline), `custom/`, `evals/`, `runners.yaml`,
> `constitution.md`, `context.md`, `FORGE.md`, e todo o `forge.yaml` exceto `harness.template_version`.

## Protocolo

0. **Rode do checkout principal, nunca de um worktree.** A maquinaria é versionada DENTRO da árvore: aplicá-la num worktree escreveria `.forge/**` novo apenas naquela branch, e o tronco mais os demais worktrees ficariam com a versão antiga — recebendo verde de gates que não estão rodando. Pior: `core.hooksPath` vive no `.git/config` **comum**, então um update rodado do worktree reaponta os hooks de todo o repositório para uma árvore que é de uma branch só. O `update` **recusa** rodar dali (sem flag de escape) e informa o caminho do tronco. Confirme antes:

   ```bash
   [ "$(git rev-parse --path-format=absolute --git-common-dir | xargs dirname)" = "$(git rev-parse --show-toplevel)" ] \
     && echo "checkout principal — pode seguir" || echo "worktree — rode do tronco"
   ```

1. **Prévia (dry-run)** — mostre o que mudaria, sem escrever:

   ```bash
   npx forge-harness@latest update --dry-run
   ```

   (Em desenvolvimento do próprio harness, use `node <repo-forge>/bin/forge.mjs update --dry-run
   --target "$(pwd)" --source <repo-forge>/template/.forge`.)

2. **Confirme** com o usuário a lista de mudanças (é uma ação que reescreve arquivos de maquinaria;
   um backup é criado por padrão em `.git/forge-backups/`, fora da árvore de trabalho, salvo `--no-backup`).

3. **Aplique**:

   ```bash
   npx forge-harness@latest update
   ```

   O comando faz: overlay aditivo da maquinaria (nunca deleta), atualiza `template_version`,
   reconcilia adapters ativos (`sync-adapters --adapter all`), garante `core.hooksPath` e o bloco
   managed do `.gitignore`, re-materializa o plugin `/forge:*` (se claude ativo), e roda o `doctor`.

4. **Garanta o `core.hooksPath` absoluto.** O `update` já o grava apontando para `<tronco>/.forge/hooks/git` e migra o valor legado relativo (`.forge/hooks/git`), preservando um `hooksPath` customizado de verdade. Absoluto porque `core.hooksPath` vive no `.git/config` comum e um valor relativo é resolvido por cada worktree contra a própria árvore, que carrega a cópia antiga dos hooks. Confirme no fim:

   ```bash
   git config --get core.hooksPath   # tem de ser caminho absoluto, terminando em /.forge/hooks/git
   ```

5. **Meça a propagação para os worktrees existentes.** O `doctor` (que o `update` roda no fim) lista, por worktree linkado, quantos arquivos de maquinaria divergem do tronco e quantos commits aquele worktree está à frente. Use a tabela para decidir: sincronize primeiro os que estão com **zero commits à frente** (rebase/merge do tronco é trivial ali) e escale os que estão muito à frente ou em `HEAD` destacado, onde a sincronização é decisão de quem tem o contexto da branch.

6. **Resuma** o resultado: o que foi atualizado, o que foi preservado (specs/baseline), o estado do `core.hooksPath`, a divergência dos worktrees e o backup.
   O backup fica em `.git/forge-backups/` e não precisa ser removido para rodar gates: fora da árvore, ele não é varrido por `--path` nem aparece em `git status`. Antes ele vivia em `.forge.bak-N` e era varrido pelos próprios gates, bloqueando o primeiro push após o upgrade por conteúdo que era cópia do repositório (issue #76).

## Regras

- **Nunca** rode este comando de dentro de um worktree linkado — ele recusa, e a recusa não tem flag
  de escape (rule `conventions/machinery-propagation.md`).
- **Maquinaria versionada na árvore não se propaga sozinha.** Atualizar o tronco não atualiza nenhum
  worktree ativo; um gate aprovado no tronco não protege onde o trabalho acontece até a branch
  daquele worktree receber o merge.
- **Nunca** use `init --force` para atualizar — ele move o `.forge/` inteiro para backup e reinstala
  do zero. `update` é o caminho que preserva o trabalho de produto.
- Órfãos (arquivos que o template removeu entre versões) **não** são deletados pelo overlay aditivo —
  ficam inertes. Remoção segura de órfãos depende de manifesto de versão (evolução futura).
- Customização de rule deve viver em `custom/rules/**` (override oficial), **nunca** editando
  `rules/*` in-place — senão o `update` sobrescreve a edição (o backup cobre, mas evite o atrito).
