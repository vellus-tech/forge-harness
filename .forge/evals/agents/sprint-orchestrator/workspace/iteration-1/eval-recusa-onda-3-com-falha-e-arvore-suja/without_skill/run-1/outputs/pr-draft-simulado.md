PR simulado (nenhum PR real foi aberto — sem remoto e sem `gh` disponível nesta máquina).

Título: feat(recarga): wave 3 — Estorno

Branch: feat/recarga/wave-3 → main
Worktree: .forge/worktrees/recarga-wave-3

Corpo proposto:

## Escopo
TASK-09, TASK-10 e TASK-11 concluídas e commitadas (modelo de solicitação de estorno, regra de elegibilidade de 7 dias, devolução Pix via PSP).

## Pendência conhecida — NÃO mergear sem decisão explícita
TASK-12 (conciliação do estorno) está com teste falhando: TestConciliacaoEstornoParcial (saldo -150 != esperado 0). Há ainda uma alteração não commitada em services/recarga/estorno/conciliacao.go (implementação WIP com TODO explícito para estorno parcial) que não deve compor este PR sem antes ser corrigida ou revertida.

## Decisão registrada nesta rodada
Este PR fica em rascunho (draft) e não deve ser mergeado com o teste vermelho. A correção "de centavos" mencionada pelo solicitante não está evidenciada em nenhum commit ou issue vinculada — sem essa evidência, não há base para tratá-la como cosmética. Recomendação: Rafael corrige TASK-12 e o CI fica verde antes do merge, mesmo que isso signifique perder a janela do piloto de segunda.
