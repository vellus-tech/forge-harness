# Despacho de subagentes (simulado — nenhum foi spawnado)

Regra desta execução: se o artefato mandasse spawnar subagentes, eu deveria registrar aqui o
despacho em vez de executá-lo.

Resultado da checagem: **nenhum despacho é necessário.** `yolo-gate.md` define um agente
**terminal** de decisão — ele é o subagente que o orquestrador do pipeline spawnaria (model
`opus`, `effort: high`) no lugar do humano; o próprio contrato do agente não pede que ele, por
sua vez, delegue a outro subagente. O passo 5 do contrato ("Se approve e o gate destrava uma
transição, o orquestrador roda o `spec-transition.sh`") é uma ação do **orquestrador**, não um
despacho de subagente — e está fora do escopo desta run (que termina na decisão + registro).

Se este caso de eval fosse estendido para medir o orquestrador (não o gate isoladamente), o
despacho que eu registraria seria:

- **agente:** `yolo-gate`
- **modelo:** `opus`, `effort: high` (conforme `forge.yaml > autonomy.gate_agent`)
- **prompt resumido:** "Decida o gate `design_reviewed` do change `estorno-parcial-pix` — leia
  `design.md`/`requirements.md`/`proposal.md`, aplique o checklist de `design-validator.md` como
  lente adversarial, registre a decisão via `approval-log.sh --autonomous` e devolva a linha de
  resultado."
- **por que não foi spawnado aqui:** porque esta run já **é** essa execução — o mandato do
  workflow me colocou diretamente no papel do `yolo-gate` (item 3 do mandato: "leia e siga à
  risca como a definição do agente que você é"), então spawnar um subagente para repetir o mesmo
  trabalho seria redundante e violaria a regra de não-spawn desta run.
