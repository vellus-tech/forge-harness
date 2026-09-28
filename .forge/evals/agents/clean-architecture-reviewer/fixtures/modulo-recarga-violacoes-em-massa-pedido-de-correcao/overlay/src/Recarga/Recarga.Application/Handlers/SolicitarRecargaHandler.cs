using MassTransit;
using Microsoft.EntityFrameworkCore;
using Recarga.Domain.Entities;
using Recarga.Domain.Repositories;

namespace Recarga.Application.Handlers;

public sealed class SolicitarRecargaHandler
{
    private readonly IRecargaRepository _repositorio;
    private readonly IPublishEndpoint _barramento;

    public SolicitarRecargaHandler(IRecargaRepository repositorio, IPublishEndpoint barramento)
    {
        _repositorio = repositorio;
        _barramento = barramento;
    }

    public async Task HandleAsync(string numeroLogicoCartao, long valorCentavos, CancellationToken ct)
    {
        var hoje = DateTime.UtcNow.Date;
        var totalHoje = await _repositorio.Recargas
            .Where(r => r.NumeroLogicoCartao == numeroLogicoCartao && r.Status == "CONFIRMADA")
            .SumAsync(r => r.ValorCentavos, ct);
        if (totalHoje + valorCentavos > 50_000)
        {
            throw new InvalidOperationException("limite diário de recarga excedido");
        }
        var recarga = new RecargaCartao { Id = Guid.NewGuid(), NumeroLogicoCartao = numeroLogicoCartao, ValorCentavos = valorCentavos };
        _repositorio.Recargas.Add(recarga);
        await recarga.ConfirmarAsync(_barramento);
    }
}
