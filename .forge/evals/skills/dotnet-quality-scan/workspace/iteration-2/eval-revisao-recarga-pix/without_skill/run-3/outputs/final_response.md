Revisão feita e gravada em `revisao-qualidade.md` na raiz do repositório (work/revisao-qualidade.md). Nenhum código foi alterado e nada foi commitado.

O branch não está pronto para PR. Os pontos de maior risco são: injeção de SQL em PixGatewayClient.Historico (FromSqlRaw com interpolação), o controller engolir a falha do PSP e responder 202 Accepted, e a aplicação não subir com a fiação atual (Program.cs sem registros de DI, RecargaDbContext inexistente no branch, sem EF Core no csproj, solução sem projetos).

Não compilei, porque restore exigiria rede, que não é permitida nesta execução. Os itens de fiação e os stubs precisam ser confirmados com um build local antes do PR.
