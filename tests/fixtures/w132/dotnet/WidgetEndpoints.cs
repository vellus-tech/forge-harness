namespace Fixture.Api.Widgets;

public static class WidgetEndpoints
{
    public static RouteGroupBuilder MapWidgetEndpoints(this RouteGroupBuilder group)
    {
        group.MapGet("/status", Status)
            .WithName("WidgetStatus");

        group.MapPost("/dispatch", Dispatch)
            .WithName("WidgetDispatch");

        // Constraint de rota: sem normalizePath isto vira falso positivo contra o contrato,
        // que escreve `{sequence}` sem o `:long`.
        group.MapGet("/items/{tenant}/{sequence:long}/export", Export)
            .WithName("WidgetExport");

        // Segundo salto: a rota final nasce de três arquivos e nenhuma linha a contém inteira.
        group.MapWidgetStreamEndpoints();

        return group;
    }
}
