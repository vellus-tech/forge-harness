TASK-03 do módulo tarifa implementada no working tree do tarifa-service, sem commit. O endpoint `POST /v1/tarifas/{linhaId}/reajustes` aplica o percentual em pontos-base (1 a 5000 bp), com arredondamento half-even para o centavo, e devolve `valorAnteriorCentavos` e `valorNovoCentavos`. Fora da faixa responde 422 com ProblemDetails e linha inexistente responde 404.

Fiz TDD: os testes falharam na compilação antes da implementação e passam agora (6 de 6). Os dois exemplos da spec batem (430 com 1250 bp dá 484; 420 com 1250 bp dá 472 no empate). A Api compila sem avisos. O contrato OpenAPI foi atualizado para a bilhetagem gerar o client, e o CHANGELOG ganhou a entrada.

Não verifiquei o endpoint por HTTP, porque a política desta execução proíbe rede. Vale um smoke test manual antes do deploy.

A árvore já tinha centenas de arquivos removidos em `.claude/` e `.forge/` antes desta tarefa. Não mexi neles, então convém confirmar se é intencional antes de commitar. A TASK-03 segue `[ ]` no tasks.md, para o fluxo de coding-loop marcar.

Detalhes e decisões estão em `<RUN>/work/entrega.md`.
