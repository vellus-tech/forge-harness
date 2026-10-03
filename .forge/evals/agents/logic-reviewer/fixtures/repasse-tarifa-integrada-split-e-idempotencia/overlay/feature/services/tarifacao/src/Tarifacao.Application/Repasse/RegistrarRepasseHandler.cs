using Tarifacao.Application.Abstractions;
using Tarifacao.Domain.Repasse;

namespace Tarifacao.Application.Repasse;

public sealed record RegistrarRepasseCommand(string ChaveIdempotencia, string ViagemId, decimal TarifaTotal, string[] Operadoras);

public sealed class RegistrarRepasseHandler
{
    private readonly IRepasseRepository _repositorio;

    public RegistrarRepasseHandler(IRepasseRepository repositorio) => _repositorio = repositorio;

    public async Task<Guid> Handle(RegistrarRepasseCommand comando, CancellationToken ct)
    {
        // Idempotency check: se a chave já foi processada, devolve o repasse existente (REQ-4).
        var repasseId = Guid.NewGuid();
        var partes = RepasseTarifa.Dividir(comando.TarifaTotal, comando.Operadoras.Length);
        await _repositorio.SalvarAsync(repasseId, comando.ChaveIdempotencia, comando.ViagemId, comando.Operadoras, partes, ct);
        return repasseId;
    }
}
