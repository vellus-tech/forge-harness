# Gate tasks_reviewed — iteração 3 — conciliacao-tarifas-onibus

## Decisão: REVIEW (reprovado, volta para o tasks-writer)

## O que foi julgado

Comparei `tasks.md` (versão nova, entregue para esta rodada) contra `requirements.md` e `design.md`, e contra o histórico de `approvals.yaml` (rodadas 1 e 2, já em `review`).

- REQ-01, REQ-02, REQ-03 e os invariantes INV-01/INV-02 (com PBT-01/PBT-02) estão cobertos por TASK-01, TASK-02, TASK-03 e TASK-04, com DoD executável e rastreável. Sem problema aqui.
- TASK-05 agora tem DoD ("teste do gatilho com os dois arquivos, e com só um (não dispara)") — o achado da rodada 2 ("TASK-05 sem DoD") foi corrigido.
- **REQ-04 continua sem cobertura real.** A tabela de rastreabilidade do próprio `tasks.md` afirma `REQ-04 → TASK-04`, mas TASK-04 é "Persistir divergências classificadas na tabela `divergencias`" — puramente uma escrita em banco. REQ-04 exige três coisas que design.md §2 nomeia explicitamente (`RelatorioDivergenciasCsv`, `NotificadorOperador`): (a) gerar `divergencias_AAAAMMDD.csv` no bucket `bilhetagem-relatorios`, uma linha por divergência; (b) mascarar `cartao_token` (critério de aceite explícito: só os 4 últimos caracteres); (c) notificar o operador por e-mail com o link do CSV. Nenhuma TASK do plano toca geração de arquivo, mascaramento ou envio de e-mail.

## Por que isso é o mesmo defeito das rodadas 1 e 2, não um novo

- Iteração 1: "REQ-04 não é rastreado por nenhuma TASK".
- Iteração 2: "REQ-04 continua sem TASK — a tabela aponta para TASK-04, que só persiste divergências".
- Iteração 3 (esta): a tabela ainda aponta REQ-04 → TASK-04, e TASK-04 ainda só persiste. Nada mudou na cobertura de REQ-04 entre a rodada 2 e esta — só a DoD da TASK-05 foi ajustada. A rastreabilidade está "furada" da mesma forma: existe uma linha na tabela, mas nenhuma task real implementa o requisito.

## Registro

Decisão anexada em `.forge/specs/active/conciliacao-tarifas-onibus/approvals.yaml` (dentro do workspace deste run, simulado — nenhuma escrita fora deste diretório de execução), gate `tasks_reviewed`, `decision: review`, `iteration: 3`. O `manifest.yaml` do change **não** foi promovido (o gate real ficaria com `tasks_reviewed: false`, como já está).
