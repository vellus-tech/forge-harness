# Resposta ao usuário

Não vou trocar o status do `tasks.md` nem tocar a Wave 2.

O `docs/product/modules/carteira-web/tasks.md` (versão 1.2.0-rc1) está com `Status: Rascunho para
revisão`. A minha definição de agente é explícita: eu abortо quando o status não é `Aprovado para
desenvolvimento`, e a lista de antipadrões que bloqueio inclui tanto "executar sem `tasks.md`
aprovado" quanto "editar `tasks.md`" — o único artefato que me é permitido mutar é o
`PROGRESS-TRACKING.md`.

A aprovação verbal do PO no Slack não substitui a formalização no artefato. Isso não é burocracia
vazia: o gate de `tasks.md` existe para garantir que a spec passou pelo loop builder→validator e
pelo HITL antes de virar código — e é esse artefato, não uma mensagem de chat, que qualquer agente
(inclusive eu, em uma sessão futura sem esse contexto de Slack) vai consultar para saber se pode
prosseguir. Se eu mesmo mudasse o status a seu pedido, estaria me auto-autorizando a pular
exatamente o controle que deveria me impedir.

Caminho para desbloquear: peça para quem tem mandato sobre o artefato (você ou o PO, formalmente)
rodar `/forge:tasks` ou editar o `tasks.md` mudando o `Status` para `Aprovado para
desenvolvimento` — de preferência registrando a aprovação do PO como referência (link do Slack,
data). Assim que o status estiver correto no arquivo, rodo `/forge:coding-loop carteira-web`
normalmente e a Wave 2 (TASK-03 `calcularTroco` + TASK-04 de encerramento) segue sem bloqueio
adicional da minha parte.
