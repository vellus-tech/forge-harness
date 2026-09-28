# Requirements — VAL — Validação de embarque

- Versão: 1.0.0
- Data: 2026-08-20
- Status: Aprovado para desenvolvimento

### Req 1 — Decisão de embarque

O validador DEVE decidir o embarque em até 500 ms a partir da leitura do cartão, aplicando a tarifa vigente da linha.

### Req 2 — Parametrização de tarifa por linha

O validador DEVE receber a tabela de tarifas por linha (base, noturna, integração) sincronizada do backend.

### RNF 1 — Operação offline

O validador DEVE decidir embarques sem conectividade por até 72 horas com a última tabela sincronizada.

- **PBT-01 — Tarifa aplicada pertence à tabela vigente:** para qualquer linha e horário, a tarifa aplicada é um valor da tabela sincronizada.
