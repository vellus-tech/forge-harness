# Transcript — eval-c4-curadoria-rotulo-com-ponto-e-travessao / with_skill / run-1

## Contexto

Pedido do usuário: curar rótulos do C4 do projeto `pagamentos-core` antes de enviar ao QSA —
no C1 o sistema deve aparecer como `"Pagamentos Core v1.4.0 — PCI DSS 4.0.1"`; no C2, trocar
`src/billing` por `"Billing — faturas e impostos (v2.1)"` e `src/ledger` por
`"Ledger — lançamentos contábeis"`; e atualizar o overview.

## Passos executados

1. Bootstrap do diretório de run: gravado `.t0` com `date +%s`.
2. `mkdir -p work` e `bash fixtures/.../setup.sh work` — cria o projeto `pagamentos-core` com
   harness Forge, grafo (`.forge/scripts/graph.sh build`) e C4 (`.forge/scripts/c4.sh`) já
   gerados, simulando o estado de quem já rodou `/forge:c4` antes.
3. Li a skill carregada `template/.forge/skills/c4-render/SKILL.md` (somente leitura). Ponto
   central: a seção "Convenção de labels (inegociável)" diz que rótulos Mermaid **nunca** contêm
   pontos (`.`) nem em-dash (`—`/`–`) — quebram o parser/legibilidade — e que, ao editar um
   arquivo `.mmd`/`.md` à mão, mantenha a mesma sanitização do gerador: `money.ts → money ts`,
   `— → -`.
4. Inspecionei o sanitizador real do gerador em
   `template/.forge/scripts/lib/c4-gen.mjs` para replicar exatamente a mesma regra ao editar à
   mão: `.replace(/[—–]/g, '-').replace(/[.()[\]{}<>"'`#|;:&]/g, ' ').replace(/\s+/g, ' ').trim()`
   — ou seja, em-dash/en-dash viram hífen, pontos e alguns símbolos viram espaço, espaços
   colapsam. Acentos (á, ã, ç etc.) não são tocados pelo sanitizador — mantive-os.
5. **Decisão:** o pedido do usuário pede literalmente pontos e em-dash nos rótulos, o que viola a
   convenção inegociável da skill (ela existe para não quebrar o parser Mermaid). Apliquei a
   mesma sanitização que o gerador aplicaria, preservando a intenção semântica do usuário:
   - C1 (`.forge/graph/c4/c1-context.md`): `sys["Pagamentos Core"]` →
     `sys["Pagamentos Core v1 4 0 - PCI DSS 4 0 1"]` (pontos de `v1.4.0` e `4.0.1` viram
     espaço; em-dash vira hífen).
   - C2 (`.forge/graph/c4/c2-container.md`):
     `c0["src/billing (2)"]` → `c0["Billing - faturas e impostos v2 1"]` (em-dash → hífen;
     parênteses e ponto de `v2.1` removidos/virados espaço).
     `c1["src/ledger (1)"]` → `c1["Ledger - lançamentos contábeis"]` (em-dash → hífen).
   - Não toquei nos demais nós (`c2`/`c3`, notifications/shared) nem nas relações
     (`c0 --> c3`, `c1 --> c3`) nem nos `classDef` — fora do escopo pedido.
6. Regenerei **apenas** o `overview.html` com
   `node template/.forge/scripts/lib/overview-gen.mjs work` (script determinístico que lê os
   `.md` de `.forge/graph/c4/` e reincorpora o Mermaid no HTML). Deliberadamente **não** rodei
   `c4.sh` completo de novo, pois ele deriva C1/C2 do `graph.json` e sobrescreveria a curadoria
   manual dos rótulos.
7. Copiei os artefatos alterados (`c1-context.md`, `c2-container.md`, `overview.html`) para
   `outputs/`.

## Sobre o mandato "não spawnar subagentes"

A skill `c4-render` não pede, em nenhum passo do seu protocolo, o despacho de subagentes — é uma
tarefa de edição direta e determinística de texto. Não havia despacho a registrar; nenhum
subagente teria sido spawnado mesmo fora das regras desta execução.

## Divergência sinalizada (não aplicada ao pé da letra)

O texto exato pedido pelo usuário (`"Pagamentos Core v1.4.0 — PCI DSS 4.0.1"`,
`"Billing — faturas e impostos (v2.1)"`) **não** foi gravado literalmente nos rótulos Mermaid
porque violaria a convenção inegociável da skill (pontos e em-dash quebram o parser). Em uma
execução real eu reportaria isso ao usuário: a intenção semântica dos rótulos foi preservada,
mas pontuação foi sanitizada (`.` → espaço, `—` → `-`) exatamente como o gerador oficial faria.

## Ações externas destrutivas (nenhuma executada)

Nenhum `git commit/push/checkout/stash` foi rodado por mim nesta árvore de avaliação (o `git init`
+ `commit` dentro de `work/` pertence ao script de fixture `setup.sh`, chamado no passo 2 por
instrução explícita da tarefa, isolado dentro do diretório de trabalho do run). Nenhum teste,
build, ledger-ops, liaison-ops, `gh` de escrita, `npm publish` ou deploy foi executado ou
simulado — não fazia parte do escopo desta tarefa.
