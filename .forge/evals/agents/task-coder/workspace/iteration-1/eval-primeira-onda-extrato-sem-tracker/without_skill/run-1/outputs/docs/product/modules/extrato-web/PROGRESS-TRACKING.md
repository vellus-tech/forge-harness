# Progress Tracking — extrato-web

Arquivo criado nesta sessão de coding-loop porque o módulo ainda não tinha rastreamento (primeira vez em codificação).

## Wave 1 — feat/extrato-web/wave-1

| TASK | Título | Status |
|---|---|---|
| TASK-01 | Implementar filtrarPorPeriodo | [X] |
| TASK-02 | Escrever 3 testes: filtro não depende de rede nem de armazenamento | [X] |
| TASK-03 | Encerramento da Wave 1 — build verde + commit | [X] (build verde; commit NÃO executado nesta sessão — ver nota) |

Notas:
- TASK-02 não trazia `Arquivos esperados` no tasks.md (o tasks-writer só descreveu os testes). Decisão: os 3 testes foram adicionados em `apps/web/extrato-web/src/filtro.test.ts`, junto dos testes de TASK-01, por serem testes do mesmo `filtrarPorPeriodo` e não justificarem arquivo próprio.
- `npm run typecheck` e `npm test` rodaram verdes na árvore de trabalho (10 testes, 0 falhas). O commit da Wave 1 (parte de TASK-03) não foi feito porque esta execução opera sob regra de simulação: nenhum `git commit` real foi rodado. Ver `outputs/transcript.md` para o commit que seria feito.

## Wave 2 — feat/extrato-web/wave-2

| TASK | Título | Status |
|---|---|---|
| TASK-04 | Implementar exportarCsv | [X] (adiantada a pedido do usuário; não fazia parte da onda alvo desta execução) |

Notas:
- Adiantada porque a tarefa do usuário pediu, "se sobrar tempo", a exportação CSV da Wave 2. Implementada `exportarCsv` em `apps/web/extrato-web/src/csv.ts` com separador `;` e valores em centavos, conforme Req 2.1 e design.md.
- Wave 2 não tem TASK de encerramento própria no tasks.md; não foi criada uma, para não extrapolar o escopo especificado pelo tasks-writer.
