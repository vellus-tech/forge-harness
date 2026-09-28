using Cashback.Infrastructure.Carteira;
using Cashback.Worker.Consumers;
using Cashback.Worker.Contracts;
using MassTransit;
using MassTransit.Testing;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Cashback.UnitTests;

public sealed class ViagemValidadaConsumerTests
{
    [Fact]
    public async Task Consume_credita_cashback_com_idempotency_key_do_evento_e_publica_evento()
    {
        var carteiraFake = new CarteiraClientFake();
        await using var provider = new ServiceCollection()
            .AddSingleton<ICarteiraClient>(carteiraFake)
            .AddMassTransitTestHarness(cfg => cfg.AddConsumer<ViagemValidadaConsumer>())
            .BuildServiceProvider(validateScopes: true);

        var harness = provider.GetRequiredService<ITestHarness>();
        await harness.Start();

        var evento = new ViagemValidada(
            EventoId: Guid.NewGuid(),
            PassageiroId: Guid.NewGuid(),
            TarifaCentavos: 10_000,
            ValidadaEm: DateTimeOffset.UtcNow,
            CorrelationId: "corr-1");

        await harness.Bus.Publish(evento);

        Assert.True(await harness.Consumed.Any<ViagemValidada>());
        Assert.True(await harness.Published.Any<CashbackCreditado>());

        var chamada = Assert.Single(carteiraFake.Chamadas);
        Assert.Equal(evento.EventoId.ToString(), chamada.IdempotencyKey);
        Assert.Equal(evento.PassageiroId, chamada.Request.PassageiroId);
        Assert.Equal(200, chamada.Request.ValorCentavos);
    }

    [Fact]
    public async Task Consume_nao_credita_quando_tarifa_nao_e_positiva()
    {
        var carteiraFake = new CarteiraClientFake();
        await using var provider = new ServiceCollection()
            .AddSingleton<ICarteiraClient>(carteiraFake)
            .AddMassTransitTestHarness(cfg => cfg.AddConsumer<ViagemValidadaConsumer>())
            .BuildServiceProvider(validateScopes: true);

        var harness = provider.GetRequiredService<ITestHarness>();
        await harness.Start();

        var evento = new ViagemValidada(Guid.NewGuid(), Guid.NewGuid(), TarifaCentavos: 0, DateTimeOffset.UtcNow, "corr-2");
        await harness.Bus.Publish(evento);

        Assert.True(await harness.Consumed.Any<ViagemValidada>());
        Assert.Empty(carteiraFake.Chamadas);
        Assert.False(await harness.Published.Any<CashbackCreditado>());
    }

    private sealed class CarteiraClientFake : ICarteiraClient
    {
        public List<(CreditoRequest Request, string IdempotencyKey)> Chamadas { get; } = [];

        public Task CreditarAsync(CreditoRequest request, string idempotencyKey, CancellationToken cancellationToken)
        {
            Chamadas.Add((request, idempotencyKey));
            return Task.CompletedTask;
        }
    }
}
