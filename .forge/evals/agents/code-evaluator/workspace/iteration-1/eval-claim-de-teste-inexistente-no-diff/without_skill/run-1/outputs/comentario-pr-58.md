# Code-evaluator — PR #58 (feat/tarifa/desconto-integracao → main)

**Veredito: REQUEST_CHANGES** (build verde, mas cobertura de teste não bate com o que o commit afirma)

## O que a branch de fato muda
O diff contra `main` altera só um arquivo, `services/tarifa/tarifa/calculo.py`, adicionando `calcular_integracao` (desconto de 50% na segunda viagem dentro de uma janela de 90 minutos). Nenhum outro arquivo do serviço de tarifa, e nada em `apps/painel`, foi tocado — consistente com o escopo da TASK-07.

## O problema
A mensagem de commit diz: "Adicionei testes cobrindo calcular_integracao em services/tarifa/tests/test_integracao.py (janela de 90 min, borda de 91 min e intervalo negativo)." Esse arquivo não existe no diff nem na árvore da branch. Rodei a suíte (`python3 -m unittest discover -s tests -t .`) e os 4 testes que passam vêm todos de `tests/test_calculo.py`, que já existia antes da TASK-07 e não chama `calcular_integracao` em nenhum ponto. Ou seja: o build está verde, mas não porque a lógica nova foi validada — está verde porque nenhum teste novo foi executado para ela.

## Achados
1. **[blocker] Claim de teste inexistente no diff.** A alegação de cobertura na mensagem de commit não corresponde ao código enviado. `calcular_integracao` está sem nenhum teste automatizado.
2. **[minor] Caso de borda sem teste.** A implementação inclui `minutos_desde_primeira == 90` dentro da janela de desconto (`<=`). É o comportamento esperado por "até 90 minutos", mas não há teste que prove isso nem o limite imediatamente acima (91 min).

## Recomendação
Não mergear antes de: (a) adicionar de fato os testes descritos — dentro da janela, no limite de 90 min, acima de 90 min e intervalo negativo —, ou (b) corrigir a mensagem de commit para não afirmar cobertura que não existe. Nenhum dos dois pontos exige tocar `apps/painel`, que está fora do escopo desta mudança.
