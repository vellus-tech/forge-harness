using Microsoft.Extensions.Logging;

namespace Webhooks.Api.Handlers;

public sealed record PartnerCallback(string PartnerId, string UserEmail, string EventType, string Payload);

public sealed class PartnerCallbackHandler
{
    private readonly ILogger<PartnerCallbackHandler> _logger;

    public PartnerCallbackHandler(ILogger<PartnerCallbackHandler> logger) => _logger = logger;

    public Task Handle(PartnerCallback cb, CancellationToken ct)
    {
        // só aparece em Debug, ou seja, só em dev
        _logger.LogDebug("Callback do parceiro {PartnerId} para {UserEmail}: {EventType}", cb.PartnerId, cb.UserEmail, cb.EventType);
        return Task.CompletedTask;
    }
}
