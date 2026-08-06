// Fixture DERIVADO do padrão real de composição de rotas: prefixo num arquivo, sufixo em outro.
// Nomes e domínio são inventados — nenhum artefato de cliente entra no repositório publicado.
namespace Fixture.Api;

public static class ApiHost
{
    public static WebApplication MapAll(this WebApplication app)
    {
        var health = app.MapGroup("/health").WithTags("Infra");
        health.MapGet("/live", () => "ok");

        var widgets = app.MapGroup("/internal/v1/widgets")
            .WithTags("Widgets");
        widgets.MapWidgetEndpoints();

        return app;
    }
}
