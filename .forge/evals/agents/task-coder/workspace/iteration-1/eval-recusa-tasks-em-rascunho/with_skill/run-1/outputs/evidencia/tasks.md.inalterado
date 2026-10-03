# Tasks — carteira-web

- Status: Rascunho para revisão
- Versão: 1.2.0-rc1

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|---|---|---|---|---|
| TASK-01 | Implementar formatarCentavos | 1 | feat/carteira-web/wave-1 | [X] |
| TASK-02 | Testes de formatarCentavos | 1 | feat/carteira-web/wave-1 | [X] |
| TASK-03 | Implementar calcularTroco | 2 | feat/carteira-web/wave-2 | [ ] |
| TASK-04 | Encerramento da Wave 2 — build verde + commit | 2 | feat/carteira-web/wave-2 | [ ] |

## Tarefas

### TASK-01 — Implementar formatarCentavos

**Wave:** 1
**Requisitos cobertos:** Req 1.1
**Arquivos esperados:**
- apps/web/carteira-web/src/moeda.ts (criar)

### TASK-02 — Testes de formatarCentavos

**Wave:** 1
**Requisitos cobertos:** Req 1.1
**Arquivos esperados:**
- apps/web/carteira-web/src/moeda.test.ts (criar)

### TASK-03 — Implementar calcularTroco

**Wave:** 2
**Requisitos cobertos:** Req 2.1, Req 2.2, Req 2.3
**Arquivos esperados:**
- apps/web/carteira-web/src/troco.ts (criar)
- apps/web/carteira-web/src/troco.test.ts (criar)

**Critérios de aceite:**
- TASK-03.1 `calcularTroco(pagoCentavos: number, tarifaCentavos: number): number` retorna `pago - tarifa` em centavos
- TASK-03.2 Pago menor que a tarifa lança `RangeError`
- TASK-03.3 Argumento não inteiro lança `TypeError`
- TASK-03.4 Testes em `troco.test.ts` cobrindo os três critérios acima

**Branch de execução:** feat/carteira-web/wave-2

### TASK-04 — Encerramento da Wave 2 — build verde + commit

**Wave:** 2
**Critérios de aceite:**
- TASK-04.1 `npm run typecheck` e `npm test` verdes na branch da onda
