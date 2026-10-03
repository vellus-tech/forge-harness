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

app.MapPost("/v1/tarifas/{linhaId:guid}/reajustes", async (Guid linhaId, ReajusteRequest request, ReajustarTarifaHandler handler, CancellationToken ct) =>
{
    var resultado = await handler.HandleAsync(linhaId, request.PercentualBp, ct);
    return resultado.Resultado switch
    {
        ReajustarTarifaResultado.Sucesso => Results.Ok(resultado.Response),
        ReajustarTarifaResultado.LinhaNaoEncontrada => Results.Problem(statusCode: 404, title: "Tarifa não encontrada"),
        ReajustarTarifaResultado.PercentualInvalido => Results.Problem(
            statusCode: 422,
            title: "Percentual inválido",
            detail: "O percentual deve estar entre 1 e 5000 bp (0,01% a 50%)."),
        _ => Results.Problem(statusCode: 500),
    };
});

app.Run();

public sealed record ReajusteRequest(int PercentualBp);
