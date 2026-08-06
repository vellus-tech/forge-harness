# Requirements — route-scan-multifile-mounts

> Dois layouts dominantes resolviam zero rotas no oráculo de rota entregue na 0.4.0 — por conservadorismo correto, mas com custo total de cobertura. Este change os cobre sem afrouxar nenhuma recusa.

## REQ-01 — Mount cross-arquivo em Express

- **Quando** um router é definido num arquivo e montado noutro (`app.use('/api/x', require('./routes/x'))`), **o sistema deve** compor o prefixo do mount com o path da rota.
- **Critérios de aceite:**
  - [ ] O import/require do símbolo montado resolve para um arquivo lido, tentando extensão explícita, implícita e `index`.
  - [ ] Router que nenhum arquivo monta continua sem emitir rota e é reportado.
  - [ ] Mount cujo especificador não resolve para arquivo lido vira `router-mount-unresolved-import`.
- **Rastreia:** LDG-0019 (2)

## REQ-02 — Montagem múltipla é união

- **Quando** o mesmo router é montado em dois prefixos, **o sistema deve** emitir as duas rotas.
- **Critérios de aceite:**
  - [ ] `app.use('/v1/x', r)` + `app.use('/v2/x', r)` produz as duas.
  - [ ] Vale também para montagem local, não só cross-arquivo.
- **Notas:** oposto do produtor .NET homônimo — lá N definições disputam UMA invocação e escolher inventaria; aqui as duas montagens existem em runtime.

## REQ-03 — Router reconhecido pela atribuição

- **Quando** um símbolo recebe `Router()`, `express.Router()` ou `require('express').Router()`, **o sistema deve** tratá-lo como router independentemente do nome.
- **Critérios de aceite:**
  - [ ] `const r = Router()` e `const r = require('express').Router()` são reconhecidos.
  - [ ] A heurística de nome anterior continua valendo como sinal adicional.
- **Rastreia:** LDG-0019 (2)

## REQ-04 — Desambiguação por using/namespace em .NET

- **Quando** um produtor homônimo é invocado, **o sistema deve** restringir as candidatas às visíveis no arquivo que invoca (`using`, namespace próprio, `global using`).
- **Critérios de aceite:**
  - [ ] Host que importa uma feature resolve para a definição dela.
  - [ ] Host que importa duas features homônimas continua reportando `producer-ambiguous` e não emite nenhuma.
  - [ ] A ambiguidade é julgada por chamada, não por nome global.
  - [ ] Filtro que não deixa candidata alguma devolve a lista original — o scanner não sabe menos do que sabia.
- **Rastreia:** LDG-0019 (1)

## REQ-05 — Nenhum receptor some calado

- **Quando** uma chamada `x.get('/literal')` aparece num arquivo que usa o framework e `x` não é classificável, **o sistema deve** reportar `route-receiver-unknown`.
- **Critérios de aceite:**
  - [ ] Zero rotas com zero irresolúveis deixa de ser possível nesse arranjo.
  - [ ] Arquivo sem framework (cliente HTTP com `axios.get`) não vira ruído.
- **Rastreia:** achado na medição deste change

## Requisitos não funcionais

- **NFR-01 —** Nenhuma recusa existente é afrouxada: path parcial segue não sendo emitido, interpolação segue recusada, ambiguidade real segue reportada.
- **NFR-02 —** Zero-dep e determinístico.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-01..05 | — (motor interno, sem parâmetro exposto) | biblioteca `lib/route-scan.mjs` consumida por `SUR-01`/`SUR-02` | TASK-01..04 |

## Fora de escopo

- Resolver alias de `using` e `ImplicitUsings` do .csproj.
- Mount por variável computada ou array de rotas.
