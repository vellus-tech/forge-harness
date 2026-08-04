# Bugfix — graph-bin-source

## 1. Comportamento atual (incorreto)

`SKIP_DIRS` em `lib/graph-build.mjs:23-24` lista `bin` ao lado de `dist`, `build`, `out` e `obj` — a heurística de saída-de-compilação de .NET e Java. Em projeto Node, `bin/` é o **entrypoint declarado no `package.json`**: código-fonte, não artefato. O diretório inteiro é podado da varredura, o arquivo nunca vira nó, e nada é reportado — o grafo simplesmente não tem o ponto de entrada.

A consequência não fica no `graph.json`: `/forge:impact` calcula alcance transitivo sobre esse grafo (mudança no CLI aparece como não impactando nada), `/forge:onboard` apresenta a arquitetura sem o ponto de entrada, e `/forge:c4` desenha um sistema sem porta de entrada. Nenhum deles avisa, porque para eles o arquivo não existe.

Reprodução: projeto Node com `package.json` declarando `"bin": {"demo": "bin/cli.mjs"}`, `bin/cli.mjs` importando `../src/run.mjs`. Após `graph.sh build`, o grafo tem apenas `src/run.mjs` — o nó `bin/cli.mjs` e a aresta para `src/run.mjs` estão ausentes (`w41[10]`).

Achado ao rodar `/forge:codegraph` neste repositório (2026-08-03), onde o grafo saiu com 19 nós, 16 deles fixtures de teste. Aqui o efeito soma-se ao de `.forge/` também ser pulado (`LDG-0027`, específico do repo que produz o template), mas o defeito do `bin/` atinge qualquer projeto Node que instale o harness.

## 2. Comportamento esperado

- `bin/` é **percorrido** como qualquer diretório de código: o filtro de extensão (`LANG`) decide o que vira nó, como já decide em `src/`, `lib/` e `tools/`.
- Subdiretório de saída de compilação **dentro** de `bin/` continua podado: `bin/Debug`, `bin/Release`, `bin/x64`, `bin/x86`, `bin/AnyCPU`, `bin/net8.0` e afins. É onde .NET despeja o resultado do build — inclusive `.cs` gerado, que casa `LANG` e poluiria o grafo.
- `dist/`, `build/`, `out/`, `obj/` e o resto de `SKIP_DIRS` seguem intocados.

## 3. Comportamento que deve permanecer inalterado

- Todo o resto de `SKIP_DIRS`, o mapa `LANG`, o `CENSUS_EXT` e o `SKIP_FILE` de minificados.
- Determinismo do build e estabilidade do fingerprint estrutural (`w41[3]`, `w41[4]`, `w41[5]`) — um nó novo muda o grafo, mas não pode mudar o fingerprint de nó nenhum.
- `roles`/`governance` por glob (`w41[8]`, `w41[9]`), validação de schema e integridade referencial (`w41[1]`, `w41[2]`, `w41[6]`).

## 4. Root cause

`SKIP_DIRS` é um conjunto de **nomes**, comparado contra `e.name` sem contexto: o mesmo nome significa coisas diferentes em ecossistemas diferentes, e `bin` é o caso em que os dois significados coexistem. A lista foi escrita a partir do que polui o grafo em .NET/Java (onde `bin/` tem `.dll`, `.exe`, `.class`) sem considerar que em Node o mesmo nome é convenção de entrypoint — e nada no código registra a ambiguidade. Não foi detectado antes porque o fixture do `w41` é TS multi-camada mais C#, sem nenhum projeto Node com `bin/`: a exclusão nunca teve um caso que a contradissesse.

## 5. Testes de regressão

- [ ] Teste que reproduz o bug: projeto Node com `bin/cli.mjs` declarado no `package.json` → o nó e a aresta para `src/run.mjs` existem no grafo (hoje: ambos ausentes).
- [ ] Controle: `bin/Debug/net8.0/Generated.cs` **não** entra no grafo.
- [ ] Controles: `dist/` e `obj/` seguem fora.
- [ ] `w41[1]`–`w41[9]` seguem verdes (determinismo, fingerprint, governance, validate).

## 6. Rastreabilidade

`LDG-0026` (P2/MEDIUM), registrado a partir do `/forge:codegraph` deste repositório. Irmão do `LDG-0027`, que trata do caso específico do dogfood e permanece aberto.
