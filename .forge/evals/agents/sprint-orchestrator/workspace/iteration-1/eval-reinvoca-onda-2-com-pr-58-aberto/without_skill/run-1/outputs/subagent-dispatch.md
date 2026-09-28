# Despacho de subagentes considerado

Nenhum subagente foi de fato spawnado nesta rodada (regra do ambiente de eval: registrar em vez
de disparar). Avaliação de necessidade:

- **task-coder** — não necessário. O enunciado já afirma que o task-coder commitou a correção
  (`142544b`) na branch `feat/recarga/wave-2` antes deste re-disparo. Rodar outro task-coder para
  a mesma TASK-06 duplicaria trabalho já feito.
- **code-evaluator** — não disparado por mim. Quem aciona uma nova rodada do code-evaluator é o
  próprio fluxo do PR (webhook/label de auto-review do GitHub) depois que o corpo do PR e o
  comentário forem atualizados (passos 3–4 do runbook). Se eu estivesse operando com escrita real
  eu dispararia isso apenas indiretamente, atualizando o PR — não chamando o code-evaluator eu
  mesmo.
- **deploy-orchestrator** — não aplicável nesta rodada; só entra após merge, conforme o próprio
  `PROGRESS-TRACKING.md` ("Próximo gate automático: `/forge:deploy-wave recarga dev` após
  merge").

Se este ambiente tivesse escrita real e um subagente fosse mesmo necessário para checar o diff
completo da wave (por exemplo, revalidar as 4 TASKs antes de atualizar o PR), o despacho seria:

```
agente: code-reviewer (ou equivalente de revisão neste harness)
modelo: sonnet
prompt (resumo): "Revise o diff de feat/recarga/wave-2 (commits ad7cfe5..142544b) contra
  requirements.md e tasks.md da onda 2 de recarga; confirme que TASK-05..TASK-08 estão cobertas
  e que o ajuste de assinatura do webhook (142544b) não introduz regressão de idempotência por
  txid (TASK-06)."
```

Este despacho não foi executado — é o registro do que eu faria, conforme instruído.
