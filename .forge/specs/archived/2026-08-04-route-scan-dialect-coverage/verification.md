# Verification — route-scan-dialect-coverage

- **Commit sob verificação:** `3fe2e53` (branch `develop`)
- **Verificado em:** 2026-08-04
- **Veredito global: PASS.** `npm test` → **PASS=74 FAIL=0 SKIP=0** (237s). `w132` em **57 casos**, com as 15 provas de mutação ainda mortas.

## Tabela REQ-a-REQ

| REQ | Veredito | Evidência |
|---|---|---|
| REQ-01 — âncora da tabela de policy | PASS | `w132[53]`: o mapa sob o heading entra, a tabela de "APIs de terceiros consumidas" não. `w132[10]` (spec sem heading) segue verde — o degrade preserva a leitura ampla e emite `policy-table-unanchored`. |
| REQ-02 — caixa do `[controller]` | PASS | `w132[54]`: `OrdersController` → `/api/orders`, com o `v1` do literal intocado. `w132[54b]`: Spring (`/api/Orders/List`) e Express (`/API/Health`) preservam a caixa. |
| REQ-03 — `.py` e `.go` | PASS | `w132[55]`: FastAPI com `APIRouter(prefix)`, Flask com `methods=[...]`, chi por verbo; `HandleFunc` sem `.Methods()` não recebe verbo inventado. Prefixo de router desconhecido não emite path parcial. |
| REQ-04 — Nest multi-controller | PASS | `w132[56]`: `/cats/{}` e `/dogs` saem separados, o segundo não herda o prefixo do primeiro, e `@Controller(BASE_PATH)` vira `class-route-not-literal` + `route-prefix-unresolved` sem emitir rota. |
| NFR-01 — nada afrouxado | PASS | 15 mutações do `w132[29]` seguem mortas; casos de path parcial, interpolação e ambiguidade verdes. |

## Duas correções de rumo durante o trabalho

**A âncora estrita quebrou o `w132[10]`** — uma spec cuja tabela não está sob o heading perderia a
superfície declarada inteira. Isso é falso negativo, e superfície declarada vazia deixa o `SUR-01`
verde por vacuidade: pior que o falso positivo que a âncora veio corrigir. A âncora passou a
degradar para varredura ampla, com diagnóstico. O caso `[10]` foi mantido como estava, de
propósito — ele é o controle dessa fronteira.

**Dois casos existentes foram atualizados** (`[6]` e `[39]`), porque codificavam a caixa antiga do
`[controller]`. É mudança deliberada de comportamento, não acomodação de teste: registro aqui para
que a revisão veja a alteração em vez de descobri-la no diff.

## Premissa do ledger que envelheceu

O `LDG-0018` (4) afirma que Nest resolve "um controller por arquivo". Medido em 2026-08-04,
multi-controller já funcionava — a correção de prefixo-por-classe do PR #40 o cobriu de passagem.
Só a parte "`@Controller` literal" continua valendo, e é comportamento correto: não literal é
reportado, nunca chutado. O caso `[56]` trava as duas coisas.

## Comandos executados

- `npm test` → PASS=74 FAIL=0 SKIP=0
- `bash tests/w132-route-surface-gate.sh` → OK (57 casos)
