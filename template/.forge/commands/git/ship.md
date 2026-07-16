---
description: Fluxo completo commit -> PR -> revisao -> merge em develop -> cleanup, num unico comando. Gate humano do §20.4 e satisfeito pela invocacao explicita de /forge:ship.
argument-hint: "[--no-review]"
---

# /forge:ship — commit, PR, revisão e merge num comando

Argumentos: `$ARGUMENTS` (`--no-review` pula o passo de revisão automatizada quando já foi feita manualmente; use com parcimônia).

> **Este comando É o gate humano (§20.4).** O protocolo `/forge:prepare-pr` existe para
> apresentar a descrição do PR e aguardar aprovação explícita porque, historicamente, abrir PR
> era uma ação separada demais para pedir em linguagem natural toda vez. `/forge:ship`
> automatiza a costura entre as etapas — mas cada etapa (commit, abrir PR, merge) só roda
> porque um humano invocou `/forge:ship` de propósito. Não abrevie isso para "sempre rodar ship
> sem pedir" em automações não supervisionadas.
>
> **Na org vellus-tech o alvo é SEMPRE `develop`** — nunca `main` diretamente (§20.1). Se o
> repositório não seguir essa convenção, pare e pergunte antes de prosseguir.

## Pré-checagens

1. **Working tree tem mudanças?** `git status --porcelain`. Vazio → nada a shippar, pare e informe.
2. **Branch atual.** `git branch --show-current`.
   - Se for `develop` ou `main`: **não commite aqui**. Crie uma branch a partir do diff atual:
     - `git diff --stat` para entender o escopo e sugerir um nome `<tipo>/<escopo>/<descricao-kebab>`
       (rule `.forge/rules/conventions/git-worktree.md`).
     - `git checkout -b <branch-sugerida>` (preserva as mudanças não commitadas).
   - Caso contrário, siga na branch atual.
3. **Testes/gates do FORGE.md.** Rode os comandos declarados em `runtime:` (test/typecheck/lint)
   do `.forge/FORGE.md` (ou `AGENTS.md` gerado) mais os gates deterministas relevantes
   (`.forge/scripts/validate-*.sh`, `npm test`/equivalente do stack). **Falha aqui interrompe o
   comando** — corrija antes de continuar; não shippe quebrado.

## Commit(s)

4. Agrupe as mudanças em commits atômicos (Conventional Commits, assunto no imperativo,
   **pt-BR**, **sem trailer de co-autoria de IA** — constitution #8). Se o diff já mistura
   assuntos não relacionados, separe em múltiplos commits por `git add -p`/paths explícitos em
   vez de um commit único genérico.

## Descrição do PR

5. **Reuse o protocolo do `/forge:prepare-pr`** para montar título + corpo: objetivo (2-3
   linhas), o que mudou (bullets), como foi verificado (gates/testes executados no passo 3),
   pendências. Com lifecycle ativo, puxe de `requirements.md`/`tasks.md`/`verification.yaml` do
   change; sem lifecycle, do diff + commits da branch.

## Abrir o PR

6. `git push -u origin <branch>` e:

   ```bash
   gh pr create --base develop --title "<título>" --body "$(cat <<'EOF'
   <corpo montado no passo 5>
   EOF
   )"
   ```

## Revisão

7. Rode a revisão do diff **antes do merge**:
   - Se a skill `code-review` estiver disponível neste ambiente, invoque-a sobre o diff da
     branch (`--effort medium` é o padrão razoável; suba para `high` em mudanças arquiteturais).
   - Sem a skill disponível, aplique o mesmo padrão manualmente (bugs de correção +
     simplificação/reuso), documentando os achados no chat.
8. **Todo achado precisa ser corrigido (ou explicitamente descartado com justificativa) antes do
   merge.** Não faça merge com findings abertos "para depois" — se for genuinamente fora de
   escopo, registre um deferral (`/forge:defer`) em vez de ignorar silenciosamente.
9. Se corrigiu algo no passo 8, commit adicional + `git push` (atualiza o PR automaticamente).

## Merge + cleanup

10. Após revisão limpa, confirme com o usuário em uma linha (a menos que ele já tenha
    pré-aprovado o fluxo completo desta sessão) e então:

    ```bash
    gh pr merge <numero-ou-branch> --squash --delete-branch
    git checkout develop
    git pull
    ```

11. Se havia um worktree dedicado para esta branch (`.forge/worktrees/<...>`), remova-o
    (`git worktree remove ...`) — o hook `post-merge` já tenta isso automaticamente; confirme que
    rodou.

## Fechar o loop de lifecycle (pós-merge)

12. **Se o merge fechou um change SDD**, o status dele não avança sozinho — reconcilie. Rode
    `node .forge/scripts/lib/orphan-changes.mjs .` (determinista, zero-LLM; pule se ausente) e, para
    o change correspondente a esta branch, **ofereça em uma linha** (nunca execute automaticamente —
    a incorporação ao baseline é decisão humana):
    - `verified` → `/forge:archive <id>` (incorpora ao baseline; o gate `human_archive_approval`
      permanece HITL humano — domínio financeiro). O archive roda fim a fim na hora: o
      `spec-delta.yaml` já nasceu autorado na fase verify (§2.5) e o pré-flight auto-recupera
      `impact.json` stale (o merge que acabou de acontecer mudou o grafo — o script re-roda
      `graph update` → `impact --change` sozinho).
    - `implemented` → `/forge:verify` antes do archive.
    - `tasks-ready`/`implementing` com TASKs 100% → `bash .forge/scripts/spec-transition.sh <id>
      implementing` / `... implemented` para destravar, depois `/forge:verify`.

    Não pule etapas da chain do `spec-transition.sh` nem arquive fora do `/forge:archive`. Se o
    change não for mapeável à branch (sem órfão correspondente), não invente — apenas siga.

## Resumo final

Reporte em poucas linhas: branch shippada, número/link do PR, gates que passaram, achados de
revisão corrigidos (se houver), e confirmação de que `develop` está atualizado localmente.

## Regras

- Sem co-autoria de IA em nenhum commit ou PR (título/corpo) — constitution #8.
- Alvo do PR é sempre `develop` (§20.1) — nunca `main`.
- Não pule o passo de testes/gates (3) nem o de revisão (7-8) "para ganhar tempo" — são o que
  torna `/forge:ship` seguro para ser um comando único em vez de um checklist manual.
- `--no-review` só pula o passo 7-8 quando o usuário já revisou manualmente nesta mesma sessão;
  não assuma isso por padrão.

## Modo autônomo (--yolo)

`--yolo` (ou `autonomy.mode: yolo`) delega a decisão de revisão/merge ao agent `yolo-gate` (Opus, effort high), que analisa o diff e decide seguir ou segurar. `ship` **não** é um gate de lifecycle de spec (não há entrada em `approvals.yaml` para ele) — a decisão autônoma é o próprio prosseguir com o merge, não um registro em approvals. Merge para `develop` **é** yolo-able (integração contínua de baixo custo). **`promote_staging` e `deploy_prd` são `irreversible_hard_stops`** — permanecem humanos mesmo em yolo. Achados de revisão ainda precisam ser corrigidos/deferidos antes do merge (yolo não faz merge com finding aberto). Ver `.forge/rules/conventions/autonomy-yolo.md`.
