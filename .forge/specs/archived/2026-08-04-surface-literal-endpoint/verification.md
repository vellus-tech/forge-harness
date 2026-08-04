# Verification — surface-literal-endpoint

- **Commit sob verificação:** `5bcf362` (branch `develop`)
- **Verificado em:** 2026-08-04
- **Veredito global: PASS.** `npm test` → **PASS=74 FAIL=0 SKIP=0** (254s).

## Tabela REQ-a-REQ

| REQ | Veredito | Evidência |
|---|---|---|
| REQ-01 — cobra o literal | PASS | `w130[17]`: prosa → 1 achado não-bloqueante nomeando o REQ; `POST /api/v1/orders` → sem achado; célula mista → sem achado; tela/CLI/flag → sem achado. |
| REQ-01 — aviso, não bloqueio | PASS | `enforceable: false` asserido no caso (a); `validate-spec` empilha em `warnings`. |
| REQ-02 — decisão registrada com números | PASS | `LDG-0010` atualizado com a medição inteira; `commands/specs/tasks.md` documenta o `SRF-03` e o porquê; plugin regenerado (`plugin-sync-gate` verde). |
| NFR-01 — nada muda de classificação | PASS | `w130[7]`, `[13]`, `[14]`, `[15]` e o `w131` inteiro verdes. |

## A medição que motivou este change

Contra `axis-go-cloud`, com o scanner já corrigido pelos dois changes anteriores:

- **Código:** 343 rotas resolvidas (o plano original media 41), 83 irresolúveis — 38 `producer-not-found`, 23 `group-path-not-literal`, 12 `producer-never-invoked`, 5 `mapgroup-unindexed`, 5 `route-site-unindexed`.
- **Declarado:** 172 endpoints (170 OpenAPI, 9 tabela, 18 checklist), 43 irresolúveis.
- **Cruzamento:** `SUR-01` = `inconclusive`, 49 abstidos, 5 kinds de blocker.
- **`SRF-01` em 35 changes:** 11 achados — 7 sem endpoint literal (o oráculo não decide), 2 com endpoint que existe (defeito de declaração), 2 com endpoint ausente (defeito de código **ou** cegueira do scanner).

**Conclusão:** a promoção do `SRF-01` a bloqueante não se sustenta nesta medição. O obstáculo não é o oráculo — é o insumo. Este change ataca o insumo; a promoção segue aberta no `LDG-0010`, agora com números.

## Impacto medido do próprio SRF-03

7 dos 26 changes com `requirements.md` no repositório de referência receberiam o achado (8 achados no
total), sobre 19 linhas de checklist que falam em API. É por isso que nasce como aviso: um check que
chega bloqueando o passado é desligado, e desligado ele não coleta o insumo que justificaria a
promoção seguinte.

## Correção durante o trabalho

O `w130[15]` grepava `SRF-01` como string solta e passou a casar a menção em prosa dentro da
mensagem do `SRF-03` ("o SRF-01 fica limitado a…"). O grep passou a casar o código do achado
(`(SRF-01 `). Vale como lembrete: asserção por substring livre em texto de diagnóstico quebra quando
outra mensagem cita o mesmo código.

## Comandos executados

- `npm test` → PASS=74 FAIL=0 SKIP=0
- `bash tests/w130-tasks-graph-gate.sh` → OK (17 casos)
- medição do `SRF-03` sobre 26 changes reais (tabela acima)
