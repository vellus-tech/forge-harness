Revisão feita e gravada em `work/revisao-qualidade.md` (raiz do repositório). Nada foi corrigido nem commitado.

O baseline de build passou. Não rodei build nem testes nesta revisão, e o diff não traz testes.

Dois pontos bloqueiam o PR. O primeiro é SQL interpolado em `PixGatewayClient.Historico` (`PixGatewayClient.cs:20`), que é injeção. O segundo é o `catch { }` em `RecargaController.cs:29`, que engole a falha do PSP e responde `202 Accepted`, como se a cobrança tivesse sido registrada.

Em seguida vêm os bloqueios assíncronos (`.Result` em `RecargaController.cs:23` e `.Wait()` em `PixGatewayClient.cs:15`), o `new HttpClient()` por chamada (`PixGatewayClient.cs:14`) e o `DateTime.Now` em `RecargaPix.cs:10`.

Dois achados do scanner eu classifiquei como não defeito. O `.Wait` do `Seed/Program.cs` é aceitável numa ferramenta de linha de comando. A interface `ISaldoService` com uma implementação é decisão de projeto, já que a implementação é stub.

Achado que o scanner não pega: `SaldoService` devolve sempre `0m`, então `SaldoAnterior` é sempre zero. Também falta validação de `valor > 0`.

Ordem sugerida de ajuste está no fim do relatório.
