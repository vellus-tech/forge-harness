---
description: Bootstrap de novo projeto — delega ao Forge (/forge:init via installer/install.sh do forge-harness no tag de release), instalando o harness .forge/ + adapters do tool ativo (Claude por default). Mantém a UX antiga como fachada (metadados, relatório).
argument-hint: "[--adapters claude,codex,...] [--force]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /init-project — Bootstrap de novo projeto (delegação ao Forge)

> **v0.1.0 — delegação.** Este comando agora **delega ao Forge Project Harness**. Em vez de copiar
> o antigo template `.claude/`, ele roda o installer do Forge a partir do clone canônico no tag de
> release. O resultado é o harness `.forge/` (fonte única) + adapters gerados para o(s) tool(s)
> ativo(s) — `AGENTS.md` (raiz, padrão da indústria) + `CLAUDE.md`/`QWEN.md`/… como projeções.

## Constantes

```bash
FORGE_REPO="$HOME/Documents/projects/forge-harness"   # clone canônico
FORGE_TAG="v0.1.0"                                      # release congelado
```

Se `FORGE_REPO` não existir → abortar com instrução de cloná-lo. Se o tag `FORGE_TAG` não existir
nesse clone → abortar (release não cortado).

## Flags

- `--adapters <lista>` — conjunto de adapters a ativar (default: `claude`). Ex.: `claude,codex,qwen`.
- `--force` — se já houver `.forge/` no alvo, faz backup (`.forge.bak-N`) e reinstala (via installer).

## Fluxo

### 1. Inspeção

```bash
test -d "$PWD/.git" && echo "git: yes" || echo "git: no"
test -d "$PWD/.forge" && echo ".forge: exists" || echo ".forge: missing"
test -d "$FORGE_REPO" && git -C "$FORGE_REPO" rev-parse "$FORGE_TAG" >/dev/null 2>&1 \
  && echo "forge: ok ($FORGE_TAG)" || echo "forge: MISSING tag/repo"
```

Se `.forge: exists` e sem `--force` → perguntar (abortar / `--force` com backup). Não prosseguir sem resposta.

### 2. Coleta de metadados (fachada preservada)

Perguntar (com defaults):
1. **Nome (display)** — default `basename "$PWD"`.
2. **Slug (kebab-case)** — default `basename "$PWD" | tr '[:upper:] ' '[:lower:]-'`.
3. **Descrição em 1 linha** — sem default. Não inventar.

### 3. Delegação ao installer do Forge

```bash
git -C "$FORGE_REPO" checkout --quiet "$FORGE_TAG"
bash "$FORGE_REPO/installer/install.sh" \
  --target "$PWD" --slug "$SLUG" --name "$NAME" --desc "$DESC" \
  ${FORCE:+--force}
# adapters além do claude (default):
[ -n "$ADAPTERS" ] && bash "$PWD/.forge/scripts/sync-adapters.sh" --set "$ADAPTERS" >/dev/null
```

O installer já faz: preenchimento de placeholders (a partir de slug/name/desc), `AGENTS.md` +
symlink `CLAUDE.md`→`AGENTS.md`, geração dos adapters ativos, patch de `.gitignore`, CI, e wiring
do hook `enforce-worktree-location`. **Não** há passos manuais de sed/placeholder — o Forge é a fonte.

### 4. Escaneio do repo + runtime

```bash
bash "$PWD/.forge/scripts/doctor.sh"   # detecta stack e diagnósticos (só reporta)
```

Preencher `FORGE.md > runtime` (test/typecheck/lint) quando a stack for detectada — o installer
deixa vazio em repo sem código (ver achado F2 dos pilotos).

### 5. Relatório no chat

```
✔ .forge/    instalado (fonte única) a partir de forge-harness@v0.1.0
✔ AGENTS.md  + CLAUDE.md → AGENTS.md (symlink); adapters ativos: <lista>
i  Pipeline SDD: /forge:spec → requirements → design → tasks → implement → verify → archive
i  Camada Quality (eval/meta) é opt-in: quality.evals_enabled em FORGE.md
i  Rode `bash .forge/scripts/doctor.sh` e preencha runtime no FORGE.md se houver stack
i  Próximo: revise AGENTS.md/FORGE.md, commit `feat(baseline): bootstrap via Forge`
```

### 6. NÃO commitar

Apenas `git status --short`. Commit fica para o usuário.

## Proibições

- Sobrescrever `.forge/` sem `--force`.
- Inventar nome/descrição/stack.
- Editar arquivos sob `.forge/` machinery à mão — a fonte é o template do Forge; mudanças vêm por
  atualização do harness (ver `docs/release/sync-policy.md`).
- Co-autoria de IA em commits sugeridos.

## Compatibilidade

O template antigo `~/.claude/templates/project-bootstrap/` permanece arquivado como referência
(snapshot congelado em `forge-harness/snapshot/project-bootstrap/`). Projetos já bootstrapados pelo
fluxo antigo continuam funcionando; novos projetos passam a usar o Forge.
