# Decisão do gate — tasks_reviewed (iteração 3)

**Change:** conciliacao-tarifas-onibus
**Gate:** tasks_reviewed
**Iteração:** 3 (rodadas 1 e 2 já registradas em `approvals.yaml`, ambas `review` autônomo)
**Decisão:** `ESCALATE human` (não registrada em approvals.yaml — ver justificativa abaixo)

## Análise adversarial

REQ-04 exige (requirements.md) que ao final da conciliação diária o sistema gere
`divergencias_AAAAMMDD.csv` no bucket `bilhetagem-relatorios` (uma linha por divergência, com
`cartao_token` mascarado) e notifique o operador por e-mail com o link. O design.md nomeia
explicitamente os dois componentes que cobririam isso — `RelatorioDivergenciasCsv` e
`NotificadorOperador` (§2) — mas o tasks.md corrente não contém nenhuma TASK que os implemente:

- TASK-01/02 — importadores (REQ-01/02).
- TASK-03 — motor de casamento (REQ-03/INV-01).
- TASK-04 — **persiste** divergências classificadas na tabela `divergencias` — não gera CSV, não
  mascara `cartao_token`, não notifica ninguém.
- TASK-05 — agenda o job diário (REQ-01/02, gatilho).

A tabela de rastreabilidade do próprio tasks.md aponta `REQ-04 → TASK-04`, mas isso é falso: TASK-04
persiste dados internamente, o que é pré-requisito de REQ-03/REQ-04, não a entrega de REQ-04 (o
arquivo CSV mascarado + e-mail). Este é exatamente o mesmo defeito apontado nas rodadas 1 e 2:

- Iteração 1 (`approvals.yaml`): "REQ-04 (relatório CSV de divergências) não é rastreado por
  nenhuma TASK; TASK-05 sem DoD".
- Iteração 2: "DoD da TASK-05 corrigido; REQ-04 continua sem TASK — a tabela de rastreabilidade o
  lista mas aponta para TASK-04, que só persiste divergências".

Comparando byte a byte com o estado anterior: o DoD da TASK-05 permanece corrigido (não regrediu),
mas **nenhuma TASK nova foi adicionada para REQ-04** entre a iteração 2 e esta (iteração 3). O
tasks-writer não endereçou a instrução da rodada 2 — o gap de rastreabilidade persiste idêntico.

## Por que ESCALATE e não mais um `review`

O protocolo do agente `yolo-gate` (`.forge/agents/review/yolo-gate.md`, opção `review`) é
explícito: "Limite: 3 iterações (`--iteration`); na 3ª ainda com pendência, escale ao humano — nunca
itere autonomamente ao infinito." Estamos na 3ª iteração e a pendência de rastreabilidade de REQ-04
segue idêntica às duas rodadas anteriores — devolver pela 3ª vez ao tasks-writer com a mesma
instrução já demonstrada ineficaz violaria essa trava. O script determinístico
`.forge/scripts/approval-log.sh` corrobora o limite (`--iteration must be 1..3`) e o comentário do
próprio script diz que "loop §14.6 escalates after 3" — ou seja, ao alcançar a 3ª rodada ainda
pendente, o passo seguinte é escalar, não decidir uma 4ª rodada autônoma.

Por isso esta decisão **não** é registrada via `approval-log.sh --decision review --iteration 3`:
seguindo a seção "O que você NÃO decide" do agente ("pare e devolva ao orquestrador... Não decida"),
uma escalada não é uma das opções canônicas do passo 3 e não passa pelo passo 4 (registro). O
comando que teria sido executado, caso a decisão fosse `review` (rejeitado por este motivo), seria:

```bash
bash .forge/scripts/approval-log.sh conciliacao-tarifas-onibus --gate tasks_reviewed \
  --decision review --iteration 3 --autonomous \
  --reason "REQ-04 ainda sem TASK dedicada ao CSV mascarado + notificação; 3ª ocorrência do mesmo gap"
```

Esse comando **não foi executado** (decisão real é escalada, não registrada como gate autônomo).

## Saída para o orquestrador

`GATE tasks_reviewed = ESCALATE human (falha: mesma lacuna de rastreabilidade de REQ-04 persiste
após 2 iterações autônomas de "review"; limite de 3 iterações atingido sem resolução — não itero
autonomamente pela 3ª vez com a mesma instrução já ineficaz)`

## Instrução que eu repassaria ao humano para a rodada 4 (se ele optar por mais uma volta ao
tasks-writer, já fora do meu escopo autônomo)

Adicionar TASK(s) explícita(s) rastreando REQ-04: (a) gerar `divergencias_AAAAMMDD.csv` no bucket
`bilhetagem-relatorios` com uma linha por divergência (classe, linha, veículo, valor esperado, valor
liquidado) e `cartao_token` mascarado (4 últimos caracteres), a partir dos dados já persistidos por
TASK-04; (b) notificar o operador por e-mail com o link do relatório; corrigir a tabela de
rastreabilidade para apontar REQ-04 à(s) TASK(s) nova(s), não a TASK-04.
