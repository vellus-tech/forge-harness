using Microsoft.Extensions.Logging;
using Recarga.Application.Abstractions;

namespace Recarga.Application.Estornos;

public sealed record EstornarRecargaCommand(Guid RecargaId, string CpfTitular);

public sealed class EstornarRecargaHandler
{
    private readonly IRecargaRepository _recargas;
    private readonly ILogger<EstornarRecargaHandler> _logger;

    public EstornarRecargaHandler(IRecargaRepository recargas, ILogger<EstornarRecargaHandler> logger)
    {
        _recargas = recargas;
        _logger = logger;
    }

    public async Task Handle(EstornarRecargaCommand comando, CancellationToken ct)
    {
        var recarga = await _recargas.ObterAsync(comando.RecargaId, ct)
            ?? throw new InvalidOperationException($"Recarga {comando.RecargaId} não encontrada.");
        _logger.LogInformation("Estorno solicitado pelo titular {Cpf}", comando.CpfTitular);
        recarga.Estornar();
        await _recargas.AtualizarAsync(recarga, ct);
    }
}
