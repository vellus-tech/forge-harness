---
name: readme-generator
description: Deriva entradas de CHANGELOG.md (Keep a Changelog, pt-BR) a partir de Conventional Commits, em modo explícito ou derivado, e valida o resultado com os gates released/preserve/lint. Use quando o `/forge:update-changelog` precisar de uma skill resolvida, ou quando o post-merge delegar a geração do rascunho de changelog.
---

# Readme Generator — motor de CHANGELOG (escopo desta versão)

Fora de escopo nesta versão: geração ou comparação de README.md, e comparação entre branches irmãs (develop/master/main) para recuperar conteúdo perdido. Essas capacidades existem na prova de conceito original (Payments) mas NÃO foram portadas para este template — só a parte de CHANGELOG. Se precisar de README, use outra ferramenta ou escreva à mão; esta skill não tenta.

## O que esta skill faz

Um motor único (`scripts/changelog-engine.mjs`) que escreve entradas em `CHANGELOG.md`, seção `## [Unreleased]`, formato Keep a Changelog, em português. É o mesmo motor usado por dois consumidores: o comando `/forge:update-changelog` (modos explícito e derivado, com gates) e o hook `post-merge` (modo `--merge-range`, sem gates — o hook é informacional).

### Modos do motor

- `--type <t> --description <d>` — explícito: grava uma entrada literal na seção mapeada de `<t>`. Cria `CHANGELOG.md` se não existir, com o cabeçalho padrão Keep a Changelog.
- `--subject "<msg>"` — derivado de um único subject de Conventional Commits (ex.: squash de PR).
- `--path <componente>` — derivado: varre o intervalo de commits do componente e deriva uma ou mais entradas. Sai com `rc=2` se o componente não existir.
- `--merge-range <A..B>` — derivado do merge (usado só pelo hook `post-merge`); NUNCA cria `CHANGELOG.md` ausente — é no-op silencioso nesse caso, e também quando `HEAD` não é merge.

Mapeamento tipo → seção (alinhado a `rules/conventions/conventional-commits.md`): `feat` → Adicionado; `fix`/`perf` → Corrigido. Demais tipos (`refactor`, `revert`, `chore`, `docs`, `style`, `test`, `build`, `ci`) não geram entrada.

Em qualquer modo, se `release-please-config.json` existir no diretório relevante (componente ou raiz), o motor recusa editar o `CHANGELOG.md` — a entrada de release, nesse caso, vem do título do PR, não deste motor.

### Gates (`scripts/gates/`)

Chamados só pelo comando `/forge:update-changelog`, nunca pelo hook (que é informacional e não bloqueia merge):

- `released.mjs <antigo> <novo>` — cada seção `## [X.Y.Z]` do arquivo anterior tem que sair byte a byte idêntica no novo. Uma versão já publicada não pode ser alterada ou removida.
- `preserve.mjs <antigo> <novo>` — nenhum bloco (entrada de lista sob um `### <Seção>`) do arquivo anterior pode desaparecer no novo sem substituto.
- `lint.mjs` — travessão, quebra de linha dentro de parágrafo, acentuação ASCII (`nao` em vez de `não`), placeholder e link quebrado.

## Resolução

Resolvida por `template/.forge/scripts/resolve-skill.sh readme-generator <arquivo...>` — ordem: `FORGE_SKILL_DIR_README_GENERATOR` → `.forge/skills/readme-generator/` do projeto → skill de usuário do adapter ativo. O hook `post-merge` NUNCA usa esse resolvedor — ele resolve só dentro de `.forge/skills/readme-generator/` do próprio projeto (ou do tronco, via `resolve_delegated`), igual a qualquer outro alvo delegado do harness.

## references/

Vazio nesta versão — nenhuma referência específica de consumidor (a referência Payments, com README e comparação de branches irmãs, está fora de escopo nesta versão, como descrito acima).
