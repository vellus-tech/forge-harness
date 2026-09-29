# Revisão do grafo — validador-embarque

## Status: NÃO CONFIÁVEL

O grafo não deve ser usado como pré-flight do `/forge:impact` em `internal/tarifa/tarifa.go`. Ele deixa de conectar as duas dependências reais desse arquivo e, por isso, o `/forge:impact` reporta hoje só o próprio arquivo como impactado — um falso negativo direto sobre o ponto que você quer mudar.

## O que a checagem encontrou

`graph.sh validate` retornou OK com um aviso de órfão em `internal/tarifa/tarifa.go`, mas o aviso está subdimensionado: o problema não é um nó isolado, é a resolução de import do extrator nativo para Go. Os nove edges do grafo (`.forge/graph/graph.json`) estão **todos** marcados `resolved: false`, incluindo os que apontam para pacotes internos do próprio módulo (`github.com/axis-mobfintech/validador-embarque/internal/...`). O extrator zero-dep não faz o join entre o caminho de import estilo Go-module e o id de nó em disco (`internal/tarifa/tarifa.go`), então toda aresta interna cai como não resolvida e o nó de destino fica sem grau de entrada.

Conferi por grep direto no código-fonte, fora do grafo: `internal/cartao/cartao.go` e `internal/embarque/validar.go` importam `internal/tarifa` e chamam `tarifa.Calcular`. São dependentes reais e diretos de `tarifa.go`. Rodei `impact.sh --files internal/tarifa/tarifa.go` sobre o grafo atual e o resultado foi `1 seed(s) -> 1 impacted` — só o próprio arquivo, sem `cartao.go` nem `validar.go`, e sem a cadeia transitiva até `internal/catraca/catraca.go` e `cmd/validador/main.go`.

## Cobertura e summaries

Cinco nós, uma linguagem (Go), 100% deles sem layer classificado (`unknown` — `codegraph.layers` não está declarado no `FORGE.md` desta fixture) e cinco summaries stale, sem curadoria. Não é o achado principal, mas reforça que o grafo ainda não passou por nenhuma curadoria depois do build.

## Recomendação

Não rode `/forge:impact` em `internal/tarifa/tarifa.go` a partir deste grafo — ele vai te dizer que a mudança de 120 para 90 minutos na janela de integração não afeta mais nada, o que é falso. Antes de confiar no `/forge:impact`, trate a resolução de import Go (module path → node id) como lacuna do extrator nativo, candidata a curadoria/tree-sitter conforme ADR 0001, e nesse meio-tempo valide manualmente os dependentes de `internal/tarifa/tarifa.go` por busca textual — o que já fiz aqui: `internal/cartao/cartao.go` e `internal/embarque/validar.go` chamam `tarifa.Calcular`, e por sua vez `internal/catraca/catraca.go` e `cmd/validador/main.go` dependem de `internal/embarque`. É essa cadeia inteira que sua mudança de janela precisa revisar, não só o arquivo isolado.
