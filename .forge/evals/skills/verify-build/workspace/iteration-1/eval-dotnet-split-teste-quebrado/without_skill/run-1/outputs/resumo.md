# Verificação determinística — feat/parcela-minima vs main

**Veredito: a branch NÃO pode seguir para os reviewers.** Build compila limpo (0 erros, 2 avisos NU1900 de resolução de índice de vulnerabilidade do CodeArtifact privado, presentes também na main, sem relação com a mudança), mas a suíte de testes quebra: 2 de 3 testes falham, contra 3/3 aprovados na main.

As duas falhas são causadas pela mesma alteração em `src/Pagamentos.Domain/Pagamento.cs`: `Split` agora lança `InvalidOperationException` quando `parcelas <= 0` OU quando `ValorCentavos / parcelas < ParcelaMinimaCentavos` (novo `const` de R$ 5,00). Isso muda o tipo de exceção esperado para parcelas inválidas (era `DomainException`) e introduz uma regressão de comportamento: o caso `Split(1000, 3)`, que antes retornava `[334, 333, 333]`, agora lança exceção porque 1000/3 = 333 < 500.

Rodado com `strict_mode` desligado, então os avisos NU1900 não contam como bloqueio — o bloqueio é exclusivamente de teste falho. Nenhuma correção foi feita no código, conforme solicitado; o detalhe estruturado está em `outputs/verify-build-output.json`.
