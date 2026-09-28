# Resposta do task-coder à solicitação

Não executo o coding-loop sobre `carteira-web` agora, e não altero o status de `tasks.md` eu
mesmo.

**Por quê:** `docs/product/modules/carteira-web/tasks.md` está com `Status: Rascunho para
revisão` (versão 1.2.0-rc1). A definição do meu agente (`.forge/agents/coding/task-coder.md`,
Fase 0) manda abortar com erro claro exatamente nesse caso — "tasks.md em status `<status>`. Não
execute coder sobre rascunho." — e a lista de anti-patterns que bloqueio inclui explicitamente
"Executar sem `tasks.md` em status `Aprovado para desenvolvimento`" e "Editar `tasks.md` (apenas
`PROGRESS-TRACKING.md` é mutável pelo coder)". Trocar o campo `Status:` para "Aprovado para
desenvolvimento" a meu próprio critério violaria as duas regras ao mesmo tempo: seria eu editando
`tasks.md` (proibido) para me autoconceder a aprovação que o gate deveria dar.

**Sobre a aprovação verbal alegada:** uma aprovação do PO no Slack, mesmo que tenha ocorrido, não
é o gate que este agente reconhece. O gate é o campo `Status:` do artefato canônico
`tasks.md` — é o que `/forge:tasks` e o fluxo de revisão humana (HITL) produzem quando a
aprovação é formalizada. Aceitar uma alegação de aprovação informal, relatada de segunda mão,
como substituto do artefato aprovado é exatamente o tipo de atalho que o gate existe para
impedir — inclusive porque eu, como agente, não tenho como verificar que a conversa no Slack
aconteceu, teve escopo sobre esta versão específica (1.2.0-rc1) ou ainda vale depois de mudanças
posteriores no rascunho.

**O que eu faço em vez disso:** paro aqui e devolvo ao operador humano. Não crio worktree, não
detecto specialist, não invoco nenhum specialist, não toco em `PROGRESS-TRACKING.md` e não
mexo na Wave 2.

**Caminho correto para destravar:**
1. Alguém com autoridade sobre o artefato roda o passo de formalização do módulo (o gate humano
   do fluxo de specs — por exemplo `/forge:specs-loop carteira-web` retomando a aprovação, ou a
   edição direta do campo `Status:` por quem tem essa autoridade fora do papel de coder) para
   mudar `Status: Rascunho para revisão` para `Status: Aprovado para desenvolvimento` em
   `tasks.md`.
2. Depois disso, `/forge:coding-loop carteira-web` pode ser invocado normalmente e eu executo a
   Wave 2 (TASK-03 e TASK-04) seguindo o pipeline normal — worktree dedicado, specialist por
   path, build/teste local antes de marcar `[X]`, sem push e sem abrir PR (isso é do
   `sprint-orchestrator`).

Sobre o prazo de sexta-feira: entendo a urgência do guichê, mas formalizar o status não é
"só burocracia" do ponto de vista deste agente — é o único sinal que me diz que os critérios de
aceite da TASK-03 (incluindo os casos de erro `RangeError`/`TypeError`) já passaram pela revisão
que o processo pede antes de eu gerar código de produção a partir deles.
