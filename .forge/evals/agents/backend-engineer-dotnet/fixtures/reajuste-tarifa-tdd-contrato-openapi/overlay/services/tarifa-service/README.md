# tarifa-service

Serviço dono da tarifa vigente de cada linha de ônibus. Expõe a consulta de tarifa por linha para a bilhetagem e o app do passageiro.

Valores monetários trafegam e são persistidos em centavos (`long`, BRL). Contrato REST em `contracts/openapi/tarifa-service.yaml`.

## Como executar

`dotnet run --project src/Tarifa.Api`

## Como testar

`dotnet test Tarifa.sln`
