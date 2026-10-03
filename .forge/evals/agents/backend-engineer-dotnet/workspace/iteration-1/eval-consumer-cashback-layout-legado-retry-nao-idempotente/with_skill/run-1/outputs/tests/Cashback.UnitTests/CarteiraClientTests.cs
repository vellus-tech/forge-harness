using System.Net;
using Cashback.Infrastructure.Carteira;
using Xunit;

namespace Cashback.UnitTests;

public sealed class CarteiraClientTests
{
    [Fact]
    public async Task CreditarAsync_envia_idempotency_key_no_header()
    {
        HttpRequestMessage? capturado = null;
        var handler = new StubHandler(request =>
        {
            capturado = request;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        });
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://carteira-api.internal") };
        var sut = new CarteiraClient(httpClient);

        await sut.CreditarAsync(new CreditoRequest(Guid.NewGuid(), 100, "cashback"), idempotencyKey: "evento-1", CancellationToken.None);

        Assert.NotNull(capturado);
        Assert.True(capturado!.Headers.TryGetValues("Idempotency-Key", out var valores));
        Assert.Equal("evento-1", Assert.Single(valores!));
    }

    [Fact]
    public async Task CreditarAsync_exige_idempotency_key()
    {
        using var httpClient = new HttpClient(new StubHandler(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK))))
        {
            BaseAddress = new Uri("http://carteira-api.internal"),
        };
        var sut = new CarteiraClient(httpClient);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            sut.CreditarAsync(new CreditoRequest(Guid.NewGuid(), 100, "cashback"), idempotencyKey: "", CancellationToken.None));
    }

    private sealed class StubHandler(Func<HttpRequestMessage, Task<HttpResponseMessage>> handle) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            handle(request);
    }
}
