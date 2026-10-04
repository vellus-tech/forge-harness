# Tasks — extrato-web

- Status: Aprovado para desenvolvimento
- Versão: 1.0.0

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|---|---|---|---|---|
| TASK-01 | Implementar filtrarPorPeriodo | 1 | feat/extrato-web/wave-1 | [ ] |
| TASK-02 | Escrever 3 testes: estornos ficam fora do extrato filtrado | 1 | feat/extrato-web/wave-1 | [ ] |
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

**Teste (comando):** `node --test apps/web/extrato-web/src/filtro.test.ts`
**Padrão de falha:** `AssertionError`

### TASK-02 — Escrever 3 testes: estornos ficam fora do extrato filtrado

**Wave:** 1
**Requisitos cobertos:** Req 1.3

**Critérios de aceite:**
- TASK-02.1 Teste: lançamento com `estornado: true` dentro do período não aparece no resultado de `filtrarPorPeriodo`
- TASK-02.2 Teste: lançamento sem o campo `estornado` continua aparecendo
- TASK-02.3 Teste: a lista de entrada não é mutada

**Teste (comando):** `node --test "apps/web/extrato-web/src/*.test.ts"`
**Padrão de falha:** `AssertionError`

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

**Teste (comando):** `node --test apps/web/extrato-web/src/csv.test.ts`
**Padrão de falha:** `AssertionError`
