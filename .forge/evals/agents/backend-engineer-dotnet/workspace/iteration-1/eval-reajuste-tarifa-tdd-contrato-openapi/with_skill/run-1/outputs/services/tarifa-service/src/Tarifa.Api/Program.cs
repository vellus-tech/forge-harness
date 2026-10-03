using Tarifa.Application;
using Tarifa.Infrastructure;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.AddSingleton<ITarifaRepository, InMemoryTarifaRepository>();
builder.Services.AddScoped<GetTarifaHandler>();
builder.Services.AddScoped<ReajustarTarifaHandler>();
builder.Services.AddHealthChecks();

var app = builder.Build();
app.UseExceptionHandler();
app.MapHealthChecks("/health");

app.MapGet("/v1/tarifas/{linhaId:guid}", async (Guid linhaId, GetTarifaHandler handler, CancellationToken ct) =>
{
    var tarifa = await handler.HandleAsync(linhaId, ct);
    return tarifa is null ? Results.Problem(statusCode: 404, title: "Tarifa não encontrada") : Results.Ok(tarifa);
});

app.MapPost(
    "/v1/tarifas/{linhaId:guid}/reajustes",
    async (Guid linhaId, ReajustarTarifaRequest request, ReajustarTarifaHandler handler, CancellationToken ct) =>
    {
        try
        {
            var resultado = await handler.HandleAsync(linhaId, request, ct);
            return resultado is null
                ? Results.Problem(statusCode: 404, title: "Tarifa não encontrada")
                : Results.Ok(resultado);
        }
        catch (PercentualInvalidoException ex)
        {
            return Results.Problem(statusCode: 422, title: "Percentual de reajuste inválido", detail: ex.Message);
        }
    });

app.Run();
