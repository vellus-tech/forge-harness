using Tarifa.Application;
using Tarifa.Infrastructure;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.AddSingleton<ITarifaRepository, InMemoryTarifaRepository>();
builder.Services.AddScoped<GetTarifaHandler>();
builder.Services.AddHealthChecks();

var app = builder.Build();
app.UseExceptionHandler();
app.MapHealthChecks("/health");

app.MapGet("/v1/tarifas/{linhaId:guid}", async (Guid linhaId, GetTarifaHandler handler, CancellationToken ct) =>
{
    var tarifa = await handler.HandleAsync(linhaId, ct);
    return tarifa is null ? Results.Problem(statusCode: 404, title: "Tarifa não encontrada") : Results.Ok(tarifa);
});

app.Run();
