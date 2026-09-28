using Microsoft.IdentityModel.Tokens;
using Notificacoes.Api;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer").AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new RsaSecurityKey(JwtKeys.LoadPublicKey(builder.Configuration, builder.Environment)),
        ValidateIssuer = true,
        ValidIssuer = "example.com",
        ValidateAudience = true,
        ValidAudience = "api",
        ValidateLifetime = true,
        // 30s de tolerância: relógio dos dispositivos push; ver docs/product/adr/0012-clockskew-30s-notificacoes.md
        ClockSkew = TimeSpan.FromSeconds(30)
    };
});
builder.Services.AddAuthorization(o => o.AddPolicy("notificacoes:enviar", p => p.RequireClaim("permissions", "notificacoes:enviar")));

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapPost("/api/v1/notificacoes", (EnviarNotificacaoRequest req, ILogger<Program> logger, HttpContext ctx) =>
{
    var correlationId = ctx.TraceIdentifier;
    logger.LogInformation("Notificação enfileirada usuario={UserId} canal={Canal} correlationId={CorrelationId}", req.UserId, req.Canal, correlationId);
    return Results.Accepted();
}).RequireAuthorization("notificacoes:enviar");

app.MapGet("/health", () => Results.Ok());
app.Run();

public sealed record EnviarNotificacaoRequest(Guid UserId, string Canal, string TemplateId);
