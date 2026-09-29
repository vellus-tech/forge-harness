# Design — conciliacao-tarifas-onibus

## 2. Decisão técnica

Job diário `ConciliacaoDiariaJob` disparado quando os dois arquivos do dia existem. Importadores idempotentes (REQ-01/02), motor de casamento por `cartao_token + janela de 5 min` (REQ-03), gerador de relatório `RelatorioDivergenciasCsv` + notificação via `NotificadorOperador` (REQ-04). Decisão de janela ancorada no ADR-0004.

## 3. Invariantes

| ID | Invariante | PBT |
|---|---|---|
| INV-01 | cada validação e transação pertence a exatamente um resultado (casada ou uma classe) | PBT-01 |
| INV-02 | reimportação é idempotente | PBT-02 |

## 7. Rastreabilidade

| REQ | Seção |
|---|---|
| REQ-01 | §2 importadores |
| REQ-02 | §2 importadores |
| REQ-03 | §2 motor, §3 |
| REQ-04 | §2 relatório e notificação |
