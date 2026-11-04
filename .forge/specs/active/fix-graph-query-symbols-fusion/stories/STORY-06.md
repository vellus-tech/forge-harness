---
story_id: STORY-06
epic: fix-graph-query-symbols-fusion
title: Documentação/rule e changelog
depends_on: [STORY-05]
status: done
---

# STORY-06 — Documentação/rule e changelog

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Fiar a documentação e as rules que instruem o agente a usar a nova capacidade de busca por símbolo (a reclamação de origem do usuário), sincronizar o espelho `plugin/forge/commands/`, e registrar a mudança de comportamento observável no `CHANGELOG.md` — sem isso, a correção de código não muda o que o agente faz na prática.

## Embedded context

### Requirements

- REQ-09 — fiação de documentação e rule. Frase canônica (verbatim): "busca por nome de símbolo (classe/função) com arquivo:linha, não só por caminho de arquivo" — entra em `template/.forge/commands/graph/query.md` (corpo + `description:` do frontmatter — é o que o agente vê na lista de comandos), `template/.forge/rules/conventions/lsp-impact-analysis.md:56`, `template/.forge/commands/specs/implement.md:51`, `README.md` (linha nova de `graph.sh query`, não edição de linha existente). `graph.sh:7`/`:59` atualizados citando `symbols`. `lsp-impact-analysis.md:54` — ajuste de precisão: a frase atual ("não entende semântica de símbolo... é papel do LSP") contradiz a mudança; corrige para distinguir "localiza declaração por nome" (nova capacidade, limitada) de "resolve tipo/overload/call graph" (continua papel do LSP). `codegraph.md` sincroniza se citar o que `query` devolve. `docs/refer/slash-commands.md:93` — gerado a partir do `description:`, ou editado manualmente se a geração não for automática (a task confirma qual caso vale). `npm run build:plugin` sem diff pendente, verificado por `git diff --exit-code -- plugin/forge/` (asserção real, não `git status --porcelain` que sempre dá `rc=0`).
- REQ-06 (fiação de texto) — `update.md` (linhas 2/16) e descrição da skill `forge:update` perdem as frases falsas que afirmam "nada é reprocessado".

### Design

- design.md §4 (tabela de contratos) — edição de texto, sem contrato de dado; `npm run build:plugin` sincroniza o espelho `plugin/forge/commands/`.
- design.md §5 item 6 — `kb.md:8` desalinhado ("Para código... use `/forge:query`" sem menção a símbolo) — achado de documentação a endereçar nesta task; `plugin/forge/commands/kb.md` entra na lista de paths conferidos (regenerado por `build:plugin` quando `kb.md` do template muda).

### Contratos / interfaces

- Nenhum contrato de dado é tocado — só texto de documentação/rule/skill. O `description:` do frontmatter de `query.md` é o contrato relevante (é o que o agente lê para decidir usar o comando).

### Rules aplicáveis

- `template/.forge/rules/conventions/lsp-impact-analysis.md` — é o próprio alvo desta story (REQ-09), corrigida, não só consultada.

### ADRs

- Não aplicável — mudança de texto, sem decisão arquitetural nova.

## Tasks

- [X] TASK-12 — Fiação de documentação/rule: frase canônica em `query.md` (corpo+`description:`), `lsp-impact-analysis.md` (:54 ajuste de precisão + :56 adição), `implement.md`:51, `README.md`, `graph.sh`:7/:59, `codegraph.md` (se citar), `slash-commands.md`, `kb.md`, `update.md` (remove frases falsas) + descrição da skill `forge:update`; `npm run build:plugin` sem diff pendente (paths: `template/.forge/commands/graph/query.md`, `template/.forge/rules/conventions/lsp-impact-analysis.md`, `template/.forge/commands/specs/implement.md`, `README.md`, `template/.forge/scripts/graph.sh`, `template/.forge/commands/graph/codegraph.md`, `docs/refer/slash-commands.md`, `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/update.md`, `plugin/forge/commands/query.md`, `plugin/forge/commands/update.md`, `plugin/forge/commands/implement.md`, `plugin/forge/commands/codegraph.md`, `plugin/forge/commands/kb.md`; depende: TASK-11). Teste: `bash tests/w344-graph-query-symbols-gate.sh && npm run build:plugin && git diff --exit-code -- plugin/forge/`. Padrão de falha: `^FAIL [33]` (`grep -L` da frase canônica nos 4 arquivos-alvo produz saída não vazia).
- [X] TASK-13 — `CHANGELOG.md` ganha entrada da mudança de comportamento observável; reconciliação final da contagem `scripts/ (N)`/badge `gates-NNN` do `README.md` (paths: `CHANGELOG.md`, `README.md`; depende: TASK-12). Teste: `bash tests/w200-readme-inventory-gate.sh`. Sem par vermelho/verde de comportamento — atualização de prosa + checagem de integridade do estado atual (`scripts/ (181)`/`gates-244` neste ponto, antes do `w345` da STORY-07 levar a `245`).

## Acceptance criteria

- [X] `grep -L "busca por nome de símbolo (classe/função) com arquivo:linha, não só por caminho de arquivo" template/.forge/commands/graph/query.md template/.forge/rules/conventions/lsp-impact-analysis.md template/.forge/commands/specs/implement.md README.md` produz saída vazia.
- [X] `description:` do frontmatter de `query.md` contém a frase canônica.
- [X] `lsp-impact-analysis.md:54` não contradiz mais a capacidade nova (distinção precisa entre "localiza declaração" e "resolve semântica profunda").
- [X] `update.md`/skill `forge:update` não afirmam mais que "nada é reprocessado".
- [X] `npm run build:plugin` roda sem diff pendente (`git diff --exit-code -- plugin/forge/` passa).
- [X] `CHANGELOG.md` registra a mudança de comportamento observável de `graph.sh symbols`/`query`/`update`.
- [X] `tests/w200-readme-inventory-gate.sh` confirma `scripts/ (N)`/badge `gates-NNN` corretos no estado atual.

## Out of scope

- Criação de `tests/w345-graph-symbols-property-gate.sh` e fechamento do Red SDD-level (`status: observed`) — é da STORY-07.
- Qualquer mudança de comportamento de código — esta story é só texto/documentação.
