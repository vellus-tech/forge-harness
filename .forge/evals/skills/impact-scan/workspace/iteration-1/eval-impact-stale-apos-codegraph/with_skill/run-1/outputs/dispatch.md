# Despacho de subagentes (registro, nao executado)

A skill `impact-scan` (SKILL.md em `template/.forge/skills/impact-scan/SKILL.md`) e um wrapper
determinista sobre `lib/impact-scan.mjs` -- o protocolo nao manda spawnar subagentes em nenhum
ponto (nao ha secao de delegacao, e a "Execucao" e um unico comando de script). Por isso, nenhum
despacho de subagente foi necessario para completar esta tarefa; a regra do harness de registrar
o despacho em vez de spawnar se aplica apenas caso o artefato mandasse -- o que nao ocorreu aqui.

Se este caso fosse tratado como uma investigacao mais ampla (por exemplo, revisar 100% das skills
via protocolo skill-creator, como pede o pedido original do usuario que disparou este workflow),
o despacho que eu faria, por skill/agente avaliado, seria:

- agente: `general-purpose` (ou equivalente sonnet), modelo: `sonnet`
- prompt resumido: "Rode o caso eval `<skill>/<caso>/<with|without>_skill/run-N`, siga o SKILL.md
  correspondente a risca, grave outputs/transcript.md e outputs/ com os artefatos, sem git
  commit/push/tests/ledger/liaison/gh, sem sleep em foreground."
- um subagente por combinacao (skill, caso, with/without_skill, run), para paralelizar a varredura
  de 100% das skills/agentes pedida na issue #176, mantendo a janela de contexto do orquestrador
  limpa (cada subagente le so o SKILL.md e os fixtures do seu proprio caso).

Este run especifico (`impact-stale-apos-codegraph`, with_skill, run-1) foi executado diretamente
por mim, sem necessidade de sub-despacho, por ser um unico caso determinista e pequeno.
