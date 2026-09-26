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

## Divergências deliberadas de maquinaria (issues #101/#131)

Maquinaria fora de `ENRICHABLE_DIRS` (`scripts/`, `hooks/`, `commands/` e qualquer outro caminho
que não esteja em `agents/rules/skills/templates` — capabilities, contracts, schemas,
`adapters/*.yaml`, `README.md`) — o overlay sempre a sobrescreve quando diverge do template, com
ou sem `machinery.lock`. Um conserto local nesses caminhos sobrevive ao próximo `update` só se
estiver declarado em `.forge/machinery-exceptions.txt`, uma linha por arquivo:

```
<sha256 do TEMPLATE no momento da declaração>  <caminho relativo a .forge/>  # razão
```

O caminho aceita prefixo `./` ou `.forge/` (normalizado antes de casar contra o template, e a
grafia original é nomeada no relatório); duas declarações que normalizam para o mesmo caminho
contam como duplicata. Um token extra na linha DEPOIS de `<sha> <caminho>`, sem `#`, vira parte da
razão em vez de malformar a linha (alinhado ao `read -r sha path _` do parser de origem); token
extra ANTES de um `#` explícito continua malformado. O sha é sempre o do TEMPLATE (nunca o do
disco) e casa por PREFIXO: um sha truncado (>= 32 dígitos, como o parser já aceita) que seja
prefixo exato do sha atual do template é **vivo**, não expirado. Se o template mudar o
arquivo de novo, a declaração **expira** — o `update` preserva o arquivo mesmo assim e nomeia os
dois shas para reexame, em vez de bloquear (parar seria mudar a fronteira publicada do comando).
O `--dry-run` usa a MESMA classificação que a aplicação real: a prévia nunca anuncia sobrescrita
(`~ caminho`) de um arquivo que uma exceção viva ou expirada preserva, nem remoção (`- caminho
(órfão ...)`) de um tombstone que uma exceção barra — os dois aparecem como `= caminho (preservado
— ...)` / `= caminho (tombstone pulado — exceção declarada)` também na prévia.

O relatório do `update` nomeia cada exceção viva (`PRESERVADO (exceção declarada)`), cada
expirada (`EXCEÇÃO EXPIRADA`, com os dois shas) e cada ociosa (`EXCEÇÃO OCIOSA` — caminho fora do
template, já idêntico a ele, enriquecível ou ainda não instalado nesta árvore). Um caminho que o
template **removeu** (tombstone) e que tem exceção declarada não é apagado pela poda de órfãos —
aparece uma única vez, como `tombstone pulado — exceção declarada`, nunca duplicado como
`EXCEÇÃO OCIOSA`. O orphan-check defensivo que reprova o `update` quando sobra um placeholder
`<PROJECT_*>` num `.md`/`.yml` de maquinaria isenta também o caminho preservado por exceção viva ou
expirada: é conteúdo do consumidor, não do template, e não deve derrubar o comando por escolha
alheia.

Toda sobrescrita de maquinaria própria sem exceção declarada é nomeada sempre, sob dois rótulos
distintos: `SOBRESCRITO (não declarado)` quando o hash local diverge do `machinery.lock` da
última aplicação (edição local de verdade), com o caminho do backup onde o conteúdo anterior
sobrevive; e `ATUALIZADO` quando o hash local bate com o lock (o consumidor nunca tocou o
arquivo — foi só o template que evoluiu), para que a única sobrescrita local real não se perca em
meio a dezenas de refreshes rotineiros. Arquivo ilegível, linha malformada ou caminho declarado
duas vezes param o update **antes** de escrever qualquer coisa (inclusive o `--dry-run`), nomeando
a linha.

`scripts/` **não** ganha preservação automática por deriva — só a declaração explícita preserva.
Ao consertar ou reconciliar um arquivo, remova a linha dele: exceção que não cobre mais nada
absolve em silêncio uma divergência futura que ninguém examinou.

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
