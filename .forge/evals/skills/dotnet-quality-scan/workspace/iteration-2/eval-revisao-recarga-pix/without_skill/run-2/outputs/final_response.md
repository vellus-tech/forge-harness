Revisão de qualidade feita e gravada em `<RUN>/work/revisao-qualidade.md` (raiz do repositório, não commitado). Nenhum código foi alterado.

Principais achados: injeção de SQL em `PixGatewayClient.Historico` (FromSqlRaw com interpolação); `catch { }` engole falha de cobrança e o endpoint responde 202 mesmo assim; a branch não compila (falta `RecargaDbContext` e o pacote EF Core), e `Program.cs` não registra `ISaldoService` nem `PixGatewayClient`. Recomendo não abrir o PR para develop antes de resolver esses itens.

A revisão é de leitura: não rodei build nem testes, porque a política desta execução proíbe restore com download. Os problemas de compilação foram verificados por inspeção.
