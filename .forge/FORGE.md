---
forge_version: 1
codegraph:
  include_paths:
    - "template/.forge/**"
---

# FORGE.md — forge-harness (dogfood)

Este repositório PRODUZ o harness Forge — não é um consumidor comum. `template/.forge/` é o
scaffold que `/forge:init` instala em outros projetos: é código-fonte do próprio produto, não
maquinaria instalada. O engine do code graph pula diretórios de nome oculto (`.forge`, …) por
default porque em todo projeto CONSUMIDOR isso é correto (harness instalado ≠ código do
projeto). Aqui é o inverso, e `codegraph.include_paths` é o mecanismo — já existente para
qualquer repositório declarar os próprios caminhos — que resolve a inversão sem uma exceção com
o nome deste projeto embutida no motor (LDG-0027).

O restante deste arquivo é deliberadamente mínimo: este repositório não é (ainda) um consumidor
completo de si mesmo — não há `forge.yaml`/adapters instalados na raiz — e este `FORGE.md`
existe só para carregar o bloco `codegraph:` que o engine já sabe ler.
