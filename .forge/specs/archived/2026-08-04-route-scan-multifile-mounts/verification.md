# Verification — route-scan-multifile-mounts

- **Commit sob verificação:** `fa6ffbb` (branch `develop`)
- **Verificado em:** 2026-08-04
- **Veredito global: PASS.** `npm test` → **PASS=74 FAIL=0 SKIP=0** (231s). `w132` em **53 casos**, incluindo as 15 provas de mutação, todas ainda mortas.

## Tabela REQ-a-REQ

| REQ | Veredito | Evidência |
|---|---|---|
| REQ-01 — mount cross-arquivo | PASS | `w132[46]`: layout canônico com `require` e com `import` resolve as três rotas; `w132[47]`: router órfão não emite e é reportado; `router-mount-unresolved-import` cobre o mount cujo especificador não resolve. |
| REQ-02 — montagem múltipla é união | PASS | `w132[48]`: `/v1/things/{}` e `/v2/things/{}` saem as duas. `mounts` passou a acumular prefixos por símbolo. |
| REQ-03 — router pela atribuição | PASS | `w132[46]` (`const r = Router()`) e `w132[51]` (`require('express').Router()`). |
| REQ-04 — desambiguação por using/namespace | PASS | `w132[50]`: host com um `using` resolve para a definição visível e **não** escolhe a do namespace não importado. `w132[49]`: host que importa as duas continua reportando `producer-ambiguous` e não emite nenhuma. |
| REQ-05 — nenhum receptor some calado | PASS | `w132[51b]`: receptor opaco vira `route-receiver-unknown`. `w132[52]`: `axios.get` em arquivo sem framework não gera achado. |
| NFR-01 — nada afrouxado | PASS | Casos de path parcial (`w132[31]`), interpolação, ambiguidade real e prefixo irresolúvel seguem verdes; as 15 mutações do `w132[29]` continuam sendo mortas. |

## Medição de cobertura (é o insumo do LDG-0010)

Dois fixtures representativos, medidos antes e depois:

| Layout | Antes | Depois |
|---|---|---|
| Express canônico (2 routers, 5 rotas, mounts no `app.js`) | **0 rotas, 0 irresolúveis** | **5 rotas, 0 irresolúveis** |
| Vertical slice .NET (2 features homônimas, host importa uma) | **0 rotas, 0 irresolúveis** | **2 rotas, 0 irresolúveis** |

O "0 rotas, 0 irresolúveis" da coluna da esquerda é o achado mais sério deste change, e não veio de
teste: veio de rodar a medição. Zero rotas **com** zero diagnósticos deixa o `SUR-01` verde por
vacuidade — pior que reprovar. A causa era `require('express').Router()` não casar o reconhecedor,
somada a um `continue` que descartava o receptor não classificado sem registrar nada.

## Premissa do ledger que não se sustentou

O `LDG-0019` afirma que desambiguar `MapEndpoints` homônimo "exige resolver namespace/using do C#,
que está fora do alcance de um scanner por regex". Para a forma comum — `namespace X;` e `using X;`
— a premissa é falsa, e é exatamente essa informação que o compilador usa. Continuam fora do
alcance o alias (`using O = Acme.Orders;`) e o `ImplicitUsings` do `.csproj`, que caem no veredito
conservador de antes.

## Comandos executados

- `npm test` → PASS=74 FAIL=0 SKIP=0
- `bash tests/w132-route-surface-gate.sh` → OK (53 casos)
- medição de cobertura nos dois layouts, antes e depois (tabela acima)
