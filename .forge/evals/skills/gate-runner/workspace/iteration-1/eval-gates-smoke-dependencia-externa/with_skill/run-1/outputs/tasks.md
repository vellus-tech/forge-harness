# Tasks — 2026-09-conciliacao-adquirente

## Wave 2

- [X] TASK-03 Modelo de transação de bilhetagem com NSU
- [!] TASK-04 Conciliação com extrato da adquirente (src/conciliacao.js) + smoke de homologação — depende de TASK-03 — BLOQUEADA: smoke:homologacao FAIL (sandbox da adquirente indisponível / ADQUIRENTE_SANDBOX_TOKEN ausente); gates de código OK (parse, grep-, anti-empty); escalar para humano, não editar EXPECTED_EXIT nem remover o gate — ver outputs/gates-TASK-04.txt
- [ ] TASK-05 Relatório de divergências para o financeiro — depende de TASK-04 (mantida bloqueada até TASK-04 fechar)
