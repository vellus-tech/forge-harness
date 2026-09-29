using Cashback.Infrastructure.Carteira;
using Xunit;

namespace Cashback.UnitTests;

public sealed class CarteiraClientTests
{
    [Fact]
    public async Task CreditarAsync_sends_idempotency_key_header()
    {
        HttpRequestMessage? capturedRequest = null;
        var handler = new StubHttpMessageHandler(request =>
        {
            capturedRequest = request;
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK);
        });

        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://carteira-api.internal") };
        var client = new CarteiraClient(httpClient);
        var request = new CreditoRequest(Guid.NewGuid(), 9, "cashback-viagem-validada");

        await client.CreditarAsync(request, "cashback-viagem-abc123", CancellationToken.None);

        Assert.NotNull(capturedRequest);
        Assert.True(capturedRequest!.Headers.TryGetValues("Idempotency-Key", out var values));
        Assert.Equal("cashback-viagem-abc123", Assert.Single(values!));
    }

    private sealed class StubHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(respond(request));
    }
}
