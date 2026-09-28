using Tarifa.Application;
using Tarifa.Domain;
using Xunit;

namespace Tarifa.UnitTests;

public sealed class ReajustarTarifaHandlerTests
{
    private sealed class FakeTarifaRepository : ITarifaRepository
    {
        private readonly Dictionary<Guid, TarifaLinha> _tarifas = new();

        public void Seed(TarifaLinha tarifa) => _tarifas[tarifa.LinhaId] = tarifa;

        public Task<TarifaLinha?> FindAsync(Guid linhaId, CancellationToken cancellationToken) =>
            Task.FromResult(_tarifas.TryGetValue(linhaId, out var tarifa) ? tarifa : null);

        public Task SaveAsync(TarifaLinha tarifa, CancellationToken cancellationToken)
        {
            _tarifas[tarifa.LinhaId] = tarifa;
            return Task.CompletedTask;
        }
    }

    [Fact]
    public async Task HandleAsync_returns_sucesso_and_persists_novo_valor()
    {
        var linhaId = Guid.NewGuid();
        var repository = new FakeTarifaRepository();
        repository.Seed(new TarifaLinha(linhaId, 430));
        var handler = new ReajustarTarifaHandler(repository);

        var result = await handler.HandleAsync(linhaId, 1250, CancellationToken.None);

        Assert.Equal(ReajustarTarifaResultado.Sucesso, result.Resultado);
        Assert.NotNull(result.Response);
        Assert.Equal(linhaId, result.Response!.LinhaId);
        Assert.Equal(430, result.Response.ValorAnteriorCentavos);
        Assert.Equal(484, result.Response.ValorNovoCentavos);

        var persistida = await repository.FindAsync(linhaId, CancellationToken.None);
        Assert.Equal(484, persistida!.ValorCentavos);
    }

    [Fact]
    public async Task HandleAsync_returns_linha_nao_encontrada_when_missing()
    {
        var repository = new FakeTarifaRepository();
        var handler = new ReajustarTarifaHandler(repository);

        var result = await handler.HandleAsync(Guid.NewGuid(), 1250, CancellationToken.None);

        Assert.Equal(ReajustarTarifaResultado.LinhaNaoEncontrada, result.Resultado);
        Assert.Null(result.Response);
    }

    [Fact]
    public async Task HandleAsync_returns_percentual_invalido_without_touching_tarifa()
    {
        var linhaId = Guid.NewGuid();
        var repository = new FakeTarifaRepository();
        repository.Seed(new TarifaLinha(linhaId, 430));
        var handler = new ReajustarTarifaHandler(repository);

        var result = await handler.HandleAsync(linhaId, 5001, CancellationToken.None);

        Assert.Equal(ReajustarTarifaResultado.PercentualInvalido, result.Resultado);
        Assert.Null(result.Response);

        var inalterada = await repository.FindAsync(linhaId, CancellationToken.None);
        Assert.Equal(430, inalterada!.ValorCentavos);
    }
}
