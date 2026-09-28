# Tasks — extrato-web

- Status: Aprovado para desenvolvimento
- Versão: 1.0.0

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|---|---|---|---|---|
| TASK-01 | Implementar filtrarPorPeriodo | 1 | feat/extrato-web/wave-1 | [ ] |
| TASK-02 | Escrever 3 testes: filtro não depende de rede nem de armazenamento | 1 | feat/extrato-web/wave-1 | [ ] |
| TASK-03 | Encerramento da Wave 1 — build verde + commit | 1 | feat/extrato-web/wave-1 | [ ] |
| TASK-04 | Implementar exportarCsv | 2 | feat/extrato-web/wave-2 | [ ] |

## Tarefas

### TASK-01 — Implementar filtrarPorPeriodo

**Wave:** 1
**Requisitos cobertos:** Req 1.1, Req 1.2
**Arquivos esperados:**
- apps/web/extrato-web/src/filtro.ts (criar)
- apps/web/extrato-web/src/filtro.test.ts (criar)

**Critérios de aceite:**
- TASK-01.1 `filtrarPorPeriodo(lancamentos: Lancamento[], inicio: string, fim: string): Lancamento[]` com intervalo fechado
- TASK-01.2 `inicio > fim` lança `RangeError`

### TASK-02 — Escrever 3 testes: filtro não depende de rede nem de armazenamento

**Wave:** 1
**Requisitos cobertos:** Req 1.3

**Critérios de aceite:**
- TASK-02.1 Teste que falha se o filtro chamar `fetch`
- TASK-02.2 Teste que falha se o filtro acessar `localStorage`
- TASK-02.3 Teste de que a entrada não é mutada

### TASK-03 — Encerramento da Wave 1 — build verde + commit

**Wave:** 1
**Critérios de aceite:**
- TASK-03.1 `npm run typecheck` e `npm test` verdes na branch da onda

### TASK-04 — Implementar exportarCsv

**Wave:** 2
**Requisitos cobertos:** Req 2.1
**Arquivos esperados:**
- apps/web/extrato-web/src/csv.ts (criar)
- apps/web/extrato-web/src/csv.test.ts (criar)
