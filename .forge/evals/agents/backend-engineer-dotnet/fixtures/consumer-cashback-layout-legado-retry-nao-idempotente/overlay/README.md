# cashback-worker

Worker do programa de fidelidade: credita cashback na carteira digital do passageiro a partir de eventos da bilhetagem. Repositório único do serviço (layout legado, sem `services/`): código em `src/`, testes em `tests/`, contratos em `contracts/`.

Mensageria: RabbitMQ via MassTransit. Entrega at-least-once — a validadora republica eventos após reconexão.

## Como testar

`dotnet test Cashback.sln`
