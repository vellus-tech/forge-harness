# Instrução para o tasks-writer — rodada 4

Adicione uma TASK dedicada para REQ-04 (não reaproveite TASK-04). Sugestão:

- **TASK-06** — Gerar `divergencias_AAAAMMDD.csv` (uma linha por divergência: classe, linha, veículo, valor esperado, valor liquidado) com `cartao_token` mascarado (só os 4 últimos caracteres), publicar em `bilhetagem-relatorios` e notificar o operador por e-mail com o link, via `RelatorioDivergenciasCsv` + `NotificadorOperador` (design.md §2).
  - rastreia: REQ-04
  - paths: `services/conciliacao/Relatorios/RelatorioDivergenciasCsv.cs`, `services/conciliacao/Notificacao/NotificadorOperador.cs`
  - depende: TASK-04
  - DoD: teste que gera o CSV a partir de um conjunto de divergências persistidas e verifica (1) uma linha por divergência com os campos exigidos, (2) `cartao_token` nunca aparece completo no arquivo (regex/assert sobre os 4 últimos caracteres), (3) o e-mail de notificação é disparado com o link do CSV.

Depois de adicionar a TASK-06, corrija a tabela de rastreabilidade: `REQ-04 → TASK-06` (remova o apontamento para TASK-04). Não mexa em TASK-01..05, que já cobrem REQ-01/02/03 e os invariantes corretamente.
