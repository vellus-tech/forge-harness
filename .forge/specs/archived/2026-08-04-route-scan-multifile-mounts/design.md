# Design — route-scan-multifile-mounts

## A simetria que faltava

O motor já resolvia composição cross-arquivo para .NET: produtores num índice global, invocações resolvidas na passa 2. Para JS isso não existia — `mounts` era uma variável local de `indexJsHttp`, viva pelo tempo de um arquivo. O conserto é aplicar a mesma forma: a montagem vira fato do índice (`idx.mounts`), a rota sem prefixo local vira pendência (`idx.pendingRoutes`), e a passa 2 cruza as duas.

## Por que união e não ambiguidade

Em .NET, N definições homônimas disputam UMA invocação: escolher inventa. Em Express, montar o mesmo router em dois prefixos faz as duas rotas existirem em runtime: reportar ambiguidade esconderia superfície real. Mesma forma sintática, decisões opostas — e é por isso que `mounts` passou a acumular prefixos por símbolo em vez de guardar o último.

## A premissa que não se sustentou

O `LDG-0019` registrava que desambiguar `MapEndpoints` homônimo "exige resolver namespace/using do C#, que está fora do alcance de um scanner por regex". Testada, a premissa cai para a forma comum: `namespace X;` e `using X;` são linhas regexáveis, e são exatamente o que o compilador usa para resolver. O que fica fora do alcance é o caso avançado — alias (`using O = Acme.Orders;`) e `ImplicitUsings` do `.csproj` —, e esses continuam caindo no veredito conservador.

A ambiguidade passou a ser julgada **por chamada**. Julgar por nome global condenava o host que importa uma feature só junto com o que importa várias.

## O risco do guard de receptor

Reportar todo receptor não classificado transformaria `axios.get('/users')` em irresolúvel — e relatório ruidoso treina a pessoa a ignorá-lo, o que é pior que não reportar. A âncora escolhida é o arquivo falar o dialeto (importa express/fastify/koa, ou declara um router). O caso [52] existe para travar essa fronteira.

## Impacto

`template/.forge/scripts/lib/route-scan.mjs` apenas. Consumidores (`SUR-01`, `SUR-02`, `api-surface.mjs`) não mudam de interface — mudam de cobertura.
