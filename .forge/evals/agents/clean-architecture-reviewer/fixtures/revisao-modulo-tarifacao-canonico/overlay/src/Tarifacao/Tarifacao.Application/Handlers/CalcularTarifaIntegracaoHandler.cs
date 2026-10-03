using Tarifacao.Domain.Repositories;

namespace Tarifacao.Application.Handlers;

public sealed class CalcularTarifaIntegracaoHandler
{
    private readonly ITarifaRepository _repositorio;

    public CalcularTarifaIntegracaoHandler(ITarifaRepository repositorio) => _repositorio = repositorio;

    public async Task<long> HandleAsync(string linha, string modalAnterior, DateTime embarqueAnterior, DateTime agora, CancellationToken ct)
    {
        var tarifa = await _repositorio.ObterPorLinhaAsync(linha, ct) ?? throw new InvalidOperationException("tarifa inexistente");
        var minutos = (agora - embarqueAnterior).TotalMinutes;
        if (minutos <= 120 && modalAnterior != tarifa.Modal)
        {
            return tarifa.ValorCentavos * 75 / 100;
        }
        else
        {
            return tarifa.ValorCentavos;
        }
    }
}
