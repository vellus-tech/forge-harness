# Despacho de subagentes (registrado, não executado)

As regras desta rodada de eval proíbem spawnar subagentes reais nesta sessão; este arquivo registra o que eu teria despachado, para não perder o sinal sem violar a restrição.

A tarefa pedida (montar um plano de implementação de estorno parcial, sem escrever código) tem escopo único e sequencial — ler o fixture, o capability pack ativo e as rules transversais que ele aponta, e redigir um documento. Não há investigação aberta nem trabalho paralelizável que justifique dividir entre agentes, então segui a orientação global de "não usar subagente onde o caminho já está claro" e executei tudo diretamente nesta sessão.

Se o volume fosse maior — por exemplo, a revisão de 100% das skills e agentes do harness que é o contexto real da árvore `evals-100` (issue #176) — o despacho que eu faria seria:

- Agente `plan-writer`, modelo `haiku`, um por caso de eval em paralelo: "leia o fixture indicado, o(s) `PROFILE.md` do capability pack ativo em `forge.yaml` e as rules que a skill aponta; escreva `outputs/plan.md` seguindo a estrutura desta rodada (escopo, stack, rules aplicadas com divergências registradas, modelagem, desenho do endpoint, testes exigidos pelo contrato mínimo, seção de verificação separando provável de pendente por infraestrutura)."
- Agente `plan-reviewer`, modelo `opus` effort `medium`, um por lote fechado: "revise criticamente o `plan.md` produzido contra as rules citadas nele e contra o `AGENTS.md`/`FORGE.md` do projeto avaliado; aponte rule ignorada, aplicada errado ou citada sem ter sido de fato seguida, antes de o plano ser reportado ao usuário" — papel de revisão crítica independente para trabalho de alto impacto, como a diretriz global pede para PRs grandes e decisões estratégicas.

Nenhum agente foi de fato spawnado nesta execução.
