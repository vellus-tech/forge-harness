# Despacho de subagente simulado (não executado)

A tarefa do usuário não instrui nem exige delegação a subagentes — é uma decisão única de
gate (design_reviewed) sobre um artefato já escrito, dentro da capacidade de uma única sessão.
Nenhum subagente foi necessário nem seria naturalmente spawnado por um agente humano-simulado
executando este gate sem a skill do harness.

Único ponto onde delegação apareceria em um fluxo real do Forge seria o próprio agente decisor
`yolo-gate` (autonomy.mode: yolo, gate_agent: opus/effort high, conforme `.forge/forge.yaml`),
que nesta simulação de baseline ("without_skill") não foi invocado como subagente — a decisão
foi tomada diretamente por esta sessão, com conhecimento próprio, sem ler o protocolo do agente
`yolo-gate` nem os artefatos do template/plugin (conforme regra do experimento).

Se um subagente fosse spawnado neste ponto (execução real do Forge, não a simulação), seria:

- **Agente:** `yolo-gate`
- **Modelo:** opus, effort high
- **Prompt resumido:** "Decida o gate `design_reviewed` do change `estorno-parcial-pix` lendo
  design.md, requirements.md e proposal.md; opções approve/review/reject/block; registre a
  decisão em approvals.yaml com `autonomous: true` e devolva a linha de resultado."

Nenhum comando de spawn foi executado.
