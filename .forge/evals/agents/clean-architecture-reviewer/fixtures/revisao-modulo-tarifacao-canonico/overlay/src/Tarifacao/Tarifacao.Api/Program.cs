using Tarifacao.Application.Handlers;
using Tarifacao.Domain.Repositories;
using Tarifacao.Infrastructure.Persistence.Repositories;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddScoped<ITarifaRepository, DynamoTarifaRepository>();
builder.Services.AddScoped<CalcularTarifaIntegracaoHandler>();

var app = builder.Build();
app.MapGet("/tarifas/{linha}/integracao", async (string linha, string modalAnterior, DateTime embarqueAnterior, CalcularTarifaIntegracaoHandler handler, CancellationToken ct) =>
    Results.Ok(await handler.HandleAsync(linha, modalAnterior, embarqueAnterior, DateTime.UtcNow, ct)));
app.Run();
