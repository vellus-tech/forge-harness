using MassTransit;
using Recarga.Contracts.Events;
using Recarga.Domain.Entities;
using Recarga.Domain.Repositories;

namespace Recarga.Application.Handlers;

public sealed class SolicitarRecargaHandler
{
    private const long LimiteDiarioCentavos = 50_000;

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
        var totalHoje = await _repositorio.ObterTotalConfirmadoNoDiaAsync(numeroLogicoCartao, hoje, ct);
        if (totalHoje + valorCentavos > LimiteDiarioCentavos)
        {
            throw new InvalidOperationException("limite diário de recarga excedido");
        }

        var recarga = new RecargaCartao
        {
            Id = Guid.NewGuid(),
            NumeroLogicoCartao = numeroLogicoCartao,
            ValorCentavos = valorCentavos,
        };
        await _repositorio.AdicionarAsync(recarga, ct);

        recarga.Confirmar();
        await _barramento.Publish(new RecargaConfirmada(recarga.Id, recarga.NumeroLogicoCartao, recarga.ValorCentavos), ct);
    }
}
