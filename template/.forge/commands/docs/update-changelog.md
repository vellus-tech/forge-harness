---
name: update-changelog
description: Atualiza o CHANGELOG.md de um componente ou da raiz, em modo explícito ou derivado de Conventional Commits, seguindo o formato Keep a Changelog em pt-BR.
arguments:
  - name: component
    description: "Caminho relativo do componente (ex: src/Server (atual), src/Domain (atual)); omitido = raiz do repositório"
    required: false
  - name: type
    description: Tipo da mudança (added, changed, deprecated, removed, fixed, security); omitido junto com description entra em modo derivado
    required: false
  - name: description
    description: Descrição da mudança em pt-BR; omitida junto com type entra em modo derivado
    required: false
---

# /forge:update-changelog

Atualiza o `CHANGELOG.md` do componente especificado (ou da raiz, se `component` for omitido), adicionando entrada(s) na seção `[Unreleased]`. Camada fina sobre o motor único da skill `readme-generator` — o mesmo motor que o hook `post-merge` usa para o CHANGELOG raiz (REQ-07: o hook nunca passa por este comando nem por `resolve-skill.sh`, cada um resolve o motor pelo seu próprio mecanismo).

## Modos

- **Explícito** — `type` e `description` informados: grava `- <description>` na seção pt-BR mapeada de `type`.
- **Derivado** — `type`/`description` omitidos: deriva entrada(s) de Conventional Commits, usando `--subject "<título>"` quando a invocação é de um squash merge (ex.: o título do PR), ou `--path <component>` para varrer o intervalo de commits do componente. `--path` apontando para um componente inexistente é erro (rc 2), nunca "nada a registrar" por vacuidade (REQ-08).

## Passos a Executar

1. **Trava de branch protegida (REQ-09)**
   - Antes de qualquer edição, verificar a branch atual (`git branch --show-current`).
   - Se a branch atual for `develop`, `master` ou `main`, parar sem editar nada e informar que o comando não roda em branch protegida.

2. **Resolver o motor (REQ-12)**
   - Chamar `template/.forge/scripts/resolve-skill.sh readme-generator scripts/changelog-engine.mjs` para localizar a skill.
   - Ordem de resolução: `FORGE_SKILL_DIR_README_GENERATOR` → `.forge/skills/readme-generator/` do projeto → skill de usuário do adapter ativo.
   - Se `resolve-skill.sh` sair com `FAIL skill readme-generator ausente` (rc 1), parar e reportar o erro — nunca cair em silêncio no comportamento antigo do comando.

3. **Detecção de `release-please-config.json` (REQ-10)**
   - Verificar se `<component ou raiz>/release-please-config.json` existe.
   - Se existir, parar sem editar `CHANGELOG.md` e apontar o título do PR atual como a fonte correta da entrada de release (quem gera release-please já deriva a entrada dali).

4. **Chamar o motor no modo apropriado**
   - Explícito: `node <skill>/scripts/changelog-engine.mjs --root <component ou raiz> --type <type> --description <description>`.
   - Derivado por subject: `node <skill>/scripts/changelog-engine.mjs --root <component ou raiz> --subject "<título>"`.
   - Derivado por path: `node <skill>/scripts/changelog-engine.mjs --root <raiz> --path <component>`.
   - O motor cria `CHANGELOG.md` com cabeçalho Keep a Changelog padrão quando ausente (REQ-14), nestes dois modos — nunca no modo `--merge-range`, que é exclusivo do hook.

5. **Rodar os 4 gates, nesta ordem, parando no primeiro que falhar (REQ-11)**
   - `node <skill>/scripts/gates/released.mjs <changelog-antigo> <changelog-novo>` — nenhuma seção `## [X.Y.Z]` já publicada pode ter mudado.
   - `node <skill>/scripts/gates/preserve.mjs <changelog-antigo> <changelog-novo>` — nenhum bloco antigo pode ter sido removido sem substituto.
   - `node <skill>/scripts/gates/lint.mjs <changelog-novo>` — travessão, quebra de linha dentro de parágrafo, acentuação, placeholder e link quebrado reprovam.
   - `.forge/scripts/check-ai-attribution.sh text <changelog-novo>` — nenhuma assinatura de IA na entrada gravada.

6. **Nunca commitar**
   - O comando só edita `CHANGELOG.md` e reporta sucesso/falha. Quem decide quando e como comitar é o humano (ou um passo explícito e separado de `/forge:ship`).

## Validações Pós-Execução

- [ ] Comando parou sem editar nada se a branch atual era `develop`/`master`/`main`
- [ ] Comando parou sem editar nada se havia `release-please-config.json` no componente/raiz
- [ ] Entrada adicionada na seção `[Unreleased]` do componente ou raiz correto (quando aplicável)
- [ ] Seção do tipo correto usada (mapeamento pt-BR)
- [ ] Sem alteração em versões já liberadas (gate `released`)
- [ ] Nenhum bloco antigo removido sem substituto (gate `preserve`)
- [ ] Sem travessão, quebra de linha indevida, acentuação ascii, placeholder ou link quebrado (gate `lint`)
- [ ] Sem assinatura de IA na entrada (`check-ai-attribution.sh text`)
- [ ] Formato Keep a Changelog preservado
- [ ] Nenhum `git commit` executado pelo comando
