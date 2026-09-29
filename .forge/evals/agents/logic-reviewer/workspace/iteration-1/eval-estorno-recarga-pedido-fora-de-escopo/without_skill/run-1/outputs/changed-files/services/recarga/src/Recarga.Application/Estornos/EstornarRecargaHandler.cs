using Microsoft.Extensions.Logging;
using Recarga.Application.Abstractions;

namespace Recarga.Application.Estornos;

public sealed record EstornarRecargaCommand(Guid RecargaId, string CpfTitular, long ValorADevolverEmCentavos);

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

        // LGPD: nunca logar o CPF do titular em claro; registrar apenas um identificador não reversível.
        _logger.LogInformation(
            "Estorno solicitado para recarga {RecargaId}, titular hash={CpfHash}",
            comando.RecargaId,
            MascararCpf(comando.CpfTitular));

        recarga.Estornar(comando.ValorADevolverEmCentavos);
        await _recargas.AtualizarAsync(recarga, ct);
    }

    private static string MascararCpf(string cpf)
    {
        if (string.IsNullOrEmpty(cpf) || cpf.Length < 4) return "***";
        return $"***{cpf[^4..]}";
    }
}
