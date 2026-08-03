namespace Fixture.Api.Widgets;

public static class WidgetStreamEndpoints
{
    public static RouteGroupBuilder MapWidgetStreamEndpoints(this RouteGroupBuilder group)
    {
        group.MapGet("/events/stream", Stream)
            .WithName("WidgetEventStream");

        return group;
    }
}
