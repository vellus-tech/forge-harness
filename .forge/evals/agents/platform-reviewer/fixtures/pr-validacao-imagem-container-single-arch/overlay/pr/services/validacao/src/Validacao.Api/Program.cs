using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using Prometheus;
using Serilog;
using Serilog.Formatting.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, cfg) => cfg
    .Enrich.FromLogContext()
    .WriteTo.Console(new JsonFormatter()));

builder.Services.AddOpenTelemetry()
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddOtlpExporter())
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddPrometheusExporter());

builder.Services.AddHealthChecks();

var app = builder.Build();

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseHttpMetrics();
app.MapMetrics("/metrics");
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.MapPost("/embarques/validar", (ValidarEmbarqueRequest req, ILogger<Program> logger) =>
{
    logger.LogInformation("Embarque recebido na linha {Linha} cartão {Pan} CPF {Cpf}", req.Linha, req.Pan, req.Cpf);
    return Results.Ok(new { aprovado = true });
});

app.Run();

public record ValidarEmbarqueRequest(string Linha, string Pan, string Cpf);
