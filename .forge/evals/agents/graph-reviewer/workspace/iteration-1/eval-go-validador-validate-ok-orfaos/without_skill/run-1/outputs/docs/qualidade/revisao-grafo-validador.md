# Revisão do grafo de código — validador-embarque

## Pergunta

Antes de rodar `/forge:impact` em `internal/tarifa/tarifa.go` (mudança planejada: janela de integração de 120 para 90 minutos), o grafo atual é confiável o suficiente, dado que `graph.sh validate` retornou OK com um aviso de nó órfão?

## Veredito

**Não.** O aviso de órfão não é cosmético — ele está sinalizando exatamente que `internal/tarifa/tarifa.go` não tem nenhuma aresta resolvida de entrada, quando na realidade existem dois chamadores diretos no código. Rodar `/forge:impact` sobre esse arquivo agora provavelmente devolve uma lista de impactados vazia ou incompleta, o que é o pior resultado possível: uma análise de impacto que parece ter rodado com sucesso mas esconde os pontos que realmente dependem da função alterada — justamente numa função de tarifação usada na catraca de embarque.

## Evidência

Comando `graph.sh validate` reproduzido neste ambiente:

```
OK graph (5 nodes, 9 edges; 1 warning(s) — 1 orphan node(s) to review — dead code or unresolved imports: internal/tarifa/tarifa.go)
```

O exit code é 0 (sucesso) e a mensagem começa com "OK", o que facilmente passa despercebido como "grafo saudável, só um aviso menor". Mas o próprio texto do aviso já nomeia o arquivo que será alterado.

Inspecionando `graph.json`: das 9 arestas do grafo, **todas as 9 estão com `"resolved": false`** — inclusive as arestas entre pacotes internos do próprio módulo (`internal/cartao` → `internal/tarifa`, `internal/embarque` → `internal/tarifa`, `internal/catraca` → `internal/embarque`, etc.). O campo `to` dessas arestas guarda o caminho de import completo (`github.com/axis-mobfintech/validador-embarque/internal/tarifa`), não o id do nó (`internal/tarifa/tarifa.go`) — ou seja, o engine de grafo não conseguiu casar imports internos do módulo com os nós já catalogados. Isso não é um problema isolado de uma dependência externa (como `zerolog` ou `uuid`, que legitimamente não têm nó); é uma falha sistêmica de resolução dentro do próprio repositório.

Confirmação direta com `graph.sh query tarifa`:

```
nodes (1):
  internal/tarifa/tarifa.go [go/unknown] loc=14
edges (2):
  internal/cartao/cartao.go -> github.com/axis-mobfintech/validador-embarque/internal/tarifa (import unresolved)
  internal/embarque/validar.go -> github.com/axis-mobfintech/validador-embarque/internal/tarifa (import unresolved)
```

E com `graph.sh path`, buscando um caminho resolvido dos dois chamadores até `tarifa.go`:

```
$ graph.sh path internal/cartao/cartao.go internal/tarifa/tarifa.go
NO PATH (no resolved import chain internal/cartao/cartao.go -> internal/tarifa/tarifa.go)

$ graph.sh path internal/embarque/validar.go internal/tarifa/tarifa.go
NO PATH (no resolved import chain internal/embarque/validar.go -> internal/tarifa/tarifa.go)
```

Leitura direta do código confirma os dois chamadores reais, que o grafo não enxerga:

- `internal/embarque/validar.go` chama `tarifa.Calcular(linha, c.UltimoEmbarque, time.Now())` dentro de `Validador.Validar` — o caminho principal de embarque/débito.
- `internal/cartao/cartao.go` importa `tarifa` e referencia `tarifa.Calcular` dentro de `Debitar` (via `_ = tarifa.Calcular`, aparentemente só para reter o import — vale investigar à parte se é código morto ou uso incompleto, mas não é o foco desta revisão de confiabilidade do grafo).

Ou seja: `tarifa.Calcular` tem no mínimo um consumidor de produção certo (`embarque.Validar`, chamado a partir de `catraca.Escutar`, chamado a partir de `main`) e um segundo ponto de referência em `cartao.go`. Nenhum dos dois aparece como aresta resolvida chegando em `tarifa.go`.

## Por que isso importa para o `/forge:impact` planejado

`/forge:impact` depende de arestas resolvidas para caminhar o grafo a partir do arquivo alterado. Com 0 de 9 arestas resolvidas neste projeto, qualquer BFS/traversal a partir de `internal/tarifa/tarifa.go` não encontra os nós que o importam — o comando tende a reportar "sem dependentes" ou uma lista vazia, quando o caso real é: `internal/embarque` e `internal/cartao` dependem diretamente da tarifa, e por transitividade `internal/catraca` e `cmd/validador/main.go` também estão na cadeia até a catraca física que debita o cartão. É exatamente o tipo de mudança (120 → 90 minutos na janela de integração) que altera comportamento observável em produção (tarifa cobrada), e a análise de impacto automatizada não vai capturar os pontos que testar/revisar.

## Recomendação

1. Não seguir para `/forge:impact` neste estado assumindo confiabilidade automática — tratar o resultado dele, se rodado assim mesmo, como piso e não teto: complementar sempre com a leitura manual já feita acima (grep/leitura direta dos `.go` em `internal/`).
2. Investigar a causa raiz da resolução zerada de imports internos no engine de grafo (`graph-build.mjs`) antes de confiar no `/forge:impact` para qualquer mudança neste repositório — o sintoma (9/9 arestas não resolvidas, incluindo import de pacote do próprio módulo) sugere um problema de matching entre o import path do `go.mod` e os ids de nó gerados, não um caso isolado de `tarifa.go`.
3. Até a correção, tratar qualquer aviso de "orphan node" do `graph.sh validate` como bloqueante para decisões de impacto, não como aviso informativo — o exit code 0 e o prefixo "OK" do comando são enganosos nesse ponto.
4. Para a mudança específica de 120 → 90 minutos: os arquivos a revisar manualmente, dado o rastreamento acima, são `internal/tarifa/tarifa.go` (a constante e a lógica), `internal/embarque/validar.go` (chamador direto) e `internal/cartao/cartao.go` (referência a investigar). Testes que cubram a fronteira exata dos 90 minutos (antes/depois do limite) são o item de maior risco, já que é lógica de negócio que debita o cartão do usuário.

## Observação lateral (fora do escopo desta revisão, mas notada)

Em `internal/cartao/cartao.go`, a linha `_ = tarifa.Calcular` dentro de `Debitar` não invoca a função — apenas referencia o símbolo para não deixar o import "não usado". Isso é atípico e vale confirmar com quem escreveu se é resquício de refatoração incompleta (não é a causa do problema de resolução do grafo, que afeta igualmente a aresta legítima vinda de `embarque/validar.go`).
